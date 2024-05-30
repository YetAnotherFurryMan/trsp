const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const default = @import("../defaults.zig");

const templatesJSON = @import("../json/templates.json.zig");
const TemplateFile = templatesJSON.TemplateFile;
const Template = templatesJSON.Template;
const NamedTemplate = struct { name: []const u8, tmpl: Template };

const str = @import("../common/str.zig");

const cla = @import("cla.zig");
const ensureProject = @import("ensureProject.zig").ensureProject;

// Use HashMap instead of ArrayLists
pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 0, .long = "c++" },
        .{ .short = 0, .long = "zig" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    var templates = std.ArrayList(NamedTemplate).init(allocator);
    defer templates.deinit();

    var names = std.ArrayList([]const u8).init(allocator);
    defer names.deinit();

    var parse_to_deinit = std.ArrayList(json.Parsed(Template)).init(allocator);
    defer {
        while (parse_to_deinit.popOrNull()) |e| {
            e.deinit();
        }
        parse_to_deinit.deinit();
    }

    var tmpls = try templatesJSON.list(cwd, allocator);
    defer tmpls.deinit();

    try names.appendSlice(tmpls.value);

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Deb, "Loading src: {s}", .{arg.value.?});
            const t = try templatesJSON.loadPath(cwd, arg.value.?, allocator);
            try parse_to_deinit.append(t);

            const name = fs.path.basename(arg.value.?);
            if (!str.validNameExt(name)) {
                logf(Log.Err, "Template name \"{s}\" is invalid.", .{name});
                log(Log.Inf, "Try renaming the file.");
                continue;
            }

            const tt = NamedTemplate{ .name = name, .tmpl = t.value };
            try templates.append(tt);
            try names.append(name);
        } else if (mem.eql(u8, descriptions[@bitCast(arg.id)].long, "c++")) {
            const t = try json.parseFromSlice(Template, allocator, default.defaultCXXTemplate, .{});
            try parse_to_deinit.append(t);
            try templates.append(.{ .name = "c++", .tmpl = t.value });
            try names.append("c++");
        } else if (mem.eql(u8, descriptions[@bitCast(arg.id)].long, "zig")) {
            const t = try json.parseFromSlice(Template, allocator, default.defaultZigTemplate, .{});
            try parse_to_deinit.append(t);
            try templates.append(.{ .name = "zig", .tmpl = t.value });
            try names.append("zig");
        } else {
            logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
            return Err.BadArg;
        }
    }

    log(Log.Inf, "Updating templates.json...");

    var file = try cwd.openFile("trsp.conf/templates.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    var writer = file.writer();
    try json.stringify(names.items, .{}, writer);
    _ = try writer.write("\n\n"); // Wreid error with additional } at the end of file

    while (templates.popOrNull()) |t| {
        const path = try mem.concat(allocator, u8, &[_][]const u8{ "trsp.conf/templates/", t.name, ".json" });
        defer allocator.free(path);

        var f = try cwd.createFile(path, .{});
        defer f.close();

        var w = f.writer();
        try json.stringify(t.tmpl, .{}, w);
        _ = try w.write("\n\n");
    }

    log(Log.Inf, "Succesfully added templates.");
}
