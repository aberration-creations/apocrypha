// x11 support library

pub const x = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
    @cInclude("stdlib.h");
});

pub const X11Connection = struct {
    conn: ?*x.xcb_connection_t,
    screen: *x.xcb_screen_t,
    depth: u8,
    colormap: u32,
    wm_state: u32 = 0,
    wm_fullscreen: u32 = 0,

    pub fn init() X11Connection {
        var c = x.xcb_connect(null, null);
        var screen = x.xcb_setup_roots_iterator(x.xcb_get_setup(c)).data;
        var depth = screen.*.root_depth;
        var colormap = screen.*.default_colormap;
        return X11Connection{
            .conn = c,
            .screen = screen,
            .depth = depth,
            .colormap = colormap,
        };
    }

    pub fn deinit(self: *X11Connection) void {
        x.xcb_disconnect(self.conn);
        self.conn = null;
    }

    fn internAtom(self: *X11Connection, name: []const u8) x.xcb_atom_t {
        // not the most efficient
        const cookie = x.xcb_intern_atom(self.conn, 1, @intCast(name.len), name.ptr);
        var err: [*c]x.xcb_generic_error_t = undefined;
        const result = x.xcb_intern_atom_reply(self.conn, cookie, &err);
        return result.*.atom;
    }

    fn internAtomWmState(self: *X11Connection) x.xcb_atom_t {
        if (self.wm_state == 0) {
            self.wm_state = self.internAtom("_NET_WM_STATE");
        }
        return self.wm_state;
    }

    fn internAtomWmFullscreen(self: *X11Connection) x.xcb_atom_t {
        if (self.wm_fullscreen == 0) {
            self.wm_fullscreen = self.internAtom("_NET_WM_STATE_FULLSCREEN");
        }
        return self.wm_fullscreen;
    }
};

pub const X11WindowInitOptions = struct {
    x: i16 = 0,
    y: i16 = 0,
    width: u16 = 600,
    height: u16 = 400,
    title: []const u8 = "Window",
    fullscreen: bool = false,
};

pub const X11Window = struct {
    win: u32,
    xc: *X11Connection,
    gc: u32,
    pixmap: x.xcb_pixmap_t = 0,
    pixmap_width: u16 = 0,
    pixmap_height: u16 = 0,

    pub fn init(xc: *X11Connection, opt: X11WindowInitOptions) X11Window {
        var c = xc.conn;
        var win = x.xcb_generate_id(c);
        var screen = xc.screen;
        var windowResult = x.xcb_create_window(
            c,
            x.XCB_COPY_FROM_PARENT,
            win,
            screen.*.root,
            0,
            0,
            opt.width,
            opt.height,
            10,
            x.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            x.XCB_CW_BACK_PIXEL | x.XCB_CW_EVENT_MASK,
            &[_]u32{
                screen.*.white_pixel,
                x.XCB_EVENT_MASK_EXPOSURE | x.XCB_EVENT_MASK_BUTTON_PRESS |
                    x.XCB_EVENT_MASK_BUTTON_RELEASE | x.XCB_EVENT_MASK_POINTER_MOTION |
                    x.XCB_EVENT_MASK_ENTER_WINDOW | x.XCB_EVENT_MASK_LEAVE_WINDOW |
                    x.XCB_EVENT_MASK_KEY_PRESS | x.XCB_EVENT_MASK_KEY_RELEASE |
                    x.XCB_EVENT_MASK_STRUCTURE_NOTIFY,
            },
        );
        _ = windowResult;

        var empty_gc = x.xcb_generate_id(c);
        _ = x.xcb_create_gc(c, empty_gc, win, 0, null);

        var window = X11Window{
            .win = win,
            .xc = xc,
            .gc = empty_gc,
        };
        window.setTitle(opt.title);
        window.setFullscreen(opt.fullscreen);
        _ = x.xcb_map_window(c, win);
        _ = x.xcb_flush(c);
        return window;
    }

    pub fn setTitle(w: *X11Window, title: []const u8) void {
        _ = x.xcb_change_property(w.xc.conn, x.XCB_PROP_MODE_REPLACE, w.win, x.XCB_ATOM_WM_NAME, x.XCB_ATOM_STRING, 8, @intCast(title.len), title.ptr);
    }

    pub fn setFullscreen(w: *X11Window, fullscreen: bool) void {
        const wm_state = w.xc.internAtomWmState();
        if (fullscreen) {
            const wm_fullscreen = w.xc.internAtomWmFullscreen();
            _ = x.xcb_change_property(w.xc.conn, x.XCB_PROP_MODE_REPLACE, w.win, wm_state, x.XCB_ATOM_ATOM, 32, 1, &wm_fullscreen);
        } else {
            _ = x.xcb_delete_property(w.xc.conn, w.win, wm_state);
        }
    }

    pub fn presentCanvas(w: *X11Window, width: u16, height: u16, data: []u8) void {
        const c = w.xc.conn;

        if (w.pixmap == 0 or w.pixmap_width != width or w.pixmap_height != height) {
            if (w.pixmap != 0) {
                _ = x.xcb_free_pixmap(c, w.pixmap);
            }
            if (w.pixmap == 0) {
                w.pixmap = x.xcb_generate_id(c);
            }
            _ = x.xcb_create_pixmap(c, w.xc.depth, w.pixmap, w.win, width, height);
            w.pixmap_width = width;
            w.pixmap_height = height;
        }

        var format = x.XCB_IMAGE_FORMAT_Z_PIXMAP;
        var image = x.xcb_image_create_native(c, width, height, @intCast(format), w.xc.depth, null, @intCast(data.len), data.ptr);
        _ = x.xcb_image_put(c, w.pixmap, w.gc, image, 0, 0, 0);
        _ = x.xcb_image_destroy(image);
        _ = x.xcb_copy_area(c, w.pixmap, w.win, w.gc, 0, 0, 0, 0, width, height);
        _ = x.xcb_flush(c);
    }

    pub fn deinit(w: *X11Window) void {
        _ = x.xcb_destroy_window(w.xc.conn, w.win);
    }
};

pub const XWindow = struct {
    win: u32,
    default_gc: u32,
    pixmap: u32,
    pixmap_width: u16,
    pixmap_height: u16,
    format: c_int,
    depth: u8,
    pix_data: []u8,
};
