pub const CanvasGeneric = @import("./canvas/canvas.zig").Canvas;
pub const Canvas32 = CanvasGeneric(u32);

const font = @import("./canvas/font/font.zig");

pub const Font = font.Font;
pub const drawText = font.drawText;

pub const loadInternalFont = font.initInternalFont;

pub const dumpCanvasToStdout = @import("./canvas/dumpCanvasToStdout.zig").dumpCanvasToStdout;
pub const dumpCanvasToFile = @import("./canvas/dumpCanvasToFile.zig").dumpCanvasToFile;

pub const color32bgra = @import("./canvas/color32bgra.zig");
pub const BoxGeneric = @import("./math/boundingBox.zig").BoundingBox;
pub const Box = BoxGeneric(u32);

pub const x11 = @import("./adapters/x11.zig");

test {
    _ = @import("./math/math.zig");
    _ = @import("./canvas/canvas.zig");
    _ = @import("./canvas/context.zig");
    _ = @import("./canvas/color32bgra.zig");
    _ = @import("./canvas/font/font.zig");
    _ = @import("./canvas/texture.zig");
}