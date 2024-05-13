const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const loadJSON = @import("loadJSON.zig").loadJSON;

pub const TemplateFile = struct { name: []u8, cnt: []u8 };
pub const TemplateMode = struct { head: []TemplateFile, src: []TemplateFile };
pub const Template = struct { name: []u8, exe: TemplateMode, shared: TemplateMode, static: TemplateMode };

pub inline fn load(cwd: fs.Dir, allocator: mem.Allocator) !json.Parsed([]Template) {
    return loadJSON([]Template, cwd, allocator, "trsp.conf/templates.json");
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
        
     
    try dir.writeFile2(.{
        .sub_path = name,
        .data = cnt,
        .flags = .{}
    });
}

