const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const templatesJSON = @import("../json/templates.json.zig");
const TemplateFile = templatesJSON.TemplateFile;
const Template = templatesJSON.Template;

const cla = @import("cla.zig");
const ensureProject = @import("ensureProject.zig").ensureProject;

const Src = struct{ path: []const u8, list: bool };

const defaultCXXTemplate= "{\"name\":\"c++\",\"exe\":{\"head\":[],\"src\":[{\"name\":\"main.cpp\",\"cnt\":\"#include <iostream>\\n\\nint main(int argc, const char** argv){\\n    std::cout << \\\"Hello World!\\\" << std::endl;\\n    return 0;\\n}\\n\"}]},\"shared\":{\"head\":[{\"name\":\"${module}.hpp\",\"cnt\":\"#pragma once\\n\\nnamespace ${module}{\\n    void hello();\\n}\"}],\"src\":[{\"name\":\"${module}.cpp\",\"cnt\":\"#include <iostream>\\n\\nnamespace ${module}{\\n    void hello(){\\n        std::cout << \\\"Hello World!\\\" << std::endl;\\n    }\\n}\"}]},\"static\":{\"head\":[{\"name\":\"${module}.hpp\",\"cnt\":\"#pragma once\\n\\nnamespace ${module}{\\n    void hello();\\n}\"}],\"src\":[{\"name\":\"${module}.cpp\",\"cnt\":\"#include <iostream>\\n\\nnamespace ${module}{\\n    void hello(){\\n        std::cout << \\\"Hello World!\\\" << std::endl;\\n    }\\n}\"}]}}";

pub fn entry(args: [][:0]const u8, allocator: mem.Allocator) !void {
    try ensureProject();

    const cwd = fs.cwd();

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 'l', .long = "list" },
        .{ .short = 0, .long = "c++" },
    };

    var argList = try cla.parse(args, &descriptions, allocator);
    defer argList.deinit();

    var srcs = std.ArrayList(Src).init(allocator);
    defer srcs.deinit();

    var templates = std.ArrayList(Template).init(allocator);
    defer templates.deinit();

    var tmpls = try templatesJSON.load(cwd, allocator);
    defer tmpls.deinit();

    try templates.appendSlice(tmpls.value);

    var parse_to_deinit = std.ArrayList(json.Parsed(Template)).init(allocator);
    defer {
        while(parse_to_deinit.popOrNull()) |e| {
            e.deinit();
        }
        parse_to_deinit.deinit();
    }

    while (argList.popOrNull()) |arg| {
        logf(Log.Deb, "Arg {}: {?s}", arg);

        if (arg.id < 0) {
            try srcs.append(.{ .path = arg.value.?, .list = false });
        } else if(mem.eql(u8, descriptions[@bitCast(arg.id)].long, "c++")){
            const t = try json.parseFromSlice(Template, allocator, defaultCXXTemplate, .{});
            try parse_to_deinit.append(t);

            try templates.append(t.value);
        } else if(descriptions[@bitCast(arg.id)].short == 'l'){
            if(arg.value == null){
                log(Log.Err, "Excepted value.");
                log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                return Err.NoValue;
            }

            try srcs.append(.{ .path = arg.value.?, .list = true });
        } else{
            logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
            return Err.BadArg;
        }
    }

    var parse_to_deinit_arr = std.ArrayList(json.Parsed([]Template)).init(allocator);
    defer {
        while(parse_to_deinit_arr.popOrNull()) |e| {
            e.deinit();
        }
        parse_to_deinit_arr.deinit();
    }

    while(srcs.popOrNull()) |src| {
        logf(Log.Deb, "Loading src: {}", .{src});
        
        if(src.list){
            const t = try templatesJSON.loadCustomList(cwd, src.path, allocator);
            try parse_to_deinit_arr.append(t);

            try templates.appendSlice(t.value);
        } else{
            const t = try templatesJSON.loadCustom(cwd, src.path, allocator);
            try parse_to_deinit.append(t);

            try templates.append(t.value);
        }
    }

    var file = try cwd.openFile("trsp.conf/templates.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    var writer = file.writer();
    try json.stringify(templates.items, .{}, writer);
    _ = try writer.write("\n"); // Wreid error with additional } at the end of file
    
    log(Log.Inf, "Succesfully added templates.");
}

