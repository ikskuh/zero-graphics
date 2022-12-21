const std = @import("std");
const zero_graphics = @import("../zero-graphics.zig");
// const c = @import("scintilla");
const log = std.log.scoped(.cpp_code_editor);

const Renderer = zero_graphics.Renderer2D;
const Color = zero_graphics.Color;
const Rectangle = zero_graphics.Rectangle;
const Point = zero_graphics.Point;
const Size = zero_graphics.Size;

const CodeEditor = @This();

const c = struct {
    // Keep in sync with code_editor.h
    pub const ZigFont = opaque {};
    pub const ZigRect = extern struct {
        x: f32,
        y: f32,
        width: f32,
        height: f32,
    };
    pub const ZigColor = u32;
    pub const ZigEditorInterface = extern struct {
        createFont: ?*const fn (*ZigEditorInterface, [*:0]const u8, f32) callconv(.C) ?*ZigFont,
        destroyFont: ?*const fn (*ZigEditorInterface, ?*ZigFont) callconv(.C) void,
        getFontAscent: ?*const fn (*ZigEditorInterface, ?*ZigFont) callconv(.C) f32,
        getFontDescent: ?*const fn (*ZigEditorInterface, ?*ZigFont) callconv(.C) f32,
        getFontLineGap: ?*const fn (*ZigEditorInterface, ?*ZigFont) callconv(.C) f32,
        getFontCharWidth: ?*const fn (*ZigEditorInterface, ?*ZigFont, u32) callconv(.C) f32,
        measureStringWidth: ?*const fn (*ZigEditorInterface, ?*ZigFont, [*]const u8, usize) callconv(.C) f32,
        measureCharPositions: ?*const fn (*ZigEditorInterface, ?*ZigFont, [*]const u8, usize, [*]f32) callconv(.C) void,
        drawString: ?*const fn (*ZigEditorInterface, *const ZigRect, ?*ZigFont, ZigColor, [*]const u8, usize) callconv(.C) void,
        drawRectangle: ?*const fn (*ZigEditorInterface, *const ZigRect, ZigColor) callconv(.C) void,
        fillRectangle: ?*const fn (*ZigEditorInterface, *const ZigRect, ZigColor) callconv(.C) void,
        setClipRect: ?*const fn (*ZigEditorInterface, *const ZigRect) callconv(.C) void,
        setClipboardContent: ?*const fn (*ZigEditorInterface, [*]const u8, usize) callconv(.C) void,
        getClipboardContent: ?*const fn (*ZigEditorInterface, [*]u8, usize) callconv(.C) usize,
        sendNotification: ?*const fn (*ZigEditorInterface, notification: u32) callconv(.C) void,
    };
    pub const ScintillaEditor = opaque {};
    pub const ZigString = extern struct {
        ptr: ?[*]u8,
        len: usize,
    };
    pub const LOG_DEBUG: c_int = 0;
    pub const LOG_INFO: c_int = 1;
    pub const LOG_WARN: c_int = 2;
    pub const LOG_ERROR: c_int = 3;
    pub const LogLevel = c_uint;

    pub const NOTIFY_CHANGE = 1;

    pub extern fn scintilla_init(...) void;
    pub extern fn scintilla_deinit(...) void;
    pub extern fn scintilla_create(*ZigEditorInterface) ?*ScintillaEditor;
    pub extern fn scintilla_setText(editor: ?*ScintillaEditor, string: [*]const u8, length: usize) void;
    pub extern fn scintilla_getText(editor: ?*ScintillaEditor, allocator: ?*anyopaque) ZigString;
    pub extern fn scintilla_tick(editor: ?*ScintillaEditor) void;
    pub extern fn scintilla_render(editor: ?*ScintillaEditor) void;
    pub extern fn scintilla_setFocus(editor: ?*ScintillaEditor, focused: bool) void;
    pub extern fn scintilla_mouseMove(editor: ?*ScintillaEditor, x: c_int, y: c_int) void;
    pub extern fn scintilla_mouseDown(editor: ?*ScintillaEditor, time: f32, x: c_int, y: c_int) void;
    pub extern fn scintilla_mouseUp(editor: ?*ScintillaEditor, time: f32, x: c_int, y: c_int) void;
    pub extern fn scintilla_keyDown(editor: ?*ScintillaEditor, zig_scancode: c_int, shift: bool, ctrl: bool, alt: bool) bool;
    pub extern fn scintilla_enterString(editor: ?*ScintillaEditor, str: [*]const u8, len: usize) void;
    pub extern fn scintilla_setPosition(editor: ?*ScintillaEditor, x: c_int, y: c_int, w: c_int, h: c_int) void;
    pub extern fn scintilla_destroy(editor: ?*ScintillaEditor) void;
};

