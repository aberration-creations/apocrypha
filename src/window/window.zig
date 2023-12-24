// cross-platform window manager integration

const std = @import("std");
const builtin = @import("builtin");
const common = @import("./adapters/common.zig");

const subsystem = builtin.target.os.tag;

pub const NextEventOptions = common.NextEventOptions;
pub const Event = common.Event;
pub const Key = common.Key;
pub const EventData = common.EventData;
pub const WindowCreateOptions = common.WindowCreateOptions;

pub const win32 = @import("adapters/win32.zig");
pub const x11 = @import("adapters/x11.zig");

const maxWindowCount = 16;
var nextWindowHandle: u16 = 0;
var window_count: u16 = 0;
var win32W: [maxWindowCount]win32.Window = undefined;
var x11W: [maxWindowCount]x11.X11Window = undefined;
var x11C: x11.X11Connection = undefined;
var x11C_connected: bool = false;

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
                ensureX11ConnectionExists();
                x11W[handle] = x11.X11Window.init(&x11C, options);
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
                x11W[self.handle].deinit();
                window_count -= 1;
                if (window_count == 0) {
                    closeX11ConnectionIfOpened();
                }
            },
            else => @compileError("not supported"),
        }
    }

    pub fn presentCanvasU32BGRA(self: Self, width: u16, height: u16, data: []u32) void {
        switch (subsystem) {
            .linux => x11W[self.handle].presentCanvasU32BGRA(width, height, data),
            .windows => win32W[self.handle].presentCanvasU32BGRA(width, height, data),
            else => @compileError("not supported"),
        }
    }
};

fn ensureX11ConnectionExists() void {
    if (!x11C_connected) {
        x11C = x11.X11Connection.init();
        x11C_connected = true;
    }
}

fn closeX11ConnectionIfOpened() void {
    if (x11C_connected) {
        x11C.deinit();
        x11C_connected = false;
    }
}

/// waits for the next UI event
/// expected to be called only from main 'GUI' thread
pub fn nextEvent(options: NextEventOptions) ?EventData {
    return switch (subsystem) {
        .windows => win32.nextEvent(options),
        .linux => x11C.nextEvent(options),
        else => @compileError("not supported"),
    };
}
