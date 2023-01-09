//!
//! A zero-graphics rendering backend.
//!

const std = @import("std");
const ui = @import("zero-ui");
const zg = @import("zero-graphics");
const logger = std.log.scoped(.standard_ui_renderer);

const Point = ui.Point;
const Size = ui.Size;
const Rectangle = ui.Rectangle;
const Color = zg.Color;

const Widget = ui.Widget;
const View = ui.View;
const Control = ui.controls.Control;

pub const Renderer = struct {
    const ControlSet = std.enums.EnumSet(ui.controls.ClassID);

    font_pool: ui.MemoryPool(Font),
    image_pool: ui.MemoryPool(Image),

    graphics: *zg.Renderer2D,
    unsupported: ControlSet = ControlSet.initEmpty(),
    theme: *const Theme = &Theme.default,

    default_font: ui.Font,

    pub fn init(r2d: *zg.Renderer2D) !Renderer {
        var r = Renderer{
            .graphics = r2d,
            .font_pool = ui.MemoryPool(Font).init(r2d.allocator),
            .image_pool = ui.MemoryPool(Image).init(r2d.allocator),

            .default_font = undefined,
        };
        errdefer r.font_pool.deinit();
        errdefer r.image_pool.deinit();

        r.default_font = try r.createFont(
            @embedFile("data/fonts/NotoSans-Regular.ttf"),
            18,
        );
        errdefer r.destroyFont(r.default_font);

        return r;
    }

    pub fn deinit(renderer: *Renderer) void {
        renderer.image_pool.deinit();
        renderer.font_pool.deinit();
        renderer.* = undefined;
    }

    pub fn createFont(renderer: *Renderer, font_data: []const u8, font_size: u15) !ui.Font {
        const inner = try renderer.graphics.createFont(font_data, font_size);
        errdefer renderer.graphics.destroyFont(inner);

        const font = try renderer.font_pool.create();
        errdefer renderer.font_pool.destroy(font);

        font.* = Font{
            .graphics = renderer.graphics,
            .inner = inner,
        };

        return ui.Font{
            .ptr = font,
            .vtable = &Font.vtable,
        };
    }

    pub fn destroyFont(renderer: *Renderer, font: ui.Font) void {
        const font_ref = Font.from(font);
        renderer.graphics.destroyFont(font_ref.inner);
        renderer.font_pool.destroy(font_ref);
    }

    pub fn createImage(renderer: *Renderer, data: []const u8) !ui.Image {
        const rm = &zg.CoreApplication.get().resources;

        const inner = try rm.createTexture(.ui, zg.ResourceManager.DecodeImageData{
            .data = data,
        });
        errdefer rm.destroyTexture(inner);

        const image = try renderer.image_pool.create();
        errdefer renderer.image_pool.destroy(image);

        image.* = Image{
            .graphics = renderer.graphics,
            .inner = inner,
        };

        return ui.Image{
            .ptr = image,
            .vtable = &Image.vtable,
        };
    }
    pub fn destroyImage(renderer: *Renderer, image: ui.Image) void {
        const img = Image.from(image);

        const rm = &zg.CoreApplication.get().resources;

        rm.destroyTexture(img.inner);
        renderer.image_pool.destroy(img);
    }

    const FocusInfo = struct {
        widget: *Widget,
        area: Rectangle,
    };

    const RenderInfo = struct {
        focus: ?FocusInfo = null,
        hover: ?FocusInfo = null,
    };

    pub fn render(renderer: *Renderer, view: View, screen_size: Size) !void {
        var info = RenderInfo{};

        try renderer.renderWidgetList(view, Rectangle.new(Point.zero, screen_size), view.widgets, &info);

        if (info.focus) |focus| {
            try renderer.graphics.drawRectangle(
                focus.area.grow(2),
                Color.red,
            );
        }

        if (@import("builtin").mode == .Debug) {
            // In debug builds, we show the currently hovered widget as well
            if (info.hover) |hover| {
                try renderer.graphics.drawRectangle(
                    hover.area.grow(3),
                    Color.magenta,
                );
            }
        }
    }

    fn renderWidgetList(renderer: *Renderer, view: View, target_area: Rectangle, list: Widget.List, render_info: *RenderInfo) error{OutOfMemory}!void {
        var it = Widget.Iterator.init(list, .bottom_to_top);
        while (it.next()) |widget| {
            try renderer.renderWidget(view, target_area, widget, render_info);
        }
    }

    fn renderWidget(renderer: *Renderer, view: View, target_area: Rectangle, widget: *Widget, render_info: *RenderInfo) error{OutOfMemory}!void {
        if (widget.visibility != .visible)
            return;

        const g = renderer.graphics;

        const position = widget.bounds.position.add(target_area.position());
        const size = widget.bounds.size;
        const area = Rectangle.new(position, size);

        if (widget == view.focus) {
            render_info.focus = FocusInfo{
                .widget = widget,
                .area = area,
            };
        }
        if (widget == view.hovered_widget) {
            render_info.hover = FocusInfo{
                .widget = widget,
                .area = area,
            };
        }

        try g.pushClipRectangle(area);
        defer g.popClipRectangle() catch {};

        try renderer.renderControl(area, widget.control, (widget == view.focus));

        try renderer.renderWidgetList(view, area, widget.children, render_info);
    }

    fn renderControl(renderer: *Renderer, target_area: Rectangle, control: Control, has_focus: bool) error{OutOfMemory}!void {
        const g = renderer.graphics;
        const t = renderer.theme;

        // see if the control has a function
        //     fn standardRender(control: ControlType, renderer: *zero_graphics.Renderer2D, theme: *Theme, rectangle: Rectangle) !void
        // and if so, invoke that function instead of using the default path
        switch (control) {
            inline else => |ctrl| {
                if (@hasDecl(@TypeOf(ctrl), "standardRender")) {
                    try ctrl.standardRender(g, t, target_area);
                    return;
                }
            },
        }

        const b = target_area;
        if (b.width < 4 or b.height < 4) // ignore all elements that are too small
            return;

        switch (control) {
            .Label => |label| {
                // TODO: Draw label text!

                if (label.text) |text| {
                    try g.drawText(
                        Font.from(label.font orelse renderer.default_font).inner,
                        text,
                        b,
                        .{
                            .color = t.text,
                            .vertical_alignment = label.vertical_alignment orelse .top,
                            .horizontal_alignment = label.horizontal_alignment orelse .left,
                        },
                    );
                }
            },

            .Panel => {
                try g.fillRectangle(b, t.area);
                try g.drawRectangle(Rectangle{
                    .x = b.x + 1,
                    .y = b.y,
                    .width = b.width - 1,
                    .height = b.height - 1,
                }, t.area_light);
                try g.drawRectangle(Rectangle{
                    .x = b.x,
                    .y = b.y + 1,
                    .width = b.width - 1,
                    .height = b.height - 1,
                }, t.area_shadow);
            },

            .Button => |button| {
                try g.fillRectangle(b.shrink(1), t.area);

                if (b.width > 2 and b.height > 2) {
                    try g.drawLine(
                        b.x + 1,
                        b.y,
                        b.x + b.width - 2,
                        b.y,
                        t.area_light,
                    );
                    try g.drawLine(
                        b.x + 1,
                        b.y + b.height - 1,
                        b.x + b.width - 2,
                        b.y + b.height - 1,
                        t.area_shadow,
                    );

                    try g.drawLine(
                        b.x,
                        b.y + 1,
                        b.x,
                        b.y + b.height - 2,
                        t.area_shadow,
                    );
                    try g.drawLine(
                        b.x + b.width - 1,
                        b.y + 1,
                        b.x + b.width - 1,
                        b.y + b.height - 2,
                        t.area_light,
                    );
                }

                if (button.text) |text| {
                    try g.drawText(
                        Font.from(button.font orelse renderer.default_font).inner,
                        text,
                        b.shrink(2),
                        .{
                            .color = t.text,
                            .vertical_alignment = .center,
                            .horizontal_alignment = .center,
                        },
                    );
                }
            },

            .TextBox => |text_box| {
                try g.fillRectangle(b.shrink(1), if (text_box.flags.read_only)
                    t.area
                else
                    t.window);

                if (b.width > 2 and b.height > 2) {
                    try g.drawLine(
                        b.x,
                        b.y,
                        b.x + b.width - 1,
                        b.y,
                        t.area_shadow,
                    );
                    try g.drawLine(
                        b.x + b.width - 1,
                        b.y + 1,
                        b.x + b.width - 1,
                        b.y + b.height - 1,
                        t.area_shadow,
                    );

                    try g.drawLine(
                        b.x,
                        b.y + 1,
                        b.x,
                        b.y + b.height - 1,
                        t.area_light,
                    );
                    try g.drawLine(
                        b.x + 1,
                        b.y + b.height - 1,
                        b.x + b.width - 2,
                        b.y + b.height - 1,
                        t.area_light,
                    );
                }

                const font = Font.from(text_box.font orelse renderer.default_font);
                const text = text_box.getText();
                const line_height = font.inner.getLineHeight();

                const dy = (b.height -| line_height) / 2;

                try g.drawString(
                    font.inner,
                    text,
                    b.x + 2,
                    b.y + dy,
                    t.text,
                );

                if (has_focus) {
                    const timestamp = @bitCast(u64, std.time.milliTimestamp() +% std.math.minInt(i64));
                    if ((timestamp % t.blink_interval) >= t.blink_interval / 2) {
                        const cursor_position = text_box.getCursor();

                        var iter = std.unicode.Utf8View.initUnchecked(text).iterator();
                        var end_pos: usize = 0;
                        var count: usize = 0;
                        while (iter.nextCodepointSlice()) |cps| : (count += 1) {
                            if (count == cursor_position)
                                break;
                            end_pos +|= cps.len;
                        }

                        const substring = text[0..end_pos];

                        const rect = font.graphics.measureString(font.inner, substring);

                        try g.drawLine(
                            b.x + 2 + rect.width,
                            b.y + dy,
                            b.x + 2 + rect.width,
                            b.y + dy + line_height,
                            t.text_cursor,
                        );
                    }
                }
            },

            .Picture => |pic| if (pic.image) |image| {
                const image_size = image.getSize();

                // aspects, if > 1.0, the width is bigger than the height
                const image_aspect = @intToFloat(f32, image_size.width) / @intToFloat(f32, image_size.height);
                const target_aspect = @intToFloat(f32, b.width) / @intToFloat(f32, b.height);

                const dest_size = switch (pic.size) {
                    .unscaled => image_size,
                    .centered => image_size,
                    .stretch => Size.new(b.width, b.height),
                    .zoom => if (target_aspect < image_aspect)
                        Size.new(b.width, @floatToInt(u15, @intToFloat(f32, b.width) / image_aspect))
                    else
                        Size.new(@floatToInt(u15, @intToFloat(f32, b.height) * image_aspect), b.height),
                    .cover => if (target_aspect > image_aspect)
                        Size.new(b.width, @floatToInt(u15, @intToFloat(f32, image_size.width) / target_aspect))
                    else
                        Size.new(@floatToInt(u15, @intToFloat(f32, image_size.height) * target_aspect), b.height),
                    .contain => if (image_size.width < b.width and image_size.height < b.height)
                        image_size
                    else if (target_aspect < image_aspect)
                        Size.new(b.width, @floatToInt(u15, @intToFloat(f32, b.width) / image_aspect))
                    else
                        Size.new(@floatToInt(u15, @intToFloat(f32, b.height) * image_aspect), b.height),
                };

                const dest_offset = switch (pic.size) {
                    .unscaled, .stretch => Point.new(0, 0),
                    .centered, .zoom, .cover, .contain => Point.new(
                        @divFloor(@as(i16, b.width) - dest_size.width, 2),
                        @divFloor(@as(i16, b.height) - dest_size.height, 2),
                    ),
                };

                try renderer.graphics.drawTexture(Rectangle.new(dest_offset.add(Point.new(b.x, b.y)), dest_size), Image.from(image).inner, pic.tint);
            },

            else => {
                // unsupported widget, draw a red box with a white outline and a cross
                try g.fillRectangle(target_area, Color.red);
                try g.drawRectangle(target_area, Color.white);
                try g.drawLine(target_area.x, target_area.y, target_area.x + target_area.width - 1, target_area.y + target_area.height - 1, Color.white);
                try g.drawLine(target_area.x, target_area.y + target_area.height - 1, target_area.x + target_area.width - 1, target_area.y, Color.white);

                if (!renderer.unsupported.contains(control)) {
                    renderer.unsupported.insert(control);
                    logger.err("Encountered unsupported widget type: {s}", .{@tagName(control)});
                }
            },
        }
    }
};

