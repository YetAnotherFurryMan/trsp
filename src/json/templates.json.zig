const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub const TemplateCompilationMod = enum { CompileAll, CompileMain };
pub const TemplateFile = struct { name: []u8, cnt: []u8 };
pub const TemplateMode = struct { head: []TemplateFile, src: []TemplateFile, main: []u8 };
pub const Template = struct { mod: TemplateCompilationMod, exe: TemplateMode, shared: TemplateMode, static: TemplateMode };

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

pub fn write(dir: fs.Dir, allocator: mem.Allocator, file: TemplateFile, module_name: []const u8) !void {
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
