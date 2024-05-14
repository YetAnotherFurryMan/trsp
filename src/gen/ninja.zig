const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const modulesJSON = @import("../json/modules.json.zig");
const ModType = modulesJSON.ModType;
const loadModules = modulesJSON.load;

const buildJSON = @import("../json/build.json.zig");
const Build = buildJSON.Build;

// TODO: Needs:
// Project version
// C std
// C++ std
// Other languages like ZIG or Fortran

const listFiles = @import("listFiles.zig").listFiles;

fn addModule(module: modulesJSON.Module, buildninja: fs.File, cwd: fs.Dir, allocator: mem.Allocator) !void {
    var mdir = try cwd.openDir(module.name, .{ .iterate = true });
    defer mdir.close();

    // WARNING: each record must be freed manualy!!!
    var filelist = try listFiles(mdir, allocator);
    defer filelist.deinit();

    var bins = std.ArrayList([]u8).init(allocator);
    defer bins.deinit();

    while (filelist.popOrNull()) |e| {
        const ext = fs.path.extension(e);
        if(mem.eql(u8, ext, ".c")){
            const bin = try mem.join(allocator, "", &[_][]const u8{
                "$builddir/",
                module.name,
                ".dir",
                e[module.name.len..],
                ".o"
            });

            _ = try buildninja.write("build ");
            _ = try buildninja.write(bin);
            _ = try buildninja.write(": cc ");
            _ = try buildninja.write(e);
            _ = try buildninja.write("\n  includes = -I.\n\n");

            try bins.append(bin);
        } else{
            logf(Log.War, "Skipping file {s} - unknown extension.", .{e});
        }
        allocator.free(e);
    }

    _ = try buildninja.write("build $builddir/");
    switch(module.mtype){
        ModType.Default,
        ModType.Executable => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(": exe ");
        },
        ModType.StaticLibrary => {
            _ = try buildninja.write("lib");
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".a: lib ");
        },
        ModType.SharedLibrary => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".so: dll ");
        }
    }

    while (bins.popOrNull()) |bin|{
        _ = try buildninja.write(bin);
        _ = try buildninja.write(" ");
        allocator.free(bin);
    }

    _ = try buildninja.write("\n\nbuild ");
    _ = try buildninja.write(module.name);
    _ = try buildninja.write(": phony $builddir/");

    switch(module.mtype){
        ModType.Default,
        ModType.Executable => {
            _ = try buildninja.write(module.name);
        },
        ModType.StaticLibrary => {
            _ = try buildninja.write("lib");
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".a");
        },
        ModType.SharedLibrary => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".so");
        }
    }

    _ = try buildninja.write("\n\n");
}

pub fn ninja(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    _ = build;

    var buildninja = try cwd.createFile("build.ninja", .{});
    defer buildninja.close();

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    log(Log.Inf, "Generating build.ninja");
    _ = try buildninja.write("ninja_required_version = 1.5\n\n");
    _ = try buildninja.write("builddir = build\n\n");
    _ = try buildninja.write("cflags = -Wall -Wextra -Wpedantic -std=c17\n");
    _ = try buildninja.write("cxxflags = -Wall -Wextra -Wpedantic -std=c++20\n");
    _ = try buildninja.write("ldflags = -L./$builddir\n\n");
    _ = try buildninja.write("rule cc\n");
    _ = try buildninja.write("  depfile = $out.d\n");
    _ = try buildninja.write("  deps = gcc\n");
    _ = try buildninja.write("  command = cc $includes $flags $cflags -c $in -MD -MT $out -MF $out.d -o $out\n");
    _ = try buildninja.write("  description = Building C object $out\n\n");
    _ = try buildninja.write("rule cpp\n");
    _ = try buildninja.write("  depfile = $out.d\n");
    _ = try buildninja.write("  deps = gcc\n");
    _ = try buildninja.write("  command = c++ $includes $flags $cxxflags -c $in -MD -MT $out -MF $out.d -o $out\n");
    _ = try buildninja.write("  description = Building C++ object $out\n\n");
    _ = try buildninja.write("rule lib\n");
    _ = try buildninja.write("  command = ar qc $out $in\n");
    _ = try buildninja.write("  description = Building static library $out\n\n");
    _ = try buildninja.write("rule dll\n");
    _ = try buildninja.write("  command = ld --shared $ldflags -o $out $in\n");
    _ = try buildninja.write("  description = Building dynamic library $out\n\n");
    _ = try buildninja.write("rule exe\n");
    _ = try buildninja.write("  command = c++ -o $out $in $ldflags $libs\n");
    _ = try buildninja.write("  description = Building executable $out\n\n");
    
    for (modules.value) |module| {
        try addModule(module, buildninja, cwd, allocator);
    }
}
