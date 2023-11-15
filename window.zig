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
                ui.Key.escape => break,
                else => std.debug.print("unknown key\n", .{}),
            },
            else => std.debug.print("unknown event\n", .{}),
        }
    }

}
