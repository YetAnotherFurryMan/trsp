const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const templatesJSON = @import("../json/templates.json.zig");
const Template = templatesJSON.Template;

const cla = @import("cla.zig");
const ensureProject = @import("ensureProject.zig").ensureProject;

const Src = struct{ path: []const u8, list: bool };

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 'l', .long = "list" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    var srcs = std.ArrayList(Src).init(allocator);
    defer srcs.deinit();

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            try srcs.append(.{ .path = arg.value.?, .list = false });
        } else{
            if(arg.value == null){
                log(Log.Err, "Excepted value.");
                log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                return Err.NoValue;
            }

            try srcs.append(.{ .path = arg.value.?, .list = true });
        }
    }

    var templates = std.ArrayList(Template).init(allocator);
    defer templates.deinit();

    var tmpls = try templatesJSON.load(cwd, allocator);
    defer tmpls.deinit();

    try templates.appendSlice(tmpls.value);

    while(srcs.popOrNull()) |src| {
        logf(Log.Deb, "Loading src: {}", .{src});
        if(src.list){
            const t = try templatesJSON.loadCustomList(cwd, src.path, allocator);
            defer t.deinit();

            try templates.appendSlice(t.value);
        }

        const t = try templatesJSON.loadCustom(cwd, src.path, allocator);
        defer t.deinit();

        try templates.append(t.value);
    }

    var file = try cwd.openFile("trsp.conf/templates.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    var writer = file.writer();
    try json.stringify(templates.items, .{}, writer);
    _ = try writer.write("\n"); // Wreid error with additional } at the end of file
    
    log(Log.Inf, "Succesfully added templates.");
}

