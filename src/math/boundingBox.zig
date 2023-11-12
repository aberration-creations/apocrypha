const std = @import("std");

pub fn BoundingBox(comptime P: type) type {

    return struct {
        const Self = BoundingBox(P);

        x0: P,
        y0: P,
        x1: P,
        y1: P,

        pub fn initCoords(x0: P, y0: P, x1: P, y1: P) BoundingBox(P)
        {
            var box = Self {
                .x0 = x0,
                .y0 = y0,
                .x1 = x1,
                .y1 = y1,
            };
            if (x1 < x0) {
                box.x1 = x0;
                box.x0 = x1;
            }
            if (y1 < y0)
            {
                box.y0 = y1;
                box.y1 = y0;
            }
            return box;
        }

        pub fn initCoordAndSize(x0: P, y0: P, width: P, height: P) BoundingBox(P)
        {
            return Self {
                .x0 = x0,
                .y0 = y0,
                .x1 = x0 + width,
                .y1 = y0 + height,
            };
        }

        pub fn containsPoint(self: Self, x: P, y: P) bool {
            if (x < self.x0) return false;
            if (x >= self.x1) return false;
            if (y < self.y0) return false;
            if (y >= self.y1) return false;
            return true;
        }

        pub fn getWidth(self: Self) P {
            return self.x1 - self.x0;
        }

        pub fn getHeight(self: Self) P {
            return self.y1 - self.y0;
        }

        pub fn equals(self: Self, other: Self) bool {
            return self.x0 == other.x0 
                and self.y0 == other.y0
                and self.x1 == other.x1 
                and self.y1 == other.y1;
        }

        pub fn containsBox(self: Self, other: Self) bool {
            return other.isInsideBox(self);
        }

        pub fn isInsideBox(self: Self, other: Self) bool {
            return self.x0 >= other.x0
                and self.y0 >= other.y0
                and self.x1 <= other.x1
                and self.y1 <= other.y1;
        }

        pub fn isOutsideOfBox(self: Self, other: Self) bool {
            return other.x1 <= self.x0 
                or self.x1 <= other.x0
                or other.y1 <= self.y0 
                or self.y1 <= other.y0;
        }

        pub fn intersectsBox(self: Self, other: Self) bool {
            return !self.isOutsideOfBox(other);
        }

        pub fn getIntersectionBox(self: Self, other: Self) BoundingBox(P)
        {
            var result = other;
            if (result.x0 < self.x0) 
            {
                result.x0 = self.x0;
                if (result.x1 < self.x0) 
                {
                    result.x1 = self.x0;
                }
            }
            if (result.y0 < self.y0) 
            {
                result.y0 = self.y0;
                if (result.y1 < self.y0)
                {
                    result.y1 = self.y0;
                }
            }
            if (self.x1 < result.x1) 
            {
                result.x1 = self.x1;
                if (self.x1 < result.x0)
                {
                    result.x0 = self.x1;
                }
            }
            if (self.y1 < result.y1) 
            {
                result.y1 = self.y1;
                if (self.y1 < result.y0)
                {
                    result.y0 = self.y1;
                }
            }
            return result;
        }
        
    };
}

test "it calculates with and height" 
{
    const box = BoundingBox(u32).initCoords(160, 100, 480, 300);
    try std.testing.expectEqual(box.getWidth(), 320);
    try std.testing.expectEqual(box.getHeight(), 200);
}

test "swaps coords if given in wrong order" 
{
    const box = BoundingBox(u32).initCoords(480, 300, 160, 100);
    try std.testing.expectEqual(box.getWidth(), 320);
    try std.testing.expectEqual(box.getHeight(), 200);
}

test "initialize from coordinate and size" 
{
    const box = BoundingBox(u32).initCoordAndSize(20, 20, 150, 100);
    try std.testing.expectEqual(box.x1, 170);
    try std.testing.expectEqual(box.y1, 120);
    try std.testing.expectEqual(box.getWidth(), 150);
    try std.testing.expectEqual(box.getHeight(), 100);
}

test "test if point is inside"
{
    const box = BoundingBox(u32).initCoords(100, 200, 110, 210);
    try std.testing.expectEqual(box.containsPoint(105, 205), true);
    try std.testing.expectEqual(box.containsPoint(105-10, 205), false);
    try std.testing.expectEqual(box.containsPoint(105+10, 205), false);
    try std.testing.expectEqual(box.containsPoint(105, 205-10), false);
    try std.testing.expectEqual(box.containsPoint(105, 205+10), false);
}

test "test if point is inside boundaries"
{
    const x0: u32 = 100;
    const x1: u32 = 200;
    const y0: u32 = 110;
    const y1: u32 = 210;
    const box = BoundingBox(u32).initCoords(x0, y0, x1, y1);
    // the point x0 y0 is required to be inside
    try std.testing.expectEqual(box.containsPoint(x0, y0), true);
    // the point x1 y1 is required to be outside
    try std.testing.expectEqual(box.containsPoint(x1, y1), false);
    // x0 - 1, y0 - 1 is definitely outside
    try std.testing.expectEqual(box.containsPoint(x0-1, y0-1), false);
    // x1 - 1, y1 - 1 is definitely inside
    try std.testing.expectEqual(box.containsPoint(x1-1, y1-1), true);
}

