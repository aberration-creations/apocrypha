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

    var font = ui.loadInternalFont(allocator);
    defer font.deinit();

    const window = ui.Window.init(.{
        .title = "Text Example",
        .width = @intCast(canvas.width),
        .height = @intCast(canvas.height),
    });
    defer window.deinit();

    while (ui.nextEvent(.{ .blocking = true })) |evt| {
        switch (evt) {
            ui.Event.paint => {
                const x: i16 = @intCast(canvas.width / 3);
                const y: i16 = @intCast(canvas.height / 3);
                canvas.clear(0xff202020);
                try drawFrame(&canvas, &font, x, y, 500, 400);
                try testFontRender(&canvas, &font);
                ui.presentCanvas32(window, canvas);
            },
            ui.Event.keydown => |key| switch(key) {
                ui.Key.escape => return,
                else => {},
            },
            ui.Event.resize => |size| try canvas.reallocate(size.width, size.height),
            ui.Event.closewindow => return,
            else => {},
        }
    }
}

fn drawFrame(canvas: *Canvas, font: *Font, x: i16, y: i16, width: i16, height: i16) !void {
    canvas.rect(x - 1, y - 1, x + width + 1, y + height + 1, 0xff101010);
    canvas.rect(x, y, x + width, y + height, 0xff303030);
    canvas.rect(x, y + 32, x + width, y + height, 0xff282828);
    try ui.drawText(canvas, font, 14, 0xff909090, @intCast(x + width - 16 - 6), @intCast(y + 16 - 11), "x");

    const bottom = y + height;
    const right = x + width;
    try drawButton(canvas, right - 80 - 16, bottom - 24 - 16, 80, 24, font, "Cancel");
    try drawButton(canvas, right - 80 - 16 - 80 - 8, bottom - 24 - 16, 80, 24, font, "Ok");
}

fn drawButton(canvas: *Canvas, x: i16, y: i16, width: i16, height: i16, font: *Font, text: []const u8) !void {
    canvas.rect(x - 1, y - 1, x + width + 1, y + height + 1, 0xff202020);
    canvas.rect(x, y, x + width, y + height, 0xff303030);
    try ui.drawCenteredTextSpan(canvas, font, 12, 0xff909090, x, y, x+width, y+height, text);
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