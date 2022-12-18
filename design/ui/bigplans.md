# The Big UI Rework

## Goals

- zero-alloc as long as possible
- allow dynamic ui structures
- automatic or manual layouting with layout engines
- allows design with a template language
- "bindable" properties
- bindable children based on templates
- template selection based on value
- decoupling of widget logic, layout, rendering, input and styling
- only use callbacks when absolutely necessary
- good code interface, so one can easily build UIs from source code
- supports animations
- user-definable look-and-feel
- custom widgets

## Solutions

### zero-alloc as long as possible

Using linked-lists instead of slices, and storing the objects out-of-tree with pools for dynamic elements and static allocation (array, declaration) makes memory management easy to handle

### allow dynamic ui structures

using linked lists, inserts and removals of nodes or subtrees are cheap operations, so this can easily be solved

### automatic or manual layouting with layout engines

making widgets only have a position + size property makes it easy to create layouts by external means, so layouting engines
can just refer to the widget rectangles + store constraints to implement layouting

the widget logic can then use the rectangles to perform all required transitions

### allows design with a template language

this can be implemented completely as a precompilation step, which will then create zig code that implements the creation and management
of the specified UI layout. this way, it is not a runtime, but buildtime component, making it non-coupled by design

### "bindable" properties

support an "object model" that can model objects with properties, similar to JS objects.

### bindable children based on templates

**dependency:** binding system

allow the "children" property of a widget to be bound, one needs to define a template that is instantiated to each item in the list.
the new widget tree then receives the list item as a binding context.

### template selection based on value

**dependency:** binding system, templated children

using a predicate system could allow to simulate classes/inheritance/type detection. would require code, which is okay.

based on that code, a template is then selected. this means different templates can be used for non-homogenenous objects

### decoupling of widget logic, layout, rendering, input and styling

input can be abstracted away completly into a single `pushInput` function that takes an abstract input
event (`mouse_moved: Point`, `mouse_down: Button`, `mouse_up: Button`, `key_down: Key`, ...), so it's not
dependend on any input framework whatsoever.

rendering can be done by inspecting widgets and painting them, so there can be more than one renderer
for a given widget structure.

layouting can also be decoupled by having a Widget/Node interface that exposes min/max/size and position

### only use callbacks when absolutely necessary

most UI events don't have to be handled synchronously (aka: when the event is processed inside the widget logic), but
can be buffered and be yielded later by a `pollEvent` function. As UIs cannot emit

### good code interface, so one can easily build UIs from source code

> this is a hard one, how could that looks like? model something like the UI markup language?
> maybe a begin/end style api for building the widget tree?

### supports animations

transitional animations based on properties changes should be easy to implement. in a similar fashion,
a regular "key frame animation" could be implemented.

only "interpolatable" properties should be animatable

### user-definable look-and-feel

the default renderer should support CSS based properties, so it's easy to style widgets and define basic
animations for `:hover`, `:focus` and so on.

also having a custom renderer resolves this problem entirely

### custom widgets

> how to do custom widgets?
>
> - `root`-object configuration style?
> - make the whole UI code generic?

A nice solution would be to make a package `widgets` that exports all possible widget types into
`ui.widgets`. This way, a configuration can be achieved in the build script, and arbitrary composition
of widgets is possible, even combining several expansion packs.

## Planned Standard Widgets

- Label
- Button
- Menu Bar
- Tool Bar
- Tool Button
- Scroll Bar
- Scroll Panel
- Panel
- Group Box
- Text Box
- Rich Text Editor
- Code Editor
- Check Box
- Radio Button
- Tab View
- Numeric Up/Down
- Combo Box
- Context Menu
- Tree View
- List Box
- Status Bar
- Picture
- Canvas
- Dock Window

## Standard Properties

- cursor
- background color
- text color
- allow drop
- background image
- background image size
- context menu
- enabled
- font, font size, font style
- min size
- max size
- preferred size
- tag
- visibility

## Standard Events

- on_click
- on_double_click
- on_focus
- on_leave
- on_mouse_enter
- on_mouse_leave
- on_mouse_move
- on_mouse_down
- on_mouse_up
- on_key_down
- on_key_up
- on_text_input
- on_hover
- on_property_changed
- on_children_changed
- on_drag_enter
- on_drag_leave
- on_drag_over
- on_drag_drop

## Standard Layout Engine

Provides the following layout styles:

- Basic Layout
- Stack Layout
- Dock Layout
- Flow Layout
- Table Layout
- Canvas Layout
