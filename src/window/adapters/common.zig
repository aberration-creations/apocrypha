// common data structure libary

pub const NextEventOptions = struct {
    blocking: bool = true,
};

pub const Event = enum {
    unknown,
    keydown,
    resize,
};

pub const Key = enum {
    unknown,
    escape,
};

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const EventData = union(Event) {
    unknown: void,
    keydown: Key,
    resize: Size,
};


pub const WindowCreateOptions = struct {
    x: i16 = 0,
    y: i16 = 0,
    width: u16 = 600,
    height: u16 = 400,
    title: []const u8 = "Window",
    fullscreen: bool = false,
};