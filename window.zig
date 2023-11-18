const std = @import("std");
const ui = @import("./src/index.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("MEMORY LEAK");
    }

    var frame: u16 = 0;
    var canvas: ui.Canvas32 = try ui.Canvas32.initAlloc(allocator, 256, 256);
    defer canvas.deinit();

    const window = ui.Window.init(.{
        .title = "Xor Texture",
    });
    defer window.deinit();


    while (ui.nextEvent(.{ .blocking = true })) |evt| {
        switch (evt) {
            ui.Event.paint => {
                frame += 1;
                renderXorTextureToCanvas(canvas, frame);
                ui.presentCanvas32(window, canvas);
            },
            ui.Event.keydown => |key| switch(key) {
                ui.Key.escape => return,
                else => std.debug.print("unknown key\n", .{}),
            },
            ui.Event.resize => |size| {
                std.debug.print("resize to {}x{}\n", .{ size.width, size.height });
                canvas.deinit();
                canvas = try ui.Canvas32.initAlloc(allocator, size.width, size.height);
            },
            ui.Event.pointermove => |position| {
                std.debug.print("pointer move to {} {}\n", .{ position.x, position.y });
            },
            ui.Event.closewindow => return,
            else => {
                // std.debug.print("unknown event\n", .{});
            },
        }
    }

}

pub fn renderXorTextureToCanvas(canvas: ui.Canvas32, frame: u16) void {
    for (0..canvas.height) |py| {
        var row = canvas.getRow(py);
        for (0..canvas.width) |px| {
            const value: u8 = @intCast(((px ^ py) + frame) & 0xff);
            const color = ui.color32bgra.makeColor32bgra(value, value, value, 255);
            row[px] = color;
        }
    }
}
