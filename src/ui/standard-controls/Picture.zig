const std = @import("std");
const ui = @import("ui");

image: ?ui.Image = null,
size: ImageSize = .contain,
tint: ?ui.Color = null,

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return false;
}

pub fn isHitTestVisible(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}

pub const ImageSize = enum {
    /// The image will be rendered aligned top-left without any scaling. Any excess is cut off.
    unscaled,

    /// The image will be rendered centered without any scaling. Any excess is cut off.
    centered,

    /// scales to fit, the image fills as much as possible of the widget without cutting borders.
    /// This is useful for picture viewers.
    zoom,

    /// scales to fill, 100% of the widget area is filled with the image without squishing the image.
    /// This is useful for backgrounds.
    cover,

    /// scales to fit if the image is larger than the widget, otherwise centered the image.
    /// This is useful for picture viewers.
    contain,

    /// scales to fill, the image is stretched to the aspect of the widget.
    /// This is useful for nice gradient backgrounds.
    stretch,
};
