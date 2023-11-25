const std = @import("std");
const common = @import("./common.zig");

pub const MSG = user32.MSG;
pub const user32 = win32.user32;
pub const gdi32 = win32.gdi32;

const EventData = common.EventData;
const Event = common.Event;
const Key = common.Key;

const win32 = std.os.windows;
const BOOL = win32.BOOL;
const DWORD = win32.DWORD;
const ATOM = u16;
const HINSTANCE = win32.HINSTANCE;
const HICON = win32.HICON;
const HCURSOR = win32.HCURSOR;
const HGDIOBJ = *opaque {};
// const HBITMAP = *opaque {}; use HGDIOBJ
const HDC = win32.HDC;
const HWND = win32.HWND;

const SM_CXSCREEN = 0;
const SM_CYSCREEN = 1;

// GDI constants
const SRCCOPY: DWORD = 0x00CC0020;

const IDI_APPLICATION = 32512;
const IDC_ARROW = 32512;

extern "user32" fn GetModuleHandleA(?[*]const u8) HINSTANCE;
extern "user32" fn LoadIconA(hInstance: ?HINSTANCE, lpIconName: u32) HICON;
extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: u32) HCURSOR;
extern "user32" fn GetSystemMetrics(nIndex: i32) i32;

extern "gdi32" fn CreateBitmap(width: i32, height: i32, nPlanes: u32, bitCount: u32, lpbits: *opaque{}) HGDIOBJ;
extern "gdi32" fn CreateCompatibleDC(hdc: HDC) HDC;
extern "gdi32" fn GetDC(hwnd: HWND) HDC;
extern "gdi32" fn SelectObject(hdc: HDC, hdobj: HGDIOBJ) HGDIOBJ;
extern "gdi32" fn BitBlt(hdc: HDC, x: i32, y: i32, cx: i32, cy: i32, hdcSrc: HDC, x1: i32, y1: i32, rop: DWORD) BOOL;
extern "gdi32" fn DeleteDC(hdc: HDC) BOOL;
extern "gdi32" fn DeleteObject(hgdiobj: HGDIOBJ) BOOL;

const static_class_name = "StaticWindowClass";
var static_class_atom: win32.ATOM = 0;
var static_event_queue: [256]EventData = undefined;
var static_event_queue_head: u8 = 0;
var static_event_queue_tail: u8 = 0;

const WindowInitOptions = common.WindowCreateOptions;

pub const Window = struct {

    hwnd: HWND,
    window_dc: ?HDC = null,
    bitmap_dc: ?HDC = null,
    bitmap: ?HGDIOBJ = null,
    prev_width: u16 = undefined,
    prev_height: u16 = undefined,
    prev_data: []u32 = undefined,

    pub fn init(options: WindowInitOptions) Window 
    {
        const hInstance: win32.HINSTANCE = GetModuleHandleA(null);

        ensureStaticClassRegistered(hInstance);
        const className = static_class_name;

        var titleBuffer: [1024]u8 = undefined; 
        // TODO maybe unicode support
        @memcpy(titleBuffer[0..options.title.len], options.title);
        titleBuffer[options.title.len] = 0;

        var style: DWORD = user32.WS_OVERLAPPEDWINDOW;
        var width: i32 = @intCast(options.width);
        var height: i32 = @intCast(options.height);


        if (options.fullscreen) {
            style = user32.WS_POPUP | user32.WS_VISIBLE;
            width = GetSystemMetrics(SM_CXSCREEN);
            height = GetSystemMetrics(SM_CXSCREEN);
        }

        if (user32.CreateWindowExA(
            0,                    // Optional window styles.
            className,            // Window class
            @ptrCast(&titleBuffer), // Window text
            style,  // Window style

            // Size and position
            user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, width, height,

            null,      // Parent window
            null,      // Menu
            hInstance, // Instance handle
            null       // Additional application data
        )) |hwnd| {

            _ = user32.ShowWindow(hwnd, user32.SW_SHOW);
            return Window { 
                .hwnd = hwnd
            };
        }
        else unreachable;
        


    }

    pub fn presentCanvasU32BGRA(w: *Window, width: u16, height: u16, data: []u32) void {

        if (w.window_dc == null) {
            w.window_dc = GetDC(w.hwnd);
        }

        if (w.bitmap_dc == null) {
            w.bitmap_dc = CreateCompatibleDC(w.window_dc.?);
        }

        if (w.bitmap == null or width != w.prev_height or height != w.prev_height or w.prev_data.ptr != data.ptr)
        {
            // need to create new bitmap (first call or resize)
            const new_bitmap = CreateBitmap(
                width,
                height, 
                1, // don't know what is it actually... let it be 1
                32, // bpp
                @ptrCast(data)
            ); 
            
            _ = SelectObject(w.bitmap_dc.?, @ptrCast(new_bitmap));

            if (w.bitmap) |bitmap| {
                _ = DeleteObject(bitmap); // delete previous bitmap 
            }

            w.bitmap = new_bitmap;
            w.prev_width = width;
            w.prev_height = height;
            w.prev_data = data;
        }
        
        _ = BitBlt(w.window_dc.?, 0, 0, width, height, w.bitmap_dc.?, 0, 0, SRCCOPY);

    }

    pub fn deinit(self: Window) void {
        // TODO

        if (self.window_dc) |dc| {
            _ = DeleteDC(dc);
        }
        if (self.bitmap_dc) |dc| {
            _ = DeleteDC(dc);
        }
        if (self.bitmap) |hgdiobj| {
            _ = DeleteObject(hgdiobj);
        }
        _ = user32.DestroyWindow(self.hwnd);
    }
    
};