pub const Notification = enum(u32) {
    text_changed,
};

pub const NotificationSet = std.EnumSet(Notification);

pub fn init() !void {
    c.scintilla_init();
}

pub fn deinit() void {
    c.scintilla_deinit();
}

interface: c.ZigEditorInterface,
instance: *c.ScintillaEditor,
renderer: *Renderer,
position: Rectangle,
notifications: NotificationSet,

pub fn create(editor: *CodeEditor, renderer: *Renderer) !void {
    editor.* = CodeEditor{
        .interface = default_editor_impl,
        .renderer = renderer,
        .instance = c.scintilla_create(&editor.interface) orelse return error.OutOfMemory,
        .position = undefined,
        .notifications = NotificationSet{},
    };
    editor.setPosition(Rectangle.new(Point.zero, zero_graphics.CoreApplication.get().screen_size));
}

pub fn destroy(editor: *CodeEditor) void {
    c.scintilla_destroy(editor.instance);
    editor.* = undefined;
}

pub fn getNotifications(editor: *CodeEditor) NotificationSet {
    const result = editor.notifications;
    editor.notifications = NotificationSet{};
    return result;
}

pub fn tick(editor: *CodeEditor) void {
    c.scintilla_tick(editor.instance);
}

pub fn render(editor: *CodeEditor) void {
    c.scintilla_render(editor.instance);
}

pub fn setPosition(editor: *CodeEditor, rectangle: Rectangle) void {
    editor.position = rectangle;
    c.scintilla_setPosition(editor.instance, rectangle.x, rectangle.y, rectangle.width, rectangle.height);
}

pub fn setText(editor: *CodeEditor, text: []const u8) !void {
    c.scintilla_setText(editor.instance, text.ptr, text.len);
}

pub fn getText(editor: *CodeEditor, allocator: std.mem.Allocator) ![:0]u8 {
    var allo = allocator;
    const str = c.scintilla_getText(editor.instance, &allo);
    const ptr = str.ptr orelse return error.OutOfMemory;
    if (str.len == 0)
        return try allocator.allocSentinel(u8, 1, 0); // we're allocating, as 0 len means the backend didn't allocate
    return ptr[0..str.len :0];
}

pub fn mouseMove(editor: *CodeEditor, x: c_int, y: c_int) void {
    c.scintilla_mouseMove(editor.instance, x - editor.position.x, y - editor.position.y);
}

pub fn mouseDown(editor: *CodeEditor, time_stamp: f32, x: c_int, y: c_int) void {
    c.scintilla_mouseDown(editor.instance, time_stamp, x - editor.position.x, y - editor.position.y);
}

pub fn mouseUp(editor: *CodeEditor, time_stamp: f32, x: c_int, y: c_int) void {
    c.scintilla_mouseUp(editor.instance, time_stamp, x - editor.position.x, y - editor.position.y);
}

pub fn keyDown(editor: *CodeEditor, scancode: zero_graphics.Input.Scancode, shift: bool, ctrl: bool, alt: bool) bool {
    return c.scintilla_keyDown(editor.instance, @enumToInt(scancode), shift, ctrl, alt);
}

pub fn enterString(editor: *CodeEditor, text: []const u8) void {
    c.scintilla_enterString(editor.instance, text.ptr, text.len);
}

pub fn setFocus(editor: *CodeEditor, focused: bool) void {
    c.scintilla_setFocus(editor.instance, focused);
}

