const std = @import("std");
const zg = @import("../zero-graphics.zig");

/// Implements the ear clipping algorithm to triangulate arbitrary N-gons.
/// - `Vertex` is the type of the vertices of the polygons.
/// - `vertexPosition` converts a vertex into a 2D position.
/// - The `Writer` type is similar to `std.io.Writer` which will receive the generated triangles.
///
/// `Writer` needs to have a function `fn(Writer, [3]Vertex) !void` and will be stored in the ear
/// clipping implementation.
///
/// The structure will allocate some temporary memory with a size limit of the largest polygon
/// triangulated.
///
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
        /// All triangles of that polygon will be emitted into the writer passed to `.init()`.
        pub fn appendPolygon(self: *Self, vertices: []const Vertex) !void {
            std.debug.assert(vertices.len >= 3);

            try self.temp_vertices.resize(vertices.len);
            std.mem.copy(Vertex, self.temp_vertices.items, vertices);

            if (windingOrder(self.temp_vertices.items) == .cw) {
                std.mem.reverse(Vertex, self.temp_vertices.items);
            }

            std.debug.assert(windingOrder(self.temp_vertices.items) == .ccw);

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

        fn sign(p1: [2]f32, p2: [2]f32, p3: [2]f32) f32 {
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1]);
        }

        fn pointInTriangle(pt: [2]f32, v1: [2]f32, v2: [2]f32, v3: [2]f32) bool {
            const d1 = sign(pt, v1, v2);
            const d2 = sign(pt, v2, v3);
            const d3 = sign(pt, v3, v1);

            const has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0);
            const has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0);

            return !(has_neg and has_pos);
        }

        fn findOneEar(self: Self) ?usize {
            const temp_vertices = self.temp_vertices.items;

            std.debug.assert(temp_vertices.len >= 3);
            search_loop: for (temp_vertices) |_, index| {
                const lo_bounds = index -| 1;
                const hi_bounds = index + 2;

                const p0 = vertexPosition(temp_vertices[self.leftOf(index)]);
                const p1 = vertexPosition(temp_vertices[index]);
                const p2 = vertexPosition(temp_vertices[self.rightOf(index)]);

                // only accept ears in the right winding order
                if (cross2D(sub(p1, p0), sub(p2, p0)) > 0) {
                    continue;
                }

                // and that contain no other vertices
                var i: usize = 0;
                while (i < lo_bounds) : (i += 1) {
                    if (pointInTriangle(vertexPosition(temp_vertices[i]), p0, p1, p2))
                        continue :search_loop;
                }

                i = hi_bounds;
                while (i < temp_vertices.len) : (i += 1) {
                    if (pointInTriangle(vertexPosition(temp_vertices[i]), p0, p1, p2))
                        continue :search_loop;
                }

                return index;
            }
            return null;
        }

        fn emitEar(self: *Self, i: usize) !void {
            const vert = self.temp_vertices.items[i];
            const left = self.temp_vertices.items[self.leftOf(i)];
            const right = self.temp_vertices.items[self.rightOf(i)];

            try self.target_vertices.emit(.{ left, vert, right });
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
