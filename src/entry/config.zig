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
const child = @import("../common/child.zig");

const buildJSON = @import("../json/build.json.zig");
const Build = buildJSON.Build;
const loadBuild = buildJSON.load;

const ensureProject = @import("ensureProject.zig").ensureProject;
const cla = @import("cla.zig");

const default_gitignore = "build\n./trsp\n";

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 0, .long = "project-name" },
        .{ .short = 0, .long = "git" },
        .{ .short = 't', .long = "register-template" },
        .{ .short = 'l', .long = "register-language" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Err, "Unknown argument \"{?s}\"", .{arg.value});
            return Err.BadArg;
        }

        const short = descriptions[@bitCast(arg.id)].short;
        if (short == 0) {
            const a = descriptions[@bitCast(arg.id)].long;
            if (mem.eql(u8, a, "project-name")) {
                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                try rename(cwd, allocator, arg.value.?);
            } else if (mem.eql(u8, a, "git")) {
                if (arg.value != null) {
                    log(Log.Err, "Unexpected value for 'git' flag.");
                    return Err.BadArg;
                }

                try git(cwd);
            } else {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            }
        } else {
            switch (short) {
                't' => {
                    if (arg.value == null) {
                        log(Log.Err, "Excepted value.");
                        log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                        return Err.NoValue;
                    }

                    try registerTemplate(cwd, allocator, arg.value.?);
                },
                'l' => {
                    if (arg.value == null) {
                        log(Log.Err, "Excepted value.");
                        log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                        return Err.NoValue;
                    }

                    try registerLanguage(cwd, allocator, arg.value.?);
                },
                else => {
                    logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                    return Err.BadArg;
                },
            }
        }
    }

    log(Log.Inf, "Succefully reconfigured.");
}

fn rename(cwd: fs.Dir, allocator: mem.Allocator, name: []const u8) !void {
    var build = try loadBuild(cwd, allocator);
    defer build.deinit();

    const name_cpy = try str.copy(name, allocator);
    defer allocator.free(name_cpy);

    const newBuild: Build = .{
        .name = name_cpy,
        .builder = build.value.builder,
    };

    log(Log.Inf, "Updating trsp.conf/build.json");

    var file = try cwd.openFile("trsp.conf/build.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    var writer = file.writer();
    try json.stringify(newBuild, .{}, writer);
    _ = try writer.write("\n"); // Wreid error with additional } at the end of file

    log(Log.Inf, "Done");
}

fn git(cwd: fs.Dir) !void {
    var accessed = true;
    cwd.access(".git", .{}) catch |e| switch (e) {
        fs.Dir.AccessError.FileNotFound => {
            accessed = false;

            log(Log.Inf, "Initializing git...");
            try child.run(&[_][]const u8{ "git", "init" });

            log(Log.Inf, "Creating .gitignore...");
            try cwd.writeFile(".gitignore", default_gitignore);
        },
        else => {
            log(Log.Err, "Unknown error.");
            return e;
        },
    };

    if (accessed) {
        log(Log.Err, "Git already initiated!");
        return Err.CannotPerform;
    }

    log(Log.Inf, "Done");
}

fn registerTemplate(cwd: fs.Dir, allocator: mem.Allocator, path: []const u8) !void {
    _ = cwd;
    _ = allocator;
    _ = path;
}

fn registerLanguage(cwd: fs.Dir, allocator: mem.Allocator, path: []const u8) !void {
    _ = cwd;
    _ = allocator;
    _ = path;
}
