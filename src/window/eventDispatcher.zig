const std = @import("std");
const common = @import("./adapters/common.zig");
const Event = common.Event;
const EventData = common.EventData;
const Key = common.Key;

const EventDispatcherFn = *const fn (event: EventDispatcher) void;

const EventDispatcher = struct {
    handler: ?EventDispatcherFn = null,
    generator: ?EventDispatcherFn = null,

    raw: EventData = undefined,
    /// application requests exit
    exit: bool = false,
    /// application does not have animations, a blocking wait may be used
    /// to wait for the next user input event
    blocking: bool = false,
    buffer: [16]EventData = undefined,
    head: u8 = 0,
    tail: u8 = 0,

    fn nextEvent(self: *EventDispatcher) ?*EventDispatcher {
        if (self.head == self.tail) {
            return null;
        }
        self.raw = self.buffer[self.head];
        self.head += 1;
        if (self.head > self.buffer.len) {
            self.head = 0;
        }
        return self;
    }

    fn addkeydown(self: *EventDispatcher, key: Key) void {
        self.addEvent(EventData{ .keydown = key });
    }

    fn addkeyup(self: *EventDispatcher, key: Key) void {
        self.addEvent(EventData{ .keyup = key });
    }

    fn addkeypress(self: *EventDispatcher, key: Key) void {
        self.addkeydown(key);
        self.addkeyup(key);
    }

    fn addEvent(self: *EventDispatcher, event: EventData) void {
        // TODO call handler if about to overwrite
        self.buffer[self.tail] = event;
        self.tail += 1;
        if (self.tail > self.buffer.len) {
            self.tail = 0;
        }
    }
};

test "initially no events can be read" {
    var disp = EventDispatcher{};
    try std.testing.expect(disp.nextEvent() == null);
}

test "returns recorded event" {
    var disp = EventDispatcher{};
    disp.addkeypress(.escape);
    const evt = disp.nextEvent();
    try std.testing.expect(evt != null);
    if (evt) |e| {
        std.debug.print("\n{}\n", .{e.raw});
        try std.testing.expect(e.raw == .keydown);
        if (e.raw == .keydown) {
            try std.testing.expect(e.raw.keydown == .escape);
        } else unreachable;
    }
}
