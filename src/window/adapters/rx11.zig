// zig run rx11.zig
// attempt at communicating directly with x11 server

const std = @import("std");
const builtin = @import("builtin");

pub const Err = error{
    DisplayNotFound,
    DisplayParseError,
    ProtocolNotSupported,
    ProtocolWriteError,
    ProtocolReadError,
    ConnectionSetupFailed,
    ConnectionSetupNeedsAuthenticate,
    ConnectionSetupUnknownReply,
};

pub fn createWindow(conn: Connection) !void {
    try conn.write(CreateWindowRequest{});
}

pub fn mapWindow(conn: Connection) !void {
    try conn.write(MapWindowRequest{});
}

pub fn pollEvents(conn: Connection) !void {

    var r: Response = undefined;
    while (try conn.poll())
    {
        try conn.read(&r);
        if (r.opcode == 0) 
        {
            // is error
            const e: *Error = @ptrCast(&r);
            std.debug.print("{}\n", .{ e });
        }
        else if (r.opcode == 1)
        {
            // is reply
        }
        else {
            // is event

        }
    }
}

pub const Response = extern struct {
    opcode: u8,
    unknown_1: u8,
    sequence_number: u16,
    unknown_2: u32,
    unknown_3: [6]u32,
};

pub const Error = extern struct {
    opcode: u8 = 0,
    code: u8,
    sequence_number: u16,
    unknown: u32,
    minor_opcode: u16,
    major_opcode: u8,
    unused_1: u8,
    unused_2: [5]u32,
};

pub const Connection = struct {
    stream: std.net.Stream,

    pub fn init() !Connection {
        const server = try getDisplayServerInfo();
        const self = Connection{
            .stream = try createDisplayServerStream(server),
        };
        errdefer destroyDisplayServerStream(self.stream);
        try self.setupConnection();
        return self;
    }

    pub fn deinit(self: Connection) void {
        destroyDisplayServerStream(self.stream);
    }

    fn setupConnection(self: Connection) !void {
        try self.write(ConnectionSetupRequest.init());

        var status: ConnectionSetupReplyStatus = undefined;
        try self.read(&status);

        switch (status.code) {
            0 => return Err.ConnectionSetupFailed, // TODO get reason
            1 => {}, // success!
            2 => return Err.ConnectionSetupNeedsAuthenticate, // TODO what auth?
            else => return Err.ConnectionSetupUnknownReply,
        }

        // handle success
        var body: SuccessfulyConnectionSetupReplyBody = undefined;
        _ = try self.read(&body);

        // TODO for now we just ignore the rest of the reply
        var buf: [65536] u8 = undefined;
        const bytes_Read = try self.stream.read(buf[0..body.additional_data_length_4bytes*4]);
        if (bytes_Read != body.additional_data_length_4bytes*4) {
            // failed to skip connection setup reply
            return Err.ProtocolReadError;
        }
    }

    fn write(self: Connection, data: anytype) !void {
        var slice: []const u8 = undefined;
        slice.ptr = @ptrCast(&data);
        slice.len = @sizeOf(@TypeOf(data));
        const written = try self.stream.write(slice);
        if (slice.len != written) return Err.ProtocolWriteError;
    }

    fn poll(self: Connection) !bool {
        var nfo = [1]std.os.linux.pollfd { std.os.linux.pollfd{
            .fd = self.stream.handle,
            .events = 1, // POLLIN
            .revents = 0,
        } };
        return try std.os.poll(&nfo, 0) != 0;
    }

    fn read(self: Connection, buffer: anytype) !void {
        var slice: []u8 = undefined;
        slice.ptr = @ptrCast(buffer);
        slice.len = @sizeOf(@TypeOf(buffer.*));
        const bytes_read = try self.stream.read(slice);
        if (slice.len != bytes_read) return Err.ProtocolReadError;
    }

};

const ConnectionSetupReplyStatus = extern struct {
    /// 0 - failed, 1 - success, 2 - authenticate
    code: u8,
    // when status is 0, it contains the length of the reason, otherwise unused
    reason_len: u8, 
};

