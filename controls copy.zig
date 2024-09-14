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
        if (deinit_status == .leak) @panic("MEMORY LEAK!");
    }

    const window = ui.Window.init(.{
        .title = "Controls",
        .width = 600,
        .height = 400,
    });
    defer window.deinit();

    var font = ui.loadInternalFont(allocator);
    defer font.deinit();

    var app = App.init(allocator, window, &font);
    defer app.deinit();

    while (ui.nextEvent(.{})) |evt| {
        try app.handleEvent(evt);
    }
}

const App = struct {
    canvas: Canvas,
    dcanvas: Canvas,
    window: ui.Window,
    font: *ui.Font,

    fn init(allocator: std.mem.Allocator, window: ui.Window, font: *ui.Font) App {
        return App{
            .canvas = Canvas.initAllocEmpty(allocator),
            .dcanvas = Canvas.initAllocEmpty(allocator),
            .window = window,
            .font = font,
        };
    }

    fn deinit(self: *App) void {
        self.canvas.deinit();
        self.dcanvas.deinit();
    }

    fn handleEvent(self: *App, evt: ui.EventData) !void {
        switch (evt) {
            ui.Event.paint => {
                const black = color(25, 0, 0, 255);
                self.canvas.clear(black);
            },
            else => {},
        }

        // try ui.drawCenteredTextSpan(&self.canvas, &self.font, 64, 0xffffffff, x0: i16, y0: i16, x1: i16, y1: i16, string: []const u8)
        try button(&self.canvas, self.font, evt, 10, 10, 50, 50, "test");

        switch (evt) {
            ui.Event.keydown => |key| switch (key) {
                ui.Key.escape => return,
                else => {},
            },
            ui.Event.resize => |size| {
                try self.canvas.reallocate(size.width, size.height);
                try self.dcanvas.reallocate(size.width, size.height);
            },
            ui.Event.closewindow => std.process.exit(0),
            ui.Event.paint => {
                ui.presentWithDeltaCanvas32(self.window, self.canvas, &self.dcanvas);
            },
            else => {},
        }
    }
};

fn button(canvas: *Canvas, font: *ui.Font, evt: ui.EventData, x0: i16, y0: i16, w: i16, h: i16, str: []const u8) !void {
    switch (evt) {
        ui.Event.paint => {
            std.debug.print("paint button\n", .{});
            try ui.drawCenteredTextSpan(canvas, font, 14, 0xffffffff, x0, y0, x0 + w, y0 + h, str);
        },
        else => {},
    }
}