const default_editor_impl = c.ZigEditorInterface{
    .createFont = createFont,
    .destroyFont = destroyFont,
    .getFontAscent = getFontAscent,
    .getFontDescent = getFontDescent,
    .getFontLineGap = getFontLineGap,
    .getFontCharWidth = getFontCharWidth,
    .measureStringWidth = measureStringWidth,
    .measureCharPositions = measureCharPositions,
    .drawRectangle = drawRectangle,
    .fillRectangle = fillRectangle,
    .drawString = drawString,
    .setClipRect = setClipRect,
    .setClipboardContent = setClipboardContent,
    .getClipboardContent = getClipboardContent,
    .sendNotification = sendNotification,
};

const PZigApp = *c.ZigAppInterface;
const PZigEditor = *c.ZigEditorInterface;

fn sendNotification(zedit: PZigEditor, notification: u32) callconv(.C) void {
    const self = getEditor(zedit);

    if ((notification & c.NOTIFY_CHANGE) != 0) {
        self.notifications.insert(.text_changed);
    }
}

fn getEditor(zedit: PZigEditor) *CodeEditor {
    return @fieldParentPtr(CodeEditor, "interface", zedit);
}

fn getFont(font: ?*c.ZigFont) *const zero_graphics.Renderer2D.Font {
    return @intToPtr(*const zero_graphics.Renderer2D.Font, @ptrToInt(font));
}

fn getColor(color: c.ZigColor) Color {
    return Color{
        .r = @truncate(u8, color),
        .g = @truncate(u8, color >> 8),
        .b = @truncate(u8, color >> 16),
        .a = @truncate(u8, color >> 24),
    };
}
fn getRect(rect: c.ZigRect) Rectangle {
    return Rectangle{
        .x = @floatToInt(i16, rect.x),
        .y = @floatToInt(i16, rect.y),
        .width = @floatToInt(u15, std.math.max(0, rect.width)),
        .height = @floatToInt(u15, std.math.max(0, rect.height)),
    };
}

export fn zero_graphics_getDisplayDpi() callconv(.C) c_int {
    return @floatToInt(c_int, zero_graphics.getDisplayDPI());
}
export fn zero_graphics_getWidth() callconv(.C) c_int {
    return zero_graphics.CoreApplication.get().screen_size.width;
}
export fn zero_graphics_getHeight() callconv(.C) c_int {
    return zero_graphics.CoreApplication.get().screen_size.height;
}

export fn zero_graphics_alloc(raw_allocator: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), raw_allocator));

    if (size == 0) return null;

    const slice = allocator.alloc(u8, size) catch return null;

    return slice.ptr;
}

export fn zero_graphics_writeLog(log_level: c_uint, msg_ptr: [*]const u8, length: usize) callconv(.C) void {
    const msg = msg_ptr[0..length];
    switch (log_level) {
        c.LOG_DEBUG => log.debug("{s}", .{msg}),
        c.LOG_INFO => log.info("{s}", .{msg}),
        c.LOG_WARN => log.warn("{s}", .{msg}),
        c.LOG_ERROR => log.err("{s}", .{msg}),
        else => unreachable,
    }
}

//////////

fn createFont(zedit: PZigEditor, font_name: [*:0]const u8, font_size: f32) callconv(.C) ?*c.ZigFont {
    const self = getEditor(zedit);

    log.debug("createFont(\"{s}\",{d})", .{ std.mem.sliceTo(font_name, 0), font_size });

    const font_bytes = @embedFile("../ui-data/SourceCodePro-Regular.ttf");

    const font = self.renderer.createFont(font_bytes, @floatToInt(u15, font_size)) catch return null;

    return @intToPtr(*c.ZigFont, @ptrToInt(font));
}

fn destroyFont(zedit: PZigEditor, font: ?*c.ZigFont) callconv(.C) void {
    const self = getEditor(zedit);
    self.renderer.destroyFont(getFont(font));
}

fn getFontAscent(zedit: PZigEditor, font_ptr: ?*c.ZigFont) callconv(.C) f32 {
    _ = zedit;
    const font = getFont(font_ptr);
    return font.scaleValue(font.ascent);
}

fn getFontDescent(zedit: PZigEditor, font_ptr: ?*c.ZigFont) callconv(.C) f32 {
    _ = zedit;
    const font = getFont(font_ptr);
    return -font.scaleValue(font.descent);
}

