// communitcation protocol with x11 display server
// doc: https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html

const std = @import("std");
const builtin = @import("builtin");

pub const Err = error{
    DisplayNotFound,
    DisplayParseError,
    ProtocolNotSupported,
    ProtocolWriteError,
    ProtocolReadError,
    ProtocolClosed,
    ConnectionSetupFailed,
    ConnectionSetupNeedsAuthenticate,
    ConnectionSetupUnknownReply,
};

const defaultEventMask = EventMask.ButtonPress | EventMask.Exposure 
        | EventMask.ButtonRelease | EventMask.PointerMotion | EventMask.EnterWindow | EventMask.LeaveWindow
        | EventMask.KeyPress | EventMask.KeyRelease | EventMask.StructureNotify;

pub fn createWindow(conn: Connection, window_id: u32) !void {
    const n = 2;
    try createWindowRaw(conn, .{
        .wid = window_id,
        .parent = conn.first_screen_id,
        .request_length = @sizeOf(CreateWindowRequest) / 4 + n,
        .bitmask = WindowBitmask.event_mask | WindowBitmask.colormap,
    }, &([n]u32{
        defaultEventMask,
        conn.first_screen.default_colormap
    }));
}

pub fn createWindowWithSize(conn: Connection, window_id: u32, x: i16, y: i16, width: u16, height: u16) !void {
    const n = 2;
    try createWindowRaw(conn, .{
        .wid = window_id,
        .parent = conn.first_screen_id,
        .request_length = @sizeOf(CreateWindowRequest) / 4 + n,
        .bitmask = WindowBitmask.event_mask | WindowBitmask.colormap,
        .width = width,
        .height = height,
        .x = x,
        .y = y,
    }, &([n]u32{
        defaultEventMask,
        conn.first_screen.default_colormap
    }));
}

pub fn createWindowRaw(conn: Connection, request: CreateWindowRequest, optionals: []const u32) !void {
    try conn.writeStruct(request);
    try conn.writeU32(optionals);
}

pub fn mapWindow(conn: Connection, window_id: u32) !void {
    try conn.writeStruct(MapWindowRequest{ .window = window_id });
}

pub fn unmapWindow(conn: Connection, window_id: u32) !void {
    try conn.writeStruct(UnmapWindowRequest{ .window = window_id });
}

pub fn destroyWindow(conn: Connection, window_id: u32) !void {
    try conn.writeStruct(DestroyWindowRequest{ .window = window_id });
}

pub fn setName(conn: Connection, window_id: u32, title: []const u8) !void {
    const n = title.len;
    const p = pad4of(n);
    const request_len = 6 + (n + p) / 4;
    const pad_bytes: [4]u8 = undefined;
    try conn.writeStruct(ChangePropertyRequest{
        .window = window_id,
        .request_len = @intCast(request_len),
        .property = PredefinedAtoms.WM_NAME,
        .property_type = PredefinedAtoms.STRING,
        .format = 8,
        .data_len = @intCast(title.len),
    });
    try conn.writeBytes(title);
    try conn.writeBytes(pad_bytes[0..p]);
}

/// Reads the next input from window system into the buffer which can be one of the following:
/// - an reply to a request, use `isReply()` function on the buffer to read it
/// - a request error, use `isError()` on the buffer to read it
/// - an input event (keyboard/mouse) use `isEvent()` to read it
///
/// The following errors are possible:
///
/// - you may get stream/protocol error in which case the connection should be closed
/// and you should save data and exit gracefully
/// - you may get a buffer too small error: you can choose to ignore this
/// error or to save data and exit gracefully
pub fn readInput(conn: Connection, buffer: []align(4) u8) !*Response {
    const r: *Response = @alignCast(@ptrCast(buffer));
    try conn.read(r);
    if (r.code == 0) {
        // is error
        const e: *Error = @ptrCast(r);
        std.debug.print("error {}\n", .{e});
        return r;
    } else if (r.code == 1) {
        // is reply
        std.debug.print("unhandled reply\n", .{});
        // TODO read rest of reply, if we don't then things get bady misaligned
        return Err.ProtocolReadError;
    } else {
        // is event
        return r;
    }
}

/// returns true if connection has input that needs to be handled
/// in case of an error the connection should be closed and you should exit and save data
pub fn hasInput(conn: Connection) !bool {
    return conn.poll();
}

/// creates a default gc to be used by graphics operations
pub fn createDefaultGC(conn: Connection, gcontext: u32, drawable: u32) !void {
    // https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html#requests:CreateGC
    const request = CreateGCRequest{
        .gcontext = gcontext,
        .drawable = drawable,
    };
    try conn.writeStruct(request);
}

pub fn createGC(conn: Connection, gcontext: u32, drawable: u32, bitmask: u32, values: []const u32) !void {
    if (@popCount(bitmask) != values.len) {
        @panic("bitmask values mismatch");
    }
    try conn.writeStruct(CreateGCRequest{
        .gcontext = gcontext,
        .drawable = drawable,
        .bitmask = bitmask,
        .request_len = 4 + @as(u16, @intCast(values.len)),
    });
    try conn.writeU32(values);
}

pub fn freeGC(conn: Connection, gcontext: u32) !void {
    return conn.writeStruct(FreeGCRequest{
        .gcontext = gcontext,
    });
}

pub fn createPixmap(conn: Connection, pixmap_id: u32, drawable: u32, width: u16, height: u16) !void {
    // https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html#requests:CreatePixmap
    const request = CreatePixmapRequest{
        .depth = 24,
        .pixmap_id = pixmap_id,
        .drawable = drawable,
        .width = width,
        .height = height,
    };
    try conn.writeStruct(request);
}

pub fn freePixmap(conn: Connection, pixmap_id: u32) !void {
    return conn.writeStruct(FreePixmapRequest{
        .pixmap_id = pixmap_id,
    });
}

pub fn copyArea(conn: Connection, src: u32, dst: u32, gc: u32, src_x: i16, src_y: i16, dst_x: i16, dst_y: i16, width: u16, height: u16) !void {
    return conn.writeStruct(CopyAreaRequest{
        .src = src,
        .dst = dst,
        .gc = gc,
        .src_x = src_x,
        .src_y = src_y,
        .dst_x = dst_x,
        .dst_y = dst_y,
        .width = width,
        .height = height,
    });
}

pub fn polyFillRectangle(conn: Connection, drawable: u32, gcontext: u32, x: i16, y: i16, width: u16, height: u16) !void {
    const n = 1; // list of 1 rectangles
    try conn.writeStruct(PolyFillRectangleRequest{
        .request_len = 3 + 2 * n,
        .drawable = drawable,
        .gcontext = gcontext,
    });
    try conn.writeStruct(Rectangle{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    });
}

