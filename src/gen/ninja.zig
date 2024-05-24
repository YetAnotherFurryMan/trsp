const std = @import("std");
const json = std.json;
const mem = std.mem;
const fs = std.fs;

const l = @import("../log.zig");
const Log = l.Log;
const log = l.log;
const logf = l.logf;

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

fn addModule(module: modulesJSON.Module, buildninja: fs.File, cwd: fs.Dir, allocator: mem.Allocator, t: std.StringHashMap(json.Parsed(Language))) !void {
    const not_compile_obj = switch (module.mtype) {
        ModType.Default, ModType.Executable => t.get(module.languages[0]).?.value.exe.obj == null,
        ModType.StaticLibrary => t.get(module.languages[0]).?.value.lib.obj == null,
        ModType.SharedLibrary => t.get(module.languages[0]).?.value.dll.obj == null,
    };

    if (not_compile_obj) {
        _ = try buildninja.write("build $builddir/");
        switch (module.mtype) {
            ModType.Default, ModType.Executable => {
                _ = try buildninja.write(module.name);
                _ = try buildninja.write(": exe-");
                _ = try buildninja.write(module.languages[0]);
                _ = try buildninja.write(" ");
                _ = try buildninja.write(module.name);
                _ = try buildninja.write("/main");
            },
            ModType.StaticLibrary => {
                _ = try buildninja.write("lib");
                _ = try buildninja.write(module.name);
                _ = try buildninja.write(".a: lib-");
                _ = try buildninja.write(module.languages[0]);
                _ = try buildninja.write(" ");
                _ = try buildninja.write(module.name);
                _ = try buildninja.write("/");
                _ = try buildninja.write(module.name);
            },
            ModType.SharedLibrary => {
                _ = try buildninja.write(module.name);
                _ = try buildninja.write(".so: dll-");
                _ = try buildninja.write(module.languages[0]);
                _ = try buildninja.write(" ");
                _ = try buildninja.write(module.name);
                _ = try buildninja.write("/");
                _ = try buildninja.write(module.name);
            },
        }
        _ = try buildninja.write(t.get(module.languages[0]).?.value.ext);
        _ = try buildninja.write("\n");

        return;
    }

    const type_str = switch (module.mtype) {
        ModType.Default, ModType.Executable => "exe",
        ModType.StaticLibrary => "lib",
        ModType.SharedLibrary => "dll",
    };

    var mdir = try cwd.openDir(module.name, .{ .iterate = true });
    defer mdir.close();

    // if (mem.eql(u8, module.languages[0], "zig")) {
    //     _ = try buildninja.write("build $builddir/");
    //     switch (module.mtype) {
    //         ModType.Default, ModType.Executable => {
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write(": zig-exe ");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write("/main.zig\n");
    //         },
    //         ModType.StaticLibrary => {
    //             _ = try buildninja.write("lib");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write(".a: zig-lib ");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write("/");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write(".zig\n");
    //         },
    //         ModType.SharedLibrary => {
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write(".so: zig-dll ");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write("/");
    //             _ = try buildninja.write(module.name);
    //             _ = try buildninja.write(".zig\n");
    //         },
    //     }
    //     return;
    // }

    // WARNING: each record must be freed manualy!!!
    var filelist = try listFiles(mdir, allocator);
    defer filelist.deinit();

    var bins = std.ArrayList([]u8).init(allocator);
    defer bins.deinit();

    while_filelist: while (filelist.popOrNull()) |e| {
        defer allocator.free(e);
        const ext = fs.path.extension(e);
        var it = t.iterator();
        while (it.next()) |lang| {
            if (mem.eql(u8, ext, lang.value_ptr.value.ext)) {
                const bin = try mem.join(allocator, "", &[_][]const u8{ "$builddir/", module.name, ".dir", e[module.name.len..], ".o" });

                _ = try buildninja.write("build ");
                _ = try buildninja.write(bin);

                _ = try buildninja.write(": ");
                _ = try buildninja.write(type_str);
                _ = try buildninja.write("-obj-");
                _ = try buildninja.write(lang.key_ptr.*);
                _ = try buildninja.write(" ");
                _ = try buildninja.write(e);
                _ = try buildninja.write("\n");

                try bins.append(bin);
                continue :while_filelist;
            }
        }

        logf(Log.War, "Skipping file {s} - unknown extension.", .{e});
    }

    _ = try buildninja.write("build $builddir/");
    switch (module.mtype) {
        ModType.Default, ModType.Executable => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(": exe-");
        },
        ModType.StaticLibrary => {
            _ = try buildninja.write("lib");
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".a: lib-");
        },
        ModType.SharedLibrary => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".so: dll-");
        },
    }
    _ = try buildninja.write(module.languages[0]);

    while (bins.popOrNull()) |bin| {
        _ = try buildninja.write(" ");
        _ = try buildninja.write(bin);
        allocator.free(bin);
    }

    _ = try buildninja.write("\n\nbuild ");
    _ = try buildninja.write(module.name);
    _ = try buildninja.write(": phony $builddir/");

    switch (module.mtype) {
        ModType.Default, ModType.Executable => {
            _ = try buildninja.write(module.name);
        },
        ModType.StaticLibrary => {
            _ = try buildninja.write("lib");
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".a");
        },
        ModType.SharedLibrary => {
            _ = try buildninja.write(module.name);
            _ = try buildninja.write(".so");
        },
    }

    _ = try buildninja.write("\n\n");
}

