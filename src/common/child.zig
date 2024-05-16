const std = @import("std");

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

pub fn run(argv: []const []const u8) !void {
    logf(Log.Inf, "Running {s}...", .{argv[0]});

    const res = try std.ChildProcess.run(.{
        .allocator = std.heap.page_allocator,
        .argv = argv
    });

    logf(Log.Deb, "    Term: {}", .{res.term});

    switch(res.term) {
        std.ChildProcess.Term.Exited => {
            if(res.term.Exited != 0){
                log(Log.Err, "Child error:");
                logf(Log.Inf, "STDOUT:\n{s}\n[INFO]: STDERR:\n{s}", .{res.stdout, res.stderr});
                return error.ChildError;
            }
        },
        else => {
            log(Log.Err, "Child error:");
            logf(Log.Inf, "STDOUT:\n{s}\n[INFO]: STDERR:\n{s}", .{res.stdout, res.stderr});
            return error.ChildError;
        },
    }
}