pub const Rectangle = extern struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
};

const FreeGCRequest = extern struct {
    // FreeGC
    //      1     60                              opcode
    opcode: u8 = Opcodes.FreeGC,
    //      1                                     unused
    unused: u8 = undefined,
    //      2     2                               request length
    request_len: u16 = 2,
    //      4     GCONTEXT                        gc
    gcontext: u32,
};

const PolyFillRectangleRequest = extern struct {
    /// PolyFillRectangle
    ///      1     70                              opcode
    opcode: u8 = Opcodes.PolyFillRectangle,
    ///      1                                     unused
    unused: u8 = undefined,
    ///      2     3+2n                            request length
    request_len: u16 = 3,
    ///      4     DRAWABLE                        drawable
    drawable: u32,
    ///      4     GCONTEXT                        gc
    gcontext: u32,
    // followed by
    //      8n     LISTofRECTANGLE                rectangles
};

const FreePixmapRequest = extern struct {
    /// FreePixmap
    ///  1     54                              opcode
    opcode: u8 = Opcodes.FreePixmap,
    ///  1                                     unused
    unused: u8 = undefined,
    ///  2     2                               request length
    request_len: u16 = 2,
    ///  4     PIXMAP                          pixmap
    pixmap_id: u32,
};

const CreatePixmapRequest = extern struct {
    /// CreatePixmap
    ///  1     53                              opcode
    opcode: u8 = Opcodes.CreatePixmap,
    ///  1     CARD8                           depth
    depth: u8,
    ///  2     4                               request length
    request_len: u16 = 4,
    ///  4     PIXMAP                          pid
    pixmap_id: u32,
    ///  4     DRAWABLE                        drawable
    drawable: u32,
    ///  2     CARD16                          width
    width: u16,
    ///  2     CARD16                          height
    height: u16,
};

pub const GCBitmaskValues = struct {
    pub const function = 0x00000001;
    pub const plane_mask = 0x00000002;
    pub const foreground = 0x00000004;
    pub const background = 0x00000008;
    pub const line_width = 0x00000010;
    pub const line_style = 0x00000020;
    pub const cap_style = 0x00000040;
    pub const join_style = 0x00000080;
    pub const fill_style = 0x00000100;
    pub const fill_rule = 0x00000200;
    pub const tile = 0x00000400;
    pub const stipple = 0x00000800;
    pub const tile_stipple_x_origin = 0x00001000;
    pub const tile_stipple_y_origin = 0x00002000;
    pub const font = 0x00004000;
    pub const subwindow_mode = 0x00008000;
    pub const graphics_exposures = 0x00010000;
    pub const clip_x_origin = 0x00020000;
    pub const clip_y_origin = 0x00040000;
    pub const clip_mask = 0x00080000;
    pub const dash_offset = 0x00100000;
    pub const dashes = 0x00200000;
};

const CreateGCRequest = extern struct {
    opcode: u8 = Opcodes.CreateGC,
    unused: u8 = undefined,
    /// 4+n request length (n is nr of bits in bitmask)
    request_len: u16 = 4,
    gcontext: u32,
    drawable: u32,
    bitmask: u32 = 0,
};

const PutImageRequest = extern struct {
    opcode: u8 = Opcodes.PutImage,
    format: u8 = 2, // ZPixmap
    /// 2 | 6+(n+p)/4 | request length
    request_len: u16 = 6,
    drawable: u32,
    gcontext: u32,
    width: u16,
    height: u16,
    dst_x: i16,
    dst_y: i16,
    /// left_pad must be zero for ZPixmap format
    left_pad: u8 = 0,
    depth: u8 = 24,
    unused: u16 = undefined,
    // folowed by n LISTofBYTE + padding p
};

const CopyAreaRequest = extern struct {
    /// CopyArea
    ///  1     62                              opcode
    opcode: u8 = Opcodes.CopyArea,
    ///  1                                     unused
    unused: u8 = undefined,
    ///  2     7                               request length
    request_len: u16 = 7,
    ///  4     DRAWABLE                        src-drawable
    src: u32,
    ///  4     DRAWABLE                        dst-drawable
    dst: u32,
    ///  4     GCONTEXT                        gc
    gc: u32,
    ///  2     INT16                           src-x
    src_x: i16,
    ///  2     INT16                           src-y
    src_y: i16,
    ///  2     INT16                           dst-x
    dst_x: i16,
    ///  2     INT16                           dst-y
    dst_y: i16,
    ///  2     CARD16                          width
    width: u16,
    ///  2     CARD16                          height
    height: u16,
};

pub fn putImage(conn: Connection, drawable: u32, gcontext: u32, width: u16, height: u16, dst_x: i16, dst_y: i16, data: []const u8) !void {
    const request = PutImageRequest{
        .drawable = drawable,
        .gcontext = gcontext,
        .width = width,
        .height = height,
        .dst_x = dst_x,
        .dst_y = dst_y,
        .request_len = @intCast(@sizeOf(PutImageRequest) / 4 + pad4(data.len) / 4),
    };
    try conn.writeStruct(request);
    try conn.writeU8andPad(data);
}

pub const DestroyWindowRequest = extern struct {
    opcode: u8 = 8,
    unused: u8 = undefined,
    request_len: u16 = 2,
    window: u32,
};

pub const UnmapWindowRequest = extern struct {
    opcode: u8 = 10,
    unused: u8 = undefined,
    request_len: u16 = 2,
    window: u32,
};

pub const ChangePropertyRequest = extern struct {
    /// ChangeProperty
    ///  1     18                              opcode
    opcode: u8 = Opcodes.ChangeProperty,
    ///  1                                     mode
    ///       0     Replace
    ///       1     Prepend
    ///       2     Append
    mode: u8 = 0, // replace
    ///  2     6+(n+p)/4                       request length
    request_len: u16,
    ///  4     WINDOW                          window
    window: u32,
    ///  4     ATOM                            property
    property: u32,
    ///  4     ATOM                            type
    property_type: u32,
    ///  1     CARD8                           format = 8 or 16 or 32
    format: u8 = 8,
    ///  3                                     unused
    unused: [3]u8 = undefined,
    ///  4     CARD32                          length of data in format units
    ///                 (= n for format = 8)
    ///                 (= n/2 for format = 16)
    ///                 (= n/4 for format = 32)
    data_len: u32,

    // must be followed by:
    //  n     LISTofBYTE                      data
    //                 (n is a multiple of 2 for format = 16)
    //                 (n is a multiple of 4 for format = 32)
    //  p                                     unused, p=pad(n)

};