fn ensureStaticClassRegistered(hInstance: win32.HINSTANCE) void {
    if (static_class_atom != 0) {
        return;
    }
    static_class_atom = registerWindowClass(
        hInstance, static_class_name, staticWindowProc
    );
    if (static_class_atom == 0){
        unreachable; // failed to register
    }
}

fn registerWindowClass(hInstance: win32.HINSTANCE, className: [*:0]const u8, windowProc: user32.WNDPROC) ATOM
{
    var wc = user32.WNDCLASSEXA
    {
        .style = user32.CS_HREDRAW | user32.CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .hInstance = hInstance,
        .lpszClassName = className,
        .hIcon = LoadIconA(null, IDI_APPLICATION),
        .hCursor = LoadCursorA(null, IDC_ARROW),
        .hIconSm = null,
        .hbrBackground = null,
        .lpszMenuName = null
    };

    const atom = user32.RegisterClassExA(&wc);
    return atom;
}

pub fn processMessagesUntilQuit() void
{
    var msg: user32.MSG = undefined;
    while (user32.GetMessageA(&msg, null, 0, 0) > 0)
    {
        _ = user32.TranslateMessage(&msg);
        _ = user32.DispatchMessageA(&msg);
    }
}

/// get next event from caller thread's message queue 
/// expected to be called from the main 'GUI' thread
pub fn nextEvent(options: common.NextEventOptions) ?EventData {
    if (getEventFromStaticQueue()) |event| {
        return event;
    }
    var hadRawMessage = false;
    if (options.blocking) {
        hadRawMessage = getRawMessage();
    }
    else {
        hadRawMessage = peekRawMessage();
    }
    if (getEventFromStaticQueue()) |event| {
        return event;
    }
    else if (hadRawMessage) {
        return EventData { .unknown = undefined };
    }
    else 
    {
        return null;
    }
}

inline fn getEventFromStaticQueue() ?EventData {
    if (static_event_queue_head != static_event_queue_tail) {
        const result = static_event_queue[static_event_queue_head];
        static_event_queue_head = static_event_queue_head +% 1;
        return result;
    }
    else {
        return null;
    }
}

/// get next message from thread's message queue
pub fn getRawMessage() bool
{
    var msg: user32.MSG = undefined;
    if (user32.GetMessageA(&msg, null, 0, 0) > 0)
    {
        handleMessage(&msg);
        return true;
    }
    else 
    {
        return false;
    }
}

/// peek next message from thread's message queue
pub fn peekRawMessage() bool 
{
    var msg: user32.MSG = undefined;
    if (user32.PeekMessageA(&msg, null, 0, 0, user32.PM_REMOVE) > 0)
    {
        handleMessage(&msg);
        return true;
    }
    else 
    {
        return false;
    }
}

fn handleMessage(msg: *user32.MSG) void {
    _ = user32.TranslateMessage(msg);
    _ = user32.DispatchMessageA(msg);
}

fn staticWindowProc(hwnd: win32.HWND, uMsg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(win32.WINAPI) win32.LRESULT
{
    var event: EventData = switch (uMsg)
    {
        user32.WM_KEYDOWN => EventData { .keydown = Key.escape }, // TODO extend
        user32.WM_PAINT => EventData { .paint = undefined },
        user32.WM_CLOSE => EventData { .closewindow = undefined },
        user32.WM_MOUSEMOVE => EventData { 
            .pointermove = common.Position {
                .x = @intCast(lParam & 0xffff), 
                .y = @intCast((lParam >> 16) & 0xffff), 
            } 
        },
        user32.WM_SIZE => EventData { 
            .resize = common.Size { 
                .width = @intCast(lParam & 0xffff), 
                .height = @intCast((lParam >> 16) & 0xffff), 
            } 
        },
        user32.WM_LBUTTONDOWN => EventData { .unknown = undefined },
        else => EventData { .unknown = undefined },
    };
    static_event_queue[static_event_queue_tail] = event;
    static_event_queue_tail = static_event_queue_tail +% 1;
    return user32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}
