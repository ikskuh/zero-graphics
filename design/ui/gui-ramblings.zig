//! xq @ UTC+2 (MasterQ32 @ GitHub) — gestern um 22:01 Uhr
//! more gui thoughts:
//!
//! i stopped using tree structures for my UIs and return to flat, ordered lists. this made the implementations sinpler by magnitudes, and one could always build stuff like a 'container' widget which would make it hierarchical by nesting UIs.
//!
//! right now, dunstwolke uses a immediate mode interface, which is now borked by a bugfix in stage2.
//!
//! now i'm thinking about how to decouple styling, layout and logic of the ui. also i'm still not sure how to manage UI events. i really dislike the callback approach of wpf/qt/winforms/...
//! compared to callbacks, immediate mode interfaces are very convenient to program, so i wonder if i can use a similar interface for a retained guy, for example a pull interface:
//! gui.pushInput(.mouse_down);
//! gui.pushInput(.mouse_up);
//!
//! while(gui.pullEvent()) |evt| {
//!   process(evt);
//! }
//! such an interface would fit the zig spirit well i guess
//! i was using a simple Event enumeration for such events, but i guess its better to enrich them with more infos
//! so for layouting:
//!
//! assuming each widget has properties like position, size, min- and size, we can then use "external" means to implement a layout engine on top of that. layout engines have to be in a hierarchical tree structure for most stuff, except for solver-based ones (which are hard to control)
//! so having a tree for layouts, layout nodes can point to 'target rectangles'
//! allowing the layout engine to move widgets around without coupling them
//! hm. good thing about this design: it can be made zero-alloc except for dynamic layouts, or text input fields
//! i guess the main thing that bugged me about UI layouting is that the layout engine has to know about the size of strings

const gui = struct {
    /// A view is a "scene" that displays widgets and manages input and event processing.
    /// It can be considered a "screen" or "window".
    const View = struct {
        widgets: []Widget,

        event_queue: RingBuffer(Event),

        /// Sends input to the UI system and processes it. When events are generated, they are
        /// put into the event queue and can be received with ´fetchEvent`.
        pub fn sendInput(view: *View, input: Input) void;

        /// Returns an event if there was any since the last call.
        /// You should call this as long as a non-`null` value is returned.
        /// Each `sendInput` call can generate events, sometimes more than one.
        pub fn fetchEvent(view: *View) ?Event;
    };

    const Input = union(enum) {
        mouse_down: MouseButton,
        mouse_up: MouseButton,
        mouse_motion: Point,
        mouse_wheel: i16,

        key_pressed: struct { KeyCode, KeyboardModifiers },
        key_released: struct { KeyCode, KeyboardModifiers },
        text_input: []const u8,
    };

    const EventHandler = struct {
        user_data: ?*anyopaque,
        id: u32,
    };

    const Event = struct {
        widget: *Widget,
        handler: EventHandler,
        data: Data,

        const Data = union(enum) {
            none,
            radio_group: *RadioGroup,
            key: KeyCode,
        };
    };

    const Widget = struct {
        // logic properties:
        control: Control,

        // common events:
        on_enter: ?EventHandler,
        on_leave: ?EventHandler,

        // layout properties:
        bounds: Rectangle,
    };

    const Control = union(enum) {
        button: Button, // a button that can be clicked by the user
        check_box: CheckBox, // a box that can be checked or unchecked
        radio_button: RadioButton, // a button withing a group where only one could be selected
        label: Label, // a text label
        text_box: TextBox, // a single-line text editor
        text_editor: TextEditor, // a multi-line text editor
        picture: Picture, // a control displaying an image
        panel: Panel, // a visual group of controls
    };

    const Button = struct {
        on_click: ?EventHandler,
        text: []const u8,
    };

    const CheckBox = struct {
        checked: bool,
        on_checked_changed: ?EventHandler,
        text: []const u8,
    };

    const RadioButton = struct {
        group: *RadioGroup,
        index: u32,
        text: []const u8,
    };

    const RadioGroup = struct {
        selection: ?u32,
        on_selection_changed: ?EventHandler,
    };

    const Label = struct {
        text: []const u8,
        on_click: ?EventHandler,
        is_link: bool,
    };

    const TextBox = struct {
        text_buffer: std.ArrayList(u8),
        password_box: bool = false,

        on_text_changed: ?EventHandler,
        on_return_pressed: ?EventHandler,
        on_escape_pressed: ?EventHandler,

        on_key_press: ?EventHandler,
    };
};

/// initialize a layout node from a given widget, using the reference
/// mode of the node to keep a back-reference to the widget.
/// margins and paddings are set up correctly.
fn layoutNodeForWidget(widget: *gui.Widget) layout_engine.Node {
    return switch (widget.control) {
        // ...
    };
}

// usage example

// Window {
//     Picture {
//         image:                "wallpaper.png";
//         image-size:           fill;
//         horizontal-alignment: stretch;
//         vertical-alignment:   stretch;
//     }
//     Panel {
//         TableLayout {
//             columns: 2;
//             rows:    auto;
//             width:   400px;
//
//             Label {
//                 text: "Username:";
//                 horizontal-alignment: right;
//             }
//
//             TextBox {
//                 horizontal-alignment: stretch;
//             }
//
//             Label {
//                 text: "Password:";
//                 horizontal-alignment: right;
//             }
//
//             TextBox {
//                 horizontal-alignment: stretch;
//                 password-box:         true;
//             }
//
//             Button {
//                 text: "Cancel";
//                 horizontal-alignment: left;
//             }
//
//             Button {
//                 text: "Login";
//                 horizontal-alignment: right;
//             }
//         }
//     }
// }

fn init() void {
    var view = gui.View{};

    var widgets = WidgetCollection.init(&view, allocator);
    defer widgets.deinit();

    var builder = UI_Builder.init(&widgets);
    builder.setLayout(.basic); // root node has basic layout

    try builder.add(Picture.new(background_image));
    builder.widget().control.picture.size = .fill; // modify the last added widget
    builder.setAlignment(.stretch, .stretch);

    try builder.add(Panel.new());
    try builder.push(.{ // set layout and start adding children to this element
        .table = .{
            .columns = 2,
            .rows = 3,
        },
    });

    try builder.add(Label.new("Username:"));
    builder.setHorizontalAlignment(.right); // modify the last created layout node

    try builder.add(Label.textBox(""));
    builder.setHorizontalAlignment(.stretch);

    try builder.add(Label.new("Password:"));
    builder.setHorizontalAlignment(.right);

    try builder.add(Label.textBox(""));
    builder.widget().control.text_box.password_box = true; // modify the last added widget
    builder.setHorizontalAlignment(.stretch);

    try builder.add(Button.new("Cancel"));
    builder.setHorizontalAlignment(.left);

    try builder.add(Button.new("Login"));
    builder.setHorizontalAlignment(.right);

    builder.pop(); // remove the current scope

    var root_layout = builder.finalize();
}
