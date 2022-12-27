//!
//! Implementation of a single-line text editor
//!

const Flags = packed struct {
    password: bool = false,
    read_only: bool = false,
};

flags: Flags = .{},

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}

pub fn isHitTestVisible(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}