const SuccessfulyConnectionSetupReplyBody = extern struct {

    ///  2     CARD16 protocol-major-version
    protocol_major_version: u16,
    
    ///  2     CARD16 protocol-minor-version
    protocol_minor_version: u16,

    ///  2 8+2n+(v+p+m)/4  length in 4-byte units of "additional data"     
    additional_data_length_4bytes: u16,

    // ///  4     CARD32                          release-number
    // release_number: u32,

    // ///  4     CARD32                          resource-id-base
    // resource_id_base: u32,

    // ///  4     CARD32                          resource-id-mask
    // resource_id_mask: u32,

    // ///  4     CARD32                          motion-buffer-size
    // motion_buffer_size: u32,

    // ///  2     v                               length of vendor
    // vendor_length: u16,

    // ///  2     CARD16                          maximum-request-length
    // max_request_length: u16,

    // ///  1     CARD8                           number of SCREENs in roots
    // number_of_SCREENs_in_roots: u8,

    // ///  1     n                               number for FORMATs in
    // ///                                        pixmap-formats
    // number_of_FORMATs_in_pixmap_formats: u8,

    // ///  1                                     image-byte-order
    // ///       0     LSBFirst
    // ///       1     MSBFirst
    // image_byte_order: u8, // 0 - LSBFirst, 1 - MSB-First

    // ///  1                                     bitmap-format-bit-order
    // ///       0     LeastSignificant
    // ///       1     MostSignificant
    // bitmap_format_bit_order: u8, // 0 - LSBFirst, 1 - MSB-First

    // ///  1     CARD8                           bitmap-format-scanline-unit
    // bitmap_format_scanline_unit: u8,

    // ///  1     CARD8                           bitmap-format-scanline-pad
    // bitmap_format_scanline_pad: u8,

    // ///  1     KEYCODE                         min-keycode
    // min_keycode: u8,

    // ///  1     KEYCODE                         max-keycode
    // max_keycode: u8,

    // ///  4                                     unused
    // unused: u32,
};

/// https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html#Connection_Setup
const ConnectionSetupRequest = extern struct {
    byte_order: u8,
    _unused_1: u8 = undefined,
    protocol_major_version: u16 = 11,
    protocol_minor_version: u16 = 0,
    auth_protocol_name_len: u16 = 0,
    auth_protocol_data_len: u16 = 0,
    _unused_2: u16 = undefined,

    fn init() ConnectionSetupRequest {
        const endiannes = builtin.target.cpu.arch.endian();
        return ConnectionSetupRequest{ .byte_order = switch (endiannes) {
            .little => 0x6c,
            .big => 0x42,
        } };
    }
};

const CreateWindowRequest = extern struct {
    opcode: u8 = 1,
    depth: u8 = 32,
    /// 8 + n
    request_length: u16 = 8,
    wid: u32 = 4,
    parent: u32 = 0,
    x: i16 = 64,
    y: i16 = 64,
    width: u16 = 400,
    height: u16 = 300,
    border_width: u16 = 0,
///           0     CopyFromParent
///           1     InputOutput
///           2     InputOnly
    class: u16 = 0,
    /// 4     VISUALID                        visual
    ///      0     CopyFromParent
    visual: u32 = 0,
    ///  4     BITMASK                         value-mask (has n bits set to 1)
    ///       #x00000001     background-pixmap
    ///       #x00000002     background-pixel
    ///       #x00000004     border-pixmap
    ///       #x00000008     border-pixel
    ///       #x00000010     bit-gravity
    ///       #x00000020     win-gravity
    ///       #x00000040     backing-store
    ///       #x00000080     backing-planes
    ///       #x00000100     backing-pixel
    ///       #x00000200     override-redirect
    ///       #x00000400     save-under
    ///       #x00000800     event-mask
    ///       #x00001000     do-not-propagate-mask
    ///       #x00002000     colormap
    ///       #x00004000     cursor
    bitmask: u32 = 0,
    // TODO
    // 4n     LISTofVALUE                    value-list
};

