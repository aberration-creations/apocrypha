const std = @import("std");
const x = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
    @cInclude("stdlib.h");
});

pub fn main() void 
{
    var xc = X11Connection.init();
    defer xc.deinit();
    var c = xc.conn;

    var win = X11Window.init(&xc, .{
        .title = "Test Window"
    });


    {
        const mapResult = x.xcb_map_window(c, win.win);
        std.debug.print("map seq {}\n", .{ mapResult.sequence });
        const flushResult = x.xcb_flush (c);
        std.debug.print("flush result {}\n", .{ flushResult });
    }

    var frame: u16 = 4;
    const pixmap_width = 1024;
    const pixmap_height = 1024;
    var pix_data: [pixmap_width*pixmap_height*4]u8 = undefined;
    renderXorTextureToCanvas(pixmap_width, pixmap_height, &pix_data, frame);
    
    var pixmap = x.xcb_generate_id(c);
    _ = x.xcb_create_pixmap(c,xc.depth,pixmap,win.win,pixmap_width,pixmap_height);
    var format = x.XCB_IMAGE_FORMAT_Z_PIXMAP;

    var image = x.xcb_image_create_native(c,pixmap_width,pixmap_height,@intCast(format),xc.depth,null,pix_data.len,&pix_data);
    _ = x.xcb_image_put(c, pixmap, win.gc, image, 0, 0, 0);
    _ = x.xcb_image_destroy(image);

    var exitRequested = false;
    while (!exitRequested) {
        const eventPtr = x.xcb_wait_for_event(c);
        if (eventPtr < 100) {
            exitRequested = true;
            continue;
        }
        const event = eventPtr.*;
        std.debug.print("event received type {}\n", .{ event.response_type });
        switch (event.response_type){
            x.XCB_EXPOSE => {
                flushPixmap(c, win.win, win.gc, pixmap, pixmap_width, pixmap_height, format, xc.depth, &pix_data);
            },
            x.XCB_KEY_PRESS => {
                const keyEventPtr = @as([*c]x.xcb_key_press_event_t, @ptrCast(eventPtr));
                const keyEvent = keyEventPtr.*;
                if (keyEvent.detail == 9){
                    exitRequested = true;
                }
                else {
                    frame += 1;
                    renderXorTextureToCanvas(pixmap_width, pixmap_height, &pix_data, frame);
                    flushPixmap(c, win.win, win.gc, pixmap, pixmap_width, pixmap_height, format, xc.depth, &pix_data);
                    std.debug.print("frame {}\n", .{frame});
                }
            },
            else => {
                std.debug.print("event type {} not handled\n", .{ event.response_type });
            }
            
        }
        x.free(eventPtr);
    }

}

fn renderXorTextureToCanvas(pixmap_width: u16, pixmap_height: u16, pix_data: []u8, frame: u16) void {
    for (0..pixmap_height) |py|
    {
        for (0..pixmap_width) |px|
        {
            const dst = (px + py * pixmap_width) * 4;
            const value: u8 = @intCast(((px ^ py) + frame) & 0xff);
            pix_data[dst] = value;
            pix_data[dst+1] = value;
            pix_data[dst+2] = value;
            pix_data[dst+3] = value;
        }
    }
}

const X11Connection = struct {
    conn: ?*x.xcb_connection_t,
    screen: *x.xcb_screen_t,
    depth: u8,
    colormap: u32,
    
    fn init() X11Connection {
        var c = x.xcb_connect(null, null);
        var screen = x.xcb_setup_roots_iterator (x.xcb_get_setup (c)).data;
        var depth = screen.*.root_depth;
        var colormap = screen.*.default_colormap;
        return X11Connection {
            .conn = c,
            .screen = screen,
            .depth = depth,
            .colormap = colormap,
        };
    }

    fn deinit(self: *X11Connection) void {
        x.xcb_disconnect(self.conn);
        self.conn = null;
    }
};

const X11WindowInitOptions = struct {
    width: u16 = 600,
    height: u16 = 400,
    title: []const u8 = "Window",
};

const X11Window = struct {
    win: u32,
    xc: *X11Connection,
    gc: u32,
    
    fn init(xc: *X11Connection, opt: X11WindowInitOptions) X11Window
    {
        var c = xc.conn;
        var win = x.xcb_generate_id(c);
        var screen = xc.screen;
        var windowResult = x.xcb_create_window(
            c,                            
            x.XCB_COPY_FROM_PARENT,        
            win,                         
            screen.*.root,                
            0, 0,                   
            opt.width, opt.height,                   
            10,                         
            x.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,       
            x.XCB_CW_BACK_PIXEL | x.XCB_CW_EVENT_MASK, 
            &[_]u32{
                screen.*.white_pixel,
                x.XCB_EVENT_MASK_EXPOSURE       | x.XCB_EVENT_MASK_BUTTON_PRESS   |
                x.XCB_EVENT_MASK_BUTTON_RELEASE | x.XCB_EVENT_MASK_POINTER_MOTION |
                x.XCB_EVENT_MASK_ENTER_WINDOW   | x.XCB_EVENT_MASK_LEAVE_WINDOW   |
                x.XCB_EVENT_MASK_KEY_PRESS      | x.XCB_EVENT_MASK_KEY_RELEASE,
            },
        );
        _ = windowResult;

        var empty_gc = x.xcb_generate_id(c);
        _ = x.xcb_create_gc(c, empty_gc, win, 0, null);


        const title = opt.title;
        _ = x.xcb_change_property (c, x.XCB_PROP_MODE_REPLACE, win,
            x.XCB_ATOM_WM_NAME, x.XCB_ATOM_STRING, 8,
            @intCast(title.len), title.ptr);

        return X11Window {
            .win = win,
            .xc = xc,
            .gc = empty_gc,
        };
    }

    fn deinit(w: *X11Window) void {
        x.xcb_destroy_window(w.xc.conn, w.win);
    }
};

const XWindow = struct {
    win: u32,
    default_gc: u32,
    pixmap: u32,
    pixmap_width: u16,
    pixmap_height: u16,
    format: c_int,
    depth: u8,
    pix_data: []u8,
};

fn flushPixmap(c: ?*x.xcb_connection_t, win: u32, gc: u32, pixmap: u32, pixmap_width: u16, pixmap_height: u16, format: c_int, depth: u8, pix_data: []u8) void {
    var image = x.xcb_image_create_native(c,pixmap_width,pixmap_height,@intCast(format),depth,null,@intCast(pix_data.len),pix_data.ptr);
    _ = x.xcb_image_put(c, pixmap, gc, image, 0, 0, 0);
    _ = x.xcb_image_destroy(image);
    _ = x.xcb_copy_area(c,pixmap,win,gc,0,0,0,0,pixmap_width,pixmap_height);
    _ = x.xcb_flush(c);
}