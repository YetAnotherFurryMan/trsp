const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const logf = l.logf;
const Log = l.Log;

// TODO: !! Restore 1024 buffer, alter how templates are stored

pub fn loadJSON(comptime T: type, cwd: fs.Dir, allocator: mem.Allocator, file: []const u8) !json.Parsed(T) {
    logf(Log.Inf, "Loading \"{s}\"...", .{file});

    var json_ = try cwd.openFile(file, .{});
    defer json_.close();

    const src = try json_.readToEndAlloc(allocator, 2048);
    defer allocator.free(src);

    return json.parseFromSlice(T, allocator, src, .{});
}
