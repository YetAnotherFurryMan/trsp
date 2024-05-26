const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub const TemplateFile = struct { name: []u8, cnt: []u8 };
pub const TemplateDir = struct { name: []u8, files: []TemplateFile, dirs: []TemplateDir };
pub const TemplateEntry = struct { files: []TemplateFile, dirs: []TemplateDir };
pub const Template = struct { languages: [][]u8, exe: TemplateEntry, shared: TemplateEntry, static: TemplateEntry };

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator, name: []const u8) !json.Parsed(Template) {
    const path = try mem.concat(allocator, u8, &[_][]const u8{ "trsp.conf/templates/", name, ".json" });
    defer allocator.free(path);

    return loadJSON(Template, cwd, allocator, path);
}

pub inline fn list(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed([][]u8) {
    return loadJSON([][]u8, cwd, allocator, "trsp.conf/templates.json");
}

pub inline fn loadPath(cwd: fs.Dir, path: []const u8, allocator: mem.Allocator) !json.Parsed(Template) {
    return loadJSON(Template, cwd, allocator, path);
}

pub fn createWriteFile(dir: fs.Dir, allocator: mem.Allocator, file: TemplateFile, module_name: []const u8) !void {
    // Name
    const name_size = mem.replacementSize(u8, file.name, "${module}", module_name);
    const name = try allocator.alloc(u8, name_size);
    defer allocator.free(name);
    _ = mem.replace(u8, file.name, "${module}", module_name, name);

    // Cnt
    const cnt_size = mem.replacementSize(u8, file.cnt, "${module}", module_name);
    const cnt = try allocator.alloc(u8, cnt_size);
    defer allocator.free(cnt);
    _ = mem.replace(u8, file.cnt, "${module}", module_name, cnt);

    try dir.writeFile2(.{ .sub_path = name, .data = cnt, .flags = .{} });
}

pub fn createWrite(dir: fs.Dir, allocator: mem.Allocator, file: TemplateEntry, module_name: []const u8) !void {
    for (file.files) |f| {
        try createWriteFile(dir, allocator, f, module_name);
    }

    for (file.dirs) |d| {
        try createWriteDir(dir, allocator, d, module_name);
    }
}

pub fn createWriteDir(dir: fs.Dir, allocator: mem.Allocator, file: TemplateDir, module_name: []const u8) !void {
    // Name
    const name_size = mem.replacementSize(u8, file.name, "${module}", module_name);
    const name = try allocator.alloc(u8, name_size);
    defer allocator.free(name);
    _ = mem.replace(u8, file.name, "${module}", module_name, name);

    var mdir = try dir.makeOpenPath(name, .{});
    defer mdir.close();

    for (file.files) |f| {
        try createWriteFile(mdir, allocator, f, module_name);
    }

    for (file.dirs) |d| {
        try createWriteDir(mdir, allocator, d, module_name);
    }
}

// pub fn write(dir: fs.Dir, allocator: mem.Allocator, file: TemplateFile, module_name: []const u8) !void {
//     // Name
//     const name_size = mem.replacementSize(u8, file.name, "${module}", module_name);
//     const name = try allocator.alloc(u8, name_size);
//     defer allocator.free(name);
//     _ = mem.replace(u8, file.name, "${module}", module_name, name);

//     // Cnt
//     const cnt_size = mem.replacementSize(u8, file.cnt, "${module}", module_name);
//     const cnt = try allocator.alloc(u8, cnt_size);
//     defer allocator.free(cnt);
//     _ = mem.replace(u8, file.cnt, "${module}", module_name, cnt);

//     try dir.writeFile2(.{ .sub_path = name, .data = cnt, .flags = .{} });
// }
