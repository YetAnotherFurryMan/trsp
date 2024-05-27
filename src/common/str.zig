const std = @import("std");
const mem = std.mem;

pub inline fn copy(str: []const u8, allocator: mem.Allocator) ![]u8 {
    const cp = mem.concat(allocator, u8, &[_][]const u8{str});
    return cp;
}
