const std = @import("std");
const process = std.process;
const heap = std.heap;
const mem = std.mem;
const fs = std.fs;

const l = @import("log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const entries = struct {
    const init     = @import("entry/init.zig").entry;
    const module   = @import("entry/module.zig").entry;
    const template = @import("entry/template.zig").entry;
    const build    = @import("entry/build.zig").entry;
    const release  = @import("entry/release.zig").entry;
    const config   = @import("entry/config.zig").entry;
};

const Err = @import("err.zig").Err;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    logf(Log.Deb, "Argc: {}", .{args.len});
    for (args) |arg| {
        logf(Log.Deb, "    Arg: {s}", .{arg});
    }

    if (args.len <= 1) {
        log(Log.Err, "Expected at least one argument.");
        return Err.NoArgs;
    }

    const program = args[0];
    const entry = args[1];

    logf(Log.Inf, "Program: {s}", .{program});

    const entryArgs = args[2..];
    if (mem.eql(u8, entry, "init")) {
        return entries.init(entryArgs, allocator);
    } else if (mem.eql(u8, entry, "module")) {
        return entries.module(entryArgs, allocator);
    } else if (mem.eql(u8, entry, "template")){
        return entries.template(entryArgs, allocator);
    } else if (mem.eql(u8, entry, "build")) {
        return entries.build(entryArgs, allocator);
    } else if (mem.eql(u8, entry, "release")) {
        return entries.release(entryArgs, allocator);
    } else if (mem.eql(u8, entry, "config")) {
        return entries.config(entryArgs, allocator);
    } else {
        logf(Log.Err, "Unknown entry: {s}", .{entry});
        return Err.BadTask;
    }
}
