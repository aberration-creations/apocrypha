const std = @import("std");
const ui = @import("./src/index.zig");

pub fn main() !void {

    const window = ui.Window.init(.{
        .title = "Test Window",
    });
    defer window.deinit();

    while (ui.nextEvent(.{ .blocking = true })) |evt| {
        switch (evt) {
            ui.Event.keydown => |key| switch(key) {
                ui.Key.escape => return,
                else => std.debug.print("unknown key\n", .{}),
            },
            ui.Event.resize => |size| {
                std.debug.print("resize to {}x{}\n", .{ size.width, size.height });
            },
            ui.Event.pointermove => |position| {
                std.debug.print("pointer move to {} {}\n", .{ position.x, position.y });
            },
            ui.Event.closewindow => return,
            else => std.debug.print("unknown event\n", .{}),
        }
    }

}
