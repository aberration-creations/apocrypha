const ui = @import("./src/index.zig");
const std = @import("std");

const Canvas = ui.Canvas32;
const color = ui.color32bgra.makeColor32bgra;
const mixColor = ui.color32bgra.mixColor32bgraByFloat;
const Box = ui.BoxGeneric(u32);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    var canvas = try Canvas.initAlloc(allocator, 1920, 1080);
    var dcanvas = try Canvas.initAlloc(allocator, 1920, 1080);
    defer canvas.deinit();
    defer dcanvas.deinit();

    const window = ui.Window.init(.{
        .title = "Text Example",
        .width = @intCast(canvas.width),
        .height = @intCast(canvas.height),
    });
    defer window.deinit();

    const black = color(0, 0, 0, 255);
    canvas.clear(black);
    const backgroundColor = color(32, 32, 32, 255);
    const red = color(255, 32, 32, 255);
    const yellow = color(255, 210, 32, 255);
    const area1 = mixColor(backgroundColor, red, 0.5);
    const area2 = mixColor(backgroundColor, yellow, 0.5);
    const area3 = mixColor(backgroundColor, color(77,255,44,255), 0.25);
    const blue = color(16,64,255,255);
    _ = blue;
    const white = color(255, 255, 255, 255);
    const pointOutside = mixColor(mixColor(backgroundColor, red, 0.5), yellow, 0.25);
    const offWhite = mixColor(backgroundColor, white, 0.7);


    while (true) {

        while (ui.nextEvent(.{ .blocking = false })) |evt| switch (evt) {
            ui.Event.keydown => |key| switch(key) {
                ui.Key.escape => return,
                else => {},
            },
            ui.Event.resize => |size| { 
                try canvas.reallocate(size.width, size.height);
                try dcanvas.reallocate(size.width, size.height);
            },
            ui.Event.closewindow => return,
            else => {},
        };

        const time: u32 = @intCast((std.time.milliTimestamp() >> 4) & 0xffffffff);
        var prng = std.Random.DefaultPrng.init(0);
        canvas.clear(black);
        for (0..14) |x| 
        {
            for(0..8) |y|
            {
                const px: u32 = @intCast(x*128+64);
                const py: u32 = @intCast(y*128+24);

                var b0 = Box.initCoords(
                    px + @as(u32, (prng.random().int(u32)+%time) % 128), 
                    py + @as(u32, prng.random().int(u32) % 128), 
                    px + @as(u32, prng.random().int(u32) % 128), 
                    py + @as(u32, prng.random().int(u32) % 128));

                var b1 = Box.initCoords(
                    px + @as(u32, prng.random().int(u32) % 128), 
                    py + @as(u32, (prng.random().int(u32)+%time) % 128), 
                    px + @as(u32, prng.random().int(u32) % 128), 
                    py + @as(u32, prng.random().int(u32) % 128));

                const b2 = b0.getIntersectionBox(b1);

                const b0c = area1;
                const b1c = area2;
                var b2c = area3;

                if (b0.isInsideBox(b1)) b2c = offWhite;
                if (b1.isInsideBox(b0)) b2c = offWhite;

                canvas.rectUnsigned(px+1, py+1, px+127, py+127, backgroundColor);
                canvas.rectUnsigned(b0.x0, b0.y0, b0.x1, b0.y1, b0c);
                canvas.rectUnsigned(b1.x0, b1.y0, b1.x1, b1.y1, b1c);
                canvas.rectUnsigned(b2.x0, b2.y0, b2.x1, b2.y1, b2c);

                for (0..256) |_|
                {
                    const qx = px + @as(u32, (prng.random().int(u32)-%time) % 128);
                    const qy = py + @as(u32, (prng.random().int(u32)+%time) % 128);
                    var qc = pointOutside;
                    if (b0.containsPoint(qx, qy) or b1.containsPoint(qx, qy)) {
                        qc = backgroundColor;
                    }
                    canvas.setPixel(qx, qy, qc);
                }
            }
            std.time.sleep(1);
        }
        // try ui.dumpCanvasToStdout(canvas);
        ui.presentWithDeltaCanvas32(window, canvas, &dcanvas);
    }

}
