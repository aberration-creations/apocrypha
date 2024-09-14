const std = @import("std");
const Canvas = @import("../canvas.zig").Canvas;
const textureModule = @import("../texture.zig");
const Texture = textureModule.Texture;
const math = @import("../../math/math.zig");
const Box = math.Box(u32);
const color32bgra = @import("../color32bgra.zig");

const print = std.debug.print;

pub fn initInternalFont(allocator: std.mem.Allocator) Font {
    return Font.initLazyFromBitmap(allocator, internalFont);
}

///
/// Draws text to canvas, it may allocate to cache additional font bitmaps
///
/// Deprecated because:
///  - no clipping is performed here
///  - coordinates are signed
///
/// > use drawTextV2, for better experience
///
pub fn drawTextV1(canvas: *Canvas(u32), font: *Font, size: usize, color: u32, x: usize, y: usize, string: []const u8) !void {
    var cursorX = x;
    const cursorY = y;
    // TODO optimize when colorAlpha == 255 or 0
    const colorAlpha = color32bgra.getAlpha(color);
    const scaleset = try font.getOrAllocSizeCache(size);

    for (string) |code| {
        if (try scaleset.lazyGetGlyph(code)) |glyph| {
            // print("draw code {}\n", .{code});
            const texture = glyph.data;
            for (0..texture.height, cursorY..) |srcY, dstY| {
                const srcRow = texture.getRow(srcY);
                var dstRow = canvas.getRow(dstY);
                for (0..texture.width, cursorX..) |srcX, dstX| {
                    const dst = dstRow[dstX];

                    const alpha = srcRow[srcX];
                    const blend = math.lerp8bit(0, alpha, colorAlpha);

                    dstRow[dstX] = color32bgra.mixByU8(dst, color, blend);
                }
            }
            cursorX += texture.width;
        }
    }
}

/// Draws text to canvas, it may allocate to cache additional font bitmaps
pub fn drawTextV2(dst: *Canvas(u32), font: *Font, size: usize, color: u32, x: i16, y: i16, string: []const u8) !void {
    var cursorX = x;
    const cursorY = y;
    // TODO optimize when colorAlpha == 255 or 0
    const colorAlpha = color32bgra.getAlpha(color);
    var scaleset = try font.getOrAllocSizeCache(size);

    if (cursorY > dst.height) {
        return; // first char start below canvas, drop all
    }

    if (cursorX > dst.width) {
        return; // first char is to the right of the canvas, drop all
    }

    for (string) |code| {
        if (try scaleset.lazyGetGlyph(code)) |glyph| {
            const src = glyph.data;
            const glyph_height: i16 = @intCast(glyph.data.height);
            const glyph_width: i16 = @intCast(glyph.data.width);

            if (cursorY + glyph_height <= 0) {
                cursorX += glyph_width;
                continue; // glypth completely outside canvas
            }
            if (cursorX + glyph_width <= 0) {
                cursorX += glyph_width;
                continue; // glypth completely outside canvas
            }
            if (cursorX > dst.width) {
                return; // rest of the chars is to the right of the canvas, drop all
            }

            var dstY: usize = 0;
            var srcFromY: usize = 0;
            if (cursorY < 0) {
                // partially outside top
                srcFromY = @intCast(-cursorY);
            } else {
                dstY = @intCast(cursorY);
            }
            var srcToY = src.height;
            if (srcToY + dstY >= dst.height) {
                // partially outside bottom
                srcToY = srcToY + dst.height - srcToY - dstY;
            }
            for (srcFromY..srcToY) |srcY| {
                const srcRow = src.getRow(srcY);
                var dstRow = dst.getRow(dstY);
                var dstX: usize = 0;
                var srcFromX: usize = 0;
                if (cursorX < 0) {
                    // partially outside left
                    srcFromX = @intCast(-cursorX);
                } else {
                    dstX = @intCast(cursorX);
                }
                var srcToX = src.width;
                var dstToX = dstX + (srcToX - srcFromX);
                if (dstToX >= dst.width) {
                    // partially outside right
                    const adjust = dstToX - dst.width;
                    srcToX -= adjust;
                    dstToX = dst.width;
                }
                for (srcFromX..srcToX) |srcX| {
                    const dstPixel = dstRow[dstX];

                    const alpha = srcRow[srcX];
                    const blend = math.lerp8bit(0, alpha, colorAlpha);

                    dstRow[dstX] = color32bgra.mixByU8(dstPixel, color, blend);
                    dstX += 1;
                }
                dstY += 1;
            }
            cursorX += @intCast(src.width);
        }
    }
}

