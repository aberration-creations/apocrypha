// cross-platform window manager integration

const std = @import("std");
const builtin = @import("builtin");
const common = @import("./adapters/common.zig");

const subsystem = builtin.target.os.tag;
const userx11 = true;

pub const NextEventOptions = common.NextEventOptions;
pub const Event = common.Event;
pub const Key = common.Key;
pub const EventData = common.EventData;
pub const WindowCreateOptions = common.WindowCreateOptions;

pub const win32 = @import("adapters/win32.zig");
pub const xcb = @import("adapters/xcb.zig");
pub const rx11 = @import("adapters/rx11.zig");

const maxWindowCount = 16;
var nextWindowHandle: u16 = 0;
var window_count: u16 = 0;
var win32W: [maxWindowCount]win32.Window = undefined;

var x11W: [maxWindowCount]xcb.X11Window = undefined;
var x11C: xcb.X11Connection = undefined;
var x11C_connected: bool = false;

var rx11C: rx11.Connection = undefined;
var rx11W: [maxWindowCount]rx11.Window = undefined;
var rx11C_connected: bool = false;

/// cross-platform Window primite,
/// in general you need one to get something on screen
pub const Window = struct {
    handle: usize,
    const Self = @This();

    /// Creates a new window. Check WindowCreateOptions for additional options.
    pub fn init(options: WindowCreateOptions) Window {
        const handle = nextWindowHandle;
        nextWindowHandle += 1;
        if (handle >= maxWindowCount) {
            unreachable;
        }
        switch (subsystem) {
            .windows => win32W[handle] = win32.Window.init(options),
            .linux => {
                if (userx11){
                    if (!rx11C_connected) {
                        rx11C = rx11.Connection.init() catch @panic("");
                        rx11C_connected = true;
                    }
                    rx11W[handle] = rx11.Window.init(&rx11C, options) catch @panic("window creation failed");
                }
                else {
                    if (!x11C_connected) {
                        x11C = xcb.X11Connection.init();
                        x11C_connected = true;
                    }
                    x11W[handle] = xcb.X11Window.init(&x11C, options);
                }
            },
            else => @compileError("not supported"),
        }
        window_count += 1;
        return Window{ .handle = handle };
    }

    pub fn deinit(self: Self) void {
        switch (subsystem) {
            .windows => win32W[self.handle].deinit(),
            .linux => {
                if (userx11) {
                    if (rx11W[self.handle].deinit()) |_| {} else |_| {
                        @panic("");
                    }
                    window_count -= 1;
                    if (window_count == 0) {
                        if (rx11C_connected) {
                            rx11C.deinit();
                            rx11C_connected = false;
                        }
                    }
                }
                else {
                    x11W[self.handle].deinit();
                    window_count -= 1;
                    if (window_count == 0) {
                        if (x11C_connected) {
                            x11C.deinit();
                            x11C_connected = false;
                        }
                    }
                }
            },
            else => @compileError("not supported"),
        }
    }

    pub fn presentCanvasU32BGRA(self: Self, width: u16, height: u16, data: []u32) void {
        switch (subsystem) {
            .linux => {
                if (userx11) {
                    rx11W[self.handle].presentCanvasU32BGRA(width, height, data) catch @panic("failed");
                }
                else {
                    x11W[self.handle].presentCanvasU32BGRA(width, height, data);
                }
            },
            .windows => win32W[self.handle].presentCanvasU32BGRA(width, height, data),
            else => @compileError("not supported"),
        }
    }

    pub fn presentCanvasWithDeltaU32BGRA(self: Self, width: u16, height: u16, data: []u32, delta: *[]u32) void {
        switch (subsystem) {
            .linux => {
                if (userx11) {
                    rx11W[self.handle].presentCanvasWithDeltaU32BGRA(width, height, data, delta) catch @panic("failed");
                }
                else {
                    // use fallback
                    x11W[self.handle].presentCanvasU32BGRA(width, height, data);
                }
            },
            // use fallback
            .windows => win32W[self.handle].presentCanvasU32BGRA(width, height, data),
            else => @compileError("not supported"),
        }
    }

    pub fn requestRepaint(self: Self, opt: common.InvalidateRectOptions) void {
        _ = opt;
        switch (subsystem) {
            .windows => win32W[self.handle].invalidateRect(),
            else => @compileError("not supported"),
        }
    }

};

/// waits for the next UI event
/// expected to be called only from main 'GUI' thread
pub fn nextEvent(options: NextEventOptions) ?EventData {
    return switch (subsystem) {
        .windows => win32.nextEvent(options),
        .linux => if (userx11) {
            if (!options.blocking and !(rx11C.hasInput() catch @panic("event handling failed"))) {
                return null;
            }
            return rx11C.readInput() catch @panic("event read failed");
        } else {
            return x11C.nextEvent(options);
        },
        else => @compileError("not supported"),
    };
}
