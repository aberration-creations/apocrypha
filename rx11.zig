const std = @import("std");
const rx11 = @import("./src/window/adapters/rx11.zig");

var input: [1024]u8 align(4) = undefined;

pub fn main() !void {
    var conn = try rx11.Connection.init();
    defer conn.deinit();

    const win = conn.generateResourceId();
    const gc = conn.generateResourceId();
    const pixmap = conn.generateResourceId();
    try rx11.createWindow(conn, win);
    try rx11.createDefaultGC(conn, gc, win);
    try rx11.mapWindow(conn, win);
    try rx11.setName(conn, win, "X11 Test Window");
    try rx11.createPixmap(conn, pixmap, win, 640, 480);
    
    try rx11.putImage(conn, pixmap, gc, 2, 2, 4, 16, &[4]u32 { 0xffffff,0,0xffffff,0 });

    while(true) {
        while (try rx11.hasInput(conn)) {
            try rx11.readInput(conn, input[0..64]);
        } 
    }
   
}