// common data structure libary

pub const NextEventOptions = struct {
    blocking: bool = true,
};

pub const Event = enum {
    unknown,
    paint,
    closewindow,
    keydown,
    keyup,
    resize,
    pointermove,
    pointerdown,
    pointerup,
};

pub const Key = enum { unknown, escape, up, left, down, right };

pub const EventData = union(Event) {
    unknown: void,
    paint: void,
    closewindow: void,
    keydown: Key,
    keyup: Key,
    resize: Size,
    pointermove: Position,
    pointerdown: Position,
    pointerup: Position,
};

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const Position = struct {
    x: i16,
    y: i16,
};

pub const WindowCreateOptions = struct {
    x: i16 = 0,
    y: i16 = 0,
    width: u16 = 600,
    height: u16 = 400,
    title: []const u8 = "Window",
    fullscreen: bool = false,
};

pub const InvalidateRectOptions = struct {};
