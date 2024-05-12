const std = @import("std");
const fs = std.fs;
const io = std.io;

const logAllowDeb = true;

pub const Log = enum {
    Err,
    War,
    Inf,
    Note,
    Deb,
};

inline fn fprintf(file: fs.File.Writer, comptime fmt: []const u8, args: anytype) void {
    file.print(fmt, args) catch {};
}

inline fn log2str(mode: Log) *const [4:0]u8 {
    return switch (mode) {
        Log.Err => "ERRO",
        Log.War => "WARN",
        Log.Inf => "INFO",
        Log.Deb => "DEBU",
        else => "NOTE",
    };
}

pub fn log(mode: Log, msg: []const u8) void {
    if (!logAllowDeb and mode == Log.Deb) return;
    const stderr = io.getStdErr().writer();
    const m = log2str(mode);
    fprintf(stderr, "[{s}]: {s}\n", .{ m, msg });
}

pub fn logf(mode: Log, comptime fmt: []const u8, args: anytype) void {
    if (!logAllowDeb and mode == Log.Deb) return;
    const stderr = io.getStdErr().writer();
    const m = log2str(mode);
    fprintf(stderr, "[{s}]: ", .{m});
    fprintf(stderr, fmt, args);
    fprintf(stderr, "\n", .{});
}
