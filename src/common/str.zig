const std = @import("std");
const mem = std.mem;

pub inline fn copy(str: []const u8, allocator: mem.Allocator) !std.ArrayList(u8) {
    var cp = std.ArrayList(u8).init(allocator);
    try cp.appendSlice(str);
    return cp;
}

