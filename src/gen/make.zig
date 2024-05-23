const std = @import("std");
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

// TODO: Needs:
// C std
// C++ std
// Other languages like ZIG or Fortran

const listFiles = @import("listFiles.zig").listFiles;
const listDirs = @import("listFiles.zig").listDirs;

fn addModule(module: modulesJSON.Module, makefile: fs.File, cwd: fs.Dir, allocator: mem.Allocator) !void {
    var mdir = try cwd.openDir(module.name, .{ .iterate = true });
    defer mdir.close();

    if (mem.eql(u8, module.template, "zig")) {
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
                _ = try makefile.write(".zig\n\t$(ZIG) build-lib -static -femit-bin=$@ $^\n\n");
            },
            ModType.SharedLibrary => {
                _ = try makefile.write(".so: ");
                _ = try makefile.write(module.name);
                _ = try makefile.write("/");
                _ = try makefile.write(module.name);
                _ = try makefile.write(".zig\n\t$(ZIG) build-lib -dynamic -femit-bin=$@ $^\n\n");
            },
            else => {
                _ = try makefile.write(": ");
                _ = try makefile.write(module.name);
                _ = try makefile.write("/main.zig\n\t$(ZIG) build-exe -femit-bin=$@ $^\n\n");
            },
        }

        return;
    }

    _ = try makefile.write("$(BUILD)/");

    if (module.mtype == ModType.StaticLibrary) {
        _ = try makefile.write("lib");
    }

    _ = try makefile.write(module.name);

    switch (module.mtype) {
        ModType.StaticLibrary => {
            _ = try makefile.write(".a: ");
        },
        ModType.SharedLibrary => {
            _ = try makefile.write(".so: ");
        },
        else => {
            _ = try makefile.write(": ");
        },
    }

    // WARNING: each record must be freed manualy!!!
    var filelist = try listFiles(mdir, allocator);
    defer filelist.deinit();

    while (filelist.popOrNull()) |e| {
        _ = try makefile.write("$(BUILD)/");
        _ = try makefile.write(module.name);
        _ = try makefile.write(".dir");
        _ = try makefile.write(e[module.name.len..]);
        _ = try makefile.write(".o ");
        allocator.free(e);
    }

    switch (module.mtype) {
        ModType.Default, ModType.Executable => {
            _ = try makefile.write("\n\t$(CXX) -o $@ $^ $(LDFLAGS) -std=c++20\n\n");
        },
        ModType.StaticLibrary => {
            _ = try makefile.write("\n\t$(AR) qc $@ $^\n\n");
        },
        ModType.SharedLibrary => {
            _ = try makefile.write("\n\t$(CXX) -o $@ $^ $(LDFLAGS) -std=c++20 --shared\n\n");
        },
    }

    _ = try makefile.write("$(BUILD)/");
    _ = try makefile.write(module.name);
    _ = try makefile.write(".dir/%.c.o: ");
    _ = try makefile.write(module.name);
    _ = try makefile.write("/%.c\n");
    _ = try makefile.write("\t$(CC) -c -o $@ $^ $(CFLAGS) $(cflags)");
    if (module.mtype == ModType.SharedLibrary)
        _ = try makefile.write(" -fPIC");
    _ = try makefile.write("\n\n");

    _ = try makefile.write("$(BUILD)/");
    _ = try makefile.write(module.name);
    _ = try makefile.write(".dir/%.cpp.o: ");
    _ = try makefile.write(module.name);
    _ = try makefile.write("/%.cpp\n");
    _ = try makefile.write("\t$(CXX) -c -o $@ $^ $(CXXFLAGS) $(cxxflags)");
    if (module.mtype == ModType.SharedLibrary)
        _ = try makefile.write(" -fPIC");
    _ = try makefile.write("\n\n");

    _ = try makefile.write("$(BUILD)/");
    _ = try makefile.write(module.name);
    _ = try makefile.write(".dir/%.zig.o: ");
    _ = try makefile.write(module.name);
    _ = try makefile.write("/%.zig\n");
    _ = try makefile.write("\t$(ZIG) build-obj -femit-bin=\"$@\" $^ --name $(notdir $^) -O ReleaseSmall");
    if (module.mtype == ModType.SharedLibrary) {
        _ = try makefile.write(" -fPIC");
    } else {
        _ = try makefile.write(" -fPIE");
    }
    _ = try makefile.write("\n\n");
}

pub fn make(cwd: fs.Dir, allocator: mem.Allocator, build: Build) !void {
    _ = build;

    var makefile = try cwd.createFile("Makefile", .{});
    defer makefile.close();

    var modules = try loadModules(cwd, allocator);
    defer modules.deinit();

    log(Log.Inf, "Generating Makefile");
    _ = try makefile.write("BUILD ?= build\n\n");
    _ = try makefile.write("RM ?= rm -f\n");
    _ = try makefile.write("MKDIR ?= mkdir\n");
    _ = try makefile.write("ZIG ?= zig\n\n");
    _ = try makefile.write("cflags := -Wall -Wextra -Wpedantic -std=c17\n");
    _ = try makefile.write("cxxflags := -Wall -Wextra -Wpedantic -std=c++20\n");
    _ = try makefile.write("ldflags := -L./$(BUILD)\n\n");

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

    // _ = try makefile.write(".SUFIXES: .c .cpp .o .a .so\n\n");

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
    _ = try makefile.write("\t$(MKDIR) $@\n\n");

    for (modules.value) |module| {
        try addModule(module, makefile, cwd, allocator);
    }
}
