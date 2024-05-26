const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const Err = @import("../err.zig").Err;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const modulesJSON = @import("../json/modules.json.zig");
const ModType = modulesJSON.ModType;
const Module = modulesJSON.Module;
const loadModules = modulesJSON.load;

const projectsJSON = @import("../json/projects.json.zig");
const Project = projectsJSON.Project;
const loadProjects = projectsJSON.load;

const templatesJSON = @import("../json/templates.json.zig");
const Template = templatesJSON.Template;
const loadTemplate = templatesJSON.load;
const listTemplates = templatesJSON.list;

const str = @import("../common/str.zig");

const cla = @import("cla.zig");
const ensureProject = @import("ensureProject.zig").ensureProject;

pub fn entry(argsx: [][:0]const u8, allocator: mem.Allocator) !void {
    if (argsx.len < 1) {
        log(Log.Err, "Excepted at least module name.");
        return Err.NotEnoughArgs;
    }

    try ensureProject();

    const cwd = fs.cwd();

    var args = argsx;
    var name: ?[]const u8 = null;
    var nameChanged = false;
    var template: ?[]const u8 = null;
    var modType: ModType = ModType.Default;

    // The module name may be the first word after task, otherwise it is under -n flag
    if (args[0][0] != '-') {
        name = args[0];
        nameChanged = true;
        args = args[1..];
    }

    log(Log.Inf, "Parsing command-line arguments...");

    const descriptions = [_]cla.ArgDescription{
        .{ .short = 'n', .long = "name" },
        .{ .short = 't', .long = "template" },
        .{ .short = 'e', .long = "exe" },
        .{ .short = 'l', .long = "lib" },
        .{ .short = 'd', .long = "dll" },
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
            'n' => {
                if (nameChanged) {
                    logf(Log.Err, "Module name already changed \"{?s}\" > \"{?s}\"", .{ name, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                name = arg.value;
            },
            't' => {
                if (template != null) {
                    logf(Log.Err, "Template name already changed \"{?s}\" > \"{?s}\"", .{ template, arg.value });
                    return Err.Changed;
                }

                if (arg.value == null) {
                    log(Log.Err, "Excepted value.");
                    log(Log.Note, "Try using \'=\' or delete space before the flag argument.");
                    return Err.NoValue;
                }

                template = arg.value;
            },
            'e' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.Executable;
            },
            'l' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.StaticLibrary;
            },
            'd' => {
                if (modType != ModType.Default) {
                    log(Log.Err, "Module type already changed.");
                    return Err.Changed;
                }

                modType = ModType.SharedLibrary;
            },
            else => {
                logf(Log.Err, "Unhandled argument \"{}:{?s}\"", arg);
                return Err.BadArg;
            },
        }
    }

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    var projects = try loadProjects(cwd, allocator);
    defer projects.deinit();

    var template_names = try listTemplates(cwd, allocator);
    defer template_names.deinit();

    log(Log.Inf, "Validating data...");

    if (name == null) {
        log(Log.Err, "No module name given.");
        return Err.NoName;
    }

    if (template == null) {
        template = "c";
    }

    if (modType == ModType.Default) {
        modType = ModType.Executable;
    }

    if (mem.eql(u8, name.?, "build") or
        mem.eql(u8, name.?, "trsp") or
        mem.eql(u8, name.?, "LICENCE"))
    {
        logf(Log.Err, "Bad module name: \"{s}\" is a reserved name.", .{name.?});
        return Err.BadName;
    }

    for (modules.value) |mod| {
        logf(Log.Deb, "Module \"{s}\"...", .{mod.name});
        if (mem.eql(u8, mod.name, name.?)) {
            logf(Log.Err, "Module \"{s}\" already exists...", .{mod.name});
            return Err.NameUsed;
        }
    }

    for (projects.value) |proj| {
        logf(Log.Deb, "Project \"{s}\"...", .{proj});
        if (mem.eql(u8, proj, name.?)) {
            logf(Log.Err, "Name \"{s}\" is used by project...", .{proj});
            return Err.NameUsed;
        }
    }

    var tmpl: ?json.Parsed(Template) = null;
    defer {
        if (tmpl != null)
            tmpl.?.deinit();
    }

    for (template_names.value) |t| {
        logf(Log.Deb, "Template \"{s}\"...", .{t});
        if (mem.eql(u8, t, template.?)) {
            logf(Log.Inf, "Found template \"{s}\".", .{t});
            tmpl = try loadTemplate(cwd, allocator, t);
            break;
        }
    }

    if (tmpl == null) {
        logf(Log.Err, "Template \"{s}\" not found.", .{template.?});
        return Err.BadTemplate;
    }

    logf(Log.Inf, "Generating module \"{s}\"...", .{name.?});

    var moduleDir = try cwd.makeOpenPath(name.?, .{});
    defer moduleDir.close();

    try switch (modType) {
        ModType.Executable => templatesJSON.createWrite(moduleDir, allocator, tmpl.?.value.exe, name.?),
        ModType.SharedLibrary => templatesJSON.createWrite(moduleDir, allocator, tmpl.?.value.shared, name.?),
        ModType.StaticLibrary => templatesJSON.createWrite(moduleDir, allocator, tmpl.?.value.static, name.?),
        else => {
            log(Log.Err, "Unhandled modType...");
            return Err.Unreachable;
        },
    };

    logf(Log.Inf, "Registering module \"{s}\"...", .{name.?});

    var name_copy = try str.copy(name.?, allocator);
    defer name_copy.deinit();

    //var template_copy = try str.copy(template.?, allocator);
    //defer template_copy.deinit();

    var mods = std.ArrayList(Module).init(allocator);
    defer mods.deinit();

    try mods.appendSlice(modules.value);
    try mods.append(.{ .name = name_copy.items, .languages = tmpl.?.value.languages, .libs = &[_][]u8{}, .mtype = modType });

    var file = try cwd.openFile("trsp.conf/modules.json", .{ .mode = fs.File.OpenMode.write_only });
    defer file.close();

    try json.stringify(mods.items, .{}, file.writer());

    logf(Log.Inf, "Succesfully generated module \"{s}\"!", .{name.?});
}
