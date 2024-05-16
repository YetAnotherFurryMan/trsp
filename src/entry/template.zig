const std = @import("std");
const mem = std.mem;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const cla = @import("cla.zig");
const ensureProject = @import("ensureProject.zig").ensureProject;

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    _ = args;
    _ = allocator;

    try ensureProject();

    log(Log.War, "Not implemented yet.");
}

