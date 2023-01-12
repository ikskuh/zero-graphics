//! The panel is a dead simple control to organize several widgets
//! into a logical group.
//! Panels are most prominent by showing a border around their contents.

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return false;
}

pub fn isHitTestVisible(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}
