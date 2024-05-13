const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

pub const BuildBuilder = enum { Make, Ninja };
pub const BuildGen = enum { Zig, CMake };
pub const Build = struct { name: []u8, gen: BuildGen, builder: BuildBuilder };

const loadJSON = @import("loadJSON.zig").loadJSON;

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed(Build){
    return loadJSON(Build, cwd, allocator, "trsp.conf/build.json");
}

