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

// Use cla
// --register

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    var cwd = fs.cwd();
    var name: []const u8 = ".";

    if (args.len == 1) {
        name = args[0];
        var dir = try cwd.makeOpenPath(name, .{});
        defer dir.close();
        try dir.setAsCwd();
    } else if (args.len > 1) {
        logf(Log.Err, "Expected olny one argument, got {}.", .{args.len});
        return Err.TooManyArgs;
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
}