pub fn measureTextSpanWidth(font: *Font, size: i16, string: []const u8) !i16 {
    var width: usize = 0;
    var scaleset = try font.getOrAllocSizeCache(@intCast(size));
    for (string) |code| {
        if (try scaleset.lazyGetGlyph(code)) |glyph| {
            width += glyph.data.width;
        }
    }
    return @intCast(width);
}

pub fn drawCenteredTextSpan(dst: *Canvas(u32), font: *Font, size: i16, color: u32, x0: i16, y0: i16, x1: i16, y1: i16, string: []const u8) !void {
    const measured_width = try measureTextSpanWidth(font, size, string);
    const width = x1 - x0;
    const height = y1 - y0;
    const scaleset = try font.getOrAllocSizeCache(@intCast(size));
    const aligned_x = x0 + @divTrunc(width - measured_width, 2);
    const aligned_y = y0 + @divTrunc(height + scaleset.capheight, 2) - scaleset.baseline;
    try drawTextV2(dst, font, @intCast(size), color, aligned_x, aligned_y, string);
}

pub const FontDataChunk = struct {
    texture: Texture(u8),
    gridCellWidth: u32,
    gridCellHeight: u32,
    cellsUsedPerGridRow: u32,
    totalCells: u32,
    firstCodePoint: u32,

    fn getCellCoords(data: FontDataChunk, codePoint: usize) Box {
        const cellIndex = codePoint - data.firstCodePoint;
        const gridRow = cellIndex / data.cellsUsedPerGridRow;
        const gridColumn = cellIndex % data.cellsUsedPerGridRow;
        const srcX0: u32 = @intCast(gridColumn * data.gridCellWidth);
        const srcY0: u32 = @intCast(gridRow * data.gridCellHeight);
        return Box.initCoordAndSize(srcX0, srcY0, data.gridCellWidth, data.gridCellHeight);
    }
};

pub const FontData = struct {
    const Self = @This();
    chunks: []const FontDataChunk,
    size: usize,
    weight: usize,
    baseline: i16,
    xheight: i16,
    lineheight: i16,
    capheight: i16,
    italic: bool,

    fn findChunk(font: Self, code: usize) ?FontDataChunk {
        for (font.chunks) |c| {
            if (c.firstCodePoint <= code and code < c.firstCodePoint + c.totalCells) {
                return c;
            }
        }
        return null;
    }
};

pub const Font = struct {
    source: FontData,
    allocator: std.mem.Allocator,
    sizeSets: std.ArrayList(FontSizeCacheMap),

    fn initLazyFromBitmap(allocator: std.mem.Allocator, bitmap: FontData) Font {
        return Font{
            .allocator = allocator,
            .source = bitmap,
            .sizeSets = std.ArrayList(FontSizeCacheMap).init(allocator),
        };
    }

    fn getOrAllocSizeCache(font: *Font, size: usize) !*FontSizeCacheMap {
        for (0..font.sizeSets.items.len) |i| {
            if (font.sizeSets.items[i].size == size) {
                return &font.sizeSets.items[i];
            }
        }
        const item = FontSizeCacheMap.init(font, size);
        try font.sizeSets.append(item);
        return &font.sizeSets.items[font.sizeSets.items.len - 1];
    }

    pub fn deinit(font: *Font) void {
        for (0..font.sizeSets.items.len) |i| {
            font.sizeSets.items[i].deinit();
        }
        font.sizeSets.deinit();
    }
};

pub const FontSizeCacheMap = struct {
    size: usize,
    baseline: i16,
    capheight: i16,
    xheight: i16,
    lineheight: i16,
    font: *Font,
    map: [256]?Glyph = .{null} ** 256,
    bitmap: [256]bool = .{false} ** 256,

    fn init(font: *Font, newsize: usize) FontSizeCacheMap {
        const i_newsize: i32 = @intCast(newsize);
        const o_size: i32 = @intCast(font.source.size);
        const o_basline: i32 = font.source.baseline;
        const o_xheight: i32 = font.source.xheight;
        const o_capheight: i32 = font.source.capheight;
        const o_lineheight: i32 = font.source.lineheight;
        const s_baseline = @divTrunc(o_basline * i_newsize, o_size);
        const s_xheight = @divTrunc(o_xheight * i_newsize, o_size);
        const s_capheight = @divTrunc(o_capheight * i_newsize, o_size);
        const s_lineheight = @divTrunc(o_lineheight * i_newsize, o_size);
        return FontSizeCacheMap{
            .font = font,
            .size = newsize,
            .baseline = @intCast(s_baseline),
            .xheight = @intCast(s_xheight),
            .capheight = @intCast(s_capheight),
            .lineheight = @intCast(s_lineheight),
        };
    }

    fn lazyGetGlyph(self: *FontSizeCacheMap, code: usize) !?Glyph {
        if (code > 256) {
            return null;
        }
        if (!self.bitmap[code]) {
            self.bitmap[code] = true;
            const source = self.font.source;
            if (source.findChunk(code)) |chunk| {
                const cell = chunk.getCellCoords(code);
                const originalSize = self.font.source.size;
                const glyphWidth = chunk.gridCellWidth * self.size / originalSize;
                const glyphHeight = chunk.gridCellHeight * self.size / originalSize;
                var dest: Canvas(u8) = try Canvas(u8).initAlloc(self.font.allocator, glyphWidth, glyphHeight);
                resampleGlyph(cell, chunk, &dest);
                self.map[code] = Glyph{
                    .data = dest,
                };
            }
        }
        return self.map[code];
    }

    fn deinit(self: *FontSizeCacheMap) void {
        for (0..self.map.len) |i| {
            if (self.map[i] != null) {
                self.map[i].?.data.deinit();
            }
        }
    }
};

