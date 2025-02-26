const std = @import("std");

const Dependency = struct {
    name: []const u8,
    module: ?[]const u8 = null,
    link: ?[]const u8 = null,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = "dotr";

    const deps = &[_]Dependency{
        .{ .name = "age" },
        .{ .name = "parg" },
        .{ .name = "zutils" },
    };

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opts = getBuildOptions(b);
    opts.addOption([]const u8, "name", name);
    exe.root_module.addOptions("build_options", opts);

    appendDependencies(b, exe, target, optimize, deps);
    b.installArtifact(exe);

    const test_deps = &[_]Dependency{
        .{ .name = "protest" },
    };

    const unit_test = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    appendDependencies(b, unit_test, target, optimize, deps ++ test_deps);

    const run_unit_tests = b.addRunArtifact(unit_test);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn appendDependencies(b: *std.Build, comp: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, deps: []const Dependency) void {
    for (deps) |d| {
        const module = d.module orelse d.name;
        const dep = b.dependency(d.name, .{ .target = target, .optimize = optimize });
        const mod = dep.module(module);
        comp.root_module.addImport(d.name, mod);

        if (d.link) |l| {
            comp.linkLibrary(dep.artifact(l));
        }
    }
}

fn getBuildOptions(b: *std.Build) *std.Build.Step.Options {
    const options = b.addOptions();

    const version = b.run(&[_][]const u8{
        "git",
        "describe",
        "--tags",
        "--abbrev=0",
    });
    options.addOption([]const u8, "version", std.mem.trim(u8, version, " \n"));

    const commit = b.run(&[_][]const u8{
        "git",
        "rev-parse",
        "HEAD",
    })[0..8];
    options.addOption([]const u8, "commit", std.mem.trim(u8, commit, " \n"));

    return options;
}
