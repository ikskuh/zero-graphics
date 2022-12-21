text: []const u8,

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return false;
}