fn resampleGlyph(box: Box, src: FontDataChunk, dst: *Canvas(u8)) void {
    const srcWidth: f32 = @floatFromInt(box.x1 - box.x0);
    const srcHeight: f32 = @floatFromInt(box.y1 - box.y0);
    const srcX: f32 = @floatFromInt(box.x0);
    const srcY: f32 = @floatFromInt(box.y0);
    const dstWidth: f32 = @floatFromInt(dst.width);
    const dstHeight: f32 = @floatFromInt(dst.height);
    // print("\n\n resample {d} {d} -> {d} {d}\n", .{srcWidth, srcHeight, dstWidth, dstHeight});
    for (0..dst.height) |dstY| {
        const dstRow = dst.getRow(dstY);
        const dstyY_f: f32 = @floatFromInt(dstY);
        for (0..dst.width) |dstX| {
            const dstX_f: f32 = @floatFromInt(dstX);
            const u: f32 = srcX + (dstX_f * srcWidth) / dstWidth;
            const v: f32 = srcY + (dstyY_f * srcHeight) / dstHeight;
            var value = textureModule.sampleU8AbsoluteLinear(src.texture, u, v);
            // print("rs {} {} value at {d}, {d} is {d}\n", .{dstX, dstY, u, v, value});
            if (value < 0) value = 0;
            if (value > 255) value = 255;
            dstRow[dstX] = @intFromFloat(value);
        }
    }
}

pub const Glyph = struct {
    data: Canvas(u8),
};

const internalFontChunk = FontDataChunk{
    .texture = Texture(u8).initBuffer(@embedFile("./fontmap/fontmap.raw"), 512, 512),
    .cellsUsedPerGridRow = 16,
    .firstCodePoint = 16,
    .totalCells = 256,
    .gridCellHeight = 32,
    .gridCellWidth = 19,
};

pub const internalFont = FontData{
    .size = 24,
    .weight = 800,
    .baseline = 27,
    .capheight = 17,
    .xheight = 13,
    .lineheight = 32,
    .italic = true,
    .chunks = &[_]FontDataChunk{internalFontChunk},
};

test "basic font drawing test drawTextV1" {
    const allocator = std.testing.allocator;
    var output = try Canvas(u32).initAlloc(allocator, 256, 256);
    defer output.deinit();
    var font = initInternalFont(std.testing.allocator);
    defer font.deinit();
    try drawTextV1(&output, &font, 14, color32bgra.white, 0, 0, "a");
}

test "clipping with drawTextV2" {
    const allocator = std.testing.allocator;
    var output = try Canvas(u32).initAlloc(allocator, 256, 256);
    defer output.deinit();
    var font = initInternalFont(std.testing.allocator);
    defer font.deinit();
    const color = color32bgra.white;
    // outside Y range
    try drawTextV2(&output, &font, 14, color, 0, 512, "a");
    try drawTextV2(&output, &font, 14, color, 0, -512, "a");
    // outside X range
    try drawTextV2(&output, &font, 14, color, 512, 0, "a");
    try drawTextV2(&output, &font, 14, color, -512, 0, "a");

    // partially outside all sides
    const m: i16 = 4;
    const txt = "abc";
    try drawTextV2(&output, &font, 14, color, 0, -m, txt);
    try drawTextV2(&output, &font, 14, color, -m, 0, txt);
    try drawTextV2(&output, &font, 14, color, 256 - m, 0, txt);
    try drawTextV2(&output, &font, 14, color, 0, 256 - m, txt);
}
