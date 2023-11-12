const std = @import("std");
const math = @import("../math/math.zig");

pub const white: u32_bgra = 0xffffffff;
pub const black: u32_bgra = 0xff000000;
pub const transparent: u32_bgra = 0xff000000;

/// standard pixel format to use within the library
/// the name comes from the fact that on little endian machines
/// the values stored in memory order are: B, G, R, A
pub const u32_bgra = u32;

/// expect t to be in 0..1024 range
pub fn mixColor32bgra(a: u32, b: u32, t: u16) u32_bgra 
{
    var a_b: u8 = @intCast(a & 0xff);
    var a_g: u8 = @intCast((a >> 8) & 0xff);
    var a_r: u8 = @intCast((a >> 16) & 0xff);
    var a_a: u8 = @intCast((a >> 24) & 0xff);
    var b_b: u8 = @intCast(b & 0xff);
    var b_g: u8 = @intCast((b >> 8) & 0xff);
    var b_r: u8 = @intCast((b >> 16) & 0xff);
    var b_a: u8 = @intCast((b >> 24) & 0xff);
    var c_b = math.lerpFixed1024(a_b, b_b, t);
    var c_g = math.lerpFixed1024(a_g, b_g, t);
    var c_r = math.lerpFixed1024(a_r, b_r, t);
    var c_a = math.lerpFixed1024(a_a, b_a, t);
    return makeColor32bgra(c_r, c_g, c_b, c_a);
}

pub fn getAlpha(color: u32) u8 {
    return @intCast((color >> 24) & 0xff);
}

pub fn mixColor32bgraByFloat(a: u32, b: u32, f: anytype) u32_bgra
{
    var t: u16 = 0;
    _ = t;
    if (f <= 0) return a;
    if (f >= 1) return b;
    return mixColor32bgra(a, b, @intFromFloat(f*1024));
}

pub fn mixByU8(a: u32, b: u32, t: u8)  u32_bgra
{
    var a_b: u8 = @intCast(a & 0xff);
    var a_g: u8 = @intCast((a >> 8) & 0xff);
    var a_r: u8 = @intCast((a >> 16) & 0xff);
    var a_a: u8 = @intCast((a >> 24) & 0xff);
    var b_b: u8 = @intCast(b & 0xff);
    var b_g: u8 = @intCast((b >> 8) & 0xff);
    var b_r: u8 = @intCast((b >> 16) & 0xff);
    var b_a: u8 = @intCast((b >> 24) & 0xff);
    var c_b = math.lerp8bit(a_b, b_b, t);
    var c_g = math.lerp8bit(a_g, b_g, t);
    var c_r = math.lerp8bit(a_r, b_r, t);
    var c_a = math.lerp8bit(a_a, b_a, t);
    return makeColor32bgra(c_r, c_g, c_b, c_a);
}

pub inline fn makeColor32bgra(r: u8, g: u8, b: u8, a: u8) u32_bgra
{
    return @as(u32,b) 
        | (@as(u32,g) << 8) 
        | (@as(u32,r) << 16) 
        | (@as(u32,a) << 24);
}

const expectEqual = std.testing.expectEqual;

test "mix works as expected" {
    try expectEqual(mixColor32bgra(0, 0xffffffff, 1024), 0xffffffff);
    try expectEqual(mixColor32bgra(0, 0xffffffff, 0), 0);
    try expectEqual(mixColor32bgra(0, 0xffffffff, 512), 0x7f7f7f7f);
    try expectEqual(mixColor32bgra(0xff008080, 0xff204040, 512), 0xff106060);

    try expectEqual(mixByU8(0, 0xffffffff, 255), 0xffffffff);
}
