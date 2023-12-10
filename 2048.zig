const std = @import("std");
const ui = @import("./src/index.zig");
var rand = std.rand.DefaultPrng.init(0);

const Cell = struct {
    value: u16 = 0,
    spawn_t: f32 = 0,
    grow_t: f32 = 1,
    in_x_t: f32 = 0,
    in_y_t: f32 = 0,
};

var window: ui.Window = undefined;
var canvas: ui.Canvas32 = undefined;
var font: ui.Font = undefined;
var game: [4][4]Cell = .{ .{ .{} } ** 4 } ** 4;
var is_animating = false;
var last_render_ms: i64 = 0;
var score: usize = 0;
var score_delta: usize = 0;
var score_delta_t: f32 = 1;

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("MEMORY LEAK");
    }

    canvas = try ui.Canvas32.initAlloc(allocator, 512, 512);
    defer canvas.deinit();
    
    window = ui.Window.init(.{
        .title = "2048 Game",
        .width = @intCast(canvas.width),
        .height = @intCast(canvas.height),
    });
    defer window.deinit();

    font = ui.loadInternalFont(allocator);
    defer font.deinit();

    addRandomValue();
    addRandomValue();

    while (true) {
        while (ui.nextEvent(.{ .blocking = !is_animating })) |evt| {
            switch (evt) {
                .paint => {
                    try render();
                },
                .keydown => |key| switch(key) {
                    .escape => return,
                    .up => try move(0, -1),
                    .left => try move(-1, 0),
                    .right => try move(1, 0),
                    .down => try move(0, 1),
                    else => {},
                },
                .resize => |size| try canvas.reallocate(size.width, size.height),
                .closewindow => return,
                else => {},
            }
        }
        if (is_animating)
        {
            try render();
            std.time.sleep(1);
        }
    }

}

fn move(dir_x: i32, dir_y: i32) !void
{
    var moved = false;
    var merge_score: usize = 0;

    for (0..4) |x| {
        for (0..4) |y| {
            
            var from_x = x;
            var from_y = y;

            if (dir_x > 0) from_x = 3 - from_x;
            if (dir_y > 0) from_y = 3 - from_y;

            const result = moveCell(from_x, from_y, dir_x, dir_y);

            if (result.moved) {
                moved = true;
                merge_score += result.score;
            }
        }
    }

    if (moved) {
        addRandomValue();

        if (merge_score > 0)
        {
            score_delta = merge_score;
            score_delta_t = 0;
            score += score_delta;
        }
    }

    is_animating = true;
}

fn moveCell(x: usize, y: usize, dx: i32, dy: i32) struct { moved: bool, score: usize = 0 } {

    var i_from_x: i32 = @intCast(x);
    var i_from_y: i32 = @intCast(y);
    var to_x = x;
    var to_y = y;
    var cell_from = &game[x][y];

    if (cell_from.value == 0) 
    {
        return .{ .moved = false };
    }

    for (1..4) |i| {
        var signed_i: i32 = @intCast(i);
        var nx = dx * signed_i + i_from_x;
        var ny = dy * signed_i + i_from_y;

        if (nx < 0 or ny < 0 or nx > 3 or ny > 3)
        {
            break; // move blocked by grid edge
        }

        var unx: usize = @intCast(nx);
        var uny: usize = @intCast(ny);

        if (game[unx][uny].value == 0) 
        {
            to_x = unx;
            to_y = uny;
            continue; // move over empty
        }
        else if (game[unx][uny].value == cell_from.value)
        {
            to_x = unx;
            to_y = uny;
            break; // merge with same value
        }
        else 
        {
            break; // move blocked by block of different value
        }
    }

    if (to_x == x and to_y == y)
    {
        return .{ .moved = false }; // no move
    }

    var cell_to = &game[to_x][to_y];
    
    if (cell_from.value == cell_to.value) {
        // merge
        cell_to.value += cell_from.value;
        cell_to.grow_t = 0; 
        cell_to.spawn_t = 1;
        cell_from.* = Cell{};
        return .{ .moved = true, .score = cell_to.value };
    }
    else if (cell_to.value == 0)
    {
        // move
        cell_to.in_x_t = cell_from.in_x_t + @as(f32, @floatFromInt(-dx));
        cell_to.in_y_t = cell_from.in_y_t + @as(f32,@floatFromInt(-dy));
        cell_to.value = cell_from.value;
        cell_to.grow_t = cell_from.grow_t;
        cell_to.spawn_t = cell_from.spawn_t;
        cell_from.* = Cell{};
        return .{ .moved = true };
    }
    else 
    {
        return .{ .moved = false };
    }
}

