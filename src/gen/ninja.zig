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

fn addModule(module: modulesJSON.Module, ninjabuild: fs.File, cwd: fs.Dir, allocator: mem.Allocator) !void {
    _ = module;
    _ = ninjabuild;
    _ = cwd;
    _ = allocator;
}

pub fn ninja(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    _ = cwd;
    _ = allocator;
    _ = build;
}
