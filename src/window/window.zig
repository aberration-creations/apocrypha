// abstract window system integration


const std = @import("std");
const builtin = @import("builtin");

const subsystem = builtin.target.os.tag;

pub const win32 = @import("adapters/win32.zig");
pub const x11 = @import("adapters/x11.zig");

pub const WindowCreateOptions = struct {
    x: i16 = 0,
    y: i16 = 0,
    width: u16 = 600,
    height: u16 = 400,
    title: []const u8 = "Window",
    fullscreen: bool = false,
};

const maxWindowCount = 16;
var nextWindowHandle: u16 = 0;
var win32W: [maxWindowCount]win32.Window = undefined;
var x11W: [maxWindowCount]x11.X11Window = undefined;
var x11C: x11.X11Connection = undefined;

/// cross-platform Window primite, 
/// in general you need one to get something on screen
pub const Window = struct {
    handle: usize,
    const Self = @This();

    pub fn init(options: WindowCreateOptions) Window {
        var handle = nextWindowHandle;
        nextWindowHandle += 1;
        if (handle >= maxWindowCount) {
            unreachable;
        }
        switch (subsystem) {
            .windows => win32W[handle] = win32.Window.init(.{
                .title = options.title
            }),
            .linux => {
                x11C = x11.X11Connection.init();
                x11W[handle] = x11.X11Window.init(&x11C, .{
                    .fullscreen = options.fullscreen,
                    .width = options.width,
                    .height = options.height,
                    .title = options.title,
                    .x = options.x,
                    .y = options.y,
                });
            },
            else => @compileError("not supported")
        }
        return Window {
            .handle = handle
        };
    }

    pub fn deinit(self: Self) void {
        switch (subsystem) {
            .windows => win32W[self.handle].deinit(),
            .linux => x11W[self.handle].deinit(),
            else => @compileError("not supported")
        }

    } 

};

pub fn createWindow(options: WindowCreateOptions) void {
    _ = options;
    switch (subsystem) {
        .windows => {
            _ = win32.Window.init(.{});
        },
        .linux => {
            _ = x11.X11Window.init(.{});
        },
        else => @compileError("not supported")
    }
}

pub const NextEventOptions = struct {
    blocking: bool = true,
};

pub const Event = enum {
    unknown,
    keydown,
};

pub const Key = enum {
    unknown,
    escape,
};

pub const EventData = union(Event) {
    unknown: void,
    keydown: Key,

    pub fn initFromWin32Msg(msg: win32.MSG) EventData {
        const user32 = win32.user32;
        return switch (msg.message) {
            user32.WM_KEYDOWN => EventData { .keydown = Key.escape }, // TODO extend
            else => EventData { .unknown = undefined },
        };
    }
};

pub fn nextEvent(options: NextEventOptions) ?EventData {
    switch (subsystem) {
        .windows => {
            if (options.blocking) {
                if (win32.getMessage()) |msg| {
                    return EventData.initFromWin32Msg(msg);
                } else {
                    return null;
                }
            }
            else {
                if (win32.peekMessage()) |msg| {
                    return EventData.initFromWin32Msg(msg);
                } else {
                    return null;
                }
            }
        },
        .linux => {
            // TODO
            return EventData { .unknown = undefined };
        },
        else => @compileError("not supported")
    }
}