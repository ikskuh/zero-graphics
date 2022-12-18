const std = @import("std");
const ui = @import("ui.zig");

const Widget = ui.Widget;

pub const Event = struct {
    //! An event represents something that happened inside a view in response
    //! to a user interaction.
    //!
    //! The most simple example here would be the action of the user clicking a
    //! button and emitting a `on_click` event.
    //!
    //! The event is then put into a queue inside the corresponding `View` and
    //! can be retrieved by the `View.pullEvent` function.

    /// The widget that issued the event.
    sender: *Widget,

    /// Additional data that can be used to handle an event appropiatly.
    data: Data,

    /// The user-provided event handler that lead to the emission of this event.
    /// Can be used to decide what action to perform.
    handler: EventHandler,

    pub const Data = union(enum) {
        none,
    };
};

pub const EventHandler = struct {
    //! An event handler is a user-created and managed structure that allows
    //! identification and attribution of events to their respective widget
    //! or intent.
    //!
    //! For the most simplest variant, event handlers would not be needed, as
    //! a user of the library could reconstruct the required context from a
    //! widget pointer alone, but this is included for performance and
    //! convenience reasons.

    /// User-assigned identifier that allows identification of this
    /// event handler. This should usually be converted from and to an
    /// enum for safety.
    id: u32,

    /// A user-assigned pointer that can provide additional context to a
    /// event, so the code receiving an event can access the required data
    /// easily.
    user_data: ?*anyopaque = null,
};
