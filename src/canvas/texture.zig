const std = @import("std");
const math = @import("../math/math.zig");

const TextureError = error{
    DoesNotFitIntoBuffer,
};

pub fn Texture(comptime P: type) type {
    const EMPTY: [0]P = .{};
    _ = EMPTY;

    return struct {
        const Self = Texture(P);

        pixels: []const P,
        width: usize,
        height: usize,

        /// not efficient but convenient
        pub inline fn getPixel(self: Self, x: usize, y: usize) P {
            return self.pixels[y * self.width + x];
        }

        /// not efficient but convenient
        pub inline fn setPixel(self: Self, x: usize, y: usize, p: P) void {
            self.pixels[y * self.width + x] = p;
        }

        /// get access to row of pixels for read/write purposes
        pub inline fn getRow(self: Self, y: usize) []const P {
            const from = y * self.width;
            const to = from + self.width;
            return self.pixels[from..to];
        }

        /// get access to stride of pixels for read/write purposes
        pub inline fn getStride(self: Self, y: usize, x0: usize, x1: usize) []const P {
            return self.getRow(y)[x0..x1];
        }

        // initialize with static buffer, allows allocatorless canvas
        pub fn initBuffer(buf: []const P, width: u32, height: u32) Self {
            return Self{
                .height = height,
                .width = width,
                .pixels = buf,
            };
        }
    };
}

pub fn sampleU8AbsoluteLinear(texture: Texture(u8), u: f32, v: f32) f32 {

    const _v0 = std.math.floor(v);
    const vf = v - _v0;
    const iv0: usize = @as(usize, @intFromFloat(_v0)) % texture.height;
    const iv1 = (iv0 + 1) % texture.height;

    const row0 = texture.getRow(iv0);
    const row1 = texture.getRow(iv1);

    const _u0 = std.math.floor(u);
    const uf = u - _u0;
    const iu0: usize = @as(usize, @intFromFloat(_u0)) % texture.width;
    const iu1 = (iu0 + 1) % texture.width;

    const s_u0_v0: f32 = @floatFromInt(row0[iu0]);
    const s_u1_v0: f32 = @floatFromInt(row0[iu1]);
    const s_u0_v1: f32 = @floatFromInt(row1[iu0]);
    const s_u1_v1: f32 = @floatFromInt(row1[iu1]);

    return math.lerpf32(
        math.lerpf32(s_u0_v0, s_u1_v0, uf),
        math.lerpf32(s_u0_v1, s_u1_v1, uf),
        vf
    );

}

test "basic linear sampling" {
    const expectEquals = std.testing.expectEqual;
    const f = sampleU8AbsoluteLinear;
    const t = testGet2x2Checker();
    try expectEquals(@as(f32, 0), f(t, 0, 0));
    try expectEquals(@as(f32, 255), f(t, 1, 0));
    try expectEquals(@as(f32, 0), f(t, 1, 1));
    try expectEquals(@as(f32, 127.5), f(t, 0.5, 0));
    try expectEquals(@as(f32, 127.5), f(t, 0.5, 0.5));
    try expectEquals(@as(f32, 127.5), f(t, 0, 0.5));
}

fn testGet2x2Checker() Texture(u8) {
    return Texture(u8).initBuffer(&[4]u8{ 0, 255, 255, 0 }, 2, 2);
}