pub const Response = extern struct {
    code: u8,
    unknown_1: u8,
    sequence_number: u16,
    unknown_2: u32,
    unknown_3: [6]u32,

    pub fn isError(r: *Response) ?*Error {
        if (r.code == 0) {
            return @ptrCast(r);
        }
        return null;
    }

    pub fn isReply(r: *Response) bool {
        return r.code == 1;
    }

    pub fn isEvent(r: *Response) ?*Event {
        if ( r.code >= 2 and r.code <= 34 ) {
            return @ptrCast(r);
        }
        return null;
    }
};

pub const Error = extern struct {
    code: u8 = 0,
    error_code: ErrorCode,
    sequence_number: u16,
    unknown: u32,
    minor_opcode: u16,
    major_opcode: u8,
    unused_1: u8,
    unused_2: [5]u32,
};

pub const Connection = struct {
    stream: std.net.Stream,
    id_generator: IdGenerator = IdGenerator{},
    first_screen_id: u32,
    first_screen: Screen,

    pub fn init() !Connection {
        const server = try getDisplayServerInfo();
        var self = Connection{
            .first_screen = undefined,
            .first_screen_id = 0,
            .stream = try createDisplayServerStream(server),
        };
        errdefer destroyDisplayServerStream(self.stream);
        try self.setupConnection();
        return self;
    }

    /// destroyes the connection, all windows and resources are automatically
    /// destroyed when this happens, so no need to waste time on manually closing
    /// everything
    pub fn deinit(self: Connection) void {
        destroyDisplayServerStream(self.stream);
    }

    pub fn generateResourceId(self: *Connection) u32 {
        return self.id_generator.generateId();
    }

    fn setupConnection(self: *Connection) !void {
        try self.writeStruct(ConnectionSetupRequest.init());

        var status: ConnectionSetupReplyStatus = undefined;
        try self.read(&status);

        switch (status.code) {
            0 => return Err.ConnectionSetupFailed, // TODO get reason
            1 => {}, // success!
            2 => return Err.ConnectionSetupNeedsAuthenticate, // TODO what auth?
            else => return Err.ConnectionSetupUnknownReply,
        }

        // handle success
        var body: SuccessfullConnectionHeader = undefined;
        _ = try self.read(&body);

        var additional: SuccessfulConnectionHeaderAdditional = undefined;
        _ = try self.read(&additional);

        // TODO for now we just ignore the rest of the reply
        var buf: [65536]u8 = undefined;
        const rest_size: usize = (body.additional_data_length_4bytes) * 4 - @sizeOf(SuccessfulConnectionHeaderAdditional);
        const bytes_Read = try self.stream.read(buf[0..rest_size]);

        if (bytes_Read != rest_size) {
            // failed to skip connection setup reply
            return Err.ProtocolReadError;
        }

        const vendor_name = buf[0..additional.vendor_length];

        const formats_offset = pad4(vendor_name.len);
        const formats_len = 8 * additional.number_of_FORMATs_in_pixmap_formats;
        const formats_buf = buf[formats_offset..formats_len];
        var formats: []Format = undefined;
        formats.ptr = @ptrCast(formats_buf.ptr);
        formats.len = additional.number_of_FORMATs_in_pixmap_formats;

        const screens_offset = formats_offset + formats_len;
        const screens_buf = buf[screens_offset..buf.len];

        const screen: *Screen = @alignCast(@ptrCast(screens_buf.ptr));

        self.first_screen_id = screen.root;
        self.first_screen = screen.*;

        // std.debug.print(" {} \n", .{ additional });
        // std.debug.print("base {x} mask {x} \n", .{  additional.resource_id_base, additional.resource_id_mask });
        self.id_generator.base = additional.resource_id_base;
        self.id_generator.mask = additional.resource_id_mask;
    }

    fn writeStruct(self: Connection, data: anytype) !void {
        var slice: []const u8 = undefined;
        slice.ptr = @ptrCast(&data);
        slice.len = @sizeOf(@TypeOf(data));
        // std.debug.print("writing {any}", .{ slice });
        return self.writeBytes(slice);
    }

    fn writeBytes(self: Connection, data: []const u8) !void {
        const written = try self.stream.write(data);
        if (data.len != written) return Err.ProtocolWriteError;
    }

    fn writeU32(self: Connection, data: []const u32) !void {
        var bytes: []const u8 = undefined;
        bytes.ptr = @ptrCast(data.ptr);
        bytes.len = data.len * 4;
        const written = try self.stream.write(bytes);
        if (data.len * 4 != written) return Err.ProtocolWriteError;
    }

    fn writeU8andPad(self: Connection, data: []const u8) !void {
        const written = try self.stream.write(data);
        if (data.len != written) return Err.ProtocolWriteError;
        const pad_to_write = pad4of(data.len);
        if (pad_to_write > 0) {
            const values = [4]u8{ 0, 0, 0, 0 };
            const wr = try self.stream.write(values[0..pad_to_write]);
            if (pad_to_write != wr) return Err.ProtocolWriteError;
        }
    }

    fn poll(self: Connection) !bool {
        var nfo = [1]std.os.linux.pollfd{std.os.linux.pollfd{
            .fd = self.stream.handle,
            .events = 1, // POLLIN
            .revents = 0,
        }};
        return try std.posix.poll(&nfo, 0) != 0;
    }

    fn read(self: Connection, buffer: anytype) !void {
        var slice: []u8 = undefined;
        slice.ptr = @ptrCast(buffer);
        slice.len = @sizeOf(@TypeOf(buffer.*));
        const bytes_read = try self.stream.read(slice);
        if (slice.len != bytes_read) {
            if (bytes_read == 0) return Err.ProtocolClosed;
            return Err.ProtocolReadError;
        }
    }
};

