const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

const str = @import("../common/str.zig");

const modulesJSON = @import("../json/modules.json.zig");
const ModType = modulesJSON.ModType;
const loadModules = modulesJSON.load;

const buildJSON = @import("../json/build.json.zig");
const Build = buildJSON.Build;

const languagesJSON = @import("../json/languages.json.zig");
const loadLanguage = languagesJSON.load;
const compileLanguage = languagesJSON.compileCmd;
const Language = languagesJSON.Language;

// TODO: Needs:
// C std
// C++ std
// Other languages like ZIG or Fortran

const listFiles = @import("listFiles.zig").listFiles;
const listDirs = @import("listFiles.zig").listDirs;

fn addModule(module: modulesJSON.Module, makefile: fs.File, cwd: fs.Dir, allocator: mem.Allocator, t: std.StringHashMap(Language)) !void {
    _ = cwd;
    _ = allocator;

    const not_compile_obj = switch (module.mtype) {
        ModType.Default, ModType.Executable => t.get(module.languages[0]).?.exe.obj == null,
        ModType.StaticLibrary => t.get(module.languages[0]).?.lib.obj == null,
        ModType.SharedLibrary => t.get(module.languages[0]).?.dll.obj == null,
    };

    if (not_compile_obj) {
        _ = try makefile.write("$(BUILD)/");

        if (module.mtype == ModType.StaticLibrary) {
            _ = try makefile.write("lib");
        }

        _ = try makefile.write(module.name);

        switch (module.mtype) {
            ModType.StaticLibrary => {
                _ = try makefile.write(".a: ");
                _ = try makefile.write(module.name);
                _ = try makefile.write("/");
                _ = try makefile.write(module.name);
                _ = try makefile.write(t.get(module.languages[0]).?.ext);
                _ = try makefile.write("\n\t");
                _ = try makefile.write(t.get(module.languages[0]).?.lib.cmd);
            },
            ModType.SharedLibrary => {
                _ = try makefile.write(".so: ");
                _ = try makefile.write(module.name);
                _ = try makefile.write("/");
                _ = try makefile.write(module.name);
                _ = try makefile.write(t.get(module.languages[0]).?.ext);
                _ = try makefile.write("\n\t");
                _ = try makefile.write(t.get(module.languages[0]).?.dll.cmd);
            },
            else => {
                _ = try makefile.write(": ");
                _ = try makefile.write(module.name);
                _ = try makefile.write("/main");
                _ = try makefile.write(t.get(module.languages[0]).?.ext);
                _ = try makefile.write("\n\t");
                _ = try makefile.write(t.get(module.languages[0]).?.dll.cmd);
            },
        }
        _ = try makefile.write("\n\n");

        return;
    }

    // var mdir = try cwd.openDir(module.name, .{ .iterate = true });
    // defer mdir.close();

    // // WARNING: each record must be freed manualy!!!
    // var filelist = try listFiles(mdir, allocator);
    // defer filelist.deinit();

    _ = try makefile.write(module.name);
    _ = try makefile.write("_SRC := ");

    var t_it = t.iterator();
    while (t_it.next()) |lang| {
        _ = try makefile.write("$(wildcard ");
        _ = try makefile.write(module.name);
        _ = try makefile.write("/**/*");
        _ = try makefile.write(lang.value_ptr.ext);
        _ = try makefile.write(" ");
        _ = try makefile.write(module.name);
        _ = try makefile.write("/*");
        _ = try makefile.write(lang.value_ptr.ext);
        _ = try makefile.write(") ");
    }

    _ = try makefile.write("\n");
    _ = try makefile.write(module.name);
    _ = try makefile.write("_BIN := $(patsubst ");
    _ = try makefile.write(module.name);
    _ = try makefile.write("/%,$(BUILD)/");
    _ = try makefile.write(module.name);
    _ = try makefile.write(".dir/%.o,$(");
    _ = try makefile.write(module.name);
    _ = try makefile.write("_SRC))\n");
    _ = try makefile.write("$(BUILD)/");
    if (module.mtype == ModType.StaticLibrary)
        _ = try makefile.write("lib");
    _ = try makefile.write(module.name);
    switch (module.mtype) {
        ModType.StaticLibrary => {
            _ = try makefile.write(".a");
        },
        ModType.SharedLibrary => {
            _ = try makefile.write(".so");
        },
        else => {},
    }
    _ = try makefile.write(": $(");
    _ = try makefile.write(module.name);
    _ = try makefile.write("_BIN)\n\t");
    switch (module.mtype) {
        ModType.Default, ModType.Executable => {
            _ = try makefile.write(t.get(module.languages[0]).?.exe.cmd);
        },
        ModType.StaticLibrary => {
            _ = try makefile.write(t.get(module.languages[0]).?.lib.cmd);
        },
        ModType.SharedLibrary => {
            _ = try makefile.write(t.get(module.languages[0]).?.dll.cmd);
        },
    }
    _ = try makefile.write("\n\n");

    // Reuse t_it
    t_it = t.iterator();
    while (t_it.next()) |lang| {
        _ = try makefile.write("$(filter %");
        _ = try makefile.write(lang.value_ptr.ext);
        _ = try makefile.write(".o, $(");
        _ = try makefile.write(module.name);
        _ = try makefile.write("_BIN)):$(BUILD)/");
        _ = try makefile.write(module.name);
        _ = try makefile.write(".dir/%.o:");
        _ = try makefile.write(module.name);
        _ = try makefile.write("/%\n\t");
        switch (module.mtype) {
            ModType.Default, ModType.Executable => {
                _ = try makefile.write(lang.value_ptr.exe.obj.?);
            },
            ModType.StaticLibrary => {
                _ = try makefile.write(lang.value_ptr.lib.obj.?);
            },
            ModType.SharedLibrary => {
                _ = try makefile.write(lang.value_ptr.dll.obj.?);
            },
        }
        _ = try makefile.write("\n\n");
    }

    // while (filelist.popOrNull()) |e| {
    //     _ = try makefile.write("$(BUILD)/");
    //     _ = try makefile.write(module.name);
    //     _ = try makefile.write(".dir");
    //     _ = try makefile.write(e[module.name.len..]);
    //     _ = try makefile.write(".o ");
    //     allocator.free(e);
    // }

    // switch (module.mtype) {
    //     ModType.Default, ModType.Executable => {
    //         _ = try makefile.write("\n\t$(CXX) -o $@ $^ $(LDFLAGS) -std=c++20\n\n");
    //     },
    //     ModType.StaticLibrary => {
    //         _ = try makefile.write("\n\t$(AR) qc $@ $^\n\n");
    //     },
    //     ModType.SharedLibrary => {
    //         _ = try makefile.write("\n\t$(CXX) -o $@ $^ $(LDFLAGS) -std=c++20 --shared\n\n");
    //     },
    // }

    // _ = try makefile.write("$(BUILD)/");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write(".dir/%.c.o: ");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write("/%.c\n");
    // _ = try makefile.write("\t$(CC) -c -o $@ $^ $(CFLAGS) $(cflags)");
    // if (module.mtype == ModType.SharedLibrary)
    //     _ = try makefile.write(" -fPIC");
    // _ = try makefile.write("\n\n");

    // _ = try makefile.write("$(BUILD)/");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write(".dir/%.cpp.o: ");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write("/%.cpp\n");
    // _ = try makefile.write("\t$(CXX) -c -o $@ $^ $(CXXFLAGS) $(cxxflags)");
    // if (module.mtype == ModType.SharedLibrary)
    //     _ = try makefile.write(" -fPIC");
    // _ = try makefile.write("\n\n");

    // _ = try makefile.write("$(BUILD)/");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write(".dir/%.zig.o: ");
    // _ = try makefile.write(module.name);
    // _ = try makefile.write("/%.zig\n");
    // _ = try makefile.write("\t$(ZIG) build-obj -femit-bin=\"$@\" $^ --name $(notdir $^) -O ReleaseSmall");
    // if (module.mtype == ModType.SharedLibrary) {
    //     _ = try makefile.write(" -fPIC");
    // } else {
    //     _ = try makefile.write(" -fPIE");
    // }
    // _ = try makefile.write("\n\n");
}

