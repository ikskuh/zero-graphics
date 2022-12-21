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

    graphics: *zg.Renderer2D,
    unsupported: ControlSet = ControlSet.initEmpty(),

    pub fn init(r2d: *zg.Renderer2D) !Renderer {
        return Renderer{
            .graphics = r2d,
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        renderer.* = undefined;
    }

    pub fn render(renderer: *Renderer, view: View, screen_size: Size) !void {
        try renderer.renderWidgetList(view, Rectangle.new(Point.zero, screen_size), view.widgets);
    }

    fn renderWidgetList(renderer: *Renderer, view: View, target_area: Rectangle, list: Widget.List) error{OutOfMemory}!void {
        var it = Widget.Iterator.init(list, .bottom_to_top);
        while (it.next()) |widget| {
            try renderer.renderWidget(view, target_area, widget);
        }
    }

    fn renderWidget(renderer: *Renderer, view: View, target_area: Rectangle, widget: *Widget) error{OutOfMemory}!void {
        if (widget.visibility != .visible)
            return;

        const g = renderer.graphics;

        const position = widget.bounds.position.add(target_area.position());
        const size = widget.bounds.size;
        const area = Rectangle.new(position, size);

        try g.pushClipRectangle(area);
        defer g.popClipRectangle() catch {};

        try renderer.renderControl(area, widget.control);

        try renderer.renderWidgetList(view, area, widget.children);
    }

    fn renderControl(renderer: *Renderer, target_area: Rectangle, control: Control) error{OutOfMemory}!void {
        const g = renderer.graphics;

        // see if the control has a function
        //     fn standardRender(ControlType, *zero_graphics.Renderer2D, rectangle: Rectangle) !void
        // and if so, invoke that function instead of using the default path
        switch (control) {
            inline else => |ctrl| {
                if (@hasDecl(@TypeOf(ctrl), "standardRender")) {
                    try ctrl.standardRender(g, target_area);
                    return;
                }
            },
        }

        switch (control) {
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
