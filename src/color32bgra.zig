const std = @import("std");

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
    var c_b = fixedLerp(a_b, b_b, t);
    var c_g = fixedLerp(a_g, b_g, t);
    var c_r = fixedLerp(a_r, b_r, t);
    var c_a = fixedLerp(a_a, b_a, t);
    return makeColor32bgra(c_r, c_g, c_b, c_a);
}

pub fn mixColor32bgraByFloat(a: u32, b: u32, f: anytype) u32_bgra
{
    var t: u16 = 0;
    _ = t;
    if (f <= 0) return a;
    if (f >= 1) return b;
    return mixColor32bgra(a, b, @intFromFloat(f*1024));
}

/// expect t to be in 0..1024 range
inline fn fixedLerp(a: u8, b: u8, t: u16) u8
{
    const a32 = @as(i32, a);
    const b32 = @as(i32, b);
    const r32 = (a32 << 10) + (b32 - a32) * t;
    return @intCast(r32 >> 10);
}

test "mix works as expected" {
    try std.testing.expectEqual(mixColor32bgra(0, 0xffffffff, 1024), 0xffffffff);
    try std.testing.expectEqual(mixColor32bgra(0, 0xffffffff, 0), 0);
    try std.testing.expectEqual(mixColor32bgra(0, 0xffffffff, 512), 0x7f7f7f7f);
    try std.testing.expectEqual(mixColor32bgra(0xff008080, 0xff204040, 512), 0xff106060);
}

pub inline fn makeColor32bgra(r: u8, g: u8, b: u8, a: u8) u32_bgra
{
    return @as(u32,b) 
        | (@as(u32,g) << 8) 
        | (@as(u32,r) << 16) 
        | (@as(u32,a) << 24);
}