const std = @import("std");
const xorTexture = @import("./xorTexture.zig");
const ui = @import("./src/index.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    var xc = ui.x11.X11Connection.init();
    defer xc.deinit();
    var c = xc.conn;

    var win = ui.x11.X11Window.init(&xc, .{
        .title = "Test Window",
    });
    defer win.deinit();

    var frame: u16 = 4;
    var width: u16 = 1024;
    var height: u16 = 1024;
    var data: []u8 = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * 4);
    defer allocator.free(data);
    xorTexture.renderXorTextureToCanvas(width, height, data, frame);

    var exitRequested = false;
    while (!exitRequested) {
        const eventPtr = ui.x11.x.xcb_wait_for_event(c);
        if (eventPtr < 100) {
            exitRequested = true;
            continue;
        }
        const event = eventPtr.*;

        switch (event.response_type) {
            ui.x11.x.XCB_CONFIGURE_NOTIFY => {
                const configureNotify = @as([*c]ui.x11.x.xcb_configure_notify_event_t, @ptrCast(eventPtr));
                std.debug.print("configure notify {} {}\n", .{ configureNotify.*.width, configureNotify.*.height });
                if (configureNotify.*.width != width or configureNotify.*.height != height) {
                    //resize
                    width = configureNotify.*.width;
                    height = configureNotify.*.height;
                    allocator.free(data);
                    data = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * 4);
                    xorTexture.renderXorTextureToCanvas(width, height, data, frame);
                    win.presentCanvas(width, height, data);
                }
            },
            ui.x11.x.XCB_EXPOSE => {
                const exposeEventPtr = @as([*c]ui.x11.x.xcb_expose_event_t, @ptrCast(eventPtr));
                std.debug.print("expose {} {}\n", .{ exposeEventPtr.*.width, exposeEventPtr.*.height });
                win.presentCanvas(width, height, data);
            },
            ui.x11.x.XCB_KEY_PRESS => {
                const keyEventPtr = @as([*c]ui.x11.x.xcb_key_press_event_t, @ptrCast(eventPtr));
                const keyEvent = keyEventPtr.*;
                if (keyEvent.detail == 9) {
                    exitRequested = true;
                } else {
                    frame += 1;
                    xorTexture.renderXorTextureToCanvas(width, height, data, frame);
                    win.presentCanvas(width, height, data);
                    std.debug.print("frame {}\n", .{frame});
                }
            },
            ui.x11.x.XCB_MOTION_NOTIFY => {
                const motionEventPtr = @as([*c]ui.x11.x.xcb_motion_notify_event_t, @ptrCast(eventPtr));
                const motionEvent = motionEventPtr.*;
                _ = motionEvent;
                // std.debug.print("motion {} {}\n", .{ motionEvent.event_x, motionEvent.event_x });
            },
            ui.x11.x.XCB_NO_EXPOSURE => {
                const noExposurePtr = @as([*c]ui.x11.x.xcb_no_exposure_event_t, @ptrCast(eventPtr));
                const noExposure = noExposurePtr.*;
                std.debug.print("no exposure {} \n", .{noExposure.major_opcode});
            },
            else => {
                std.debug.print("event type {} not handled\n", .{event.response_type});
            },
        }
        ui.x11.x.free(eventPtr);
    }
}
