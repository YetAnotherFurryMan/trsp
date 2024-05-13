const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

pub const Project = []u8;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed([]Project) {
    return loadJSON([]Project, cwd, allocator, "trsp.conf/projects.json");
}

