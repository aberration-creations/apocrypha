const std = @import("std");

/// Generic representation of grid of pixels. 
/// Meant for graphics operations.
pub fn Canvas(comptime P: type) type {

    const EMPTY: [0]P = .{};

    return struct {
        const Self = Canvas(P);

        allocator: ?std.mem.Allocator,
        pixels: []P,
        width: usize,
        height: usize,

        /// Not efficient, only exists for convenience.
        /// Put pixel at given position.
        pub inline fn putPixel(self: Self, x: usize, y: usize, p: P) void {
            if (x < self.width and y < self.height)
                self.putPixelUnsafe(x, y, p);
        }

        /// Not efficient, only exists for convenience.
        /// Returns pixel from given position or null if outside canvas range.
        pub inline fn getPixel(self: Self, x: usize, y: usize) ?P {   
            if (x < self.width and y < self.height)
                return self.getPixelUnsafe(x, y);
            return null;
        }

        /// Not efficient, only exists for convenience.
        /// Caller must ensure that the coordinates are in range.
        pub inline fn putPixelUnsafe(self: Self, x: usize, y: usize, p: P) void {
            self.row(y)[x] = p;
        }

        /// Not efficient, only exists for convenience.
        /// Caller must ensure that the coordinates are in range.
        pub inline fn getPixelUnsafe(self: Self, x: usize, y: usize) P {   
            return self.row(y)[x];
        }

        /// Get direct access to row of pixels for read/write purposes.
        /// Caller must ensure that the coordinates are in range.
        pub inline fn row(self: Self, y: usize) []P {
            const from = y*self.width;
            const to = from + self.width;
            return self.pixels[from..to];
        }
        
        /// Get direct access to a contiguous span of pixels for read/write purposes.
        /// Caller must ensure that the coordinates are in range.
        pub inline fn span(self: Self, y: usize, x0: usize, x1: usize) []P {
            return self.getRow(y)[x0..x1];
        }

        /// Initialize with allocator and allocate canvas
        pub fn initAlloc(allocator: std.mem.Allocator, width: usize, height: usize) !Self 
        {
            var data = try allocator.alloc(P, width*height);
            return Self {
                .allocator = allocator,
                .pixels = data,
                .width = width,
                .height = height,
            };
        }

        // Initializes with allocator, but does not allocate yet.
        pub fn initAllocEmpty(allocator: std.mem.Allocator) Self {
            return Self {
                .allocator = allocator,
                .pixels = &EMPTY,
                .width = 0,
                .height = 0,
            };
        }

        // Initialize with static buffer, enables canvas usage without allocator
        pub fn initBuffer(buf: []P, width: u32, height: u32) Self
        {
            const requiredSize = width * height;
            if (buf.len < requiredSize){
                @panic("given width/height will not fit into buffer");
            }
            return Self {
                .allocator = null,
                .height = height,
                .width = width,
                .pixels = buf,
            };
        }

        // Reallocates to new size, pixels are left uninitialized.
        pub fn reallocate(self: *Self, width: u32, height: u32) !void {
            self.deinit();
            const new = try initAlloc(self.allocator.?, width, height);
            self.height = new.height;
            self.width = new.width;
            self.pixels = new.pixels;
        }

        // Set all pixels to same color
        pub fn clear(self: *Self, pixel: P) void {
            @memset(self.pixels, pixel);
        }

        // Draws a rectangle at given position and color.
        pub fn rect(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, p: P) void {
            var clip_x0: usize = 0;
            var clip_y0: usize = 0;
            var clip_x1: usize = 0;
            var clip_y1: usize = 0;
            if (x1 > 0) clip_x1 = @intCast(x1);
            if (y1 > 0) clip_y1 = @intCast(y1);
            if (x0 > 0) clip_x0 = @intCast(x0);
            if (y0 > 0) clip_y0 = @intCast(y0);

            self.rectUnsigned(clip_x0, clip_y0, clip_x1, clip_y1, p);
        }

        // Draws a rectangle at given unsigned position and color.
        pub fn rectUnsigned(self: *Self, x0: usize, y0: usize, x1: usize, y1: usize, p: P) void {
            var clip_x0 = x0;
            var clip_y0 = y0;
            var clip_x1 = x1;
            var clip_y1 = y1;
            if (clip_x0 > self.width) clip_x0 = self.width;
            if (clip_y0 > self.height) clip_y0 = self.height;
            if (clip_x1 > self.width) clip_x1 = self.width;
            if (clip_y1 > self.height) clip_y1 = self.height;

            self.rectUnsafe(clip_x0, clip_y0, clip_x1, clip_y1, p);
        }

        /// Draw a rectangle at given position and color.
        /// Caller must ensure that the coordinates are in range.
        pub fn rectUnsafe(self: *Self, x0: usize, y0: usize, x1: usize, y1: usize, p: P) void {
            for (y0..y1) |y| 
                @memset(self.span(y, x0, x1), p);
        }
    
        /// Free the memory used by the canvas, to be used with defer
        pub fn deinit(self: *Self) void {
            if (self.allocator) |allocator|
            {
                if (self.pixels.ptr != &EMPTY)
                {
                    allocator.free(self.pixels);
                }
            }
            self.pixels = &EMPTY;
        }

        // old function names

        pub const setPixel = putPixel;
        pub const getRow = row;
        pub const getStride = span;

    };

}

test "using buffer"
{
    var buf: [256*256]u32 = undefined;
    var c = Canvas(u32).initBuffer(&buf, 256, 256);
    c.putPixel(0, 0, 0xff00ff00);
    try std.testing.expectEqual(c.getPixel(0,0), 0xff00ff00);
    c.putPixel(255, 255, 0xff00ff00);
    try std.testing.expectEqual(c.getPixel(255,255), 0xff00ff00);
}

test "using allocator"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    c.putPixel(0, 0, 0xff00ff00);
    try std.testing.expectEqual(c.getPixel(0,0), 0xff00ff00);
}

test "can write full area"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    for (0..c.height) |y|
    {
        var row = c.getRow(y);
        for (row, 0..) |_, x|
        {   
            row[x] = 0xff00ff00;
        }
    }
    try std.testing.expectEqual(c.getPixel(15,15), 0xff00ff00);
}

test "clear canvas"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    c.clear(0xffeedd);
    try std.testing.expectEqual(c.getPixel(0,0), 0xffeedd);
    try std.testing.expectEqual(c.getPixel(15,15), 0xffeedd);
}

test "rect on canvas"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    c.clear(0x000000);
    c.rect(4, 4, 8, 8, 0xffffff);
    try std.testing.expectEqual(c.getPixel(3,3), 0x000000);
    try std.testing.expectEqual(c.getPixel(4,4), 0xffffff);
    try std.testing.expectEqual(c.getPixel(7,7), 0xffffff);
    try std.testing.expectEqual(c.getPixel(8,8), 0x000000);
}

test "reallocate"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    try c.reallocate(64, 96);
    try std.testing.expectEqual(c.width, 64);
    try std.testing.expectEqual(c.height, 96);
}

test "rect is clipped"
{
    var allocator = std.testing.allocator;
    var c = try Canvas(u32).initAlloc(allocator, 16, 16);
    defer c.deinit();
    c.rect(8, 8, 24, 24, 0);
    c.rect(-8, -8, 24, 24, 1);
    c.rect(-80, -80, -24, -24, 1);
    c.rect(18, 18, 24, 24, 0);
}

test "get/set pixel is clipped"
{
    var allocator = std.testing.allocator;
    var c = try Canvas(u32).initAlloc(allocator, 16, 16);
    defer c.deinit();
    c.putPixel(114, 144, 0);
}