const MapWindowRequest = extern struct {
    opcode: u8 = 8,
    unused: u8 = undefined,
    request_len: u16 = 2,
    window: u32 = 4,
};

fn createDisplayServerStream(server: Display) !std.net.Stream {
    if (isUnixProtocol(server)) {
        var buf: [200]u8 = undefined;
        const path = try std.fmt.bufPrint(&buf, "/tmp/.X11-unix/X{}", .{server.display});
        return try std.net.connectUnixSocket(path);
    } else {
        // TODO handle connect network tcp socket
        return Err.ProtocolNotSupported;
    }
}

// if we manually async
// fn connectUnixSocket(path: []const u8) !std.net.Stream {
//     const os = std.os;
//     const sockfd = try os.socket(
//         os.AF.UNIX,
//         os.SOCK.STREAM | os.SOCK.CLOEXEC | std.os.SOCK.NONBLOCK,
//         0,
//     );
//     errdefer os.closeSocket(sockfd);

//     var addr = try std.net.Address.initUnix(path);
//     try os.connect(sockfd, &addr.any, addr.getOsSockLen());

//     return std.net.Stream{
//         .handle = sockfd,
//     };
// }

fn destroyDisplayServerStream(stream: std.net.Stream) void {
    stream.close();
}

const Display = struct {
    host: []const u8 = "",
    protocol: []const u8 = "",
    display: u8 = 0,
    screen: u8 = 0,
};

fn getDisplayServerInfo() !Display {
    if (std.os.getenv("DISPLAY")) |display| {
        return parseDisplay(display);
    }
    return Err.DisplayNotFound;
}

fn parseDisplay(str: []const u8) !Display {
    var result = Display{};
    var cursor: usize = 0;
    var expect_display = false;
    var expect_screen = false;
    for (str, 0..) |chr, i| {
        if (chr == '/') {
            result.host = str[cursor..i];
            cursor = i + 1;
        } else if (chr == ':') {
            if (result.host.len > 0) {
                result.protocol = str[cursor..i];
            } else {
                result.host = str[cursor..i];
            }
            cursor = i + 1;
            expect_display = true;
        } else if (chr == '.') {
            result.display = std.fmt.parseInt(u8, str[cursor..i], 10) catch return Err.DisplayParseError;
            cursor = i + 1;
            expect_display = false;
            expect_screen = true;
        }
    }
    const last_value = std.fmt.parseInt(u8, str[cursor..str.len], 10) catch return Err.DisplayParseError;
    if (expect_screen) result.screen = last_value;
    if (expect_display) result.display = last_value;
    return result;
}

fn isUnixProtocol(server: Display) bool {
    const unix: []const u8 = "unix";
    return server.host.len == 0 or streql(server.protocol, unix);
}

fn streql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (0..a.len) |i| if (a[i] != b[i]) return false;
    return true;
}

test "parse display" {
    const parse = parseDisplay;
    const eq = std.testing.expectEqualDeep;
    try eq(Display{ .host = "localhost", .display = 12 }, try parse("localhost:12.0"));
    try eq(Display{ .host = "host", .protocol = "unix", .display = 1, .screen = 2 }, try parse("host/unix:1.2"));
    try eq(Display{ .display = 1 }, try parse(":1"));
    const ee = std.testing.expectError;
    try ee(Err.DisplayParseError, parse(":A.B"));
}

test "is unix protocol" {
    const isUnix = isUnixProtocol;
    const parse = parseDisplay;
    const expect = std.testing.expect;
    try expect(isUnix(try parse("host/unix:1.2")));
    try expect(!isUnix(try parse("localhost:12.0")));
    try expect(isUnix(try parse(":1")));
}

test "struct sizes are as expected" {
    // this is important as we are communicating over binary procotol
    // the struct size need to be perfectly aligned
    const expect = std.testing.expect;
    try expect(@sizeOf(Response) == 32);
    try expect(@sizeOf(Error) == 32);
    
}