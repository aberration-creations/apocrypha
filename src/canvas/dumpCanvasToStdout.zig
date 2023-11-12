const std = @import("std");
const Canvas = @import("canvas.zig").Canvas(u32);

pub fn dumpCanvasToStdout(canvas: Canvas) !void
{
    const file = std.io.getStdOut();

    var data: []u8 = undefined;
    data.ptr = @ptrCast(canvas.pixels.ptr);
    data.len = canvas.pixels.len * @sizeOf(u32);
    const bytes_written = try file.writeAll(data);
    _ = bytes_written;
}