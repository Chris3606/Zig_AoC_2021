const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day05.txt");

// Takes in lines, returns number of intersections
pub fn numberOfIntersections(lines: []const util.Line(i32), consider_diagonals: bool) !usize {
    var map = util.Map(util.Point(i32), usize).init(util.gpa);
    defer map.deinit();

    for (lines) |line| {
        // Skip diagonals if requested
        const line_type = line.getType();
        if (!consider_diagonals and line_type == .Diagonal) continue;

        // Diagonal lines must be 45 degrees per problem statement
        var delta = util.Point(i32).subtract(line.end, line.start);
        if (line_type == .Diagonal and try util.absInt(delta.x) != try util.absInt(delta.y)) return error.InvalidInput;

        // Turn delta into a number you can increment a position by to iterate along the line
        delta.x = if (delta.x == 0) @as(i32, 0) else if (delta.x < 0) @as(i32, -1) else @as(i32, 1);
        delta.y = if (delta.y == 0) @as(i32, 0) else if (delta.y < 0) @as(i32, -1) else @as(i32, 1);

        // Iterate over line.  We need to ensure the end value allows us to _include_ the last point.
        var pos = line.start;
        const end = util.Point(i32){ .x = line.end.x + delta.x, .y = line.end.y + delta.y };
        while (!std.meta.eql(pos, end)) : (pos = util.Point(i32).add(pos, delta)) {
            try map.put(pos, (map.get(pos) orelse 0) + 1);
        }
    }

    // Given that map, find the number of points that have 2 or more lines
    var num_intersections: usize = 0;
    var it = map.valueIterator();
    while (it.next()) |value| {
        if (value.* >= 2) num_intersections += 1;
    }

    return num_intersections;
}

pub fn main() !void {
    defer std.debug.assert(!util.gpa_impl.deinit());

    var lines = util.List(util.Line(i32)).init(util.gpa);
    defer lines.deinit();

    // Parse into lines
    var it = util.tokenize(u8, data, "\n");
    while (it.next()) |line_data| {
        var point_it = util.tokenize(u8, line_data, "-> ,");

        const line = util.Line(i32){
            .start = util.Point(i32){
                .x = util.parseInt(i32, point_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
                .y = util.parseInt(i32, point_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
            },
            .end = util.Point(i32){
                .x = util.parseInt(i32, point_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
                .y = util.parseInt(i32, point_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
            },
        };

        try lines.append(line);
    }

    // Part 1
    var intersections_pt1 = try numberOfIntersections(lines.items, false);
    util.print("Part 1: Number of intersections: {d}\n", .{intersections_pt1});

    // Part 2
    var intersections_pt2 = try numberOfIntersections(lines.items, true);
    util.print("Part 2: Number of intersections: {d}\n", .{intersections_pt2});
}
