const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub fn listFiles(dir: fs.Dir, allocator: mem.Allocator) !std.ArrayList([]u8) {
    var list = std.ArrayList([]u8).init(allocator);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            fs.Dir.Entry.Kind.file => {
                const path = try entry.dir.realpathAlloc(allocator, entry.basename);
                defer allocator.free(path);

                const dot = ".";
                try list.append(try fs.path.relative(allocator, dot, path));
            },
            fs.Dir.Entry.Kind.directory => {},
            else => {},
        }
    }

    return list;
}

pub fn listDirs(dir: fs.Dir, allocator: mem.Allocator) !std.ArrayList([]u8) {
    var list = std.ArrayList([]u8).init(allocator);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            fs.Dir.Entry.Kind.file => {},
            fs.Dir.Entry.Kind.directory => {
                const path = try entry.dir.realpathAlloc(allocator, entry.basename);
                defer allocator.free(path);

                const dot = ".";
                try list.append(try fs.path.relative(allocator, dot, path));
            },
            else => {},
        }
    }

    return list;
}

