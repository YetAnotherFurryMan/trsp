const std = @import("std");
const mem = std.mem;

pub inline fn copy(str: []const u8, allocator: mem.Allocator) ![]u8 {
    const cp = mem.concat(allocator, u8, &[_][]const u8{str});
    return cp;
}

inline fn A2Za2z029_(ch: u8) bool {
    return (ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9') or ch == '_';
}

pub inline fn validName(str: []const u8) bool {
    // [A-Za-z0-9_]
    for (str) |ch| {
        if (!A2Za2z029_(ch))
            return false;
    }
    return true;
}

inline fn plusMinusHashDollar(ch: u8) bool {
    return ch == '+' or ch == '-' or ch == '#' or ch == '$';
}

pub inline fn validNameExt(str: []const u8) bool {
    // [A-Za-z0-9_+-#$]
    for (str) |ch| {
        if (!A2Za2z029_(ch) and !plusMinusHashDollar(ch))
            return false;
    }
    return true;
}
