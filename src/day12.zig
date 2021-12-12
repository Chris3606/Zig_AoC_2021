const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day12.txt");

/// Errors for our recursive depth-first-search function.
pub const DFSError = error{ InvalidInput, OutOfMemory };

/// Takes in a graph, and conducts a variation of depth-first-search on it that is consistent
/// with the day12 problem statement (allow repeats only in large caves and possibly a single
/// small cave).  Returns number of paths found between start and end.
pub fn paths_to_end_dfs(allocator: *util.Allocator, graph: util.Graph([]const u8), allow_single_repeats: bool) DFSError!u32 {
    var visited = util.Map(*util.Graph([]const u8).Node, void).init(allocator);
    defer visited.deinit();

    // Start at the start node
    const start = graph.vertices.get("start") orelse return error.InvalidInput;

    // Call DFS recursively
    return try dfs_paths_to_end_recursive(start, &visited, allow_single_repeats);
}

// The recursive element of the day 12 DFS algorithm
fn dfs_paths_to_end_recursive(
    node: *util.GraphNode([]const u8),
    visited: *util.Map(*util.GraphNode([]const u8), void),
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
    var graph = util.Graph([]const u8).init(util.gpa);
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
