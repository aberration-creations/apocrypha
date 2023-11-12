// TODO move this to example file

pub fn renderXorTextureToCanvas(pixmap_width: u16, pixmap_height: u16, pix_data: []u8, frame: u16) void {
    for (0..pixmap_height) |py| {
        for (0..pixmap_width) |px| {
            const dst = (px + py * pixmap_width) * 4;
            const value: u8 = @intCast(((px ^ py) + frame) & 0xff);
            pix_data[dst] = value;
            pix_data[dst + 1] = value;
            pix_data[dst + 2] = value;
            pix_data[dst + 3] = value;
        }
    }
}
