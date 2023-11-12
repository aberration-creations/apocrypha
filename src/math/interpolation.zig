const std = @import("std");


/// expect t to be in [0, 255] range
pub inline fn lerp8bit(a: u8, b: u8, t: u8) u8
{
    const wa = @as(i32, a);
    const wb = @as(i32, b);
    const wt = @as(i32, t);
    const wr = (wa << 8) - wa + (wb - wa) * wt;
    return @intCast((wr + 255) >> 8);
}

/// expect t to be in [0, 1024] range
pub inline fn lerpFixed1024(a: u8, b: u8, t: u16) u8
{
    const a32 = @as(i32, a);
    const b32 = @as(i32, b);
    const r32 = (a32 << 10) + (b32 - a32) * t;
    return @intCast(r32 >> 10);
}

pub inline fn lerpf32(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

const expectEqual = std.testing.expectEqual;

test "lerp8bit works as expected" {
    const f = lerp8bit;
    try expectEqual(255, f(0, 255, 255));
    try expectEqual(0, f(0, 255, 0));
    try expectEqual(255, f(255, 0, 0));
    try expectEqual(0, f(255, 0, 255));
    try expectEqual(127, f(0, 255, 127));
    try expectEqual(128, f(0, 255, 128));
    try expectEqual(128, f(255, 0, 127));
    try expectEqual(127, f(255, 0, 128));
}

test "fixedLerp1024 works as expected" {
    const f = lerpFixed1024;
    try expectEqual(255, f(0, 255, 1024));
    try expectEqual(0, f(0, 255, 0));
    try expectEqual(255, f(255, 0, 0));
    try expectEqual(0, f(255, 0, 1024));
    try expectEqual(127, f(0, 255, 512));
    try expectEqual(127, f(255, 0, 512));
}

test "lerpf32 works as expected" {
    const f = lerpf32;
    try expectEqual(255, f(0, 255, 1.0));
    try expectEqual(0, f(0, 255, 0));
    try expectEqual(255, f(255, 0, 0));
    try expectEqual(0, f(255, 0, 1.0));
    try expectEqual(127.5, f(0, 255, 0.5));
    try expectEqual(127.5, f(255, 0, 0.5));
}
