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

    var values: [2]u32 = undefined;
    values[0] = screen.*.white_pixel;
    values[1] = x.XCB_EVENT_MASK_EXPOSURE | x.XCB_EVENT_MASK_KEY_PRESS;

    var win = x.xcb_generate_id(c);
    var windowResult = x.xcb_create_window(
        c,                            
        x.XCB_COPY_FROM_PARENT,        
        win,                         
        screen.*.root,                
        0, 0,                   
        150, 150,                   
        10,                         
        x.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        screen.*.root_visual,       
        x.XCB_CW_BACK_PIXEL | x.XCB_CW_EVENT_MASK, 
        &values,
    );
    std.debug.print("window created, seq {}\n", .{ windowResult.sequence } );            
                    
    {
        const mapResult = x.xcb_map_window(c, win);
        std.debug.print("map seq {}\n", .{ mapResult.sequence });
        const flushResult = x.xcb_flush (c);
        std.debug.print("flush result {}\n", .{ flushResult });
    }

    var exitRequested = false;
    while (!exitRequested) {
        const eventPtr = x.xcb_wait_for_event(c);
        const event = eventPtr.*;
        std.debug.print("event received type {}\n", .{ event.response_type });
        switch (event.response_type){
            x.XCB_EXPOSE => {
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