fn getFontLineGap(zedit: PZigEditor, font_ptr: ?*c.ZigFont) callconv(.C) f32 {
    _ = zedit;
    const font = getFont(font_ptr);
    return font.scaleValue(font.line_gap);
}

fn getFontCharWidth(zedit: PZigEditor, font_ptr: ?*c.ZigFont, char: u32) callconv(.C) f32 {
    const self = getEditor(zedit);
    const font = getFont(font_ptr);

    const glyph = self.renderer.getGlyph(font, @truncate(u21, char)) catch return 0.0;
    return font.scaleValue(glyph.advance_width);
}

fn measureStringWidth(zedit: PZigEditor, font_ptr: ?*c.ZigFont, str: [*]const u8, length: usize) callconv(.C) f32 {
    const self = getEditor(zedit);
    const font = getFont(font_ptr);

    const size = self.renderer.measureString(font, str[0..length]);

    return @intToFloat(f32, size.width);
}

fn measureCharPositions(zedit: PZigEditor, font_ptr: ?*c.ZigFont, str: [*]const u8, length: usize, positions: [*]f32) callconv(.C) void {
    const self = getEditor(zedit);
    const font = getFont(font_ptr);

    var view = std.unicode.Utf8View.init(str[0..length]) catch @panic("invalid utf8 detected!");

    var glyph_offset: f32 = 0.0;
    var str_offset: usize = 0;

    // log.debug("measureCharPositions(\"{s}\")", .{view.bytes});

    var iter = view.iterator();
    while (iter.nextCodepointSlice()) |slice| {
        const codepoint = std.unicode.utf8Decode(slice) catch unreachable;

        var glyph = self.renderer.getGlyph(font, codepoint) catch continue;

        glyph_offset += font.scaleValue(glyph.advance_width);
        for (slice) |_| {
            positions[str_offset] = glyph_offset;
            str_offset += 1;
        }
    }
}

fn patchRect(editor: *CodeEditor, rect: Rectangle) Rectangle {
    return Rectangle{
        .x = editor.position.x + rect.x,
        .y = editor.position.y + rect.y,
        .width = rect.width,
        .height = rect.height,
    };
}

fn drawRectangle(zedit: PZigEditor, rect: *const c.ZigRect, color: c.ZigColor) callconv(.C) void {
    const self = getEditor(zedit);

    self.renderer.drawRectangle(self.patchRect(getRect(rect.*)), getColor(color)) catch {};
}

fn fillRectangle(zedit: PZigEditor, rect: *const c.ZigRect, color: c.ZigColor) callconv(.C) void {
    const self = getEditor(zedit);

    self.renderer.fillRectangle(self.patchRect(getRect(rect.*)), getColor(color)) catch {};
}

fn drawString(zedit: PZigEditor, rect: *const c.ZigRect, font_ptr: ?*c.ZigFont, color: c.ZigColor, str: [*]const u8, length: usize) callconv(.C) void {
    const self = getEditor(zedit);
    const font = getFont(font_ptr);
    const dst_rect = self.patchRect(getRect(rect.*));
    const dst_color = getColor(color);

    self.renderer.drawString(font, str[0..length], dst_rect.x, dst_rect.y, dst_color) catch {};
}

fn setClipRect(zedit: PZigEditor, zrect: *const c.ZigRect) callconv(.C) void {
    const self = getEditor(zedit);
    const rect = getRect(zrect.*);

    self.renderer.setClipRectangle(rect) catch {};
}

fn setClipboardContent(zedit: PZigEditor, str: [*]const u8, length: usize) callconv(.C) void {
    _ = zedit;
    log.err("setClipboardContent(\"{}\") is not implemented yet!", .{
        std.zig.fmtEscapes(str[0..length]),
    });
}

fn getClipboardContent(zedit: PZigEditor, maybe_str: ?[*]u8, max_length: usize) callconv(.C) usize {
    _ = zedit;
    log.err("getClipboardContent({}) is not implemented yet!", .{max_length});
    const dummy = "You should implement clipboarding";
    if (maybe_str) |str| {
        std.mem.copy(u8, str[0..max_length], dummy);
    }
    return dummy.len;
}
