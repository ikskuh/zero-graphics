const std = @import("std");
const zg = @import("../zero-graphics.zig");

pub fn EarClipper(
    comptime Vertex: type,
    comptime vertexPosition: fn (Vertex) [2]f32,
    comptime Writer: type,
) type {
    return struct {
        const Self = @This();

        temp_vertices: std.ArrayList(Vertex),
        target_vertices: Writer,

        pub fn init(allocator: std.mem.Allocator, writer: Writer) Self {
            return Self{
                .temp_vertices = std.ArrayList(Vertex).init(allocator),
                .target_vertices = writer,
            };
        }

        pub fn deinit(self: *Self) void {
            self.temp_vertices.deinit();
            self.* = undefined;
        }

        /// Appends a polygon to the current triangle soup.
        pub fn appendPolygon(self: *Self, vertices: []const Vertex) !void {
            try self.temp_vertices.resize(vertices.len);
            std.mem.copy(Vertex, self.temp_vertices.items, vertices);

            if (windingOrder(vertices) == .cw) {
                std.mem.reverse(Vertex, self.temp_vertices.items);
            }

            std.debug.assert(windingOrder(vertices) == .ccw);

            try self.flush();
        }

        pub const WindingOrder = enum { cw, ccw };
        fn windingOrder(vertices: []const Vertex) WindingOrder {
            return if (signedPolygonArea(vertices) > 0)
                .ccw
            else
                .cw;
        }

        fn signedPolygonArea(vertices: []const Vertex) f32 {
            var signed_area: f32 = 0.0;
            var p0 = vertexPosition(vertices[vertices.len - 1]);
            for (vertices) |pt| {
                var p1 = vertexPosition(pt);
                signed_area += cross2D(p0, p1);
            }
            return signed_area / 2;
        }

        fn leftOf(self: Self, i: usize) usize {
            return if (i == 0) self.temp_vertices.items.len - 1 else i - 1;
        }

        fn rightOf(self: Self, i: usize) usize {
            return (i + 1) % self.temp_vertices.items.len;
        }

        const Form = enum { concave, convex };
        fn convexity(self: Self, i: usize) Form {
            const vert = vertexPosition(self.temp_vertices.items[i]);
            const left = vertexPosition(self.temp_vertices.items[self.leftOf(i)]);
            const right = vertexPosition(self.temp_vertices.items[self.rightOf(i)]);

            const total = [2]f32{
                right[0] - left[0],
                right[1] - left[1],
            };

            const delta = [2]f32{
                vert[0] - left[0],
                vert[1] - left[1],
            };

            const dp = dot(total, delta);
            if (dp < 0)
                return .concave;
            return .convex;
        }

        fn dot(a: [2]f32, b: [2]f32) f32 {
            return a[0] * b[0] + a[1] * b[1];
        }

        fn cross2D(a: [2]f32, b: [2]f32) f32 {
            return a[0] * b[1] - a[1] * b[0];
        }

        fn sub(a: [2]f32, b: [2]f32) [2]f32 {
            return .{
                a[0] - b[0],
                a[1] - b[1],
            };
        }

        fn findOneEar(self: Self) ?usize {
            std.debug.assert(self.temp_vertices.items.len >= 3);
            for (self.temp_vertices.items) |_, i| {
                if (self.convexity(i) != .convex)
                    continue;
                if (self.convexity(self.leftOf(i)) != .convex)
                    continue;
                if (self.convexity(self.rightOf(i)) != .convex)
                    continue;
                return i;
            }
            return null;
        }

        fn emitEar(self: *Self, i: usize) !void {
            const vert = self.temp_vertices.items[i];
            const left = self.temp_vertices.items[self.leftOf(i)];
            const right = self.temp_vertices.items[self.rightOf(i)];

            // const p0 = vertexPosition(vert);
            // const p1 = vertexPosition(left);
            // const p2 = vertexPosition(right);

            // only push triangles out with the right winding order.
            // if (cross2D(sub(p1, p0), sub(p2, p0)) > 0) {
            try self.target_vertices.emit(.{ left, vert, right });
            // }
        }

        fn flush(self: *Self) !void {
            while (self.temp_vertices.items.len > 3) {
                const ear = self.findOneEar() orelse return error.NoEarFound;

                try self.emitEar(ear);

                _ = self.temp_vertices.orderedRemove(ear);
            }

            try self.emitEar(0);
        }
    };
}
