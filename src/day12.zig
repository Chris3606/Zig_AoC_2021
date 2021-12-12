const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day12_sample.txt");

pub const GraphNode = struct {
    const Self = @This();

    id: []const u8,
    edges: util.List(*Self),

    pub fn init(id: []const u8, allocator: *util.Allocator) Self {
        return Self{
            .id = id,
            .edges = util.List(*Self).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.edges.deinit();
    }
};

pub const Graph = struct {
    const Self = @This();

    vertices: util.List(*GraphNode),
    allocator: *util.Allocator,

    pub fn init(allocator: *util.Allocator) Self {
        return Self{
            .vertices = util.List(*GraphNode).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.vertices.items) |vertex| {
            vertex.deinit();
            self.allocator.destroy(vertex);
        }

        self.vertices.deinit();
    }

    pub fn addVertex(self: *Self, vertexID: []const u8) !void {
        const vertex = try self.allocator.create(GraphNode);
        errdefer vertex.deinit();

        vertex.* = GraphNode.init(vertexID, self.allocator);
        try self.vertices.append(vertex);
    }

    pub fn getVertex(self: Self, vertexID: []const u8) ?*GraphNode {
        return for (self.vertices.items) |vertex| {
            if (std.mem.eql(u8, vertex.id, vertexID)) break vertex;
        } else null;
    }

    pub fn addEdge(self: *Self, fromVertexID: []const u8, toVertexID: []const u8) !void {
        // Find edges we're concerned with.  This is rather inefficient and we should probably have a hash map
        // that denotes which vertex ID goes to which vertex so the search part is O(1), but this is fast enough
        // for our use case.
        var from_node = self.getVertex(fromVertexID) orelse return error.InvalidInput;
        var to_node = self.getVertex(toVertexID) orelse return error.InvalidInput;

        // Add edges both ways
        try from_node.edges.append(to_node);
        try to_node.edges.append(from_node);
    }
};

pub const DFSError = error{OutOfMemory};

/// Takes in a graph, and conducts a variation of depth-first-search on it that is consistent
/// with the day12 problem statement (allow repeats only in large caves and possibly a single
/// small cave).  Returns number of paths found between start and end.
pub fn paths_to_end_dfs(allocator: *util.Allocator, graph: Graph) DFSError!u32 {
    var visited = util.Map(*GraphNode, void).init(allocator);
    defer visited.deinit();

    // Start at the start node
    const start = graph.getVertex("start").?;

    // Call DFS recursively
    return try dfs_paths_to_end_recursive(start, &visited);
}

// The recursive element of the day 12 DFS algorithm
fn dfs_paths_to_end_recursive(node: *GraphNode, visited: *util.Map(*GraphNode, void)) DFSError!u32 {
    // Label node as discovered, if it isn't a big cave (those, each path is allowed to visit
    // more than once, so we won't mark at all).  We'll mark them as unvisited after we're done
    // processing the current path, so that other paths can visit the same nodes.
    if (node.id[0] < 'A' or node.id[0] > 'Z') {
        try visited.put(node, {});
    }
    defer _ = visited.remove(node);

    // Since we only care about paths that get to end, we can stop as soon as the path ends up
    // there
    if (std.mem.eql(u8, node.id, "end")) return 1;

    // Process all edges recursively.
    var paths_to_end: u32 = 0;
    for (node.edges.items) |edge_dest| {
        if (!visited.contains(edge_dest)) {
            paths_to_end += try dfs_paths_to_end_recursive(edge_dest, visited);
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
    var graph = Graph.init(util.gpa);
    defer graph.deinit();

    // Parse through each line, parsing out the edge and adding it to the graph
    var it = std.mem.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        // Find ID for start and end vertex
        var start_end_it = std.mem.tokenize(u8, line, "-");
        const start = start_end_it.next() orelse return error.InvalidInput;
        const end = start_end_it.next() orelse return error.InvalidInput;

        // Add vertices defined by edge if they don't exist.  Again this is super inefficient search,
        // but works for now.
        if (graph.getVertex(start) == null) try graph.addVertex(start);
        if (graph.getVertex(end) == null) try graph.addVertex(end);

        // Add bidirectional edge
        try graph.addEdge(start, end);
    }

    const paths_to_end_pt1 = paths_to_end_dfs(util.gpa, graph);
    util.print("Part 1: Number of paths to \"end\" found is {d}\n", .{paths_to_end_pt1});

    // const paths_to_end_pt2 = paths_to_end_dfs(util.gpa, graph);
    // util.print("Part 2: Number of paths to \"end\" found is {d}\n", .{paths_to_end_pt2});
}
