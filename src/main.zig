const Canvas = @import("canvas.zig").Canvas(u32);
const std = @import("std");
const font = @import("font.zig");
const dumpToStdout = @import("./dumpCanvas32ToStdout.zig").dumpCanvasToStdout;


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    var canvas = try Canvas.initAlloc(allocator, 1920, 1080);
    defer canvas.deinit();
    canvas.clear(0xff202020);

    var width: usize = 500; 
    var height: usize = 400;
    var frame: usize = 0;

    while (true) {
        var x = (canvas.width-width)/3;
        var y = (canvas.height-height)/3;
        var t: f32 = @floatFromInt(frame);
        t *= 1.0/24.0;
    
        canvas.clear(0xff202020);
        drawFrame(&canvas, x, y, width, height);
        font.drawText(&canvas, font.internalFont, 64, 64, "The quick brown fox jumps over the lazy dog!");
        font.drawText(&canvas, font.internalFont, 64, 64+32, "Citrus irjal endzsint!");

        try dumpToStdout(canvas);
        frame += 1;
    }
}

fn drawFrame(canvas: *Canvas, x: usize, y: usize, width: usize, height: usize) void
{
    canvas.rect(x-1,y-1,x+width+1,y+height+1, 0xff101010);
    canvas.rect(x,y,x+width,y+height, 0xff303030);
    canvas.rect(x,y+32,x+width,y+height, 0xff282828);
    canvas.rect(x+width-16-8,y+16-8,x+width-8,y+32-8, 0xff404040);

    var bottom = y+height;
    var right = x+width;
    drawButton(canvas, right-80-16, bottom-24-16, 80, 24);
    drawButton(canvas, right-80-16-80-8, bottom-24-16, 80, 24);
}

fn drawButton(canvas: *Canvas, x: usize, y: usize, width: usize, height: usize) void
{
    canvas.rect(x-1,y-1,x+width+1,y+height+1, 0xff202020);
    canvas.rect(x,y,x+width,y+height, 0xff303030);
}