test "equality check" 
{
    const a = BoundingBox(u32).initCoordAndSize(20, 20, 150, 100);
    const b = BoundingBox(u32).initCoordAndSize(20, 20, 150, 100);
    const c = BoundingBox(u32).initCoordAndSize(0, 0, 10, 10);
    try std.testing.expectEqual(a.equals(b), true);
    try std.testing.expectEqual(a.equals(c), false);
}

test "check if box contains another"
{
    const x: u32 = 100;
    const y: u32 = 100;
    const a = BoundingBox(u32).initCoordAndSize(x-50, y-50, x+50, y+50);
    const b = BoundingBox(u32).initCoordAndSize(x-40, y-40, x+40, y+40);
    const c = BoundingBox(u32).initCoordAndSize(x+40, y+40, x+60, y+60);
    // bigger box contains smaller box
    try std.testing.expectEqual(a.containsBox(b), true);
    try std.testing.expectEqual(b.containsBox(a), false);
    // matching boxes will be considered to be inside one another
    try std.testing.expectEqual(a.containsBox(a), true);
    try std.testing.expectEqual(a.containsBox(a), true);
    // c actually intersects a at around x1,y1 so its not considered inside
    try std.testing.expectEqual(a.containsBox(c), false);
    try std.testing.expectEqual(c.containsBox(a), false);
}
 
test "check if box is outside another"
{
    const x: u32 = 100;
    const y: u32 = 100;
    const center = BoundingBox(u32).initCoords(x-50, y-50, x+50, y+50);
    const right = BoundingBox(u32).initCoords(x+50, y-40, x+90, y+40);
    const bottom = BoundingBox(u32).initCoords(x-50, y+50, x+50, y+90);
    try std.testing.expectEqual(center.isOutsideOfBox(right), true);
    try std.testing.expectEqual(right.isOutsideOfBox(center), true);
    try std.testing.expectEqual(center.isOutsideOfBox(bottom), true);
    try std.testing.expectEqual(bottom.isOutsideOfBox(center), true);
    const centerSmaller = BoundingBox(u32).initCoords(x-10, y-10, x+10, y+10);
    try std.testing.expectEqual(centerSmaller.isOutsideOfBox(center), false);
    try std.testing.expectEqual(center.isOutsideOfBox(centerSmaller), false);
}

test "check intersects box"
{
    const x: u32 = 100;
    const y: u32 = 400;
    const center = BoundingBox(u32).initCoords(x-50, y-50, x+50, y+50);
    const right = BoundingBox(u32).initCoords(x+50, y-40, x+90, y+40);
    const bottom = BoundingBox(u32).initCoords(x-50, y+50, x+50, y+90);
    const centerSmaller = BoundingBox(u32).initCoords(x-10, y-10, x+10, y+10);
    const intersectsRight = BoundingBox(u32).initCoords(x+45, y-40, x+90, y+40);
    const intersectsBottom = BoundingBox(u32).initCoords(x-50, y+45, x+50, y+90);
    try std.testing.expectEqual(center.intersectsBox(right), false);
    try std.testing.expectEqual(center.intersectsBox(bottom), false);
    try std.testing.expectEqual(center.intersectsBox(centerSmaller), true);
    try std.testing.expectEqual(center.intersectsBox(intersectsRight), true);
    try std.testing.expectEqual(center.intersectsBox(intersectsBottom), true);
}

test "get intersection box"
{
    const x: u32 = 100;
    const y: u32 = 400;
    const centerBox = BoundingBox(u32).initCoords(x-50, y-50, x+50, y+50);
    const smallerInsideBox = BoundingBox(u32).initCoords(x-10, y-10, x+10, y+10);
    try std.testing.expectEqual(centerBox.getIntersectionBox(smallerInsideBox), smallerInsideBox);
    try std.testing.expectEqual(smallerInsideBox.getIntersectionBox(centerBox), smallerInsideBox);

    // returns common region
    const intersectsRight = BoundingBox(u32).initCoords(x+45, y-40, x+90, y+40);
    const expectedRight = BoundingBox(u32).initCoords(x+45, y-40, x+50, y+40);
    try std.testing.expectEqual(expectedRight, centerBox.getIntersectionBox(intersectsRight));
    try std.testing.expectEqual(expectedRight, intersectsRight.getIntersectionBox(centerBox));

    const outsideA = BoundingBox(u32).initCoords(x+98, y+98, x+99, y+99);
    const outsideAResult = BoundingBox(u32).initCoords(x+50, y+50, x+50, y+50);
    const outsideAResult2 = BoundingBox(u32).initCoords(x+98, y+98, x+98, y+98);
    try std.testing.expectEqual(outsideAResult, centerBox.getIntersectionBox(outsideA));
    try std.testing.expectEqual(outsideAResult2, outsideA.getIntersectionBox(centerBox));

}
