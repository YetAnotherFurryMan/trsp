const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const defaults = @import("../defaults.zig");

const str = @import("../common/str.zig");

const defaultBuildJSON = "{\"name\":\"${name}\",\"builder\":\"Ninja\"}";
const defaultModulesJSON = "[]";
const defaultProjectsJSON = "[]";

const defaultTemplatesJSON = "[\"c\"]";
const defaultLanguagesJSON = "[\"c\",\"cxx\",\"zig\"]";

const cla = @import("cla.zig");

pub fn entry(argsx: [][:0]const u8, allocator: mem.Allocator) !void {
    var cwd = fs.cwd();

    var args = argsx;
    var name: []const u8 = ".";
    var nameChanged = false;
    var register: bool = false;

    // The project name may be the first word after task, otherwise it is under -n flag or was not seted
    if (args[0][0] != '-') {
        name = args[0];
        nameChanged = true;
        args = args[1..];

        var dir = try cwd.makeOpenPath(name, .{});
        defer dir.close();
        try dir.setAsCwd();
    }

    log(Log.Deb, "Parsing command-line arguments...");

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 'n', .long = "name" },
        .{ .short = 'r', .long = "register" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Err, "Unknown argument \"{?s}\"", .{arg.value});
            return Err.BadArg;
        }

        switch (descriptions[@bitCast(arg.id)].short) {
            'n' => {
                if (nameChanged) {
                    logf(Log.Err, "Module name already changed \"{?s}\" > \"{?s}\"", .{ name, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                name = arg.value.?;

                var dir = try cwd.makeOpenPath(name, .{});
                defer dir.close();
                try dir.setAsCwd();
            },
            'r' => {
                if (register) {
                    log(Log.Err, "Register flag already seted.");
                    return Err.Changed;
                }

                register = true;
            },
            else => {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            },
        }
    }

    // Validate name
    if (mem.eql(u8, name, ".")) {
        name = "root";
        log(Log.War, "Using default project name: \"root\"!");
        log(Log.Inf, "To change project name use:");
        log(Log.Inf, "    ./trsp config --project-name=$NAME");
    }

    if (!str.validName(name)) {
        logf(Log.Err, "Name \"{s}\" is not valid!", .{name});
        return Err.InvalidName;
    }

    cwd = fs.cwd();

    const dir_path = try cwd.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    logf(Log.Inf, "Using \"{s}\" directory...", .{dir_path});

    const exeDir_path = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exeDir_path);

    var exe_path = try fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);

    const exe = exe_path[exeDir_path.len + 1 ..];

    logf(Log.Inf, "Coping \"{s}\": \"{s}\" => \"{s}\"", .{ exe, exeDir_path, dir_path });

    var exeDir = try fs.openDirAbsolute(exeDir_path, .{});
    defer exeDir.close();

    try exeDir.copyFile(exe, cwd, "trsp", .{});

    if (!register) {
        log(Log.Inf, "Generating configuration...");

        var conf = try cwd.makeOpenPath("trsp.conf", .{});
        defer conf.close();

        const myBuildJSON_size = mem.replacementSize(u8, defaultBuildJSON, "${name}", name);
        const myBuildJSON = try allocator.alloc(u8, myBuildJSON_size);
        defer allocator.free(myBuildJSON);
        _ = mem.replace(u8, defaultBuildJSON, "${name}", name, myBuildJSON);

        try conf.writeFile("build.json", myBuildJSON);
        try conf.writeFile("modules.json", defaultModulesJSON);
        try conf.writeFile("projects.json", defaultProjectsJSON);
        try conf.writeFile("templates.json", defaultTemplatesJSON);
        try conf.writeFile("languages.json", defaultLanguagesJSON);

        var tmpls = try conf.makeOpenPath("templates", .{});
        defer tmpls.close();

        try tmpls.writeFile("c.json", defaults.defaultCTemplate);

        var langs = try conf.makeOpenPath("languages", .{});
        defer langs.close();

        try langs.writeFile("c.json", defaults.defaultCLanguage);
        try langs.writeFile("cxx.json", defaults.defaultCXXLanguage);
        try langs.writeFile("zig.json", defaults.defaultZigLanguage);

        logf(Log.Inf, "Succesfully generated project \"{s}\"!", .{name});

        log(Log.War, "TIPS:");
        log(Log.Inf, "To initialize git use:");
        log(Log.Inf, "    ./trsp config --git");
    } else {
        logf(Log.Inf, "Successfully registered project \"{s}\"!", .{name});
    }
}
