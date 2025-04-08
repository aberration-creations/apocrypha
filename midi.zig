const std = @import("std");
const as = @cImport(
    @cInclude("alsa/asoundlib.h") // -lasound
);
const xc = @cImport({
    @cInclude("xcb/xcb.h"); // -lc -lxcb -lxcb-image (sudo apt install libxcb1-dev)
    @cInclude("xcb/xtest.h"); // -lxcb-xtest (sudo apt install libxcb-xtest0-dev)
});

var seq_handle: ?*as.snd_seq_t = null;
var in_port: c_int = 0;
var conn: ?*xc.xcb_connection_t = null;

pub fn main() void {
    try openMidi();
    conn = xc.xcb_connect(null, null);
    while (true) {
        if (readMidi()) |ev| {
            processMidiEvent(ev.*);
        }
    }
}

fn openMidi() !void {
    _ = as.snd_seq_open(&seq_handle, "default", as.SND_SEQ_OPEN_INPUT, 0);

    _ = as.snd_seq_set_client_name(seq_handle, "Midi Listener");

    in_port = as.snd_seq_create_simple_port(seq_handle, "listen:in",
        as.SND_SEQ_PORT_CAP_WRITE|as.SND_SEQ_PORT_CAP_SUBS_WRITE,
        as.SND_SEQ_PORT_TYPE_APPLICATION);
}

fn readMidi() ?*as.snd_seq_event_t {
    var ev: ?*as.snd_seq_event_t = null;
    _ = as.snd_seq_event_input(seq_handle, &ev);
    return ev;
}

fn processMidiEvent(ev: as.snd_seq_event_t) void {
    switch (ev.type) {
        as.SND_SEQ_EVENT_NOTEON => {
            const note = ev.data.note.note;
            const velocity = ev.data.note.velocity;
            std.debug.print("note on {} {}\n", .{ note, velocity });
            if (mapNoteToKey(note)) |key_code| {
                pressKey(key_code);
            }
        },
        as.SND_SEQ_EVENT_NOTEOFF => {
            const note = ev.data.note.note;
            const velocity = ev.data.note.velocity;
            std.debug.print("note off {} {}\n", .{ note, velocity });
            if (mapNoteToKey(note)) |key_code| {
                releaseKey(key_code);
            }
        },
        as.SND_SEQ_EVENT_CONTROLLER => {
            const param = ev.data.control.param;
            const value = ev.data.control.value;
            std.debug.print("control change {} {}\n", .{ param, value });

        },
        else => {
            std.debug.print("unknown command\n", .{});
        },
    }
}

fn pressKey(code: u8) void {
    _ = xc.xcb_test_fake_input(conn, xc.XCB_KEY_PRESS, code, xc.XCB_CURRENT_TIME, xc.XCB_NONE, 0, 0, 0);
    _ = xc.xcb_flush(conn);
}

fn releaseKey(code: u8) void {
    _ = xc.xcb_test_fake_input(conn, xc.XCB_KEY_RELEASE, code, xc.XCB_CURRENT_TIME, xc.XCB_NONE, 0, 0, 0);
    _ = xc.xcb_flush(conn);
}

fn mapNoteToKey(note: u8) ?u8 {
    if (note < 48) {
        return null;
    }
    const i = note - 48;
    if (i >= keymap.len) {
        return null;
    }
    return keymap[i];
}

const keymap: [36 + 1]u8 = .{
    // 1st octave
    kb_z, kb_s, kb_x, kb_d, kb_c, 
    kb_v, kb_g, kb_b, kb_h, kb_n, kb_j, kb_m, 
    // 2nd octave
    kb_comma, kb_l, kb_dot, kb_semicolon, kb_slash, 
    kb_q, kb_2, kb_w, kb_3, kb_e, kb_4, kb_r, 
    // 3rd octave
    kb_t, kb_6, kb_y, kb_7, kb_u, 
    kb_i, kb_9, kb_o, kb_0, kb_p, kb_minus, kb_bracket_open, 
    // 4th octave 
    kb_bracket_close, // c only
};


// 1st row
const kb_1 = 10;
const kb_2 = 11;
const kb_3 = 12;
const kb_4 = 13;
const kb_5 = 14;
const kb_6 = 15;
const kb_7 = 16;
const kb_8 = 17;
const kb_9 = 18;
const kb_0 = 19;
const kb_minus = 20;
const kb_equals = 21;
const kb_backspace = 22;

// 2nd row
const kb_q = 24;
const kb_w = 25;
const kb_e = 26;
const kb_r = 27;
const kb_t = 28;
const kb_y = 29;
const kb_u = 30;
const kb_i = 31;
const kb_o = 32;
const kb_p = 33;
const kb_bracket_open = 34;
const kb_bracket_close = 35;
const kb_backslash = 51;

// 3rd row
const kb_a = 38;
const kb_s = 39;
const kb_d = 40;
const kb_f = 41;
const kb_g = 42;
const kb_h = 43;
const kb_j = 44;
const kb_k = 45;
const kb_l = 46;
const kb_semicolon = 47;
const kb_apos = 48;

// 4th row
const kb_z = 52;
const kb_x = 53;
const kb_c = 54;
const kb_v = 55;
const kb_b = 56;
const kb_n = 57;
const kb_m = 58;
const kb_comma = 59;
const kb_dot = 60;
const kb_slash = 61;
