const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day11.txt");

pub const OctapusGrid = struct {
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

        // Return grid
        return Self{ .values = values, .width = width, .allocator = allocator };
    }

    /// Deallocates underlying representation of the grid.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.values);
    }

    /// Performs a "step" as per problem 1 description, returning the number of flashes that
    /// occur.
    pub fn doStep(self: *Self) !u32 {
        // Keeps track of items we're dequeueing when going through flashes
        var queue = util.List(util.Point(i32)).init(self.allocator);
        defer queue.deinit();

        // Increment all energy levels by 1, and queue up any position that will initially flash.
        for (self.values) |*val, idx| {
            val.* += 1;
            if (val.* > 9) {
                try queue.append(util.Point(i32).fromIndex(idx, self.width));
            }
        }

        // Keep track of anything that flashes this step, so we can avoid flashing it twice and set
        // its energy level appropriately
        var visited = util.Map(util.Point(i32), void).init(self.allocator);
        defer visited.deinit();

        var flashes: u32 = 0;

        while (queue.items.len != 0) {
            // Conduct flood fill from each point that is flashing
            const cur_pos = queue.orderedRemove(0);
            if (visited.contains(cur_pos)) continue;

            // Record that a flash has occured.
            flashes += 1;

            // Add to visited set to ensure we don't flash the same cell twice
            try visited.put(cur_pos, {});

            // Set current value to 0
            self.values[cur_pos.toIndex(self.width)] = 0;

            // Increment all neighboring cells if they haven't already flashed, and add them to
            // the queue if the addition will make them flash
            for (util.eightWayNeighbors) |direction| {
                const neighbor = util.Point(i32).add(cur_pos, direction);

                // Out of map bounds, or already flashed
                if (neighbor.x < 0 or neighbor.x >= self.width or neighbor.y < 0 or neighbor.y >= self.height()) continue;
                if (visited.contains(neighbor)) continue;

                // Increment value and add to queue if the increment results in a flash
                const neighbor_idx = neighbor.toIndex(self.width);
                self.values[neighbor_idx] += 1;
                if (self.values[neighbor_idx] > 9) {
                    try queue.append(neighbor);
                }
            }
        }

        return flashes;
    }

    pub fn height(self: Self) u32 {
        return @intCast(u32, self.values.len / self.width);
    }
};

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    var grid = try OctapusGrid.initFromSerializedData(util.gpa, data);
    defer grid.deinit();

    // Go through steps until we've extracted the required data
    var step: u32 = 1;
    var step_100_flashes: u32 = 0;
    var first_simultaneous_flash: u32 = 0;

    while (true) : (step += 1) {
        const current_step_flashes = try grid.doStep();
        if (step <= 100) {
            step_100_flashes += current_step_flashes;
        }

        if (first_simultaneous_flash == 0 and current_step_flashes == grid.values.len) {
            first_simultaneous_flash = step;
        }

        // Just in case the first flash happens before step 100, we will ensure we get both results.
        if (step >= 100 and first_simultaneous_flash != 0) break;
    }

    util.print("Part 1: Number of flashes after 100 steps is {d}\n", .{step_100_flashes});
    util.print("Part 2: First simultaneous flash occured on step {d}\n", .{first_simultaneous_flash});
}
