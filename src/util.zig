const std = @import("std");
pub const Allocator = std.mem.Allocator;
pub const List = std.ArrayList;
pub const Map = std.AutoHashMap;
pub const StrMap = std.StringHashMap;
pub const BitSet = std.DynamicBitSet;
pub const Str = []const u8;

pub var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = &gpa_impl.allocator;

// Input-handling errors.
pub const Error = error{InvalidInput};

// Basic point for a 2D integral grid.
pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T = 0,
        y: T = 0,

        /// Given known grid width, maps a location to a unique 1D array index that represents its location.
        pub fn toIndex(self: Self, width: u32) usize {
            return xyToIndex(self.x, self.y, width);
        }

        /// Given known grid width, maps a location to a unique 1D array index that represents its location.
        pub fn xyToIndex(x: T, y: T, width: u32) usize {
            return width * @intCast(u32, y) + @intCast(u32, x);
        }

        /// Given known grid width, and an index in a 1D array mapped via toIndex, gets the Point that
        /// represents its location.
        pub fn fromIndex(index: usize, width: u32) Self {
            return Self{ .x = @intCast(T, index % width), .y = @intCast(T, index / width) };
        }

        /// Adds the two given points together and returns a new point.
        pub fn add(p1: Point(T), p2: Point(T)) Point(T) {
            return .{ .x = p1.x + p2.x, .y = p1.y + p2.y };
        }

        pub fn subtract(p1: Point(T), p2: Point(T)) Point(T) {
            return .{ .x = p1.x - p2.x, .y = p1.y - p2.y };
        }
    };
}

pub const cardinalNeighbors = [_]Point(i32){
    .{ .x = 0, .y = -1 }, // Up
    .{ .x = 1, .y = 0 }, // Right
    .{ .x = 0, .y = 1 }, // Down
    .{ .x = -1, .y = 0 }, // Left
};

pub const eightWayNeighbors = [_]Point(i32){
    .{ .x = 0, .y = -1 }, // Up
    .{ .x = 1, .y = -1 }, // UpRight
    .{ .x = 1, .y = 0 }, // Right
    .{ .x = 1, .y = 1 }, // DownRight
    .{ .x = 0, .y = 1 }, // Down
    .{ .x = -1, .y = 1 }, // DownLeft
    .{ .x = -1, .y = 0 }, // Left
    .{ .x = -1, .y = -1 }, // UpLeft
};

/// Basic bearings of lines
pub const LineType = enum {
    Horizontal,
    Vertical,
    Diagonal,
};

/// Line consisting of 2 points
pub fn Line(comptime T: type) type {
    return struct {
        const Self = @This();

        start: Point(T),
        end: Point(T),

        pub fn getType(self: Self) LineType {
            if (self.start.x == self.end.x) return .Vertical;
            if (self.start.y == self.end.y) return .Horizontal;

            return .Diagonal;
        }
    };
}

/// Represents nodes in a graph of items that are of type T.
pub fn GraphNode(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The value this node represents.
        value: T,
        /// The vertices this node is (unidirectionally) connected to.
        edges: List(*Self),

        /// Creates a node for the given value with no edges.
        pub fn init(value: T, allocator: *Allocator) Self {
            return Self{
                .value = value,
                .edges = List(*Self).init(allocator),
            };
        }

        /// Deinitializes the node.
        pub fn deinit(self: *Self) void {
            self.edges.deinit();
        }
    };
}

