// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");
const rx11 = @import("./src/window/adapters/rx11.zig");

var input: [1024]u8 align(4) = undefined;

pub fn main() !void {
    var conn = try rx11.Connection.init();
    defer conn.deinit();

    const window_id = conn.generateResourceId();
    try rx11.createWindow(conn, window_id);
    try rx11.mapWindow(conn, window_id);
    try rx11.setName(conn, window_id, "X11 Test Window");
    std.time.sleep(1_000_000_000);
    while(true) {
        while (try rx11.hasInput(conn)) {
            try rx11.readInput(conn, input[0..64]);
        }
    }
   
}