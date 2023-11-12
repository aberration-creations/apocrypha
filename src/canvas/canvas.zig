const std = @import("std");

const CanvasError = error {
    DoesNotFitIntoBuffer,
};

pub fn Canvas(comptime P: type) type {

    const EMPTY: [0]P = .{};

    return struct {
        const Self = Canvas(P);

        allocator: std.mem.Allocator = undefined,
        pixels: []P,
        width: usize,
        height: usize,
        boundaryTop: []P,
        boundaryBottom: []P,
        data: []P,

        /// not efficient but convenient
        pub inline fn getPixel(self: Self, x: usize, y: usize) P {   
            return self.pixels[y*self.width+x];
        }

        /// not efficient but convenient
        pub inline fn setPixel(self: Self, x: usize, y: usize, p: P) void {
            self.pixels[y*self.width+x] = p;
        }

        /// get access to row of pixels for read/write purposes
        pub inline fn getRow(self: Self, y: usize) []P {
            const from = y*self.width;
            const to = from + self.width;
            return self.pixels[from..to];
        }
        
        /// get access to stride of pixels for read/write purposes
        pub inline fn getStride(self: Self, y: usize, x0: usize, x1: usize) []P {
            return self.getRow(y)[x0..x1];
        }

        /// initialize with allocator and allocate canvas
        pub fn initAlloc(allocator: std.mem.Allocator, width: usize, height: usize) !Self 
        {
            var data = try allocator.alloc(P, width*(height+2));
            return Self {
                .allocator = allocator,
                .boundaryTop = data[0..width],
                .boundaryBottom = data[width*(height+1)..width*(height+2)],
                .pixels = data[width..width*(height+1)],
                .data = data,
                .width = width,
                .height = height,
            };
        }

        // initialize with static buffer, allows allocatorless canvas
        pub fn initBuffer(buf: []P, width: u32, height: u32) !Self
        {
            const requiredSize = width * height;
            if (buf.len < requiredSize){
                return CanvasError.DoesNotFitIntoBuffer;
            }
            return Self {
                .boundaryBottom = &EMPTY,
                .boundaryTop = &EMPTY,
                .height = height,
                .width = width,
                .pixels = buf,
                .data = &EMPTY,
            };
        }

        pub fn clear(self: *Self, pixel: P) void {
            if (self.data.len > 0) {
                @memset(self.data, pixel);
            }
            else 
            {
                @memset(self.boundaryTop, pixel);
                @memset(self.pixels, pixel);
                @memset(self.boundaryBottom, pixel);
            }
        }

        pub fn rect(self: *Self, x0: usize, y0: usize, x1: usize, y1: usize, p: P) void {
            for (y0..y1) |y| {
                var row = self.getStride(y, x0, x1);
                for (row, 0..) |_, x| {
                    row[x] = p;
                }
            }
        }

        pub fn deinit(self: *Self) void {
            if (self.data.len > 0)
            {
                self.allocator.free(self.data);
            }
            self.data = &EMPTY;
        }

    };

}

test "using buffer"
{
    var buf: [256*256]u32 = undefined;
    var c = try Canvas(u32).initBuffer(&buf, 256, 256);
    c.setPixel(0, 0, 0xff00ff00);
    try std.testing.expectEqual(c.getPixel(0,0), 0xff00ff00);
    c.setPixel(255, 255, 0xff00ff00);
    try std.testing.expectEqual(c.getPixel(255,255), 0xff00ff00);
}

test "using allocator"
{
    var c = try Canvas(u32).initAlloc(std.testing.allocator, 16, 16);
    defer c.deinit();
    c.setPixel(0, 0, 0xff00ff00);
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