// cross-platform window manager integration

const std = @import("std");
const builtin = @import("builtin");
const common = @import("./adapters/common.zig");

const WindowManagerIntegration = enum {
    win32,
    rx11,
    xcb,
};

// define wether to use xcb integration
const useXcb = false;

const wmi: WindowManagerIntegration = switch (builtin.target.os.tag) {
    .windows => .win32,
    .linux => if (useXcb) .xcb else .rx11,
    else => @compileError("window system not supported"),
};

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
var rx11_has_invalidated_rect = false;

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
        switch (wmi) {
            .rx11 => {
                if (!rx11C_connected) {
                    rx11C = rx11.Connection.init() catch @panic("");
                    rx11C_connected = true;
                }
                rx11W[handle] = rx11.Window.init(&rx11C, options) catch @panic("window creation failed");
            },
            .xcb => {
                if (!x11C_connected) {
                    x11C = xcb.X11Connection.init();
                    x11C_connected = true;
                }
                x11W[handle] = xcb.X11Window.init(&x11C, options);
            },
            .win32 => win32W[handle] = win32.Window.init(options),
        }
        window_count += 1;
        return Window{ .handle = handle };
    }

    pub fn deinit(self: Self) void {
        switch (wmi) {
            .rx11 => {
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
            },
            .xcb => {
                x11W[self.handle].deinit();
                window_count -= 1;
                if (window_count == 0) {
                    if (x11C_connected) {
                        x11C.deinit();
                        x11C_connected = false;
                    }
                }
            },
            .win32 => win32W[self.handle].deinit(),
        }
    }

    pub fn presentCanvasU32BGRA(self: Self, width: u16, height: u16, data: []u32) void {
        switch (wmi) {
            .rx11 => rx11W[self.handle].presentCanvasU32BGRA(width, height, data) catch @panic("presentCanvasU32BGRA failed"),
            .xcb => x11W[self.handle].presentCanvasU32BGRA(width, height, data),
            .win32 => win32W[self.handle].presentCanvasU32BGRA(width, height, data),
        }
    }

    pub fn presentCanvasWithDeltaU32BGRA(self: Self, width: u16, height: u16, data: []u32, delta: *[]u32) void {
        switch (wmi) {
            .rx11 => rx11W[self.handle].presentCanvasWithDeltaU32BGRA(width, height, data, delta) catch @panic("presentCanvasWithDeltaU32BGRA failed"),
            .xcb => x11W[self.handle].presentCanvasU32BGRA(width, height, data),
            .win32 => win32W[self.handle].presentCanvasU32BGRA(width, height, data),
        }
    }

    pub fn requestRepaint(self: Self, opt: common.InvalidateRectOptions) void {
        _ = opt;
        switch (wmi) {
            .rx11 => rx11_has_invalidated_rect = true,
            .xcb => @compileError("not supported"),
            .win32 => win32W[self.handle].invalidateRect(),
        }
    }
};

/// waits for the next UI event
/// expected to be called only from main 'GUI' thread
pub fn nextEvent(options: NextEventOptions) ?EventData {
    return switch (wmi) {
        .rx11 => {
            const blocking = options.blocking and !rx11_has_invalidated_rect;
            if (!blocking and !(rx11C.hasInput() catch @panic("event handling failed"))) {
                if (rx11_has_invalidated_rect) {
                    rx11_has_invalidated_rect = false;
                    // TODO: emit event per window
                    return EventData{ .paint = undefined };
                } else {
                    return null;
                }
            }
            return rx11C.readInput() catch @panic("event read failed");
        },
        .xcb => x11C.nextEvent(options),
        .win32 => win32.nextEvent(options),
    };
}
