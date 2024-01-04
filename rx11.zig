// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");
const rx11 = @import("./src/window/adapters/rx11.zig");

pub fn main() !void {
    var conn = try rx11.Connection.init();
    defer conn.deinit();

    try rx11.createWindow(conn);
    try rx11.mapWindow(conn);
    std.time.sleep(1_000_000_000);
}