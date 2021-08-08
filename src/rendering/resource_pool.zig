const std = @import("std");

pub fn ResourcePool(comptime Resource: type, comptime Context: type, destruct: fn (Context, *Resource) void) type {
    return struct {
        const Self = @This();

        const Item = struct {
            refcount: usize,
            resource: Resource,
        };

        const List = std.TailQueue(Item);
        const Node = std.TailQueue(Item).Node;

        arena: std.heap.ArenaAllocator,
        list: List,
        free_list: List,

        pub fn init(allocator: *std.mem.Allocator) Self {
            return Self{
                .arena = std.heap.ArenaAllocator.init(allocator),
                .list = List{},
                .free_list = List{},
            };
        }

        pub fn deinit(self: *Self, context: Context) void {
            while (self.list.first) |node| {
                self.destroy(context, node);
            }
            self.arena.deinit();
            self.* = undefined;
        }

        fn getNode(resource: *Resource) *Node {
            const item = @fieldParentPtr(Item, "resource", resource);
            const node = @fieldParentPtr(Node, "data", item);
            return node;
        }

        /// Creates a duplicate of the given resource and will return a pool-interned variant
        /// that can be passed around.
        /// Will have its resource count set to 1 for convenience.
        pub fn allocate(self: *Self, resource: Resource) error{OutOfMemory}!*Resource {

            // try pulling a node from the free list before allocating new memory.
            // by using both an arena and a free-list, cache locality is quite good
            // and allocation count is kept low. this is both useful for quick
            // alloc/release cycles as well as for long-lasting allocations.
            const node = if (self.free_list.pop()) |old_node|
                old_node
            else
                try self.arena.allocator.create(Node);
            node.* = .{
                .data = .{
                    .refcount = 1,
                    .resource = resource,
                },
            };
            self.list.append(node);
            return &node.data.resource;
        }

        /// Increases the reference count by one.
        pub fn retain(self: *Self, resource: *Resource) void {
            _ = self;
            const node = getNode(resource);
            std.debug.assert(node.data.refcount > 0);
            node.data.refcount += 1;
        }

        /// Reduces the reference count by one and destroys the resource if necessary.
        pub fn release(self: *Self, context: Context, resource: *Resource) void {
            const node = getNode(resource);
            std.debug.assert(node.data.refcount > 0);
            node.data.refcount -= 1;
            if (node.data.refcount == 0)
                self.destroy(context, node);
        }

        /// Destroys the resource immediatly. Bypasses all reference counting
        fn destroy(self: *Self, context: Context, node: *Node) void {
            self.list.remove(node);

            destruct(context, &node.data.resource);
            node.* = undefined;

            // Just recycle the node into a free list and
            // reuse that memory later.
            self.free_list.append(node);
        }
    };
}
