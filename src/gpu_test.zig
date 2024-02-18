const std = @import("std");
const zgpu = @import("zgpu");
const zglfw = @import("zglfw");

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.os.chdir(path) catch {};
    }

    const window = try zglfw.Window.create(1600, 1000, "gpu device", null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const gctx = try zgpu.GraphicsContext.create(
        allocator,
        window,
        .{},
    );
    std.debug.print("gpu device: {any}\n", .{gctx.device});

    defer gctx.destroy(allocator);
    // defer allocator.destroy();

    while (!window.shouldClose()) {
        zglfw.pollEvents();
    }
}
