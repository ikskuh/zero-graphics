//! This package implements a very basic layouting engine that supports hierarchical structures
//! of rectangles, organized as nodes.
//! Each `Node` has its own layout and constraints, the following layouts are supported:
//! - *basic*, a layout that will put each child into the full body
//! - *stack*, a layout that will put children side-by-side
//! - *dock*, a layout that will put children next to a give edge of the container
//! - *flow*, a layout that will behave similar to a text flow. it will try putting as
//!   much items as possible into a row, then will wrap and continue in the next row
//! - *table*, a layout that will put children into table cells
//! - *canvas*, a layout that allows arbitrary positioning of the children
//!

const std = @import("std");
const ui = @import("ui");

pub const Point = ui.Point;
pub const Size = ui.Size;
pub const Rectangle = ui.Rectangle;

/// A rectangle that can either be stored out-of-tree (for example in a widget)
/// or in-tree (in the `Bounds` value itself).
const Bounds = union(enum) {
    storage: Rectangle,
    reference: *Rectangle,

    pub fn set(bounds: *Bounds, value: Rectangle) void {
        switch (bounds.*) {
            .storage => |*val| val.* = value,
            .reference => |ref| ref.* = value,
        }
    }

    pub fn get(bounds: Bounds) Rectangle {
        return switch (bounds.*) {
            .storage => |val| val,
            .reference => |ref| ref.*,
        };
    }
};

pub const Margins = struct {
    left: u15,
    right: u15,
    top: u15,
    bottom: u15,
};

pub const VerticalAlignment = enum {
    /// expands the item to the available horizontal space
    stretch,
    left,
    center,
    right,
};

pub const HorizontalAlignment = enum {
    /// expands the item to the available vertical space
    stretch,
    top,
    middle,
    bottom,
};

/// A node in the layout tree, has a position and size
pub const Node = struct {
    bounds: Bounds,

    min_size: Size,
    max_size: Size,

    children: []Node,
    layout: Layout,

    margin: Margins, // outer margins
    padding: Margins, // inner margins

    vertical_alignment: VerticalAlignment, // layout inside the parent region
    horizontal_alignment: HorizontalAlignment, // layout inside the parent region

    container_layout_data: ContainerLayoutData,
};

pub const ContainerLayoutData = union {
    pub const empty = ContainerLayoutData{ .none = {} };

    /// No data is stored for this node.
    none: void,

    /// On which edge of the parent node is this node docked?
    dock_layout: DockLayout.Site,

    /// Where is the node located inside the parent node?
    canvas_layout: CanvasLayout.Location,

    /// Which cells in the table does our node take up?
    table_layout: TableLayout.Slot,
};

pub const Layout = union(enum) {
    /// all children are layed out in the bounds independent of other children
    basic,

    /// items are put side-by-side
    stack: StackLayout,

    /// items dock on an edge of the parent, the last item is expanded into the rest
    dock: DockLayout,

    /// flow based layout (similar to CSS flex)
    flow: FlowLayout,

    /// row/column based layout
    table: TableLayout,

    /// absolute positioning with (x,y) offset
    canvas: CanvasLayout,
};

pub const StackLayout = struct {
    direction: Direction,

    pub const Direction = enum {
        left_to_right,
        right_to_left,
        top_to_bottom,
        bottom_to_top,
    };
};

pub const DockLayout = struct {
    pub const Site = enum {
        top,
        left,
        right,
        bottom,
    };
};

pub const FlowLayout = struct {
    major_axis: Axis = .row,
    primary_direction: Direction = .increment,
    secondary_direction: Direction = .increment,

    pub const Axis = enum {
        /// the vertical axis
        row,

        /// the horizontal axis
        column,
    };

    pub const Direction = enum {
        increment,
        decrement,
    };
};

pub const TableLayout = struct {
    rows: []const SizeSpecification,
    columns: []const SizeSpecification,

    pub const Slot = struct {
        row: u15,
        column: u15,
        row_span: u15,
        col_span: u15,
    };

    pub const SizeSpecification = union(enum) {
        /// The row/colum will take the given portion of the total width of the element.
        /// Assumes a range between 0.0 and 1.0.
        relative: f32,

        /// The row/column will take exactly this amount of units size.
        absolute: u15,

        /// The row/column will take up leftover space shared with other `flex` elements.
        /// A value of 0.0 means that the element will be at its minimal size,
        /// a value of 1.0 means that the element will share the space at a maximum amount.
        ///
        /// Having a single column with `flex=1.0` will make this column take 100% of the leftover
        /// space from relative + absolute columns.
        ///
        /// Assumes a range between 0.0 and 1.0.
        flex: f32,

        pub const auto = SizeSpecification{ .flex = 0.0 };
        pub const expand = SizeSpecification{ .flex = 1.0 };
    };
};

pub const CanvasLayout = struct {
    /// The reference point is the position of the top-left point of the
    /// canvas.
    /// If this value is modified, the whole canvas content can be shifted
    /// similar to a scroll view.
    reference: Point = Point.zero,

    pub const Location = Point;
};
