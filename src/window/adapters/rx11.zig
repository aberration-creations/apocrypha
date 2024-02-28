const std = @import("std");
const protocol = @import("./protocols/x11.zig");
const common = @import("./common.zig");

pub const WindowOptions = common.WindowCreateOptions;

pub const Connection = struct {
    
    conn: protocol.Connection,

    pub fn init() !Connection {
        return Connection {
            .conn = try protocol.Connection.init(),
        };
    }

    pub fn deinit(self: *Connection) void {
        self.conn.deinit();
    }

    pub fn createWindow(self: *Connection, opt: WindowOptions) !Window {
        return Window.init(self, opt);
    }

    pub fn destroyWindow(w: *Window) !void {
        w.deinit();
    }

    pub fn hasInput(self: *Connection) !bool {
        return protocol.hasInput(self.conn);
    }

    pub fn readInput(self: *Connection) !common.EventData {
        var buffer: [256]u8 align(4) = undefined;
        return eventDataFrom(try protocol.readInput(self.conn, &buffer));
    }

};

pub const Window = struct {

    c: *Connection,
    id: u32,
    gc: u32,
    
    pub fn init(c: *Connection, opt: WindowOptions) !Window {
        const id = c.conn.generateResourceId();
        try protocol.createWindowWithSize(c.conn, id, opt.x, opt.y, opt.width, opt.height);
        try protocol.setName(c.conn, id, opt.title);
        try protocol.mapWindow(c.conn, id);
        return Window {
            .id = id,
            .c = c,
            .gc = c.conn.generateResourceId(),
        };
    }

    pub fn deinit(w: *Window) !void {
        try protocol.destroyWindow(w.c.conn, w.id);
    }

    pub fn presentCanvasU32BGRA(w: *Window, width: u16, height: u16, data: []u32) !void {
        if (width == 0 or height == 0) {
            return;
        }
        for (0..height) |y| {
            const from: usize = y * width;
            const to: usize = from + width;
            const slice = data[from..to];
            var value_prev = slice[0];
            var value_from: usize = 0;
            var value_count: usize = 0;
            for (slice, 0..) |value, x| {
                if (value != value_prev){
                    try protocol.createGC(w.c.conn, w.gc, w.id, protocol.GCBitmaskValues.foreground, &[1]u32{ value_prev });   
                    try protocol.polyFillRectangle(w.c.conn, w.id, w.gc, @intCast(value_from), @intCast(y), @intCast(value_count), 1);
                    try protocol.freeGC(w.c.conn, w.gc);
                    value_prev = value;
                    value_from = x;
                    value_count = 1;
                }
                else {
                    value_count += 1;
                }
            }
            if (value_count > 0) {
                try protocol.createGC(w.c.conn, w.gc, w.id, protocol.GCBitmaskValues.foreground, &[1]u32{ value_prev });   
                try protocol.polyFillRectangle(w.c.conn, w.id, w.gc, @intCast(value_from), @intCast(y), @intCast(value_count), 1);
                try protocol.freeGC(w.c.conn, w.gc);
            }
        }

    }

    pub fn presentCanvasWithDeltaU32BGRA(w: *Window, width: u16, height: u16, data: []u32, deltabuffer: *[]u32) !void {
        if (width == 0 or height == 0) {
            return;
        }
        var requests: usize = 0;
        var written: usize = 0;
        var skipped: usize = 0;
        for (0..height) |y| {
            const from: usize = y * width;
            const to: usize = from + width;
            const slice = data[from..to];
            const dslice = deltabuffer.*[from..to];
            var value_prev = slice[0];
            var value_from: usize = 0;
            var value_count: usize = 0;
            for (slice, dslice, 0..) |value, dvalue, x| {
                if (value == dvalue) {
                    if (value_count > 0) {
                        try protocol.createGC(w.c.conn, w.gc, w.id, protocol.GCBitmaskValues.foreground, &[1]u32{ value_prev });   
                        try protocol.polyFillRectangle(w.c.conn, w.id, w.gc, @intCast(value_from), @intCast(y), @intCast(value_count), 1);
                        try protocol.freeGC(w.c.conn, w.gc);
                        value_count = 0;
                        requests += 1;
                        written += value_count;
                    }
                    skipped += 1;
                    value_from = x;
                    value_prev = 0;
                }
                else if (value != value_prev){
                    try protocol.createGC(w.c.conn, w.gc, w.id, protocol.GCBitmaskValues.foreground, &[1]u32{ value_prev });   
                    try protocol.polyFillRectangle(w.c.conn, w.id, w.gc, @intCast(value_from), @intCast(y), @intCast(value_count), 1);
                    try protocol.freeGC(w.c.conn, w.gc);
                    requests += 1;
                    written += value_count;
                    value_prev = value;
                    value_from = x;
                    value_count = 1;
                }
                else {
                    value_count += 1;
                }
                dslice[x] = value;
            }
            if (value_count > 0) {
                try protocol.createGC(w.c.conn, w.gc, w.id, protocol.GCBitmaskValues.foreground, &[1]u32{ value_prev });   
                try protocol.polyFillRectangle(w.c.conn, w.id, w.gc, @intCast(value_from), @intCast(y), @intCast(value_count), 1);
                try protocol.freeGC(w.c.conn, w.gc);
                requests += 1;
                written += value_count;
            }
        }
        std.debug.print("req {} wr {} sk {}\n", .{ requests, written, skipped });
    }
};

pub fn eventDataFrom(res: *protocol.Response) common.EventData {
    const EventData = common.EventData;
    if (res.isEvent()) |event| {
        return eventDataFromEvent(event);
    } else {
        return EventData { .unknown = undefined };
    }
}

pub fn eventDataFromEvent(event: *protocol.Event) common.EventData {
    const EventData = common.EventData;

    if (event.isKeyPress()) |keyPress| {
        return EventData{ .keydown = switch (keyPress.detail) {
            9 => .escape,
            111 => .up,
            113 => .left,
            116 => .down,
            114 => .right,
            else => .unknown,
        } };
    }
    else if (event.isConfigureNotify()) |configureNotify| {
        return EventData{ .resize = common.Size{ 
            .width = configureNotify.width, 
            .height = configureNotify.height,
        } };
    }
    else if (event.isExpose()) |_| {
        return EventData{ .paint = undefined };
    }
    else if (event.isKeyPress()) |keyPress| {
        return EventData{ .keydown = switch (keyPress.detail) {
            9 => .escape,
            111 => .up,
            113 => .left,
            116 => .down,
            114 => .right,
            else => .unknown,
        } };
    }
    else if (event.isMotionNotify()) |motionEvent| {
        return EventData{ .pointermove = .{
            .x = motionEvent.event_x,
            .y = motionEvent.event_y,
        } };
    }
    else if (event.isNoExposure()) |_| {
        // std.debug.print("no exposure {} \n", .{noExposure.major_opcode});
        return EventData{ .unknown = undefined };
    }
    else if (event.isClientMessage()) |_| {
        //     const clientMessage = @as([*c]const x.xcb_client_message_event_t, @ptrCast(&raw)).*;
        //     if (clientMessage.data.data32[0] == conn.getWmDeleteWindowAtom()) {
        //         return EventData{ .closewindow = undefined };
        //     } else {
        //         return EventData{ .unknown = undefined };
        //     }
        // std.debug.print("no exposure {} \n", .{noExposure.major_opcode});
        return EventData{ .unknown = undefined };
    }
    else {
        // std.debug.print("event type {} not handled\n", .{event.response_type});
        return EventData{ .unknown = undefined };
    }
}
