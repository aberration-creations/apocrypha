const std = @import("std");
const Canvas = @import("../canvas.zig").Canvas(u32);

pub const FontDataChunk = struct {
    alphaMap: []const u8,
    alphaMapWidth: usize,
    alphaMapHeight: usize,
    gridCellWidth: usize,
    gridCellHeight: usize,
    cellsUsedPerGridRow: usize,
    totalCells: usize,
    firstCodePoint: usize,
};

pub const FontData = struct {
    chunks: []const FontDataChunk,
};

pub const internalFont: FontData = .{ .chunks = &[_]FontDataChunk{FontDataChunk{
    .alphaMap = @embedFile("./fontmap/fontmap.raw"),
    .alphaMapWidth = 256,
    .alphaMapHeight = 256,
    .cellsUsedPerGridRow = 16,
    .firstCodePoint = 16,
    .totalCells = 256,
    .gridCellHeight = 32,
    .gridCellWidth = 19,
}} };

pub fn drawText(canvas: *Canvas, font: FontData, x: usize, y: usize, string: []const u8) void {
    var cursorX = x;
    var cursorY = y;
    for (string) |code| {
        for (font.chunks) |data| {
            if (code < data.firstCodePoint or data.firstCodePoint + data.totalCells <= code) {
                continue;
            }
            var cellIndex = code - data.firstCodePoint;
            var gridRow = cellIndex / data.cellsUsedPerGridRow;
            var gridColumn = cellIndex % data.cellsUsedPerGridRow;

            var srcX0 = gridColumn * data.gridCellWidth;
            var srcY0 = gridRow * data.gridCellHeight;
            var srcX1 = srcX0 + data.gridCellWidth;
            var srcY1 = srcY0 + data.gridCellHeight;

            for (srcY0..srcY1, cursorY..) |srcY, dstY| {
                var alphaMapRowFrom = srcY * data.alphaMapWidth;
                var alphaMapRowTo = alphaMapRowFrom + data.alphaMapWidth;
                var srcRow = data.alphaMap[alphaMapRowFrom * 2 .. alphaMapRowTo * 2];
                var dstRow = canvas.getRow(dstY);
                for (srcX0..srcX1, cursorX..) |srcX, dstX| {
                    var dst = dstRow[dstX];

                    var p: u32 = @intCast(srcRow[srcX]);
                    p = p << 8 | p << 16 | p | 0xff000000;

                    dstRow[dstX] = dst | p;
                }
            }
            cursorX += data.gridCellWidth;
            break;
        }
    }
}
