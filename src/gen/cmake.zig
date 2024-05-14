const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const modulesJSON = @import("../json/modules.json.zig");
const loadModules = modulesJSON.load;

const buildJSON = @import("../json/build.json.zig");
const Build = buildJSON.Build;

// TODO: Needs:
// Project name
// Project version
// C std
// C++ std
// Other languages like ZIG or Fortran

const listFiles = @import("listFiles.zig").listFiles;

fn addModule(module: modulesJSON.Module, cmakelists: fs.File, cwd: fs.Dir, allocator: mem.Allocator) !void {
    var mdir = try cwd.openDir(module.name, .{ .iterate = true });
    defer mdir.close();

    var is_lib: bool = false;
    switch (module.mtype) {
        modulesJSON.ModType.Default, modulesJSON.ModType.Executable => {
            _ = try cmakelists.write("add_executable(");
        },
        modulesJSON.ModType.SharedLibrary, modulesJSON.ModType.StaticLibrary => {
            is_lib = true;
            _ = try cmakelists.write("add_library(");
        },
    }

    _ = try cmakelists.write(module.name);

    switch (module.mtype) {
        modulesJSON.ModType.SharedLibrary => {
            _ = try cmakelists.write(" SHARED ");
        },
        modulesJSON.ModType.StaticLibrary => {
            _ = try cmakelists.write(" STATIC ");
        },
        else => {},
    }

    // WARNING: each record must be freed manualy!!!
    var filelist = try listFiles(mdir, allocator);
    defer filelist.deinit();

    while (filelist.popOrNull()) |e| {
        _ = try cmakelists.write("\n\t${CMAKE_SOURCE_DIR}/");
        _ = try cmakelists.write(e);
        allocator.free(e);
    }

    _ = try cmakelists.write("\n)\ntarget_include_directories(");
    _ = try cmakelists.write(module.name);
    _ = try cmakelists.write(" PRIVATE ${CMAKE_SOURCE_DIR})\n\n");
}

pub fn cmake(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    var cmakelists = try cwd.createFile("CMakeLists.txt", .{});
    defer cmakelists.close();

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    log(Log.Inf, "Generating CMakeLists.txt");
    _ = try cmakelists.write("cmake_minimum_required(VERSION 3.22)\n\n");
    _ = try cmakelists.write("project(");
    _ = try cmakelists.write(build.name);
    _ = try cmakelists.write(" VERSION 1.0)\n\n");
    _ = try cmakelists.write("set(CMAKE_C_STANDARD 17)\nset(CMAKE_C_STANDARD_REQUIRED True)\n\n");
    _ = try cmakelists.write("set(CMAKE_CXX_STANDARD 20)\nset(CMAKE_CXX_STANDARD_REQUIRED True)\n\n");
    _ = try cmakelists.write("\n\n");

    for (modules.value) |module| {
        try addModule(module, cmakelists, cwd, allocator);
    }
}
