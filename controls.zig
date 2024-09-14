const ui = @import("./src/index.zig");
const std = @import("std");
const dom = @import("./src/dom.zig");

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

    var app = try App.init(allocator, window, &font);
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
    root: dom.Element,

    fn init(allocator: std.mem.Allocator, window: ui.Window, font: *ui.Font) !App {
        return App{
            .canvas = Canvas.initAllocEmpty(allocator),
            .dcanvas = Canvas.initAllocEmpty(allocator),
            .window = window,
            .font = font,
            .root = try dom.Element.init(.{
                .x = 10,
                .y = 20,
                .w = 600,
                .h = 200,
                .static_text = "asdsa",
            }),
        };
    }

    fn deinit(self: *App) void {
        self.canvas.deinit();
        self.dcanvas.deinit();
    }

    fn handleEvent(self: *App, evt: ui.EventData) !void {
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
