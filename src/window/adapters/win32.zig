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

extern "gdi32" fn CreateBitmap(width: i32, height: i32, nPlanes: u32, bitCount: u32, lpbits: *opaque {}) HGDIOBJ;
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

    pub fn init(options: WindowInitOptions) Window {
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
            style = user32.WS_POPUP;
            width = GetSystemMetrics(SM_CXSCREEN);
            height = GetSystemMetrics(SM_CYSCREEN);
        }

        if (user32.CreateWindowExA(0, // Optional window styles.
            className, // Window class
            @ptrCast(&titleBuffer), // Window text
            style, // Window style

        // Size and position
            user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, width, height, null, // Parent window
            null, // Menu
            hInstance, // Instance handle
            null // Additional application data
        )) |hwnd| {
            _ = user32.ShowWindow(hwnd, user32.SW_SHOW);
            return Window{ .hwnd = hwnd };
        } else unreachable;
    }

    pub fn presentCanvasU32BGRA(w: *Window, width: u16, height: u16, data: []u32) void {
        if (w.window_dc == null) {
            w.window_dc = GetDC(w.hwnd);
        }

        if (w.bitmap_dc == null) {
            w.bitmap_dc = CreateCompatibleDC(w.window_dc.?);
        }

        if (w.bitmap == null or width != w.prev_height or height != w.prev_height or w.prev_data.ptr != data.ptr) {
            // need to create new bitmap (first call or resize)
            const new_bitmap = CreateBitmap(width, height, 1, // don't know what is it actually... let it be 1
                32, // bpp
                @ptrCast(data));

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
    static_class_atom = registerWindowClass(hInstance, static_class_name, staticWindowProc);
    if (static_class_atom == 0) {
        unreachable; // failed to register
    }
}

fn registerWindowClass(hInstance: win32.HINSTANCE, className: [*:0]const u8, windowProc: user32.WNDPROC) ATOM {
    var wc = user32.WNDCLASSEXA{ .style = user32.CS_HREDRAW | user32.CS_VREDRAW, .lpfnWndProc = windowProc, .hInstance = hInstance, .lpszClassName = className, .hIcon = LoadIconA(null, IDI_APPLICATION), .hCursor = LoadCursorA(null, IDC_ARROW), .hIconSm = null, .hbrBackground = null, .lpszMenuName = null };

    const atom = user32.RegisterClassExA(&wc);
    return atom;
}

pub fn processMessagesUntilQuit() void {
    var msg: user32.MSG = undefined;
    while (user32.GetMessageA(&msg, null, 0, 0) > 0) {
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
    } else {
        hadRawMessage = peekRawMessage();
    }
    if (getEventFromStaticQueue()) |event| {
        return event;
    } else if (hadRawMessage) {
        return EventData{ .unknown = undefined };
    } else {
        return null;
    }
}

inline fn getEventFromStaticQueue() ?EventData {
    if (static_event_queue_head != static_event_queue_tail) {
        const result = static_event_queue[static_event_queue_head];
        static_event_queue_head = static_event_queue_head +% 1;
        return result;
    } else {
        return null;
    }
}

/// get next message from thread's message queue
pub fn getRawMessage() bool {
    var msg: user32.MSG = undefined;
    if (user32.GetMessageA(&msg, null, 0, 0) > 0) {
        handleMessage(&msg);
        return true;
    } else {
        return false;
    }
}

/// peek next message from thread's message queue
pub fn peekRawMessage() bool {
    var msg: user32.MSG = undefined;
    if (user32.PeekMessageA(&msg, null, 0, 0, user32.PM_REMOVE) > 0) {
        handleMessage(&msg);
        return true;
    } else {
        return false;
    }
}

fn handleMessage(msg: *user32.MSG) void {
    _ = user32.TranslateMessage(msg);
    _ = user32.DispatchMessageA(msg);
}

fn staticWindowProc(hwnd: win32.HWND, uMsg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(win32.WINAPI) win32.LRESULT {
    const event: EventData = switch (uMsg) {
        user32.WM_KEYDOWN => EventData{ .keydown = switch (wParam) {
            VK_LEFT => .left,
            VK_RIGHT => .right,
            VK_UP => .up,
            VK_DOWN => .down,
            VK_ESCAPE => .escape,
            else => .unknown,
        } }, // TODO extend
        user32.WM_PAINT => EventData{ .paint = undefined },
        user32.WM_CLOSE => EventData{ .closewindow = undefined },
        user32.WM_MOUSEMOVE => EventData{ .pointermove = common.Position{
            .x = @intCast(lParam & 0xffff),
            .y = @intCast((lParam >> 16) & 0xffff),
        } },
        user32.WM_SIZE => EventData{ .resize = common.Size{
            .width = @intCast(lParam & 0xffff),
            .height = @intCast((lParam >> 16) & 0xffff),
        } },
        user32.WM_LBUTTONDOWN => EventData{ .unknown = undefined },
        else => EventData{ .unknown = undefined },
    };
    static_event_queue[static_event_queue_tail] = event;
    static_event_queue_tail = static_event_queue_tail +% 1;
    return user32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}

const VK_LBUTTON = 0x01; // 	Left mouse button
const VK_RBUTTON = 0x02; // 	Right mouse button
const VK_CANCEL = 0x03; // 	Control-break processing
const VK_MBUTTON = 0x04; // 	Middle mouse button
const VK_XBUTTON1 = 0x05; // 	X1 mouse button
const VK_XBUTTON2 = 0x06; // 	X2 mouse button
const VK_BACK = 0x08; // 	BACKSPACE key
const VK_TAB = 0x09; // 	TAB key
const VK_CLEAR = 0x0C; // 	CLEAR key
const VK_RETURN = 0x0D; // 	ENTER key
const VK_SHIFT = 0x10; // 	SHIFT key
const VK_CONTROL = 0x11; // 	CTRL key
const VK_MENU = 0x12; // 	ALT key
const VK_PAUSE = 0x13; // 	PAUSE key
const VK_CAPITAL = 0x14; // 	CAPS LOCK key
const VK_KANA = 0x15; // 	IME Kana mode
const VK_HANGUL = 0x15; // 	IME Hangul mode
const VK_IME_ON = 0x16; // 	IME On
const VK_JUNJA = 0x17; // 	IME Junja mode
const VK_FINAL = 0x18; // 	IME final mode
const VK_HANJA = 0x19; // 	IME Hanja mode
const VK_KANJI = 0x19; // 	IME Kanji mode
const VK_IME_OFF = 0x1A; // 	IME Off
const VK_ESCAPE = 0x1B; // 	ESC key
const VK_CONVERT = 0x1C; // 	IME convert
const VK_NONCONVERT = 0x1D; // 	IME nonconvert
const VK_ACCEPT = 0x1E; // 	IME accept
const VK_MODECHANGE = 0x1F; // 	IME mode change request
const VK_SPACE = 0x20; // 	SPACEBAR
const VK_PRIOR = 0x21; // 	PAGE UP key
const VK_NEXT = 0x22; // 	PAGE DOWN key
const VK_END = 0x23; // 	END key
const VK_HOME = 0x24; // 	HOME key
const VK_LEFT = 0x25; // 	LEFT ARROW key
const VK_UP = 0x26; // 	UP ARROW key
const VK_RIGHT = 0x27; // 	RIGHT ARROW key
const VK_DOWN = 0x28; // 	DOWN ARROW key
const VK_SELECT = 0x29; // 	SELECT key
const VK_PRINT = 0x2A; // 	PRINT key
const VK_EXECUTE = 0x2B; // 	EXECUTE key
const VK_SNAPSHOT = 0x2C; // 	PRINT SCREEN key
const VK_INSERT = 0x2D; // 	INS key
const VK_DELETE = 0x2E; // 	DEL key
const VK_HELP = 0x2F; // 	HELP key
const VK_KEY_0 = 0x30; // 	0 key
const VK_KEY_1 = 0x31; // 	1 key
const VK_KEY_2 = 0x32; // 	2 key
const VK_KEY_3 = 0x33; // 	3 key
const VK_KEY_4 = 0x34; // 	4 key
const VK_KEY_5 = 0x35; // 	5 key
const VK_KEY_6 = 0x36; // 	6 key
const VK_KEY_7 = 0x37; // 	7 key
const VK_KEY_8 = 0x38; // 	8 key
const VK_KEY_9 = 0x39; // 	9 key
const VK_KEY_A = 0x41; // 	A key
const VK_KEY_B = 0x42; // 	B key
const VK_KEY_C = 0x43; // 	C key
const VK_KEY_D = 0x44; // 	D key
const VK_KEY_E = 0x45; // 	E key
const VK_KEY_F = 0x46; // 	F key
const VK_KEY_G = 0x47; // 	G key
const VK_KEY_H = 0x48; // 	H key
const VK_KEY_I = 0x49; // 	I key
const VK_KEY_J = 0x4A; // 	J key
const VK_KEY_K = 0x4B; // 	K key
const VK_KEY_L = 0x4C; // 	L key
const VK_KEY_M = 0x4D; // 	M key
const VK_KEY_N = 0x4E; // 	N key
const VK_KEY_O = 0x4F; // 	O key
const VK_KEY_P = 0x50; // 	P key
const VK_KEY_Q = 0x51; // 	Q key
const VK_KEY_R = 0x52; // 	R key
const VK_KEY_S = 0x53; // 	S key
const VK_KEY_T = 0x54; // 	T key
const VK_KEY_U = 0x55; // 	U key
const VK_KEY_V = 0x56; // 	V key
const VK_KEY_W = 0x57; // 	W key
const VK_KEY_X = 0x58; // 	X key
const VK_KEY_Y = 0x59; // 	Y key
const VK_KEY_Z = 0x5A; // 	Z key
const VK_LWIN = 0x5B; // 	Left Windows key
const VK_RWIN = 0x5C; // 	Right Windows key
const VK_APPS = 0x5D; // 	Applications key
const VK_SLEEP = 0x5F; // 	Computer Sleep key
const VK_NUMPAD0 = 0x60; // 	Numeric keypad 0 key
const VK_NUMPAD1 = 0x61; // 	Numeric keypad 1 key
const VK_NUMPAD2 = 0x62; // 	Numeric keypad 2 key
const VK_NUMPAD3 = 0x63; // 	Numeric keypad 3 key
const VK_NUMPAD4 = 0x64; // 	Numeric keypad 4 key
const VK_NUMPAD5 = 0x65; // 	Numeric keypad 5 key
const VK_NUMPAD6 = 0x66; // 	Numeric keypad 6 key
const VK_NUMPAD7 = 0x67; // 	Numeric keypad 7 key
const VK_NUMPAD8 = 0x68; // 	Numeric keypad 8 key
const VK_NUMPAD9 = 0x69; // 	Numeric keypad 9 key
const VK_MULTIPLY = 0x6A; // 	Multiply key
const VK_ADD = 0x6B; // 	Add key
const VK_SEPARATOR = 0x6C; // 	Separator key
const VK_SUBTRACT = 0x6D; // 	Subtract key
const VK_DECIMAL = 0x6E; // 	Decimal key
const VK_DIVIDE = 0x6F; // 	Divide key
const VK_F1 = 0x70; // 	F1 key
const VK_F2 = 0x71; // 	F2 key
const VK_F3 = 0x72; // 	F3 key
const VK_F4 = 0x73; // 	F4 key
const VK_F5 = 0x74; // 	F5 key
const VK_F6 = 0x75; // 	F6 key
const VK_F7 = 0x76; // 	F7 key
const VK_F8 = 0x77; // 	F8 key
const VK_F9 = 0x78; // 	F9 key
const VK_F10 = 0x79; // 	F10 key
const VK_F11 = 0x7A; // 	F11 key
const VK_F12 = 0x7B; // 	F12 key
const VK_F13 = 0x7C; // 	F13 key
const VK_F14 = 0x7D; // 	F14 key
const VK_F15 = 0x7E; // 	F15 key
const VK_F16 = 0x7F; // 	F16 key
const VK_F17 = 0x80; // 	F17 key
const VK_F18 = 0x81; // 	F18 key
const VK_F19 = 0x82; // 	F19 key
const VK_F20 = 0x83; // 	F20 key
const VK_F21 = 0x84; // 	F21 key
const VK_F22 = 0x85; // 	F22 key
const VK_F23 = 0x86; // 	F23 key
const VK_F24 = 0x87; // 	F24 key
const VK_NUMLOCK = 0x90; // 	NUM LOCK key
const VK_SCROLL = 0x91; // 	SCROLL LOCK key
const VK_LSHIFT = 0xA0; // 	Left SHIFT key
const VK_RSHIFT = 0xA1; // 	Right SHIFT key
const VK_LCONTROL = 0xA2; // 	Left CONTROL key
const VK_RCONTROL = 0xA3; // 	Right CONTROL key
const VK_LMENU = 0xA4; // 	Left ALT key
const VK_RMENU = 0xA5; // 	Right ALT key
const VK_BROWSER_BACK = 0xA6; // 	Browser Back key
const VK_BROWSER_FORWARD = 0xA7; // 	Browser Forward key
const VK_BROWSER_REFRESH = 0xA8; // 	Browser Refresh key
const VK_BROWSER_STOP = 0xA9; // 	Browser Stop key
const VK_BROWSER_SEARCH = 0xAA; // 	Browser Search key
const VK_BROWSER_FAVORITES = 0xAB; // 	Browser Favorites key
const VK_BROWSER_HOME = 0xAC; // 	Browser Start and Home key
const VK_VOLUME_MUTE = 0xAD; // 	Volume Mute key
const VK_VOLUME_DOWN = 0xAE; // 	Volume Down key
const VK_VOLUME_UP = 0xAF; // 	Volume Up key
const VK_MEDIA_NEXT_TRACK = 0xB0; // 	Next Track key
const VK_MEDIA_PREV_TRACK = 0xB1; // 	Previous Track key
const VK_MEDIA_STOP = 0xB2; // 	Stop Media key
const VK_MEDIA_PLAY_PAUSE = 0xB3; // 	Play/Pause Media key
const VK_LAUNCH_MAIL = 0xB4; // 	Start Mail key
const VK_LAUNCH_MEDIA_SELECT = 0xB5; // 	Select Media key
const VK_LAUNCH_APP1 = 0xB6; // 	Start Application 1 key
const VK_LAUNCH_APP2 = 0xB7; // 	Start Application 2 key
const VK_OEM_1 = 0xBA; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ;: key
const VK_OEM_PLUS = 0xBB; // 	For any country/region, the + key
const VK_OEM_COMMA = 0xBC; // 	For any country/region, the , key
const VK_OEM_MINUS = 0xBD; // 	For any country/region, the - key
const VK_OEM_PERIOD = 0xBE; // 	For any country/region, the . key
const VK_OEM_2 = 0xBF; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the /? key
const VK_OEM_3 = 0xC0; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the `~ key
const VK_OEM_4 = 0xDB; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the [{ key
const VK_OEM_5 = 0xDC; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the \\| key
const VK_OEM_6 = 0xDD; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ]} key
const VK_OEM_7 = 0xDE; // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '" key
const VK_OEM_8 = 0xDF; // 	Used for miscellaneous characters; it can vary by keyboard.
const VK_OEM_102 = 0xE2; // 	The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard
const VK_PROCESSKEY = 0xE5; // 	IME PROCESS key
const VK_PACKET = 0xE7; // 	Used to pass Unicode characters as if they were keystrokes. The VK_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
const VK_ATTN = 0xF6; // 	Attn key
const VK_CRSEL = 0xF7; // 	CrSel key
const VK_EXSEL = 0xF8; // 	ExSel key
const VK_EREOF = 0xF9; // 	Erase EOF key
const VK_PLAY = 0xFA; // 	Play key
const VK_ZOOM = 0xFB; // 	Zoom key
const VK_NONAME = 0xFC; // 	Reserved
const VK_PA1 = 0xFD; // 	PA1 key
const VK_OEM_CLEAR = 0xFE; // 	Clear key