fn render() !void {

    const now = std.time.milliTimestamp();
    var dt: f32 = 0;
    if (is_animating)
    {
        dt = @floatFromInt(now - last_render_ms);
        dt /= 1000;
    }
    last_render_ms = now;
    score_delta_t += dt;

    is_animating = false; // may prove to be wrong

    const color_background = 0xff202020;
    const color_empty = 0xff303030;
    const white = 0xffffffff;
    canvas.clear(color_background);

    var buffer: [32]u8 = undefined;

    const size: i32 = 64;
    const gap: i32 = 16;
    const size_and_gap: i32 = size + gap;
    const margin_x: i32 = @divFloor(@as(i32, @intCast(canvas.width)) - 4*size-3*gap, 2);
    const margin_y: i32 = @divFloor(@as(i32, @intCast(canvas.height)) - 4*size-3*gap, 2);

    for (0..4) |ux| {
        for (0..4) |uy| {
            const x: i32 = @intCast(ux);
            const y: i32 = @intCast(uy);
            var x0 = margin_x + x * size_and_gap;
            var y0 = margin_y + y * size_and_gap;
            var x1 = x0 + size;
            var y1 = y0 + size;
            canvas.rect(x0, y0, x1, y1, color_empty);
        }
    }

    for (0..4) |ux| {
        for (0..4) |uy| {
            const x: i32 = @intCast(ux);
            const y: i32 = @intCast(uy);
            var x0 = margin_x + x * size_and_gap;
            var y0 = margin_y + y * size_and_gap;
            var x1 = x0 + size;
            var y1 = y0 + size;
            var c = &game[ux][uy];
            const movespeed = 20;
            if (c.in_x_t > 0) {
                is_animating = true;
                c.in_x_t -= dt*movespeed;
                if (c.in_x_t < 0) {
                    c.in_x_t = 0;
                }
            }
            else if (c.in_x_t < 0) {
                is_animating = true;
                c.in_x_t += dt*movespeed;
                if (c.in_x_t >= 0) {
                    c.in_x_t = 0;
                }
            }
            if (c.in_y_t > 0) {
                is_animating = true;
                c.in_y_t -= dt*movespeed;
                if (c.in_y_t < 0) {
                    c.in_y_t = 0;
                }
            }
            else if (c.in_y_t < 0) {
                is_animating = true;
                c.in_y_t += dt*movespeed;
                if (c.in_y_t >= 0) {
                    c.in_y_t = 0;
                }
            }
            c.grow_t += dt;
            if (c.grow_t > 1){
                c.grow_t = 1;
            } else {
                is_animating = true;
            }
            var cell_t = game[ux][uy].spawn_t + dt;
            if (cell_t > 1) {
                cell_t = 1;
            } else {
                is_animating = true;
            }
            game[ux][uy].spawn_t = cell_t;
            const cell = game[ux][uy];

            if (cell.value > 0)
            {
                var bg_color = getColorByValue(cell.value);
                var s: i32 = @intFromFloat(32-cell_t*128);
                x0 += @intFromFloat(cell.in_x_t * 96);
                y0 += @intFromFloat(cell.in_y_t * 96);
                x1 += @intFromFloat(cell.in_x_t * 96);
                y1 += @intFromFloat(cell.in_y_t * 96);
                if (s < 0) s = 0;
                s += @intFromFloat(@max(0,(1-(c.grow_t*c.grow_t)*8))*-16);
                canvas.rect(x0+s, y0+s, x1-s, y1-s, bg_color);
                const str = try std.fmt.bufPrint(&buffer, "{}", .{ cell.value });
                const font_color = ui.color32bgra.mixColor32bgraByFloat(0x00ffffff, white, cell_t*2);
                try ui.drawCenteredTextSpan(&canvas, &font, 24, font_color, @intCast(x0), @intCast(y0), @intCast(x1), @intCast(y1), str);
            }
        }
    }

    const str = try std.fmt.bufPrint(&buffer, "score {}", .{ score });
    const score_x0: i16 = @intCast(margin_x);
    const score_y0: i16 = @intCast(margin_y - 48);
    try ui.drawTextV2(&canvas, &font, 24, white, score_x0, score_y0, str);

    if (score_delta_t > 1) {
        score_delta_t = 1;
    } else {
        is_animating = true;
    }
    

    const str2 = try std.fmt.bufPrint(&buffer, "+{}", .{ score_delta });
    const anim_color = ui.color32bgra.mixColor32bgraByFloat(0xf080c020, 0x00ff00, score_delta_t);
    const anim_sx = score_x0 + @as(i16, @intCast(str.len*20));
    const anim_sy = score_y0 + @as(i16, @intFromFloat(score_delta_t*score_delta_t*-50));
    try ui.drawTextV2(&canvas, &font, 24, anim_color, anim_sx, anim_sy, str2);

    ui.presentCanvas32(window, canvas);
}

fn addRandomValue() void {
    for (0..100) |i| {
        _ = i;
        var rx = rand.next() % 4;
        var ry = rand.next() % 4;
        if (game[rx][ry].value == 0)
        {   
            var value: u16 = 2;
            if (rand.next() % 6 == 0) {
                value = 4;
            }
            var cell = &game[rx][ry];
            cell.value = value;
            cell.spawn_t = 0;
            cell.grow_t = 1;
            return;
        }
    }
}

fn getColorByValue(value: u16) u32
{
    return switch (value) {
        0 => 0xff303030,
        2 => 0xff3050b0,
        4 => 0xff3080b0,
        8 => 0xff303060,
        16 => 0xff309070,
        32 => 0xff709030,
        64 => 0xffb09030,
        128 => 0xffb06030,
        256 => 0xffb02030,
        512 => 0xffb02060,
        1024 => 0xffb02090,
        2048 => 0xff9020b0,
        else => 0xff708030,
    };
}