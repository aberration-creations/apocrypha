const std = @import("std");
const Canvas = @import("canvas.zig").Canvas(u32);

pub fn dumpCanvas32ToFile(canvas: Canvas, path: []const u8) !void {

    const file = try std.fs.cwd().createFile(
        path,
        .{ .read = true },
    );
    defer file.close();
    
    var data: []u8 = undefined;
    data.ptr = @ptrCast(canvas.pixels.ptr);
    data.len = canvas.pixels.len * @sizeOf(u32);
    const bytes_written = try file.writeAll(data);
    _ = bytes_written;
}
