const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const buildJSON = @import("../json/build.json.zig");
const BuildBuilder = buildJSON.BuildBuilder;
const BuildGen = buildJSON.BuildGen;
const Build = buildJSON.Build;
const loadBuild = buildJSON.load;

const cmake = @import("../gen/cmake.zig");
const make = @import("../gen/make.zig");
const ninja = @import("../gen/ninja.zig");

const child = @import("../common/child.zig");

const ensureProject = @import("ensureProject.zig").ensureProject;
const cla = @import("cla.zig");

pub fn cleanUp() !void {
    const cwd = fs.cwd();

    log(Log.Inf, "Cleaning Up...");

    try cwd.deleteTree("build");
    cwd.deleteFile("CMakeLists.txt") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
    cwd.deleteFile("Makefile") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
    cwd.deleteFile("build.ninja") catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };
}

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    var generator_s: ?[]const u8 = null;
    var builder_s: ?[]const u8 = null;

    log(Log.Inf, "Parsing command-line arguments...");

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 'g', .long = "generator" },
        .{ .short = 'b', .long = "builder" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    log(Log.Inf, "Loading data...");

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            logf(Log.Err, "Unknown argument \"{?s}\"", .{arg.value});
            return Err.BadArg;
        }

        switch (descriptions[@bitCast(arg.id)].short) {
            'g' => {
                if (generator_s != null) {
                    logf(Log.Err, "Generator already changed \"{?s}\" > \"{?s}\"", .{ generator_s, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                generator_s = arg.value;
            },
            'b' => {
                if (builder_s != null) {
                    logf(Log.Err, "Builder already changed \"{?s}\" > \"{?s}\"", .{ builder_s, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                builder_s = arg.value;
            },
            else => {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            },
        }
    }

    var _build = try loadBuild(cwd, allocator);
    defer _build.deinit();

    log(Log.Inf, "Validating data...");

    var generator = _build.value.gen;
    if (generator_s != null) {
        if (mem.eql(u8, generator_s.?, "zig")) {
            generator = BuildGen.Zig;
        } else if (mem.eql(u8, generator_s.?, "cmake")) {
            generator = BuildGen.CMake;
        } else {
            logf(Log.Err, "Unknown generator \"{?s}\".", .{generator_s});
            return Err.BadGenerator;
        }
    }

    var builder = _build.value.builder;
    if (builder_s != null) {
        if (mem.eql(u8, builder_s.?, "make")) {
            builder = BuildBuilder.Make;
        } else if (mem.eql(u8, builder_s.?, "ninja")) {
            builder = BuildBuilder.Ninja;
        } else {
            logf(Log.Err, "Unknown builder \"{?s}\".", .{builder_s});
            return Err.BadBuilder;
        }
    }

    logf(Log.Deb, "Generator: {}", .{generator});
    logf(Log.Deb, "Builder: {}", .{builder});

    const newBuild: Build = .{
        .name = _build.value.name,
        .builder = builder,
        .gen = generator,
    };

    try cleanUp();

    switch (generator) {
        BuildGen.Zig => {
            switch(builder){
                BuildBuilder.Ninja => {
                    try ninja.ninja(cwd, allocator, newBuild);
                    try child.run(&[_][]const u8{"ninja"});
                },
                BuildBuilder.Make => {
                    try make.make(cwd, allocator, newBuild);
                    try child.run(&[_][]const u8{"make"});
                },
            }
        },
        BuildGen.CMake => {
            try cmake.cmake(cwd, allocator, newBuild);
            switch(builder){
                BuildBuilder.Ninja => {
                    try child.run(&[_][]const u8{"cmake", "-S", ".", "-B", "build", "-G", "Ninja"});
                    try child.run(&[_][]const u8{"ninja", "-C", "build"});
                },  
                BuildBuilder.Make => {
                    try child.run(&[_][]const u8{"cmake", "-S", ".", "-B", "build", "-G", "Unix Makefiles"});
                    try child.run(&[_][]const u8{"make", "-C", "build"});
                },
            }
        },
    }

    log(Log.Inf, "Updating trsp.conf/build.json");

    var file = try cwd.openFile("trsp.conf/build.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    var writer = file.writer();
    try json.stringify(newBuild, .{}, writer);
    _ = try writer.write("\n"); // Wreid error with additional } at the end of file

    log(Log.Inf, "Succesfully builded.");
}


