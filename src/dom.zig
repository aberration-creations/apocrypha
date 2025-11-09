const std = @import("std");

pub const EventHandler = *const fn () void;

pub const ElementStyle = struct {
    color: u32 = 0,
    border_size: i16 = 0,
    background_color: u32 = 0,
    border_color: u32 = 0,
};

pub const ElementInit = struct {
    id: i16 = -1,
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,
    style: ElementStyle = ElementStyle{},
    children: ?[]const ElementInit = null,
    static_text: []const u8 = "",
    onclick: ?EventHandler = null,
    allocator: ?std.mem.Allocator = null,
    hidden: bool = false,
};

pub const Element = struct {
    id: i16 = -1,
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,
    hidden: bool = false,
    style: ElementStyle,
    static_text: []const u8 = "",
    children: ?std.ArrayList(Element) = null,
    dynamic_text: ?std.ArrayList(u8) = null,
    allocator: ?std.mem.Allocator = null,
    onclick: ?EventHandler = null,

    pub fn init(data: ElementInit) !Element {
        var result = Element{
            .id = data.id,
            .x = data.x,
            .y = data.y,
            .w = data.w,
            .h = data.h,
            .style = data.style,
            .static_text = data.static_text,
            .onclick = data.onclick,
            .hidden = data.hidden,
        };
        if (data.allocator) |allocator| {
            result.allocator = allocator;
            if (data.children) |children| {
                var list: std.ArrayList(Element) = .{};
                for (children) |child| {
                    try list.append(allocator, try Element.init(child));
                }
                result.children = list;
            }
        } else {
            if (data.children) |_| {
                @panic("cannot build children without allocator!");
            }
        }
        return result;
    }

    pub fn initChild(self: *Element, data: ElementInit) !void {
        if (self.allocator) |allocator| {
            if (self.children == null) {
                self.children = std.ArrayList(Element).init(allocator);
            }
            if (self.children) |*list| {
                try list.append(try Element.init(data));
            } else {
                @panic("failed to init children list");
            }
        } else {
            @panic("cannot add children without having an allocator");
        }
    }

    pub fn deinit(self: *Element) void {
        self.deinitChildren();
    }

    pub fn deinitChildren(self: *Element) void {
        if (self.children) |arr| {
            for (arr.items) |*child| {
                child.deinit();
            }
            arr.deinit();
        }
    }

    pub fn resize(self: *Element, width: i16, height: i16) void {
        self.w = width;
        self.h = height;
    }

    pub fn click(self: *Element, x: i16, y: i16) void {
        if (self.hidden) {
            return; // hidden elements cannot be clicked
        }
        if (self.x <= x and x < self.x + self.w and
            self.y <= y and y < self.y + self.h)
        {
            const local_x = x - self.x;
            const local_y = y - self.y;
            if (self.onclick) |func| {
                func();
            }
            if (self.children) |*list| {
                for (list.items) |*child| {
                    child.click(local_x, local_y);
                }
            }
        }
    }

    pub fn getElementOrNullById(self: *Element, id: i16) ?*Element {
        if (self.id == id) {
            return self;
        }
        if (self.children) |children| {
            for (children.items) |*child| {
                const result = child.getElementOrNullById(id);
                if (result) |r| return r;
            }
        }
        return null;
    }

    pub fn getElementById(self: *Element, id: i16) *Element {
        if (self.getElementOrNullById(id)) |element| {
            return element;
        }
        @panic("Element not found!");
    }

    pub fn getElementOrNullByClickHandler(self: *Element, handler: EventHandler) ?*Element {
        if (self.onclick == handler) {
            return self;
        }
        if (self.children) |children| {
            for (children.items) |*child| {
                const result = child.getElementOrNullByClickHandler(handler);
                if (result) |r| return r;
            }
        }
        return null;
    }

    pub fn getElementByClickHandler(self: *Element, handler: EventHandler) *Element {
        if (self.getElementOrNullByClickHandler(handler)) |element| {
            return element;
        }
        @panic("Element not found!");
    }
};
