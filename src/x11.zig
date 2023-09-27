const std = @import("std");
const x = @cImport({
    @cInclude("xcb/xcb.h");
});

pub fn main() void 
{
    var c = x.xcb_connect(null, null);
    // defer x.xcb_disconnect(c);
    var screen = x.xcb_setup_roots_iterator (x.xcb_get_setup (c)).data;
    std.debug.print("screen is {}x{}\n", .{ screen.*.width_in_pixels, screen.*.height_in_pixels });
    std.debug.print("white pixel is {}\n", .{ screen.*.white_pixel });
    std.debug.print("black pixel is {}\n", .{ screen.*.black_pixel });

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

    {
        const mapResult = x.xcb_map_window(c, win);
        std.debug.print("map seq {}\n", .{ mapResult.sequence });
        const flushResult = x.xcb_flush (c);
        std.debug.print("flush result {}\n", .{ flushResult });
    }

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
                _ = x.xcb_poly_rectangle (c, win, black, 1, &[_]x.struct_xcb_rectangle_t{ .{.x=100, .y=10, .width=140, .height=30}});
                const flushResult = x.xcb_flush (c);
                std.debug.print("flush result {}\n", .{ flushResult });
            },
            x.XCB_KEY_PRESS => {
                exitRequested = true;
            },
            else => {
                std.debug.print("event type {} not handled\n", .{ event.response_type });
            }
        }

    }


}

