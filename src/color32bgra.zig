const std = @import("std");

pub const u32_bgra = u32;

/// expect t to be in 0..1024 range
fn mixColor32bgra(a: u32, b: u32, t: u16) u32 
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
    return (@as(u32,c_a) << 24) | (@as(u32,c_r) << 16) | (@as(u32,c_g) << 8) | @as(u32,c_b);
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