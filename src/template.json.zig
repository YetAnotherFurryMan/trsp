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
