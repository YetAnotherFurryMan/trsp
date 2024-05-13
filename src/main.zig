const std = @import("std");
const process = std.process;
const heap = std.heap;
const json = std.json;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const io = std.io;

const l = @import("./log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const templateJSON = @import("json/templates.json.zig");
const Template = templateJSON.Template;
const loadTemplates = templateJSON.load;

const modulesJSON = @import("json/modules.json.zig");
const ModType = modulesJSON.ModType;
const Module = modulesJSON.Module;
const loadModules = modulesJSON.load;

const projectsJSON = @import("json/projects.json.zig");
const Project = projectsJSON.Project;
const loadProjects = projectsJSON.load;

const buildJSON = @import("json/build.json.zig");
const BuildBuilder = buildJSON.BuildBuilder;
const BuildGen = buildJSON.BuildGen;
const Build = buildJSON.Build;
const loadBuild = buildJSON.load;

const cmake = @import("gen/cmake.zig");

const defaultBuildJSON = "{\"name\":\"${name}\",\"gen\":\"Zig\",\"builder\":\"Ninja\"}";
const defaultModulesJSON = "[]";
const defaultProjectsJSON = "[]";
const defaultTemplatesJSON = "[{\"name\":\"c\",\"exe\":{\"head\":[],\"src\":[{\"name\":\"main.c\",\"cnt\":\"#include <stdio.h>\\n\\nint main(int argc, const char** argv){\\n    printf(\\\"Hello World!\\\\n\\\");\\n    return 0;\\n}\\n\"}]},\"shared\":{\"head\":[{\"name\":\"${module}.h\",\"cnt\":\"#ifndef _${module}_H_\\n#define _${module}_H_\\n\\nvoid hello();\\n\\n#endif\"}],\"src\":[{\"name\":\"${module}.c\",\"cnt\":\"#include <stdio.h>\\n\\nvoid hello(){\\n    printf(\\\"Hello World!\\\\n\\\");\\n}\\n\"}]},\"static\":{\"head\":[{\"name\":\"${module}.h\",\"cnt\":\"#ifndef _${module}_H_\\n#define _${module}_H_\\n\\nvoid hello();\\n\\n#endif\"}],\"src\":[{\"name\":\"${module}.c\",\"cnt\":\"#include <stdio.h>\\n\\nvoid hello(){\\n    printf(\\\"Hello World!\\\\n\\\");\\n}\\n\"}]}}]";

const Err = error{
    NoArgs,
    TooManyArgs,
    NotEnoughArgs,
    Changed,
    BadArg,
    NoValue,
    NoName,
    NoModule,
    NoProject,
    BadTask,
    BadName,
    NameUsed,
    BadTemplate,
    BadGenerator,
    BadBuilder,
    Unreachable,
};

const ArgDescription = struct { short: u8, long: []const u8 };
const Arg = struct { id: i64, value: ?[]const u8 };

fn amIProject() bool {
    const file = fs.cwd().openFile("trsp", .{}) catch {
        return false;
    };
    file.close();
    return true;
}

inline fn ensureProject() !void {
    if (!amIProject()) {
        log(Log.Err, "Project not detected.");
        log(Log.Note, "Try \'trsp init\'");
        return Err.NoProject;
    }
}

inline fn copyStr(str: []const u8, allocator: mem.Allocator) !std.ArrayList(u8) {
    var copy = std.ArrayList(u8).init(allocator);
    try copy.appendSlice(str);
    return copy;
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    logf(Log.Deb, "Argc: {}", .{args.len});
    for (args) |arg| {
        logf(Log.Deb, "    Arg: {s}", .{arg});
    }

    if (args.len <= 1) {
        log(Log.Err, "Expected at least one argument.");
        return Err.NoArgs;
    }

    const program = args[0];
    const task = args[1];

    logf(Log.Inf, "Program: {s}", .{program});

    const taskArgs = args[2..];
    if (mem.eql(u8, task, "init")) {
        return init(taskArgs, allocator);
    } else if (mem.eql(u8, task, "module")) {
        return module(taskArgs, allocator);
    } else if (mem.eql(u8, task, "build")) {
        return build(taskArgs, allocator);
    } else if (mem.eql(u8, task, "release")) {
        return release(taskArgs, allocator);
    } else if (mem.eql(u8, task, "set")) {
        return set(taskArgs, allocator);
    } else {
        logf(Log.Err, "Unknown task: {s}", .{task});
        return Err.BadTask;
    }
}

fn parseCLA(args: [][:0]const u8, desc: []const ArgDescription, allocator: mem.Allocator) !std.ArrayList(Arg) {
    var out = std.ArrayList(Arg).init(allocator);

    for (args) |arg| {
        var a: Arg = .{ .id = -1, .value = arg };
        if (arg[0] == '-') {
            if (arg.len == 1) {
                a.id = -2;
            } else if (arg[1] == '-') {
                if (arg.len == 2) {
                    a.id = -2;
                } else {
                    var argx = mem.split(u8, arg[2..], "=");
                    const argName = argx.next().?;
                    const argValue = argx.next();
                    for (desc, 0..) |d, i| {
                        if (mem.eql(u8, argName, d.long)) {
                            a.id = @bitCast(i);
                            a.value = argValue;
                            break;
                        }
                    }
                }
            } else {
                for (desc, 0..) |d, i| {
                    if (arg[1] == d.short) {
                        a.id = @bitCast(i);
                        if (arg.len > 2) {
                            a.value = arg[2..];
                        } else {
                            a.value = null;
                        }
                        break;
                    }
                }
            }
        }
        try out.append(a);
    }
    return out;
}

fn init(args: [][:0]const u8, allocator: mem.Allocator) !void {
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

    if(mem.eql(u8, name, ".")){
        name = "root";
        log(Log.War, "Using default project name: \"root\"!");
        log(Log.Inf, "To change project name use:");
        log(Log.Inf, "    ./trsp set --project-name=$NAME");
    }

    const myBuildJSON_size = mem.replacementSize(u8, defaultBuildJSON, "${name}", name);
    const myBuildJSON = try allocator.alloc(u8, myBuildJSON_size);
    defer allocator.free(myBuildJSON);
    _ = mem.replace(u8, defaultBuildJSON, "${name}", name, myBuildJSON);

    try conf.writeFile("build.json", myBuildJSON);
    try conf.writeFile("modules.json", defaultModulesJSON);
    try conf.writeFile("projects.json", defaultProjectsJSON);
    try conf.writeFile("templates.json", defaultTemplatesJSON);

    logf(Log.Inf, "Succesfully generated project \"{s}\"!", .{name});
}

fn module(argsx: [][:0]const u8, allocator: mem.Allocator) !void {
    if (argsx.len < 1) {
        log(Log.Err, "Excepted at least module name.");
        return Err.NotEnoughArgs;
    }

    try ensureProject();

    const cwd = fs.cwd();

    var args = argsx;
    var name: ?[]const u8 = null;
    var nameChanged = false;
    var template: ?[]const u8 = null;
    var modType: ModType = ModType.Default;

    // The module name may be the first word after task, otherwise it is under -n flag
    if (args[0][0] != '-') {
        name = args[0];
        nameChanged = true;
        args = args[1..];
    }

    log(Log.Inf, "Parsing command-line arguments...");

    const descriptions = [_]ArgDescription{
        .{ .short = 'n', .long = "name" },
        .{ .short = 't', .long = "template" },
        .{ .short = 'e', .long = "exe" },
        .{ .short = 'l', .long = "lib" },
        .{ .short = 'd', .long = "dll" },
    };

    var argList = try parseCLA(args, &descriptions, allocator);
    defer argList.deinit();

    log(Log.Inf, "Loading data...");

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

                name = arg.value;
            },
            't' => {
                if (template != null) {
                    logf(Log.Err, "Template name already changed \"{?s}\" > \"{?s}\"", .{ template, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                template = arg.value;
            },
            'e' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.Executable;
            },
            'l' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.StaticLibrary;
            },
            'd' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.SharedLibrary;
            },
            else => {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            },
        }
    }

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    var projects = try loadProjects(cwd, allocator);
    defer projects.deinit();

    var templates = try loadTemplates(cwd, allocator);
    defer templates.deinit();

    log(Log.Inf, "Validating data...");

    if (name == null) {
        log(Log.Err, "No module name given.");
        return Err.NoName;
    }

    if (template == null) {
        template = "c";
    }

    if (modType == ModType.Default) {
        modType = ModType.Executable;
    }

    if (mem.eql(u8, name.?, "build")) {
        log(Log.Err, "Bad module name: \"build\" is a reserved name.");
        return Err.BadName;
    }

    for (modules.value) |mod| {
        logf(Log.Deb, "Module \"{s}\"...", .{mod.name});
        if (mem.eql(u8, mod.name, name.?)) {
            logf(Log.Err, "Module \"{s}\" already exists...", .{mod.name});
            return Err.NameUsed;
        }
    }

    for (projects.value) |proj| {
        logf(Log.Deb, "Project \"{s}\"...", .{proj});
        if (mem.eql(u8, proj, name.?)) {
            logf(Log.Err, "Name \"{s}\" is used by project...", .{proj});
            return Err.NameUsed;
        }
    }

    var tmpl: ?Template = null;

    for (templates.value) |t| {
        logf(Log.Deb, "Template \"{s}\"...", .{t.name});
        if (mem.eql(u8, t.name, template.?)) {
            logf(Log.Inf, "Found template \"{s}\".", .{t.name});
            tmpl = t;
            break;
        }
    }

    if (tmpl == null) {
        logf(Log.Err, "Template \"{s}\" not found.", .{template.?});
        return Err.BadTemplate;
    }

    logf(Log.Inf, "Generating module \"{s}\"...", .{name.?});

    var moduleDir = try cwd.makeOpenPath(name.?, .{});
    defer moduleDir.close();

    const tmplMode = switch (modType) {
        ModType.Executable => tmpl.?.exe,
        ModType.SharedLibrary => tmpl.?.shared,
        ModType.StaticLibrary => tmpl.?.static,
        else => {
            log(Log.Err, "Unhandled modType...");
            return Err.Unreachable;
        },
    };

    for (tmplMode.src) |file| {
        try templateJSON.write(moduleDir, allocator, file, name.?);
    }

    for (tmplMode.head) |file| {
        try templateJSON.write(cwd, allocator, file, name.?);
    }

    logf(Log.Inf, "Registering module \"{s}\"...", .{name.?});

    var name_copy = try copyStr(name.?, allocator);
    defer name_copy.deinit();

    var template_copy = try copyStr(template.?, allocator);
    defer template_copy.deinit();

    var mods = std.ArrayList(Module).init(allocator);
    defer mods.deinit();

    try mods.appendSlice(modules.value);
    try mods.append(.{ .name = name_copy.items, .template = template_copy.items, .libs = &[_][]u8{}, .mtype = modType });

    var file = try cwd.openFile("trsp.conf/modules.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    try json.stringify(mods.items, .{}, file.writer());

    logf(Log.Inf, "Succesfully generated module \"{s}\"!", .{name.?});
}

