const std = @import("std");

const win32 = std.os.windows;
pub const user32 = win32.user32;
const ATOM = u16;
const HINSTANCE = win32.HINSTANCE;
const HICON = win32.HICON;
const HCURSOR = win32.HCURSOR;

const IDI_APPLICATION = 32512;
const IDC_ARROW = 32512;

extern "user32" fn GetModuleHandleA(?[*]const u8) HINSTANCE;
extern "user32" fn LoadIconA(hInstance: ?HINSTANCE, lpIconName: u32) HICON;
extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: u32) HCURSOR;

const staticClassName = "StaticWindowClass";
var staticClassAtom: win32.ATOM = 0;

const WindowInitOptions = struct {
    title: []const u8 = "Window"

};

pub const Window = struct {

    hwnd: win32.HWND,

    pub fn init(options: WindowInitOptions) Window 
    {
        const hInstance: win32.HINSTANCE = GetModuleHandleA(null);

        ensureStaticClassRegistered(hInstance);
        const className = staticClassName;

        var titleBuffer: [1024]u8 = undefined; 
        // TODO maybe unicode support
        @memcpy(titleBuffer[0..options.title.len], options.title);
        titleBuffer[options.title.len] = 0;

        if (user32.CreateWindowExA(
            0,                    // Optional window styles.
            className,            // Window class
            @ptrCast(&titleBuffer), // Window text
            user32.WS_OVERLAPPEDWINDOW,  // Window style

            // Size and position
            user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, 600, 400,

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

    pub fn deinit(self: Window) void {
        // TODO
        _ = self;
    }
    
};


fn ensureStaticClassRegistered(hInstance: win32.HINSTANCE) void {
    if (staticClassAtom != 0) {
        return;
    }
    staticClassAtom = registerWindowClass(
        hInstance, staticClassName, user32.DefWindowProcA
    );
    if (staticClassAtom == 0){
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

// fn staticWindowProc(hwnd: win32.HWND, uMsg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(win32.WINAPI) win32.LRESULT
// {
//     switch (uMsg)
//     {
//         user32.WM_PAINT => {

//         },
//         user32.WM_DESTROY => {
//             user32.PostQuitMessage(0);
//         },
//         user32.WM_MOUSEMOVE => {

//         },
//         user32.WM_SIZE => {

//         },
//         user32.WM_LBUTTONDOWN => {

//         },
//         else => {}
//     }
//     return user32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
// }

pub fn processMessagesUntilQuit() void
{
    var msg: user32.MSG = undefined;
    while (user32.GetMessageA(&msg, null, 0, 0) > 0)
    {
        _ = user32.TranslateMessage(&msg);
        _ = user32.DispatchMessageA(&msg);
    }
}

pub fn getMessage() ?user32.MSG
{
    var msg: user32.MSG = undefined;
    if (user32.GetMessageA(&msg, null, 0, 0) > 0)
    {
        _ = user32.TranslateMessage(&msg);
        _ = user32.DispatchMessageA(&msg);
        return msg;
    }
    else 
    {
        return null;
    }
}

pub fn peekMessage() ?user32.MSG {
    var msg: user32.MSG = undefined;
    if (user32.PeekMessageA(&msg, null, 0, 0, user32.PM_REMOVE) > 0)
    {
        _ = user32.TranslateMessage(&msg);
        _ = user32.DispatchMessageA(&msg);
        return msg;
    }
    else 
    {
        return null;
    }
}

pub const MSG = user32.MSG;