/// A graph structure supporting arbitrary value types for nodes.
///
/// Currently, the graph depends on either std.StringHashMap or std.AutoHashMap as applicable,
/// and does not allow the specification of custom contexts.  This could change in the future.
pub fn Graph(comptime T: type) type {
    return struct {
        const Self = @This();
        /// Type for nodes in the graph
        pub const Node = GraphNode(T);
        /// Hash type used to map vertex values to their corresponding vertices
        pub const VertexMap = switch (T) {
            []const u8 => StrMap(*Node),
            else => Map(T, *Node),
        };

        /// Map of values to the vertex representing that value, if any such vertex exists.
        vertices: VertexMap,
        /// Allocator used for maintaining the graph.
        allocator: *Allocator,

        /// Initializes a graph which will use the given allocator.
        pub fn init(allocator: *Allocator) Self {
            return Self{
                .vertices = VertexMap.init(allocator),
                .allocator = allocator,
            };
        }

        /// Deinitializes the graph, deallocating all of its vertices in the process.
        pub fn deinit(self: *Self) void {
            // Deinitialize vertices and free them
            var it = self.vertices.valueIterator();
            while (it.next()) |vertexPtr| {
                vertexPtr.*.*.deinit();
                self.allocator.destroy(vertexPtr.*);
            }

            // Free vertex map
            self.vertices.deinit();
        }

        /// Gets the vertex representing the given value, if one exists.  If no vertex exists, it
        /// creates and adds a vertex to represent the given value, and returns that one.
        pub fn getOrAddVertex(self: *Self, value: T) !*Node {
            const result = try self.vertices.getOrPut(value);
            if (!result.found_existing) {
                result.value_ptr.* = try self.allocator.create(Node);
                errdefer result.value_ptr.*.deinit();
                result.value_ptr.*.* = Node.init(value, self.allocator);
            }

            return result.value_ptr.*;
        }

        // Adds an edge between the given vertices, creating vertices as needed.  The edge will be
        // bidirectional is specified.
        pub fn addEdge(self: *Self, from_vertex: T, to_vertex: T, bidirectional: bool) !void {
            // Get or add vertices defined by the edge
            const from_node = try self.getOrAddVertex(from_vertex);
            const to_node = try self.getOrAddVertex(to_vertex);

            // Add edges as needed
            try from_node.edges.append(to_node);
            if (bidirectional) try to_node.edges.append(from_node);
        }
    };
}

/// Returns the first integer larger than or equal to x, casted to an integer of the given type.
pub fn ceilCast(comptime T: type, x: anytype) T {
    return @floatToInt(T, std.math.ceil(x));
}

/// Errors returned by the find algorithm.
pub const FindError = error{
    /// Element that was searched for could not be found
    NotFound,
};

// Searches slice for element, using std.meta.eql for comparison.  Returns index of element if found,
// or error if not found.
pub fn find(comptime T: type, slice: []const T, element: T) !usize {
    for (slice) |elem, idx| {
        if (std.meta.eql(elem, element)) return idx;
    }

    return error.NotFound;
}

/// Searches the slice for element, using std.meta.eql for comparison.  Returns true if element
/// is found, false otherwise.
pub fn contains(comptime T: type, slice: []const T, element: T) bool {
    _ = find(T, slice, element) catch {
        return false;
    };

    return true;
}

/// Use with std.sort.sort to sort a list of slices in descending order based on their length.
/// Similar to std.sort.asc.
pub fn sliceLenDesc(comptime T: type) fn (void, []const T, []const T) bool {
    const impl = struct {
        fn inner(context: void, a: []const T, b: []const T) bool {
            _ = context;
            return a.len > b.len;
        }
    };

    return impl.inner;
}

/// Utilizes a closed-form solution to find a geometric sum of all terms between 1 and n.
///
/// For example, for n = 3, the function returns 1 + 2 + 3 = 6 via the standard closed-form solution
/// n * (n-1) / 2.
pub fn geometricSummation(n: anytype) @TypeOf(n) {
    return @floatToInt(@TypeOf(n), @intToFloat(f32, n) * (@intToFloat(f32, n) + 1.0) / 2.0);
}

// Useful stdlib functions
pub const tokenize = std.mem.tokenize;
pub const split = std.mem.split;
pub const indexOf = std.mem.indexOfScalar;
pub const indexOfAny = std.mem.indexOfAny;
pub const indexOfStr = std.mem.indexOfPosLinear;
pub const lastIndexOf = std.mem.lastIndexOfScalar;
pub const lastIndexOfAny = std.mem.lastIndexOfAny;
pub const lastIndexOfStr = std.mem.lastIndexOfLinear;
pub const trim = std.mem.trim;
pub const sliceMin = std.mem.min;
pub const sliceMax = std.mem.max;

pub const parseInt = std.fmt.parseInt;
pub const parseFloat = std.fmt.parseFloat;

pub const min = std.math.min;
pub const min3 = std.math.min3;
pub const max = std.math.max;
pub const max3 = std.math.max3;
pub const absInt = std.math.absInt;
pub const absCast = std.math.absCast;

pub const print = std.debug.print;
pub const assert = std.debug.assert;

pub const sort = std.sort.sort;
pub const asc = std.sort.asc;
pub const desc = std.sort.desc;
