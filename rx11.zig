// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");
const rx11 = @import("./src/window/adapters/rx11.zig");

pub fn main() !void {
    var conn = try rx11.Connection.init();
    defer conn.deinit();

    const window_id = conn.generateResourceId();
    try rx11.createWindow(conn, window_id);
    try rx11.mapWindow(conn, window_id);
    try rx11.setName(conn, window_id, "X11 Test Window");
    try rx11.pollEvents(conn);
    std.time.sleep(1_000_000_000);
    try rx11.pollEvents(conn);
    std.time.sleep(1_000_000_000);

    try rx11.setName(conn, window_id, "Other title");
    try rx11.pollEvents(conn);
    std.time.sleep(1_000_000_000);
    try rx11.pollEvents(conn);
    std.time.sleep(1_000_000_000);

    try rx11.unmapWindow(conn, window_id);
    std.time.sleep(1_000_000_000);
    try rx11.mapWindow(conn, window_id);
    std.time.sleep(1_000_000_000);
    try rx11.unmapWindow(conn, window_id);
    try rx11.destroyWindow(conn, window_id);

    std.time.sleep(1_000_000_000);
    try rx11.pollEvents(conn);
}