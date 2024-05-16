const std = @import("std");
const fs = std.fs;

const llog = @import("../log.zig");
const Log = llog.Log;
const log = llog.log;

const Err = @import("../err.zig").Err;

fn amIProject() bool {
    const file = fs.cwd().openFile("trsp", .{}) catch {
        return false;
    };
    file.close();
    return true;
}

pub inline fn ensureProject() !void {
    if (!amIProject()) {
        log(Log.Err, "Project not detected.");
        log(Log.Note, "Try \'trsp init\'");
        return Err.NoProject;
    }
}

