pub const Box = @import("./boundingBox.zig").BoundingBox;

const interpolation = @import("./interpolation.zig");

pub const lerp8bit = interpolation.lerp8bit;
pub const lerpFixed1024 = interpolation.lerpFixed1024;
pub const lerpf32 = interpolation.lerpf32;

test {
    _ = @import("./boundingBox.zig");
    _ = @import("./interpolation.zig");
}