pub fn make(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    _ = build;

    var makefile = try cwd.createFile("Makefile", .{});
    defer makefile.close();

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    var languages_map = std.StringHashMap(Language).init(allocator);
    defer {
        var languages_map_it = languages_map.iterator();
        while (languages_map_it.next()) |entry| {
            allocator.free(entry.value_ptr.ext);
            allocator.free(entry.value_ptr.exe.cmd);
            allocator.free(entry.value_ptr.lib.cmd);
            allocator.free(entry.value_ptr.dll.cmd);
            if (entry.value_ptr.exe.obj != null) allocator.free(entry.value_ptr.exe.obj.?);
            if (entry.value_ptr.lib.obj != null) allocator.free(entry.value_ptr.lib.obj.?);
            if (entry.value_ptr.dll.obj != null) allocator.free(entry.value_ptr.dll.obj.?);
        }
        languages_map.deinit();
    }

    for (modules.value) |module| {
        for (module.languages) |name| {
            if (languages_map.get(name) == null) {
                const lang = try loadLanguage(cwd, allocator, name);
                defer lang.deinit();

                const lg: Language = .{
                    .ext = (try str.copy(lang.value.ext, allocator)),
                    .exe = .{
                        .cmd = try languagesJSON.compileCmd(allocator, lang.value.exe.cmd, "$^", "$@"),
                        .obj = if (lang.value.exe.obj == null) null else try languagesJSON.compileCmd(allocator, lang.value.exe.obj.?, "$^", "$@"),
                    },
                    .lib = .{
                        .cmd = try languagesJSON.compileCmd(allocator, lang.value.lib.cmd, "$^", "$@"),
                        .obj = if (lang.value.lib.obj == null) null else try languagesJSON.compileCmd(allocator, lang.value.lib.obj.?, "$^", "$@"),
                    },
                    .dll = .{
                        .cmd = try languagesJSON.compileCmd(allocator, lang.value.dll.cmd, "$^", "$@"),
                        .obj = if (lang.value.dll.obj == null) null else try languagesJSON.compileCmd(allocator, lang.value.dll.obj.?, "$^", "$@"),
                    },
                };

                try languages_map.put(name, lg);
            }
        }
    }

    log(Log.Inf, "Generating Makefile");
    _ = try makefile.write("BUILD ?= build\n\n");
    _ = try makefile.write("RM ?= rm -f\n");
    _ = try makefile.write("MKDIR ?= mkdir\n\n");

    _ = try makefile.write("dirs := $(BUILD) ");
    for (modules.value) |module| {
        _ = try makefile.write("$(BUILD)/");
        _ = try makefile.write(module.name);
        _ = try makefile.write(".dir ");

        var mdir = try cwd.openDir(module.name, .{ .iterate = true });
        defer mdir.close();

        var dirs = try listDirs(mdir, allocator);
        defer dirs.deinit();

        while (dirs.popOrNull()) |dir| {
            _ = try makefile.write("$(BUILD)/");
            _ = try makefile.write(module.name);
            _ = try makefile.write(".dir");
            _ = try makefile.write(dir[module.name.len..]);
            _ = try makefile.write(" ");
            allocator.free(dir);
        }
    }
    _ = try makefile.write("\n\n");

    _ = try makefile.write(".PHONY: all\n");
    _ = try makefile.write("all: $(dirs) ");
    for (modules.value) |module| {
        _ = try makefile.write("$(BUILD)/");
        if (module.mtype == ModType.StaticLibrary) {
            _ = try makefile.write("lib");
        }
        _ = try makefile.write(module.name);
        switch (module.mtype) {
            ModType.StaticLibrary => {
                _ = try makefile.write(".a ");
            },
            ModType.SharedLibrary => {
                _ = try makefile.write(".so ");
            },
            else => {
                _ = try makefile.write(" ");
            },
        }
    }
    _ = try makefile.write("\n\n");

    _ = try makefile.write("clean:\n");
    _ = try makefile.write("\t$(RM) -r $(BUILD)\n\n");
    _ = try makefile.write("$(dirs):\n");
    _ = try makefile.write("\t$(MKDIR) -p $@\n\n");

    for (modules.value) |module| {
        try addModule(module, makefile, cwd, allocator, languages_map);
    }
}
