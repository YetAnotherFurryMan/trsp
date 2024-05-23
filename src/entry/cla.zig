const std = @import("std");
const mem = std.mem;

pub const ArgDescription = struct { short: u8, long: []const u8 };
pub const Arg = struct { id: i64, value: ?[]const u8 };

pub fn parse(args: [][:0]const u8, desc: []const ArgDescription, allocator: mem.Allocator) !std.ArrayList(Arg) {
    var out = std.ArrayList(Arg).init(allocator);

    for (args) |arg| {
        var a: Arg = .{ .id = -1, .value = arg };
        if (arg[0] == '-') {
            if (arg.len == 1) {
                a.id = -2;
            } else if (arg[1] == '-') {
                if (arg.len == 2) {
                    a.id = -2;
                } else {
                    var argx = mem.split(u8, arg[2..], "=");
                    const argName = argx.next().?;
                    const argValue = argx.next();
                    for (desc, 0..) |d, i| {
                        if (mem.eql(u8, argName, d.long)) {
                            a.id = @bitCast(i);
                            a.value = argValue;
                            break;
                        }
                    }
                }
            } else {
                for (desc, 0..) |d, i| {
                    if (arg[1] == d.short) {
                        a.id = @bitCast(i);
                        if (arg.len > 2) {
                            a.value = arg[2..];
                        } else {
                            a.value = null;
                        }
                        break;
                    }
                }
            }
        }
        try out.append(a);
    }
    return out;
}

