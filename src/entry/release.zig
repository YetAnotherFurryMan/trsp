const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const buildJSON = @import("../json/build.json.zig");
const loadBuild = buildJSON.load;

const cmake = @import("../gen/cmake.zig");
const make = @import("../gen/make.zig");
const ninja = @import("../gen/ninja.zig");

const cleanUpBuild = @import("build.zig").cleanUp;
const ensureProject = @import("ensureProject.zig").ensureProject;

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    _ = args;

    try ensureProject();
    try cleanUpBuild();

    const cwd = fs.cwd();

    var _build = try loadBuild(cwd, allocator);
    defer _build.deinit();

    try cmake.cmake(cwd, allocator, _build.value);
    try ninja.ninja(cwd, allocator, _build.value);
    try make.make(cwd, allocator, _build.value);
}

