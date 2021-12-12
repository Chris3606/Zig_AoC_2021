const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day12.txt");

/// Represents nodes in a graph of items that are of type T.
pub fn GraphNode(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The value this node represents.
        value: T,
        /// The vertices this node is (unidirectionally) connected to.
        edges: util.List(*Self),

        /// Creates a node for the given value with no edges.
        pub fn init(value: T, allocator: *util.Allocator) Self {
            return Self{
                .value = value,
                .edges = util.List(*Self).init(allocator),
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
            []const u8 => util.StrMap(*Node),
            else => util.Map(T, *Node),
        };

        /// Map of values to the vertex representing that value, if any such vertex exists.
        vertices: VertexMap,
        /// Allocator used for maintaining the graph.
        allocator: *util.Allocator,

        /// Initializes a graph which will use the given allocator.
        pub fn init(allocator: *util.Allocator) Self {
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

/// Errors for our recursive depth-first-search function.
pub const DFSError = error{ InvalidInput, OutOfMemory };

/// Takes in a graph, and conducts a variation of depth-first-search on it that is consistent
/// with the day12 problem statement (allow repeats only in large caves and possibly a single
/// small cave).  Returns number of paths found between start and end.
pub fn paths_to_end_dfs(allocator: *util.Allocator, graph: Graph([]const u8), allow_single_repeats: bool) DFSError!u32 {
    var visited = util.Map(*Graph([]const u8).Node, void).init(allocator);
    defer visited.deinit();

    // Start at the start node
    const start = graph.vertices.get("start") orelse return error.InvalidInput;

    // Call DFS recursively
    return try dfs_paths_to_end_recursive(start, &visited, allow_single_repeats);
}

// The recursive element of the day 12 DFS algorithm
fn dfs_paths_to_end_recursive(
    node: *GraphNode([]const u8),
    visited: *util.Map(*GraphNode([]const u8), void),
    allow_single_repeat: bool,
) DFSError!u32 {
    // Label node as discovered, if it isn't a big cave (those, each path is allowed to visit
    // more than once, so we won't mark at all).  We'll mark them as unvisited after we're done
    // processing the current path, so that other paths can visit the same nodes.
    const count_as_visited = !visited.contains(node) and (node.value[0] < 'A' or node.value[0] > 'Z');
    if (count_as_visited) try visited.put(node, {});

    // Ensure we only remove it IF we're the one who added it.  This is necessary because depending
    // on config, small caves can repeat once (meaning this function is potentially run when) they
    // are already visited.
    defer if (count_as_visited) {
        _ = visited.remove(node);
    };

    // Since we only care about paths that get to end, we can stop as soon as the path ends up
    // there
    if (std.mem.eql(u8, node.value, "end")) return 1;

    // Process all edges recursively
    var paths_to_end: u32 = 0;
    for (node.edges.items) |edge_dest| {
        // If we haven't visited the node yet, we can clearly just proceed to visit it.
        //
        // If we _have_ already visited the node, but we still have our repeat, count the path anyway
        // and disallow future repetition (assuming we're not going back to start)
        if (!visited.contains(edge_dest)) {
            paths_to_end += try dfs_paths_to_end_recursive(edge_dest, visited, allow_single_repeat);
        } else if (allow_single_repeat and !std.mem.eql(u8, edge_dest.value, "start")) {
            paths_to_end += try dfs_paths_to_end_recursive(edge_dest, visited, false);
        }
    }

    return paths_to_end;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Graph structure we'll parse data into
    var graph = Graph([]const u8).init(util.gpa);
    defer graph.deinit();

    // Parse through each line, parsing out the edge and adding it to the graph
    var it = std.mem.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        // Find value for start and end vertex for the edge
        var start_end_it = std.mem.tokenize(u8, line, "-");
        const start = start_end_it.next() orelse return error.InvalidInput;
        const end = start_end_it.next() orelse return error.InvalidInput;

        // Add bidirectional edge, adding vertices as needed
        try graph.addEdge(start, end, true);
    }

    const paths_to_end_pt1 = paths_to_end_dfs(util.gpa, graph, false);
    util.print("Part 1: Number of paths to \"end\" found is {d}\n", .{paths_to_end_pt1});

    const paths_to_end_pt2 = paths_to_end_dfs(util.gpa, graph, true);
    util.print("Part 2: Number of paths to \"end\" found is {d}\n", .{paths_to_end_pt2});
}