pub fn ninja(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    _ = build;

    var buildninja = try cwd.createFile("build.ninja", .{});
    defer buildninja.close();

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    log(Log.Inf, "Generating build.ninja");
    _ = try buildninja.write("ninja_required_version = 1.5\n\n");
    _ = try buildninja.write("builddir = build\n\n");
    // _ = try buildninja.write("cflags = -Wall -Wextra -Wpedantic -std=c17\n");
    // _ = try buildninja.write("cxxflags = -Wall -Wextra -Wpedantic -std=c++20\n");
    // _ = try buildninja.write("ldflags = -L./$builddir\n\n");
    // _ = try buildninja.write("rule cc\n");
    // _ = try buildninja.write("  depfile = $out.d\n");
    // _ = try buildninja.write("  deps = gcc\n");
    // _ = try buildninja.write("  command = cc $includes $flags $cflags -c $in -MD -MT $out -MF $out.d -o $out\n");
    // _ = try buildninja.write("  description = Building C object $out\n\n");
    // _ = try buildninja.write("rule cpp\n");
    // _ = try buildninja.write("  depfile = $out.d\n");
    // _ = try buildninja.write("  deps = gcc\n");
    // _ = try buildninja.write("  command = c++ $includes $flags $cxxflags -c $in -MD -MT $out -MF $out.d -o $out -fno-use-cxa-atexit\n");
    // _ = try buildninja.write("  description = Building C++ object $out\n\n");
    // _ = try buildninja.write("rule zig-obj\n");
    // _ = try buildninja.write("  command = zig build-obj $includes $flags $in -femit-bin=$out -O ReleaseSmall\n");
    // _ = try buildninja.write("  description = Building Zig object $out\n\n");
    // _ = try buildninja.write("rule zig-exe\n");
    // _ = try buildninja.write("  command = zig build-exe $includes $flags $in -femit-bin=$out\n");
    // _ = try buildninja.write("  description = Building Zig executable $out\n\n");
    // _ = try buildninja.write("rule zig-lib\n");
    // _ = try buildninja.write("  command = zig build-lib $includes $flags $in -femit-bin=$out -static\n");
    // _ = try buildninja.write("  description = Building Zig static library $out\n\n");
    // _ = try buildninja.write("rule zig-dll\n");
    // _ = try buildninja.write("  command = zig build-lib $includes $flags $in -femit-bin=$out -dynamic\n");
    // _ = try buildninja.write("  description = Building Zig shared library $out\n\n");
    // _ = try buildninja.write("rule lib\n");
    // _ = try buildninja.write("  command = ar qc $out $in\n");
    // _ = try buildninja.write("  description = Building static library $out\n\n");
    // _ = try buildninja.write("rule dll\n");
    // _ = try buildninja.write("  command = ld --shared $ldflags -o $out $in\n");
    // _ = try buildninja.write("  description = Building dynamic library $out\n\n");
    // _ = try buildninja.write("rule exe\n");
    // _ = try buildninja.write("  command = c++ -o $out $in $libs\n");
    // _ = try buildninja.write("  description = Building executable $out\n\n");

    var languages_map = std.StringHashMap(json.Parsed(Language)).init(allocator);
    defer {
        var languages_map_it = languages_map.iterator();
        while (languages_map_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        languages_map.deinit();
    }

    for (modules.value) |module| {
        for (module.languages) |name| {
            if (languages_map.get(name) == null) {
                const lang = try loadLanguage(cwd, allocator, name);
                try languages_map.put(name, lang);
            }
        }
    }

    var languages_map_it = languages_map.iterator();
    while (languages_map_it.next()) |entry| {
        const lang = entry.value_ptr;

        { // exe
            const cmd_exe = try compileLanguage(allocator, lang.value.exe.cmd, "$in", "$out");
            defer allocator.free(cmd_exe);

            _ = try buildninja.write("rule exe-");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write("\n  command = ");
            _ = try buildninja.write(cmd_exe);
            _ = try buildninja.write("\n  description = Compiling ");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write(" executable $out\n\n");

            if (lang.value.exe.obj != null) {
                const cmd_exe_obj = try compileLanguage(allocator, lang.value.exe.obj.?, "$in", "$out");
                defer allocator.free(cmd_exe_obj);

                _ = try buildninja.write("rule exe-obj-");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write("\n  command = ");
                _ = try buildninja.write(cmd_exe_obj);
                _ = try buildninja.write("\n  description = Compiling ");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write(" object $out\n\n");
            }
        }
        { // lib
            const cmd_lib = try compileLanguage(allocator, lang.value.lib.cmd, "$in", "$out");
            defer allocator.free(cmd_lib);

            _ = try buildninja.write("rule lib-");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write("\n  command = ");
            _ = try buildninja.write(cmd_lib);
            _ = try buildninja.write("\n  description = Compiling ");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write(" static library $out\n\n");

            if (lang.value.lib.obj != null) {
                const cmd_lib_obj = try compileLanguage(allocator, lang.value.lib.obj.?, "$in", "$out");
                defer allocator.free(cmd_lib_obj);

                _ = try buildninja.write("rule lib-obj-");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write("\n  command = ");
                _ = try buildninja.write(cmd_lib_obj);
                _ = try buildninja.write("\n  description = Compiling ");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write(" object $out\n\n");
            }
        }
        { // dll
            const cmd_dll = try compileLanguage(allocator, lang.value.dll.cmd, "$in", "$out");
            defer allocator.free(cmd_dll);

            _ = try buildninja.write("rule dll-");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write("\n  command = ");
            _ = try buildninja.write(cmd_dll);
            _ = try buildninja.write("\n  description = Compiling ");
            _ = try buildninja.write(entry.key_ptr.*);
            _ = try buildninja.write(" dynamic library $out\n\n");

            if (lang.value.dll.obj != null) {
                const cmd_dll_obj = try compileLanguage(allocator, lang.value.dll.obj.?, "$in", "$out");
                defer allocator.free(cmd_dll_obj);

                _ = try buildninja.write("rule dll-obj-");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write("\n  command = ");
                _ = try buildninja.write(cmd_dll_obj);
                _ = try buildninja.write("\n  description = Compiling ");
                _ = try buildninja.write(entry.key_ptr.*);
                _ = try buildninja.write(" object $out\n\n");
            }
        }
    }

    for (modules.value) |module| {
        try addModule(module, buildninja, cwd, allocator, languages_map);
    }
}
