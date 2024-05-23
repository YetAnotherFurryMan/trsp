const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub const LanguageMod = struct { cmd: [][]u8, obj: [][]u8 };
pub const Language = struct { ext: []u8, exe: LanguageMod, lib: LanguageMod, dll: LanguageMod };

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator, name: []const u8) !json.Parsed(Language) {
    const path = try mem.concat(allocator, u8, &[_][]const u8{ "trsp.conf/languages/", name, ".json" });
    defer allocator.free(path);

    return loadJSON(Language, cwd, allocator, path);
}

pub inline fn list(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed([][]u8) {
    return loadJSON([][]u8, cwd, allocator, "trsp.conf/languages.json");
}

pub inline fn loadPath(cwd: fs.Dir, path: []const u8, allocator: mem.Allocator) !json.Parsed(Language) {
    return loadJSON(Language, cwd, allocator, path);
}

pub fn compileCmd(allocator: mem.Allocator, cmd: []const u8, in: []const u8, out: []const u8) ![]u8 {
    // In
    const with_in = mem.replacementSize(u8, cmd, "${in}", in);
    const s1 = try allocator.alloc(u8, with_in);
    errdefer allocator.free(s1);
    _ = mem.replace(u8, cmd, "${in}", in, s1);

    // Out
    const with_out = mem.replacementSize(u8, s1, "${out}", out);
    const s2 = try allocator.alloc(u8, with_out);
    errdefer allocator.free(s2);
    _ = mem.replace(u8, s1, "${out}", out, s2);
    allocator.free(s1);

    return s2;
}