fn cleanUpBuild() !void {
    const cwd = fs.cwd();

    log(Log.Inf, "Cleaning Up...");

    try cwd.deleteTree("build");
    cwd.deleteFile("CMakeLists.txt") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
    cwd.deleteFile("Makefile") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
    cwd.deleteFile("build.ninja") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
}

fn build(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    var generator_s: ?[]const u8 = null;
    var builder_s: ?[]const u8 = null;

    log(Log.Inf, "Parsing command-line arguments...");

    const descriptions = [_]ArgDescription{
        .{ .short = 'g', .long = "generator" },
        .{ .short = 'b', .long = "builder" },
    };

    var argList = try parseCLA(args, &descriptions, allocator);
    defer argList.deinit();

    log(Log.Inf, "Loading data...");

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Err, "Unknown argument \"{?s}\"", .{arg.value});
            return Err.BadArg;
        }

        switch (descriptions[@bitCast(arg.id)].short) {
            'g' => {
                if (generator_s != null) {
                    logf(Log.Err, "Generator already changed \"{?s}\" > \"{?s}\"", .{ generator_s, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                generator_s = arg.value;
            },
            'b' => {
                if (builder_s != null) {
                    logf(Log.Err, "Builder already changed \"{?s}\" > \"{?s}\"", .{ builder_s, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                builder_s = arg.value;
            },
            else => {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            },
        }
    }

    var _build = try loadBuild(cwd, allocator);
    defer _build.deinit();

    log(Log.Inf, "Validating data...");

    var generator = _build.value.gen;
    if (generator_s != null) {
        if (mem.eql(u8, generator_s.?, "zig")) {
            generator = BuildGen.Zig;
        } else if (mem.eql(u8, generator_s.?, "cmake")) {
            generator = BuildGen.CMake;
        } else {
            logf(Log.Err, "Unknown generator \"{?s}\".", .{generator_s});
            return Err.BadGenerator;
        }
    }

    var builder = _build.value.builder;
    if (builder_s != null) {
        if (mem.eql(u8, builder_s.?, "make")) {
            builder = BuildBuilder.Make;
        } else if (mem.eql(u8, builder_s.?, "ninja")) {
            builder = BuildBuilder.Ninja;
        } else {
            logf(Log.Err, "Unknown builder \"{?s}\".", .{builder_s});
            return Err.BadBuilder;
        }
    }

    logf(Log.Deb, "Generator: {}", .{generator});
    logf(Log.Deb, "Builder: {}", .{builder});

    try cleanUpBuild();

    // TODO: Generate build files (use function)
    switch (generator) {
        BuildGen.Zig => {},
        BuildGen.CMake => {
            try cmake.cmake(cwd, allocator);
            log(Log.Inf, "Calling cmake...");
            switch(builder){
                BuildBuilder.Ninja => {
                    _ = try std.ChildProcess.run(.{
                        .allocator = std.heap.page_allocator,
                        .argv = &[_][]const u8{"cmake", "-S", ".", "-B", "build", "-G", "Ninja"}
                    });

                    log(Log.Inf, "Calling Ninja...");
                    _ = try std.ChildProcess.run(.{
                        .allocator = std.heap.page_allocator,
                        .argv = &[_][]const u8{"ninja", "-C", "build"}
                    });
                },
                BuildBuilder.Make => {
                    _ = try std.ChildProcess.run(.{
                        .allocator = std.heap.page_allocator,
                        .argv = &[_][]const u8{"cmake", "-S", ".", "-B", "build", "-G", "Ninja"}
                    });

                    log(Log.Inf, "Calling Make...");
                    _ = try std.ChildProcess.run(.{
                        .allocator = std.heap.page_allocator,
                        .argv = &[_][]const u8{"make", "-C", "build"}
                    });
                },
            }
        },
    }

    // TODO: Update build.json
    // TODO: Run build process
}

fn release(args: [][:0]const u8, allocator: mem.Allocator) !void {
    _ = args;
    log(Log.War, "Not implemented yet.");

    try ensureProject();
    try cleanUpBuild();

    const cwd = fs.cwd();

    try cmake.cmake(cwd, allocator);
    // TODO: Generate build files (use function)
}

fn set(args: [][:0]const u8, allocator: mem.Allocator) !void {
    _ = args;
    _ = allocator;
    log(Log.War, "Not implemented yet.");
}

