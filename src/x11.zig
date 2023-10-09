const std = @import("std");
const x = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
    @cInclude("stdlib.h");
});

pub fn main() void 
{
    var c = x.xcb_connect(null, null);
    // defer x.xcb_disconnect(c);
    var screen = x.xcb_setup_roots_iterator (x.xcb_get_setup (c)).data;
    var depth = screen.*.root_depth;
    std.debug.print("depth {}\n", .{depth});
    var colormap = screen.*.default_colormap;
    _ = colormap;

    var width: u16 = 600;
    var height: u16 = 400;

    var win = x.xcb_generate_id(c);
    var windowResult = x.xcb_create_window(
        c,                            
        x.XCB_COPY_FROM_PARENT,        
        win,                         
        screen.*.root,                
        0, 0,                   
        width, height,                   
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
    std.debug.print("window created, seq {}\n", .{ windowResult.sequence } );            
    const title = "Hello World!";
    _ = x.xcb_change_property (c, x.XCB_PROP_MODE_REPLACE, win,
        x.XCB_ATOM_WM_NAME, x.XCB_ATOM_STRING, 8,
        title.len, title);
    var black = x.xcb_generate_id(c);
    _ = x.xcb_create_gc (c, black, win, x.XCB_GC_FOREGROUND, &[_]u32{ screen.*.black_pixel });

    var empty_gc = x.xcb_generate_id(c);
    _ = x.xcb_create_gc(c, empty_gc, win, 0, null);

    {
        const mapResult = x.xcb_map_window(c, win);
        std.debug.print("map seq {}\n", .{ mapResult.sequence });
        const flushResult = x.xcb_flush (c);
        std.debug.print("flush result {}\n", .{ flushResult });
    }

    var pixmap_width: u16 = 256;
    var pixmap_height: u16 = 256;
    var pix_data: [256*256*4]u8 = undefined;
    for (0..pixmap_height) |py|
    {
        for (0..pixmap_width) |px|
        {
            const dst = (px + py * pixmap_height) * 4;
            const value: u8 = @intCast((px ^ py) & 0xff);
            pix_data[dst] = value;
            pix_data[dst+1] = value;
            pix_data[dst+2] = value;
            pix_data[dst+3] = value;
        }
    }
    var pixmap = x.xcb_generate_id(c);
    _ = x.xcb_create_pixmap(c,depth,pixmap,win,pixmap_width,pixmap_height);
    var format = x.XCB_IMAGE_FORMAT_Z_PIXMAP;
    var image = x.xcb_image_create_native(c,pixmap_width,pixmap_height,@intCast(format),depth,null,pix_data.len,&pix_data);
    _ = x.xcb_image_put(c, pixmap, empty_gc, image, 0, 0, 0);
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
                // x.xcb_expose_event_t *event = (xcb_expose_event_t *)event;
                _ = x.xcb_poly_rectangle (c, win, black, 1, &[_]x.struct_xcb_rectangle_t{ .{.x=100, .y=10, .width=140, .height=30}});
                _ = x.xcb_copy_area(c,pixmap,win,empty_gc,0,0,0,0,pixmap_width,pixmap_height);
                _ = x.xcb_flush(c);
            },
            x.XCB_KEY_PRESS => {
                const keyEventPtr = @as([*c]x.xcb_key_press_event_t, @ptrCast(eventPtr));
                const keyEvent = keyEventPtr.*;
                if (keyEvent.detail == 9){
                    exitRequested = true;
                }
            },
            else => {
                std.debug.print("event type {} not handled\n", .{ event.response_type });
            }
            
        }
        x.free(eventPtr);
    }


}

