const std = @import("std");
const mach_core = @import("mach_core");
const zflecs = @import("zflecs");
const zmath = @import("zmath");
const zstbi = @import("zstbi");
const builtin = @import("builtin");
const zgpu = @import("zgpu");
const zglfw = @import("zglfw");
const zpool = @import("zpool");

const content_dir = "assets/";
const src_path = "src/aftersun.zig";

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zflecs_pkg = zflecs.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{ .options = .{}, .deps = .{
        .zpool = zpool_pkg,
        .zglfw = zglfw_pkg,
    } });

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });
    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "myapp",
        .src = src_path,
        .target = target,
        .optimize = optimize,
        .deps = &[_]std.Build.Module.Import{
            .{
                .name = "zflecs",
                .module = zflecs_pkg.zflecs,
            },
            .{
                .name = "zmath",
                .module = zmath_pkg.zmath,
            },
            .{
                .name = "zstbi",
                .module = zstbi_pkg.zstbi,
            },
        },
    });
    // if (b.args) |args| app.run.addArgs(args);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&app.run.step);

    zflecs_pkg.link(app.compile);
    zmath_pkg.link(app.compile);
    zstbi_pkg.link(app.compile);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);
    app.compile.step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    app.compile.step.dependOn(&install_content_step.step);

    const gpu_test_step = b.step("gpu_test", "run gpu device");

    const gpu_exe = b.addExecutable(.{
        .name = "gpu_test",
        .root_source_file = .{ .path = "src/gpu_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_gpu = b.addRunArtifact(gpu_exe);

    zgpu_pkg.link(gpu_exe);
    zglfw_pkg.link(gpu_exe);

    gpu_test_step.dependOn(&run_gpu.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

comptime {
    const min_zig = std.SemanticVersion.parse("0.11.0") catch unreachable;
    if (builtin.zig_version.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ builtin.zig_version, min_zig }));
    }
}
