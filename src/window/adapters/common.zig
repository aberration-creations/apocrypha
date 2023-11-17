// common data structure libary

pub const NextEventOptions = struct {
    blocking: bool = true,
};

pub const Event = enum {
    unknown,
    closewindow,
    keydown,
    resize,
    pointermove,
};

pub const Key = enum {
    unknown,
    escape,
};

pub const EventData = union(Event) {
    unknown: void,
    closewindow: void,
    keydown: Key,
    resize: Size,
    pointermove: Position,
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