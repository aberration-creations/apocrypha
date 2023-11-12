pub const CanvasGeneric = @import("./canvas/canvas.zig").Canvas;
pub const Canvas32 = CanvasGeneric(u32);

const font = @import("./canvas/font/font.zig");

pub const FontData = font.FontData;
pub const drawText = font.drawText;

pub fn loadInternalFont() FontData {
    return font.internalFont;
}

pub const dumpCanvas32ToStdout = @import("./canvas/dumpCanvasToStdout.zig").dumpCanvasToStdout;
pub const dumpCanvas32ToFile = @import("./canvas/dumpCanvasToFile.zig").dumpCanvasToFile;

pub const color32bgra = @import("./canvas/color32bgra.zig");
pub const BoxGeneric = @import("./math/boundingBox.zig").BoundingBox;
pub const Box = BoxGeneric(u32);

pub const x11 = @import("./adapters/x11.zig");