pub const Theme = struct {
    window: Color, // filling for text-editable things like text boxes, ...

    area: Color, // filling for panels, buttons, (read only) text boxes, ...
    area_light: Color, // a brighter version of `area`
    area_shadow: Color, // a darker version of `area`

    label: Color, // the text of a label
    text: Color, // the text of a button, text box, ...

    focus: Color, // color of the dithered focus border
    text_cursor: Color, // color of the text cursor

    blink_interval: u32, // cursor blink interval in milliseconds

    pub const default = Theme{
        .window = Color.rgb(0xde, 0xee, 0xd6),
        .area = Color.rgb(0x75, 0x71, 0x61),
        .area_light = Color.rgb(0x85, 0x95, 0xa1),
        .area_shadow = Color.rgb(0x4e, 0x4a, 0x4e),
        .label = Color.rgb(0xde, 0xee, 0xd6),
        .text = Color.rgb(0x14, 0x0c, 0x1c),
        .focus = Color.rgb(0x44, 0x24, 0x34),
        .text_cursor = Color.rgb(0x30, 0x34, 0x6d),
        .blink_interval = 1000,
    };
};

pub const Font = struct {
    const vtable = ui.Font.VTable{
        .getLineHeightFn = font_getLineHeight,
        .measureStringFn = font_measureString,
    };

    graphics: *zg.Renderer2D,
    inner: *const zg.Renderer2D.Font,

    inline fn cast(ptr: *anyopaque) *Font {
        return @ptrCast(*Font, @alignCast(@alignOf(Font), ptr));
    }

    pub fn from(font: ui.Font) *Font {
        std.debug.assert(font.vtable == &vtable);
        return cast(font.ptr);
    }

    fn font_getLineHeight(font_ptr: *anyopaque) u15 {
        const font = cast(font_ptr);
        return font.inner.getLineHeight();
    }

    fn font_measureString(font_ptr: *anyopaque, text: []const u8) u15 {
        const font = cast(font_ptr);

        const size = font.graphics.measureString(font.inner, text);

        return size.width;
    }
};

pub const Image = struct {
    const vtable = ui.Image.VTable{
        .getSizeFn = getSize,
    };

    graphics: *zg.Renderer2D,
    inner: *zg.ResourceManager.Texture,

    inline fn cast(ptr: *anyopaque) *Image {
        return @ptrCast(*Image, @alignCast(@alignOf(Image), ptr));
    }

    pub fn from(image: ui.Image) *Image {
        std.debug.assert(image.vtable == &vtable);
        return cast(image.ptr);
    }

    fn getSize(image_ptr: *anyopaque) ui.Size {
        const img = cast(image_ptr);
        return ui.Size.new(img.inner.width, img.inner.height);
    }
};
