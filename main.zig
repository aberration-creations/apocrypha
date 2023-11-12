const ui = @import("src/index.zig");
const std = @import("std");

const Canvas = ui.Canvas32;
const Font = ui.Font;
const dumpToStdout = ui.dumpCanvasToStdout;

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

    var font = ui.loadInternalFont(allocator);
    defer font.deinit();

    while (true) {
        var x = (canvas.width - width) / 3;
        var y = (canvas.height - height) / 3;
        var t: f32 = @floatFromInt(frame);
        t *= 1.0 / 24.0;

        canvas.clear(0xff202020);
        try drawFrame(&canvas, &font, x, y, width, height);
        try testFontRender(&canvas, &font);

        try dumpToStdout(canvas);
        frame += 1;
    }
}

fn drawFrame(canvas: *Canvas, font: *Font, x: usize, y: usize, width: usize, height: usize) !void {
    canvas.rect(x - 1, y - 1, x + width + 1, y + height + 1, 0xff101010);
    canvas.rect(x, y, x + width, y + height, 0xff303030);
    canvas.rect(x, y + 32, x + width, y + height, 0xff282828);
    // canvas.rect(x + width - 16 - 8, y + 16 - 8, x + width - 8, y + 32 - 8, 0xff404040);
    try ui.drawText(canvas, font, 14, 0xff909090, x + width - 16 - 6, y + 16 - 11, "x");

    var bottom = y + height;
    var right = x + width;
    try drawButton(canvas, right - 80 - 16, bottom - 24 - 16, 80, 24, font, "Cancel");
    try drawButton(canvas, right - 80 - 16 - 80 - 8, bottom - 24 - 16, 80, 24, font, "Ok");
}

fn drawButton(canvas: *Canvas, x: usize, y: usize, width: usize, height: usize, font: *Font, text: []const u8) !void {
    canvas.rect(x - 1, y - 1, x + width + 1, y + height + 1, 0xff202020);
    canvas.rect(x, y, x + width, y + height, 0xff303030);
    try ui.drawText(canvas, font, 12, 0xff909090, x+width/2-text.len*9/2, y+2, text);
}

fn testFontRender(canvas: *Canvas, font: *Font) !void
{
    try ui.drawText(canvas, font, 10, 0xffff9050, 64, 32, "The quick brown fox jumps over the lazy dog!");
    try ui.drawText(canvas, font, 14, 0xffff0000, 64, 64, "The quick brown fox jumps over the lazy dog!");
    try ui.drawText(canvas, font, 24, 0xffffff00, 64, 64 + 32, "Citrus irjal endzsint!");
    try ui.drawText(canvas, font, 48, 0x40ffffff, 64, 64 + 128, "Transparent!");
    try ui.drawText(canvas, font, 48, 0x20ffffff, 64, 64 + 128+32, "Transparent!");
    try ui.drawText(canvas, font, 48, 0x10ffffff, 64, 64 + 128+64, "Transparent!");
}