const Screen = extern struct {
    ///  4     WINDOW                          root
    root: u32,
    ///  4     COLORMAP                        default-colormap
    default_colormap: u32,
    ///  4     CARD32                          white-pixel
    white_pixel: u32,
    ///  4     CARD32                          black-pixel
    black_pixel: u32,
    ///  4     SETofEVENT                      current-input-masks
    current_input_masks: u32,
    ///  2     CARD16                          width-in-pixels
    width_in_pixels: u16,
    ///  2     CARD16                          height-in-pixels
    height_in_pixels: u16,
    ///  2     CARD16                          width-in-millimeters
    width_in_millimeters: u16,
    ///  2     CARD16                          height-in-millimeters
    height_in_millimeters: u16,
    ///  2     CARD16                          min-installed-maps
    min_installed_maps: u16,
    ///  2     CARD16                          max-installed-maps
    max_installed_maps: u16,
    ///  4     VISUALID                        root-visual
    root_visual: u32,
    ///  1                                     backing-stores
    ///       0     Never
    ///       1     WhenMapped
    ///       2     Always
    backing_stores: u8,
    ///  1     BOOL                            save-unders
    save_unders: u8,
    ///  1     CARD8                           root-depth
    root_depth: u8,
    ///  1     CARD8                           number of DEPTHs in allowed-depths
    number_of_allowed_depths: u8,
    // followed by list of allowed depths...
};

const Format = extern struct {
    depth: u8,
    bpp: u8,
    scanline_pad: u8,
    unused: [5]u8,
};

fn pad4(size: usize) usize {
    return size + pad4of(size);
}

fn pad4of(size: usize) u8 {
    return @intCast(((0b100 - (size & 0b11)) & 0b11));
}

const IdGenerator = struct {
    mask: u32 = 0,
    base: u32 = 0,
    id: u32 = 0,

    fn generateId(self: *IdGenerator) u32 {
        var id = self.id;
        while (id == self.id) {
            id += 1;
            id &= self.mask;
            id |= self.base;
        }
        self.id = id;
        std.debug.print("generated id {}\n", .{id});
        return id;
    }
};

const ConnectionSetupReplyStatus = extern struct {
    /// 0 - failed, 1 - success, 2 - authenticate
    code: u8,
    // when status is 0, it contains the length of the reason, otherwise unused
    reason_len: u8,
};

const SuccessfullConnectionHeader = extern struct {
    ///  2     CARD16 protocol-major-version
    protocol_major_version: u16,

    ///  2     CARD16 protocol-minor-version
    protocol_minor_version: u16,

    ///  2 8+2n+(v+p+m)/4  length in 4-byte units of "additional data"
    additional_data_length_4bytes: u16,
};

