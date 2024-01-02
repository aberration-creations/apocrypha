// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");

const Err = error{
    DisplayNotFound,
    DisplayParseError,
    ProtocolNotSupported,
};

pub fn main() !void {
    const server = try getDisplayServerInfo();
    std.debug.print("host: {s} protocol: {s} display: {} screen: {}\n", .{ server.host, server.protocol, server.display, server.screen });
    if (isUnixProtocol(server)) {
        // TODO connect local unix socket
        // "/tmp/.X11-unix/X"
    } else {
        // TODO connect network tcp socket
    }
}

const Display = struct {
    host: []const u8 = "",
    protocol: []const u8 = "",
    display: u8 = 0,
    screen: u8 = 0,
};

fn getDisplayServerInfo() !Display {
    if (std.os.getenv("DISPLAY")) |display| {
        return parseDisplay(display);
    }
    return Err.DisplayNotFound;
}

fn parseDisplay(str: []const u8) !Display {
    var result = Display{};
    var cursor: usize = 0;
    var expect_display = false;
    var expect_screen = false;
    for (str, 0..) |chr, i| {
        if (chr == '/') {
            result.host = str[cursor..i];
            cursor = i + 1;
        } else if (chr == ':') {
            if (result.host.len > 0) {
                result.protocol = str[cursor..i];
            } else {
                result.host = str[cursor..i];
            }
            cursor = i + 1;
            expect_display = true;
        } else if (chr == '.') {
            result.display = std.fmt.parseInt(u8, str[cursor..i], 10) catch return Err.DisplayParseError;
            cursor = i + 1;
            expect_display = false;
            expect_screen = true;
        }
    }
    const last_value = std.fmt.parseInt(u8, str[cursor..str.len], 10) catch return Err.DisplayParseError;
    if (expect_screen) result.screen = last_value;
    if (expect_display) result.display = last_value;
    return result;
}

fn isUnixProtocol(server: Display) bool {
    const unix: []const u8 = "unix";
    return server.host.len == 0 or streql(server.protocol, unix);
}

fn streql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (0..a.len) |i| if (a[i] != b[i]) return false;
    return true;
}

test "parse display" {
    const parse = parseDisplay;
    const eq = std.testing.expectEqualDeep;
    try eq(Display{ .host = "localhost", .display = 12 }, try parse("localhost:12.0"));
    try eq(Display{ .host = "host", .protocol = "unix", .display = 1, .screen = 2 }, try parse("host/unix:1.2"));
    try eq(Display{ .display = 1 }, try parse(":1"));
    const ee = std.testing.expectError;
    try ee(Err.DisplayParseError, parse(":A.B"));
}

test "is unix protocol" {
    const isUnix = isUnixProtocol;
    const parse = parseDisplay;
    const expect = std.testing.expect;
    try expect(isUnix(try parse("host/unix:1.2")));
    try expect(!isUnix(try parse("localhost:12.0")));
    try expect(isUnix(try parse(":1")));
}
