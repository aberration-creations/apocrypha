const dom = @import("./dom.zig");
const ui = @import("./index.zig");
const Canvas32 = ui.Canvas32;
const Font = ui.Font;

fn drawDomTree(self: *dom.Element, canvas: *Canvas32, font: *Font) !void {
    if (self.hidden) {
        return;
    }

    const x0 = self.x;
    const y0 = self.y;
    const x1 = x0 + self.w;
    const y1 = y0 + self.h;
    const text = self.static_text;

    if (self.style.border_size > 0) {
        drawBorderedRect(x0, y0, x1, y1, self.style.border_size, self.style.border_color, self.style.background_color);
    } else if (self.style.background_color != 0) {
        canvas.rect(x0, y0, x1, y1, self.style.background_color);
    }

    if (text.len > 0) {
        try ui.drawCenteredTextSpan(canvas, font, 10, self.style.color, x0, y0, x1, y1, text);
    }

    if (self.children) |*list| {
        for (list.items) |*child| {
            try drawDomTree(child);
        }
    }
}

pub fn drawBorderedRect(canvas: *Canvas32, x0: i16, y0: i16, x1: i16, y1: i16, border: i16, border_color: u32, bg_color: u32) void {
    canvas.rect(x0 + border, y0 + border, x1 - border, y1 - border, bg_color);
    drawBorder(x0, y0, x1, y1, border, border_color);
}

pub fn drawBorder(canvas: *Canvas32, x0: i16, y0: i16, x1: i16, y1: i16, thickness: i16, color: u32) void {
    canvas.rect(x0, y0, x1, y0 + thickness, color);
    canvas.rect(x0, y1 - thickness, x1, y1, color);
    canvas.rect(x0, y0 + thickness, x0 + thickness, y1 - thickness, color);
    canvas.rect(x1 - thickness, y0 + thickness, x1, y1 - thickness, color);
}