const SuccessfulConnectionHeaderAdditional = extern struct {
    ///  4     CARD32                          release-number
    release_number: u32,

    // ///  4     CARD32                          resource-id-base
    resource_id_base: u32,

    // ///  4     CARD32                          resource-id-mask
    resource_id_mask: u32,

    ///  4     CARD32                          motion-buffer-size
    motion_buffer_size: u32,

    ///  2     v                               length of vendor
    vendor_length: u16,

    ///  2     CARD16                          maximum-request-length
    max_request_length: u16,

    ///  1     CARD8                           number of SCREENs in roots
    number_of_SCREENs_in_roots: u8,

    ///  1     n                               number for FORMATs in
    ///                                        pixmap-formats
    number_of_FORMATs_in_pixmap_formats: u8,

    ///  1                                     image-byte-order
    ///       0     LSBFirst
    ///       1     MSBFirst
    image_byte_order: u8, // 0 - LSBFirst, 1 - MSB-First

    ///  1                                     bitmap-format-bit-order
    ///       0     LeastSignificant
    ///       1     MostSignificant
    bitmap_format_bit_order: u8, // 0 - LSBFirst, 1 - MSB-First

    ///  1     CARD8                           bitmap-format-scanline-unit
    bitmap_format_scanline_unit: u8,

    ///  1     CARD8                           bitmap-format-scanline-pad
    bitmap_format_scanline_pad: u8,

    ///  1     KEYCODE                         min-keycode
    min_keycode: u8,

    ///  1     KEYCODE                         max-keycode
    max_keycode: u8,

    ///  4                                     unused
    unused: u32,
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
    opcode: u8 = Opcodes.CreateWindow,
    depth: u8 = 24,
    /// 8 + n
    request_length: u16 = 8,
    wid: u32,
    parent: u32 = 0,
    x: i16 = 64,
    y: i16 = 64,
    width: u16 = 400,
    height: u16 = 300,
    border_width: u16 = 0,
    ///           0     CopyFromParent
    ///           1     InputOutput
    ///           2     InputOnly
    class: u16 = 1,
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

const WindowBitmask = struct {
    const background_pixmap = 0x00000001;
    const background_pixel = 0x00000002;
    const border_pixmap = 0x00000004;
    const border_pixel = 0x00000008;
    const bit_gravity = 0x00000010;
    const win_gravity = 0x00000020;
    const backing_store = 0x00000040;
    const backing_planes = 0x00000080;
    const backing_pixel = 0x00000100;
    const override_redirect = 0x00000200;
    const save_under = 0x00000400;
    const event_mask = 0x00000800;
    const do_not_propagate_mask = 0x00001000;
    const colormap = 0x00002000;
    const cursors = 0x00004000;
};

const EventMask = struct {
    const KeyPress = 0x00000001;
    const KeyRelease = 0x00000002;
    const ButtonPress = 0x00000004;
    const ButtonRelease = 0x00000008;
    const EnterWindow = 0x00000010;
    const LeaveWindow = 0x00000020;
    const PointerMotion = 0x00000040;
    const PointerMotionHint = 0x00000080;
    const Button1Motion = 0x00000100;
    const Button2Motion = 0x00000200;
    const Button3Motion = 0x00000400;
    const Button4Motion = 0x00000800;
    const Button5Motion = 0x00001000;
    const ButtonMotion = 0x00002000;
    const KeymapState = 0x00004000;
    const Exposure = 0x00008000;
    const VisibilityChange = 0x00010000;
    const StructureNotify = 0x00020000;
    const ResizeRedirect = 0x00040000;
    const SubstructureNotify = 0x00080000;
    const SubstructureRedirect = 0x00100000;
    const FocusChange = 0x00200000;
    const PropertyChange = 0x00400000;
    const ColormapChange = 0x00800000;
    const OwnerGrabButton = 0x01000000;
    const unused_but_must_be_zero = 0xFE000000;
};

const MapWindowRequest = extern struct {
    opcode: u8 = 8,
    unused: u8 = undefined,
    request_len: u16 = 2,
    window: u32,
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
    if (std.posix.getenv("DISPLAY")) |display| {
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

const Opcodes = struct {
    const CreateWindow = 1;
    const DestroyWindow = 4;
    const MapWindow = 8;
    const UnmapWindow = 10;
    const ChangeProperty = 18;
    const CreatePixmap = 53;
    const FreePixmap = 54;
    const CreateGC = 55;
    const FreeGC = 60;
    const CopyArea = 62;
    const PolyFillRectangle = 70;
    const PutImage = 88;
    const NoOperation = 127;
};

const PredefinedAtoms = struct {
    const PRIMARY = 1;
    const SECONDARY = 2;
    const ARC = 3;
    const ATOM = 4;
    const BITMAP = 5;
    const CARDINAL = 6;
    const COLORMAP = 7;
    const CURSOR = 8;
    const CUT_BUFFER0 = 9;
    const CUT_BUFFER1 = 10;
    const CUT_BUFFER2 = 11;
    const CUT_BUFFER3 = 12;
    const CUT_BUFFER4 = 13;
    const CUT_BUFFER5 = 14;
    const CUT_BUFFER6 = 15;
    const CUT_BUFFER7 = 16;
    const DRAWABLE = 17;
    const FONT = 18;
    const INTEGER = 19;
    const PIXMAP = 20;
    const POINT = 21;
    const RECTANGLE = 22;
    const RESOURCE_MANAGER = 23;
    const RGB_COLOR_MAP = 24;
    const RGB_BEST_MAP = 25;
    const RGB_BLUE_MAP = 26;
    const RGB_DEFAULT_MAP = 27;
    const RGB_GRAY_MAP = 28;
    const RGB_GREEN_MAP = 29;
    const RGB_RED_MAP = 30;
    const STRING = 31;
    const VISUALID = 32;
    const WINDOW = 33;
    const WM_COMMAND = 34;
    const WM_HINTS = 35;
    const WM_CLIENT_MACHINE = 36;
    const WM_ICON_NAME = 37;
    const WM_ICON_SIZE = 38;
    const WM_NAME = 39;
    const WM_NORMAL_HINTS = 40;
    const WM_SIZE_HINTS = 41;
    const WM_ZOOM_HINTS = 42;
    const MIN_SPACE = 43;
    const NORM_SPACE = 44;
    const MAX_SPACE = 45;
    const END_SPACE = 46;
    const SUPERSCRIPT_X = 47;
    const SUPERSCRIPT_Y = 48;
    const SUBSCRIPT_X = 49;
    const SUBSCRIPT_Y = 50;
    const UNDERLINE_POSITION = 51;
    const UNDERLINE_THICKNESS = 52;
    const STRIKEOUT_ASCENT = 53;
    const STRIKEOUT_DESCENT = 54;
    const ITALIC_ANGLE = 55;
    const X_HEIGHT = 56;
    const QUAD_WIDTH = 57;
    const WEIGHT = 58;
    const POINT_SIZE = 59;
    const RESOLUTION = 60;
    const COPYRIGHT = 61;
    const NOTICE = 62;
    const FONT_NAME = 63;
    const FAMILY_NAME = 64;
    const FULL_NAME = 65;
    const CAP_HEIGHT = 66;
    const WM_CLASS = 67;
    const WM_TRANSIENT_FOR = 68;
};

const ErrorCode = enum(u8) {
    Request = 1,
    Value = 2,
    Window = 3,
    Pixmap = 4,
    Atom = 5,
    Cursor = 6,
    Font = 7,
    Match = 8,
    Drawable = 9,
    Access = 10,
    Alloc = 11,
    Colormap = 12,
    GContext = 13,
    IDChoice = 14,
    Name = 15,
    Length = 16,
    Implementation = 17,
};

pub const EventCode = enum(u8) {
    KeyPress = 2,
    KeyRelease = 3,
    ButtonPress = 4,
    ButtonRelease = 5,
    MotionNotify = 6,
    EnterNotify = 7,
    LeaveNotify = 8,
    FocusIn = 9,
    FocusOut = 10,
    KeymapNotify = 11,
    Expose = 12,
    GraphicsExposure = 13,
    NoExposure = 14,
    VisibilityNotify = 15,
    CreateNotify = 16,
    DestroyNotify = 17,
    UnmapNotify = 18,
    MapNotify = 19,
    MapRequest = 20,
    ReparentNotify = 21,
    ConfigureNotify = 22,
    ConfigureRequest = 23,
    GravityNotify = 24,
    ResizeRequest = 25,
    CirculateNotify = 26,
    CirculateRequest = 27,
    PropertyNotify = 28,
    SelectionClear = 29,
    SelectionRequest = 30,
    SelectionNotify = 31,
    ColormapNotify = 32,
    ClientMessage = 33,
    MappingNotify = 34,
};


pub const Event = extern struct {

    code: EventCode,
    unknown_1: u8,
    sequence_number: u16,
    unknown_2: u32,
    unknown_3: [6]u32,

    pub fn isKeyPress(self: *Event) ?*KeyPress {
        return if (self.code == EventCode.KeyPress) @ptrCast(self) else null;
    }

    const KeyPress = extern struct { 
        code: EventCode = 2,       //      1     2                               code
        detail: u8,     //      1     KEYCODE                         detail
        number: u16,  //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,    //      4     WINDOW                          event
        child: u32,    //      4     WINDOW                          child
                         //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        screen: u8,     //      1     BOOL                            same-screen
        unused: u8,     //      1                                     unused
    };

    pub fn isKeyRelease(self: *Event) ?*KeyRelease {
        return if (self.code == EventCode.KeyRelease) @ptrCast(self) else null;
    }

    const KeyRelease = extern struct { 
        code: u8,     //      1     3                               code
        detail: u8,     //      1     KEYCODE                         detail
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        screen: u8,     //      1     BOOL                            same-screen
        unused: u8,     //      1                                     unused

    };

    pub fn isButtonPress(self: *Event) ?*ButtonPress {
        return if (self.code == EventCode.ButtonPress) @ptrCast(self) else null;
    }

    const ButtonPress = extern struct { 
        code: u8,     //      1     4                               code
        detail: u8,     //      1     BUTTON                          detail
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        screen: u8,     //      1     BOOL                            same-screen
        unused: u8,     //      1                                     unused

    };

    pub fn isButtonRelease(self: *Event) ?*ButtonRelease {
        return if (self.code == EventCode.ButtonRelease) @ptrCast(self) else null;
    }

    const ButtonRelease = extern struct { 
        code: u8,     //      1     5                               code
        detail: u8,     //      1     BUTTON                          detail
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        screen: u8,     //      1     BOOL                            same-screen
        unused: u8,     //      1                                     unused

    };

    pub fn isMotionNotify(self: *Event) ?*MotionNotify {
        return if (self.code == EventCode.MotionNotify) @ptrCast(self) else null;
    }

    const MotionNotify = extern struct { 
        code: u8,     //      1     6                               code
        detail: u8,     //      1                                     detail
        //           0     Normal
        //           1     Hint
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //            0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        screen: u8,     //      1     BOOL                            same-screen
        unused: u8,     //      1                                     unused

    };

    pub fn isEnterNotify(self: *Event) ?*EnterNotify {
        return if (self.code == EventCode.EnterNotify) @ptrCast(self) else null;
    }

    const EnterNotify = extern struct { 
        code: u8,     //      1     7                               code
        detail: u8,     //      1                                     detail
        //           0     Ancestor
        //           1     Virtual
        //           2     Inferior
        //           3     Nonlinear
        //           4     NonlinearVirtual
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        mode: u8,     //      1                                     mode
        //           0     Normal
        //           1     Grab
        //           2     Ungrab
        focus: u8,     //      1                                     same-screen, focus
        //           #x01     focus (1 is True, 0 is False)
        //           #x02     same-screen (1 is True, 0 is False)
        //           #xFC     unused

    };

    pub fn isLeaveNotify(self: *Event) ?*LeaveNotify {
        return if (self.code == EventCode.LeaveNotify) @ptrCast(self) else null;
    }

    const LeaveNotify = extern struct { 
        code: u8,     //      1     8                               code
        detail: u8,     //      1                                     detail
        //           0     Ancestor
        //           1     Virtual
        //           2     Inferior
        //           3     Nonlinear
        //           4     NonlinearVirtual
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        root: u32,     //      4     WINDOW                          root
        event: u32,     //      4     WINDOW                          event
        child: u32,     //      4     WINDOW                          child
        //           0     None
        root_x: i16,     //      2     INT16                           root-x
        root_y: i16,     //      2     INT16                           root-y
        event_x: i16,     //      2     INT16                           event-x
        event_y: i16,     //      2     INT16                           event-y
        state: u16,     //      2     SETofKEYBUTMASK                 state
        mode: u8,     //      1                                     mode
        //           0     Normal
        //           1     Grab
        //           2     Ungrab
        focus: u8,     //      1                                     same-screen, focus
        //           #x01     focus (1 is True, 0 is False)
        //           #x02     same-screen (1 is True, 0 is False)
        //           #xFC     unused

    };

    pub fn isFocusIn(self: *Event) ?*FocusIn {
        return if (self.code == EventCode.FocusIn) @ptrCast(self) else null;
    }

    const FocusIn = extern struct { 
        code: u8,     //      1     9                               code
        detail: u8,     //      1                                     detail
        //           0     Ancestor
        //           1     Virtual
        //           2     Inferior
        //           3     Nonlinear
        //           4     NonlinearVirtual
        //           5     Pointer
        //           6     PointerRoot
        //           7     None
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        mode: u8,     //      1                                     mode
        //           0     Normal
        //           1     Grab
        //           2     Ungrab
        //           3     WhileGrabbed
        // unused: u16,     //      23                                    unused
        unused: [23]u8,

    };

    pub fn isFocusOut(self: *Event) ?*FocusOut {
        return if (self.code == EventCode.FocusOut) @ptrCast(self) else null;
    }

    const FocusOut = extern struct { 
        code: u8,     //      1     10                              code
        detail: u8,     //      1                                     detail
        //           0     Ancestor
        //           1     Virtual
        //           2     Inferior
        //           3     Nonlinear
        //           4     NonlinearVirtual
        //           5     Pointer
        //           6     PointerRoot
        //           7     None
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        mode: u8,     //      1                                     mode
        //           0     Normal
        //           1     Grab
        //           2     Ungrab
        //           3     WhileGrabbed
        // unused: u16,     //      23                                    unused
        unused: [23]u8,

    };

    pub fn isKeymapNotify(self: *Event) ?*KeymapNotify {
        return if (self.code == EventCode.KeymapNotify) @ptrCast(self) else null;
    }

    const KeymapNotify = extern struct { 
        code: u8,     //      1     11                              code
        //      31    LISTofCARD8                     keys (byte for keycodes 0-7 is
        //                                            omitted)
        keys: [31]u8,
    };

    pub fn isExpose(self: *Event) ?*Expose {
        return if (self.code == EventCode.Expose) @ptrCast(self) else null;
    }

    const Expose = extern struct { 
        code: u8,     //      1     12                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        x: u16,     //      2     CARD16                          x
        y: u16,     //      2     CARD16                          y
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        count: u16,     //      2     CARD16                          count
        // unused: u8,     //      14                                    unused
        unused_2: [14]u8,
    };

    pub fn isGraphicsExposure(self: *Event) ?*GraphicsExposure {
        return if (self.code == EventCode.GraphicsExposure) @ptrCast(self) else null;
    }

    const GraphicsExposure = extern struct { 
        code: u8,     //      1     13                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        drawable: u32,     //      4     DRAWABLE                        drawable
        x: u16,     //      2     CARD16                          x
        y: u16,     //      2     CARD16                          y
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        minor_opcode: u16,     //      2     CARD16                          minor-opcode
        count: u16,     //      2     CARD16                          count
        major_opcode: u8,     //      1     CARD8                           major-opcode
        // unused: u8,     //      11                                    unused
        unused_2: [11]u8,

    };

    pub fn isNoExposure(self: *Event) ?*NoExposure {
        return if (self.code == EventCode.NoExposure) @ptrCast(self) else null;
    }

    const NoExposure = extern struct { 
        code: u8,     //      1     14                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        drawable: u32,     //      4     DRAWABLE                        drawable
        minor_opcode: u16,     //      2     CARD16                          minor-opcode
        major_opcode: u8,     //      1     CARD8                           major-opcode
        // unused: u16,     //      21                                    unused
        unused_2: [21]u8,

    };

    pub fn isVisibilityNotify(self: *Event) ?*VisibilityNotify {
        return if (self.code == EventCode.VisibilityNotify) @ptrCast(self) else null;
    }

    const VisibilityNotify = extern struct { 
        code: u8,     //      1     15                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        state: u8,     //      1                                     state
        //           0     Unobscured
        //           1     PartiallyObscured
        //           2     FullyObscured
        // unused: u16,     //      23                                    unused
        unused_2: [23]u8,

    };

    pub fn isCreateNotify(self: *Event) ?*CreateNotify {
        return if (self.code == EventCode.CreateNotify) @ptrCast(self) else null;
    }

    const CreateNotify = extern struct { 
        code: u8,     //      1     16                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        parent: u32,     //      4     WINDOW                          parent
        window: u32,     //      4     WINDOW                          window
        x: i16,     //      2     INT16                           x
        y: i16,     //      2     INT16                           y
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        border_width: u16,     //      2     CARD16                          border-width
        redirect: u8,     //      1     BOOL                            override-redirect
        //      9                                     unused
        unused_2: [9]u8,

    };

    pub fn isDestroyNotify(self: *Event) ?*DestroyNotify {
        return if (self.code == EventCode.DestroyNotify) @ptrCast(self) else null;
    }

    const DestroyNotify = extern struct { 
        code: u8,     //      1     17                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        // unused: u16,     //      20                                    unused
        unused_2: [20]u8,

    };

    pub fn isUnmapNotify(self: *Event) ?*UnmapNotify {
        return if (self.code == EventCode.UnmapNotify) @ptrCast(self) else null;
    }

    const UnmapNotify = extern struct { 
        code: u8,     //      1     18                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        configure: u8,     //      1     BOOL                            from-configure
        // unused: u8,     //      19                                    unused
        unused_2: [19]u8,

    };

    pub fn isMapNotify(self: *Event) ?*MapNotify {
        return if (self.code == EventCode.MapNotify) @ptrCast(self) else null;
    }

    const MapNotify = extern struct { 
        code: u8,     //      1     19                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        redirect: u8,     //      1     BOOL                            override-redirect
        // unused: u8,     //      19                                    unused
        unused_2: [19]u8,

    };

    pub fn isMapRequest(self: *Event) ?*MapRequest {
        return if (self.code == EventCode.MapRequest) @ptrCast(self) else null;
    }

    const MapRequest = extern struct { 
        code: u8,     //      1     20                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        parent: u32,     //      4     WINDOW                          parent
        window: u32,     //      4     WINDOW                          window
        // unused: u16,     //      20                                    unused
        unused_2: [20]u8,

    };

    pub fn isReparentNotify(self: *Event) ?*ReparentNotify {
        return if (self.code == EventCode.ReparentNotify) @ptrCast(self) else null;
    }

    const ReparentNotify = extern struct { 
        code: u8,     //      1     21                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        parent: u32,     //      4     WINDOW                          parent
        x: i16,     //      2     INT16                           x
        y: i16,     //      2     INT16                           y
        redirect: u8,     //      1     BOOL                            override-redirect
        // unused: u8,     //      11                                    unused
        unused_2: [11]u8,

    };

    pub fn isConfigureNotify(self: *Event) ?*ConfigureNotify {
        return if (self.code == EventCode.ConfigureNotify) @ptrCast(self) else null;
    }

    const ConfigureNotify = extern struct { 
        code: u8,     //      1     22                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        sibling: u32,     //      4     WINDOW                          above-sibling
    //           0     None
        x: i16,     //      2     INT16                           x
        y: i16,     //      2     INT16                           y
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        border_width: u16,     //      2     CARD16                          border-width
        redirect: u8,     //      1     BOOL                            override-redirect
    //      5                                     unused
        unused_2: [5]u8,

    };

    pub fn isConfigureRequest(self: *Event) ?*ConfigureRequest {
        return if (self.code == EventCode.ConfigureRequest) @ptrCast(self) else null;
    }

    const ConfigureRequest = extern struct { 
        code: u8,     //      1     23                              code
        mode: u8,     //      1                                     stack-mode
    //           0     Above
    //           1     Below
    //           2     TopIf
    //           3     BottomIf
    //           4     Opposite
        number: u16,     //      2     CARD16                          sequence number
        parent: u32,     //      4     WINDOW                          parent
        window: u32,     //      4     WINDOW                          window
        sibling: u32,     //      4     WINDOW                          sibling
    //           0     None
        x: i16,     //      2     INT16                           x
        y: i16,     //      2     INT16                           y
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        border_width: u16,     //      2     CARD16                          border-width
        mask: u16,     //      2     BITMASK                         value-mask
        //           #x0001     x
        //           #x0002     y
        //           #x0004     width
        //           #x0008     height
        //           #x0010     border-width
        //           #x0020     sibling
        //           #x0040     stack-mode
        // unused: u32,     //      4                                     unused
        unused_2: [4]u8,

    };

    pub fn isGravityNotify(self: *Event) ?*GravityNotify {
        return if (self.code == EventCode.GravityNotify) @ptrCast(self) else null;
    }

    const GravityNotify = extern struct { 
        code: u8,     //      1     24                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        x: i16,     //      2     INT16                           x
        y: i16,     //      2     INT16                           y
        // unused: u8,     //      16                                    unused
        unused_2: [16]u8,

    };

    pub fn isResizeRequest(self: *Event) ?*ResizeRequest {
        return if (self.code == EventCode.ResizeRequest) @ptrCast(self) else null;
    }

    const ResizeRequest = extern struct { 
        code: u8,     //      1     25                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        width: u16,     //      2     CARD16                          width
        height: u16,     //      2     CARD16                          height
        unused_2: u16,     //      20                                    unused
        unused_3: [20]u8,
    };

    pub fn isCirculateNotify(self: *Event) ?*CirculateNotify {
        return if (self.code == EventCode.CirculateNotify) @ptrCast(self) else null;
    }

    const CirculateNotify = extern struct { 
        code: u8,     //      1     26                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        event: u32,     //      4     WINDOW                          event
        window: u32,     //      4     WINDOW                          window
        unused_2: u32,     //      4     WINDOW                          unused
        place: u8,     //      1                                     place
        //           0     Top
        //           1     Bottom
        // unused: u8,     //      15                                    unused
        unused_3: [15]u8,
    };

    pub fn isCirculateRequest(self: *Event) ?*CirculateRequest {
        return if (self.code == EventCode.CirculateRequest) @ptrCast(self) else null;
    }

    const CirculateRequest = extern struct { 
        code: u8,     //      1     27                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        parent: u32,     //      4     WINDOW                          parent
        window: u32,     //      4     WINDOW                          window
        unused_2: u32,     //      4                                     unused
        place: u8,     //      1                                     place
        //           0     Top
        //           1     Bottom
        // unused: u8,     //      15                                    unused
        unused_3: [15]u8,
    };

    pub fn isPropertyNotify(self: *Event) ?*PropertyNotify {
        return if (self.code == EventCode.PropertyNotify) @ptrCast(self) else null;
    }

    const PropertyNotify = extern struct { 
        code: u8,     //      1     28                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        atom: u32,     //      4     ATOM                            atom
        time: u32,     //      4     TIMESTAMP                       time
        state: u8,     //      1                                     state
        //           0     NewValue
        //           1     Deleted
        // unused: u8,     //      15                                    unused
        unused_2: [15]u8,
    };

    pub fn isSelectionClear(self: *Event) ?*SelectionClear {
        return if (self.code == EventCode.SelectionClear) @ptrCast(self) else null;
    }

    const SelectionClear = extern struct { 
        code: u8,     //      1     29                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        owner: u32,     //      4     WINDOW                          owner
        selection: u32,     //      4     ATOM                            selection
        // unused: u8,     //      16                                    unused
        unused_2: [16]u8,
    };

    pub fn isSelectionRequest(self: *Event) ?*SelectionRequest {
        return if (self.code == EventCode.SelectionRequest) @ptrCast(self) else null;
    }

    const SelectionRequest = extern struct { 
        code: u8,     //      1     30                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        //           0     CurrentTime
        owner: u32,     //      4     WINDOW                          owner
        property: u32,     //      4     WINDOW                      property
        //           0     None
        //      8                                     unused
        unused_2: [8]u8,
    };

    pub fn isColormapNotify(self: *Event) ?*ColormapNotify {
        return if (self.code == EventCode.ColormapNotify) @ptrCast(self) else null;
    }

    const ColormapNotify = extern struct {
        //  1     32                              code
        //  1                                     unused
        //  2     CARD16                          sequence number
        //  4     WINDOW                          window
        //  4     COLORMAP                        colormap
        //       0     None
        //  1     BOOL                            new
        //  1                                     state
        //       0     Uninstalled
        //       1     Installed
        //  18                                    unused
        code: u8,     //      1     32                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        colormap: u32,     //      4     COLORMAP               events
        new: u8,
        state: u8,
        unused_2: [18]u8,
    };

    pub fn isClientMessage(self: *Event) ?*ClientMessage {
        return if (self.code == EventCode.ClientMessage) @ptrCast(self) else null;
    }

    const ClientMessage = extern struct { 
        code: u8,     //      1     33                              code
        format: u8,     //      1     CARD8                           format
        number: u16,     //      2     CARD16                          sequence number
        window: u32,     //      4     WINDOW                          window
        type: u32,     //      4     ATOM                            type
        data: [20]u8,     //      20                                    data
    };

    pub fn isMappingNotify(self: *Event) ?*MappingNotify {
        return if (self.code == EventCode.MappingNotify) @ptrCast(self) else null;
    }

    const MappingNotify = extern struct { 
        code: u8,     //      1     34                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        request: u8,     //      1                                     request
        //           0     Modifier
        //           1     Keyboard
        //           2     Pointer
        keycode: u8,     //      1     KEYCODE                         first-keycode
        count: u8,     //      1     CARD8                           count
        unused_2: [25]u8,     //      25                                    unused
    };

    pub fn isSelectionNotify(self: *Event) ?*SelectionNotify {
        return if (self.code == EventCode.SelectionNotify) @ptrCast(self) else null;
    }

    const SelectionNotify = extern struct { 
        code: u8,     //      1     31                              code
        unused: u8,     //      1                                     unused
        number: u16,     //      2     CARD16                          sequence number
        time: u32,     //      4     TIMESTAMP                       time
        //           0     CurrentTime
        requestor: u32,     //      4     WINDOW                          requestor
        selection: u32,     //      4     ATOM                            selection
        target: u32,     //      4     ATOM                            target
        property: u32,     //      4     ATOM                            property
        //           0     None
        //      8                                     unused
        unused_2: [8]u8,
    };

 };


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
    try expect(@sizeOf(Format) == 8);
    try expect(@sizeOf(ChangePropertyRequest) == 6 * 4);
    try expect(@sizeOf(PutImageRequest) == 6 * 4);
    try expect(@sizeOf(CreateGCRequest) == 4 * 4);
    try expect(@sizeOf(CreatePixmapRequest) == 4 * 4);
    try expect(@sizeOf(CopyAreaRequest) == 7 * 4);
}

test "pad4 works as expected" {
    const expect = std.testing.expect;
    try expect(pad4(0) == 0);
    try expect(pad4(1) == 4);
    try expect(pad4(2) == 4);
    try expect(pad4(3) == 4);
    try expect(pad4(4) == 4);
    try expect(pad4(5) == 8);
}

test "all events should have 32 bytes" {
    // this is important as we are communicating over binary procotol
    // the struct size need to be perfectly aligned
    const expect = std.testing.expect;
    try expect(@sizeOf(Event) == 32);
    try expect(@sizeOf(Event.KeyPress) == 32);
    try expect(@sizeOf(Event.KeyRelease) == 32);
    try expect(@sizeOf(Event.ButtonPress) == 32);
    try expect(@sizeOf(Event.ButtonRelease) == 32);
    try expect(@sizeOf(Event.MotionNotify) == 32);
    try expect(@sizeOf(Event.EnterNotify) == 32);
    try expect(@sizeOf(Event.LeaveNotify) == 32);
    try expect(@sizeOf(Event.FocusIn) == 32);
    try expect(@sizeOf(Event.FocusOut) == 32);
    try expect(@sizeOf(Event.KeymapNotify) == 32);
    try expect(@sizeOf(Event.Expose) == 32);
    try expect(@sizeOf(Event.GraphicsExposure) == 32);
    try expect(@sizeOf(Event.NoExposure) == 32);
    try expect(@sizeOf(Event.VisibilityNotify) == 32);
    try expect(@sizeOf(Event.CreateNotify) == 32);
    try expect(@sizeOf(Event.DestroyNotify) == 32);
    try expect(@sizeOf(Event.UnmapNotify) == 32);
    try expect(@sizeOf(Event.MapNotify) == 32);
    try expect(@sizeOf(Event.MapRequest) == 32);
    try expect(@sizeOf(Event.ReparentNotify) == 32);
    try expect(@sizeOf(Event.ConfigureNotify) == 32);
    try expect(@sizeOf(Event.ConfigureRequest) == 32);
    try expect(@sizeOf(Event.GravityNotify) == 32);
    try expect(@sizeOf(Event.ResizeRequest) == 32);
    try expect(@sizeOf(Event.CirculateNotify) == 32);
    try expect(@sizeOf(Event.CirculateRequest) == 32);
    try expect(@sizeOf(Event.PropertyNotify) == 32);
    try expect(@sizeOf(Event.SelectionClear) == 32);
    try expect(@sizeOf(Event.SelectionRequest) == 32);
    try expect(@sizeOf(Event.ColormapNotify) == 32);
    try expect(@sizeOf(Event.MappingNotify) == 32);
    try expect(@sizeOf(Event.SelectionNotify) == 32);
    try expect(@sizeOf(Event.ColormapNotify) == 32);
    try expect(@sizeOf(Event.MappingNotify) == 32);
}
