const BoundingBox = @import("../math/math.zig").Box;

pub fn Context(comptime P: type) type {

    return struct {
        const Self = Context(P);

        // drawing context target
        pixels: []P,
        width: usize,
        height: usize,

        viewport: BoundingBox(usize),
        background: P,

        /// not efficient but convenient
        pub inline fn getPixel(self: Self, x: usize, y: usize) P {  
            return self.pixels[y*self.width+x];
        }

        /// not efficient but convenient
        pub inline fn setPixel(self: Self, x: usize, y: usize, p: P) void {
            // TODO
            if (x < self.viewportX or y < self.viewportY) return;
            self.pixels[y*self.width+x] = p;
        }

        /// get access to row of pixels for read/write purposes
        pub inline fn getRow(self: Self, y: usize) []P {
            // TODO
            const from = y*self.width;
            const to = from + self.width;
            return self.pixels[from..to];
        }
        
        /// get access to stride of pixels for read/write purposes
        pub inline fn getStride(self: Self, y: usize, x0: usize, x1: usize) []P {
            // TODO
            return self.getRow(y)[x0..x1];
        }

    };

}
