const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const str = @import("../common/str.zig");

const buildJSON = @import("../json/build.json.zig");
const Build = buildJSON.Build;
const loadBuild = buildJSON.load;

const ensureProject = @import("ensureProject.zig").ensureProject;
const cla = @import("cla.zig");

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 0, .long="project-name" }
    };
    
    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Err, "Unknown argument \"{?s}\"", .{arg.value});
            return Err.BadArg;
        }

        const a = descriptions[@bitCast(arg.id)].long;
        if(mem.eql(u8, a, "project-name")){
            if (arg.value == null) {
                log(Log.Err, "Excepted value.");
                log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                return Err.NoValue;
            }

            var build = try loadBuild(cwd, allocator);
            defer build.deinit();

            var name_cpy = try str.copy(arg.value.?, allocator);
            defer name_cpy.deinit();

            const newBuild: Build = .{
                .name = name_cpy.items,
                .builder = build.value.builder,
                .gen = build.value.gen,
            };

            log(Log.Inf, "Updating trsp.conf/build.json");

            var file = try cwd.openFile("trsp.conf/build.json", .{ .mode = fs.File.OpenMode.write_only });
            defer file.close();
  
            var writer = file.writer();
            try json.stringify(newBuild, .{}, writer);
            _ = try writer.write("\n"); // Wreid error with additional } at the end of file

            log(Log.Inf, "Done");
        } else {
            logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
            return Err.BadArg;
        }
    }

    log(Log.Inf, "Succefully reconfigured.");
}

