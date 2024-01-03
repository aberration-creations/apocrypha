// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");
const rx11 = @import("./src/window/adapters/rx11.zig");

pub fn main() !void {
    var conn = try rx11.Connection.init();
    conn.thing();
    defer conn.deinit();
}