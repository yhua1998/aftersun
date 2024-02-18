const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const math = game.math;
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Position), .inout = .In };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Rotation), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.SpriteRenderer), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[3] = .{ .id = ecs.id(components.CharacterRenderer), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[4] = .{ .id = ecs.id(components.ParticleRenderer), .oper = ecs.oper_kind_t.Optional };
    desc.query.order_by_component = ecs.id(components.Position);
    desc.query.order_by = orderBy;
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const uniforms = gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.renderTextureMatrix()) };

    // Draw diffuse texture sprites using diffuse pipeline
    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_height,
        .bind_group_handle = game.state.bind_group_height,
        .output_handle = game.state.reverse_height_output.view_handle,
        .clear_color = math.Color.initBytes(1, 0, 0, 255).toGpuColor(),
    }) catch unreachable;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Position, 1)) |positions| {
                const rotation = if (ecs.field(it, components.Rotation, 2)) |rotations| rotations[i].value else 0.0;
                var position = positions[i].toF32x4();
                position[1] += position[2];

                if (ecs.field(it, components.SpriteRenderer, 3)) |renderers| {
                    renderers[i].order = i; // Set order so height passes can match time

                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].index],
                        .{
                            .vert_mode = renderers[i].vert_mode,
                            .time = game.state.game_time + @as(f32, @floatFromInt(renderers[i].order)),
                            .rotation = rotation,
                            .flip_x = renderers[i].flip_x,
                            .flip_y = renderers[i].flip_y,
                        },
                    ) catch unreachable;
                }

                if (ecs.field(it, components.CharacterRenderer, 4)) |renderers| {

                    // Hair
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].hair_index],
                        .{
                            .flip_x = renderers[i].flip_head,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Back
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].back_index],
                        .{
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Top
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].top_index],
                        .{
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Feet
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].feet_index],
                        .{
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Bottom
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].bottom_index],
                        .{
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Head
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].head_index],
                        .{
                            .flip_x = renderers[i].flip_head,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Body
                    game.state.batcher.sprite(
                        position,
                        &game.state.heightmap,
                        game.state.atlas.sprites[renderers[i].body_index],
                        .{
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;
                }

                if (ecs.field(it, components.ParticleRenderer, 5)) |renderers| {
                    for (renderers[i].particles) |particle| {
                        if (particle.alive()) {
                            game.state.batcher.sprite(
                                zmath.f32x4(particle.position[0], particle.position[1], particle.position[2], 0),
                                &game.state.heightmap,
                                game.state.atlas.sprites[particle.index],
                                .{},
                            ) catch unreachable;
                        }
                    }
                }
            }
        }
    }

    game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
}

fn orderBy(e1: ecs.entity_t, c1: ?*const anyopaque, e2: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const position_1 = ecs.cast(components.Position, c1);
    const position_2 = ecs.cast(components.Position, c2);

    if (position_1.z > position_2.z) return @as(c_int, 1) else if (position_1.z < position_2.z) return @as(c_int, 0);

    const maptile_1 = ecs.has_id(game.state.world, e1, ecs.id(components.MapTile));
    const maptile_2 = ecs.has_id(game.state.world, e2, ecs.id(components.MapTile));

    if (!maptile_1 and maptile_2) return @as(c_int, 1) else if (maptile_1 and !maptile_2) return @as(c_int, 0);

    const tile_1 = position_1.toTile(0);
    const tile_2 = position_1.toTile(0);

    if (tile_1.y > tile_2.y) return @as(c_int, 0) else if (tile_1.y < tile_2.y) return @as(c_int, 1);

    if (@abs(position_1.y - position_2.y) <= 16) {
        var counter1 = if (ecs.get(game.state.world, e1, components.Tile)) |tile| tile.counter else 0;
        var counter2 = if (ecs.get(game.state.world, e2, components.Tile)) |tile| tile.counter else 0;
        return @as(c_int, @intCast(@intFromBool(counter1 < counter2))) - @as(c_int, @intCast(@intFromBool(counter1 > counter2)));
    }
    return @as(c_int, @intCast(@intFromBool(position_1.y > position_2.y))) - @as(c_int, @intCast(@intFromBool(position_1.y < position_2.y)));
}
