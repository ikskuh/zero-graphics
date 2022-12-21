const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime cap: comptime_int) type {
    const IndexType = if (cap <= 0x40)
        u8
    else if (cap <= 0x4000)
        u16
    else if (cap <= 0x40000000)
        u32
    else
        @compileError("Capacity of ring buffer is too big!");

    return struct {
        const Self = @This();

        items: [cap]T = undefined,
        read: IndexType = 0,
        write: IndexType = 0,

        /// Returns the maximum amount of items in the ring.
        pub fn capacity(_: Self) usize {
            return cap;
        }

        /// Returns true if no items in are in the ring.
        pub fn empty(ring: Self) bool {
            return (ring.read == ring.write);
        }

        /// Returns true if the ring is completly full.
        pub fn full(ring: Self) bool {
            return (ring.write >= cap) and (ring.read == ring.write - cap);
        }

        /// Returns the amount of items in the ring.
        pub fn count(ring: Self) usize {
            return ring.write - ring.read;
        }

        /// Pushes an item into the ring, removing the last item if the ring is full.
        pub fn push(buffer: *Self, value: T) void {
            buffer.items[buffer.write % cap] = value;

            if (buffer.write >= cap and buffer.read == buffer.write - cap) {
                // if we were at full capacity, "remove" the last item
                buffer.read += 1;
            }

            buffer.write += 1;

            // if both read and write pointer are shifted by one capacity,
            // we can move both back without destroying any information
            if (buffer.read >= cap and buffer.write >= cap) {
                buffer.read -= cap;
                buffer.write -= cap;
            }
        }

        /// Pulls an item from the ring if any.
        pub fn pull(buffer: *Self) ?T {
            if (buffer.read == buffer.write) {
                return null;
            }
            const item = buffer.items[buffer.read % cap];
            buffer.read += 1;
            return item;
        }
    };
}

test RingBuffer {
    var buffer = RingBuffer(u32, 4){};

    try std.testing.expectEqual(true, buffer.empty());
    try std.testing.expectEqual(false, buffer.full());
    try std.testing.expectEqual(@as(usize, 0), buffer.count());
    try std.testing.expectEqual(@as(usize, 4), buffer.capacity());

    // test empty by default, don't corrupt on consecutive pull
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // test push single, pop single
    buffer.push(1);

    try std.testing.expectEqual(@as(?u32, 1), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // test push to some percent of capacity, pop all
    buffer.push(1);
    buffer.push(2);
    try std.testing.expectEqual(@as(?u32, 1), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 2), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // test push to capacity, pop all
    buffer.push(1);
    buffer.push(2);
    buffer.push(3);
    buffer.push(4);
    try std.testing.expectEqual(@as(?u32, 1), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 2), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 3), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 4), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // push to overflow, pop 4

    buffer.push(1);
    buffer.push(2);
    buffer.push(3);
    buffer.push(4);
    buffer.push(5);
    try std.testing.expectEqual(@as(?u32, 2), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 3), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 4), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 5), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // push way over the overflow

    {
        var i: u32 = 1;
        while (i <= 1000) : (i += 1) {
            buffer.push(i);
        }
    }
    try std.testing.expectEqual(@as(?u32, 997), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 998), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 999), buffer.pull());
    try std.testing.expectEqual(@as(?u32, 1000), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());
    try std.testing.expectEqual(@as(?u32, null), buffer.pull());

    // Test status functions

    try std.testing.expectEqual(true, buffer.empty());
    try std.testing.expectEqual(false, buffer.full());
    try std.testing.expectEqual(@as(usize, 0), buffer.count());
    try std.testing.expectEqual(@as(usize, 4), buffer.capacity());

    buffer.push(0);

    try std.testing.expectEqual(false, buffer.empty());
    try std.testing.expectEqual(false, buffer.full());
    try std.testing.expectEqual(@as(usize, 1), buffer.count());
    try std.testing.expectEqual(@as(usize, 4), buffer.capacity());

    buffer.push(0);

    try std.testing.expectEqual(false, buffer.empty());
    try std.testing.expectEqual(false, buffer.full());
    try std.testing.expectEqual(@as(usize, 2), buffer.count());
    try std.testing.expectEqual(@as(usize, 4), buffer.capacity());

    buffer.push(0);
    buffer.push(0);

    try std.testing.expectEqual(false, buffer.empty());
    try std.testing.expectEqual(true, buffer.full());
    try std.testing.expectEqual(@as(usize, 4), buffer.count());
    try std.testing.expectEqual(@as(usize, 4), buffer.capacity());
}
