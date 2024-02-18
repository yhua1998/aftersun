const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.callback = callback;
    return desc;
}

// ! Custom uniforms are automatically aligned by zgpu to 256 bytes,
// ! but arrays and vectors need to be manually aligned to 16 bytes.
// ! https://gpuweb.github.io/gpuweb/wgsl/#alignment-and-size
pub const EnvironmentUniforms = extern struct {
    mvp: zmath.Mat,
    ambient_xy_angle: f32 = 45,
    ambient_z_angle: f32 = 82,
    _pad0: f64 = 0,
    shadow_color: [3]f32 = [_]f32{ 0.7, 0.7, 1.0 },
    shadow_steps: i32 = 250,
};

pub fn callback(it: *ecs.iter_t) callconv(.C) void {
    if (it.count() > 0) return;

    const shadow_color = game.state.environment.shadowColor().toSlice();
    const uniforms = EnvironmentUniforms{
        .mvp = zmath.transpose(zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100)),
        .ambient_xy_angle = game.state.environment.ambientXYAngle(),
        .ambient_z_angle = game.state.environment.ambientZAngle(),
        .shadow_color = .{ shadow_color[0], shadow_color[1], shadow_color[2] },
        .shadow_steps = 150,
    };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_environment,
        .bind_group_handle = game.state.bind_group_environment,
        .output_handle = game.state.environment_output.view_handle,
        .clear_color = game.math.Colors.white.toGpuColor(),
    }) catch unreachable;

    const position = zmath.f32x4(-@as(f32, @floatFromInt(game.state.environment_output.image.width)) / 2, -@as(f32, @floatFromInt(game.state.environment_output.image.height)) / 2, 0, 0);

    game.state.batcher.texture(position, &game.state.environment_output, .{ .color = game.state.environment.ambientColor().value }) catch unreachable;

    game.state.batcher.end(uniforms, game.state.uniform_buffer_environment) catch unreachable;
}
