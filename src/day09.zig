const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day09.txt");

pub const DijkstraMap = struct {
    const Self = @This();

    values: []u8,
    width: u32,
    allocator: *util.Allocator,

    pub fn initFromSerializedData(allocator: *util.Allocator, serialized_data: []const u8) !Self {
        var width: u32 = 0;
        const values = blk: {
            var values_list = util.List(u8).init(allocator);
            defer values_list.deinit();

            var it = util.tokenize(u8, serialized_data, "\n");
            // Parse each row
            while (it.next()) |row_data| {
                if (row_data.len == 0) continue; // Just in case we get an extra newline
                width = @intCast(u32, row_data.len);

                // For each row, parse the numbers (no in-row separator)
                for (row_data) |int_data| {
                    if (int_data < '0' or int_data > '9') return error.InvalidInput;
                    try values_list.append(int_data - '0');
                }
            }

            break :blk values_list.toOwnedSlice();
        };
        errdefer allocator.free(values);

        // Return map
        return Self{ .values = values, .width = width, .allocator = allocator };
    }

    /// Deallocates underlying representation of the map.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.values);
    }

    /// Finds the low-points of the map (as defined in the part 1 problem description), and
    /// returns them.
    pub fn findLowPoints(self: Self) ![]util.Point(i32) {
        var low_points = util.List(util.Point(i32)).init(self.allocator);
        defer low_points.deinit();

        for (self.values) |val, idx| {
            const cur_point = util.Point(i32).fromIndex(idx, self.width);

            // Iterate over all neighbors, skipping ones off the edge of the map
            const is_low_point = for (util.cardinalNeighbors) |direction| {
                const neighbor = util.Point(i32).add(cur_point, direction);
                if (neighbor.x < 0 or neighbor.x >= self.width or neighbor.y < 0 or neighbor.y >= self.height()) continue;

                const neighborIndex = neighbor.toIndex(self.width);
                if (self.values[neighborIndex] <= val) break false;
            } else true;

            if (is_low_point) {
                try low_points.append(cur_point);
            }
        }

        return low_points.toOwnedSlice();
    }

    /// Per part 1 problem description, risk level is the sum of (1 + height) for all points such
    /// that they have no lower neighbors.
    pub fn calculateRiskLevel(self: Self) !u32 {
        var sum: u32 = 0;

        const low_points = try self.findLowPoints();
        defer self.allocator.free(low_points);

        for (low_points) |low_point| {
            sum += (1 + self.values[low_point.toIndex(self.width)]);
        }

        return sum;
    }

    /// Uses the map given to find all basins, as defined in the part 2 problem description.
    pub fn getBasins(self: Self) ![][]util.Point(i32) {
        var basins = util.List([]util.Point(i32)).init(self.allocator);
        defer basins.deinit();

        // Find low points
        const low_points = try self.findLowPoints();
        defer self.allocator.free(low_points);

        // For each low-point, flood outward toward high points, until we can't get to a higher
        // point.  The resulting points are the basin associated with that low point.
        for (low_points) |low_point| {
            // Queue of points we still need to check
            var queue = util.List(util.Point(i32)).init(self.allocator);
            defer queue.deinit();

            // Set of nodes we've already visited while finding this basin.  Same as the result
            // however the set is unordered, and contains operations are much faster so the algorithm
            // can be more efficient.
            var visited = util.Map(util.Point(i32), void).init(self.allocator);
            defer visited.deinit();

            // Set of nodes we've found in this basin.
            var current_basin = util.List(util.Point(i32)).init(self.allocator);
            defer current_basin.deinit();

            // Queue first node in basin
            try queue.append(low_point);

            while (queue.items.len > 0) {
                // Skip nodes we've already visited
                const cur_point = queue.orderedRemove(0);
                if (visited.contains(cur_point)) continue;

                // Add current position to basin, and mark current position as visited
                try current_basin.append(cur_point);
                try visited.put(cur_point, {});

                // Check neighbors, and if they aren't 9's and are greater, then add them to the
                // basin queue
                for (util.cardinalNeighbors) |direction| {
                    const neighbor = util.Point(i32).add(cur_point, direction);
                    if (neighbor.x < 0 or neighbor.x >= self.width or neighbor.y < 0 or neighbor.y >= self.height()) continue;

                    const neighborIndex = neighbor.toIndex(self.width);
                    if (self.values[neighborIndex] != 9 and
                        self.values[neighborIndex] > self.values[cur_point.toIndex(self.width)] and
                        !visited.contains(neighbor))
                    {
                        try queue.append(neighbor);
                    }
                }
            }

            // Add basin to list of basins we've found
            try basins.append(current_basin.toOwnedSlice());
        }

        return basins.toOwnedSlice();
    }

    pub fn height(self: Self) u32 {
        return @intCast(u32, self.values.len / self.width);
    }
};

/// Find basins of the map as defined in the part 2 problem description, and return the sizes of the
/// biggest 3 multiplied together.
pub fn calculateTopThreeBasinValue(map: DijkstraMap) !u32 {
    // Find basins of the map
    var basins = try map.getBasins();
    defer {
        for (basins) |basin| {
            util.gpa.free(basin);
        }

        util.gpa.free(basins);
    }

    // Sort such that the biggest basins are at the top
    util.sort([]util.Point(i32), basins, {}, comptime util.sliceLenDesc(util.Point(i32)));

    // Calculate product of top 3 basin sizes
    var product: u32 = 1;
    for (basins[0..3]) |basin| {
        product *= @intCast(u32, basin.len);
    }

    return product;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    var map = try DijkstraMap.initFromSerializedData(util.gpa, data);
    defer map.deinit();

    // Part 1
    const risk_lvl_pt1 = try map.calculateRiskLevel();
    util.print("Part 1: Risk level of map is {d}\n", .{risk_lvl_pt1});

    // Part 2
    const top_3_basin_product_pt2 = try calculateTopThreeBasinValue(map);
    util.print("Part 2: Product of top 3 basin sizes is {d}\n", .{top_3_basin_product_pt2});
}
