const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub const ModType = enum { Default, Executable, SharedLibrary, StaticLibrary };
pub const Module = struct { name: []u8, template: []u8, libs: [][]u8, mtype: ModType };

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed([]Module) {
    return loadJSON([]Module, cwd, allocator, "trsp.conf/modules.json");
}
