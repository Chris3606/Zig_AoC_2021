const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day15.txt");

pub const PointNode = struct {
    const Self = @This();

    position: util.Point(i32),
    priority: u32,

    pub fn lessThan(a: Self, b: Self) std.math.Order {
        return std.math.order(a.priority, b.priority);
    }
};

pub const GridMap = struct {
    const Self = @This();

    values: []u32,
    width: u32,
    allocator: *util.Allocator,

    pub fn init(allocator: *util.Allocator, width: u32, height: u32) !Self {
        const values = try allocator.alloc(u32, width * height);
        errdefer allocator.free(values);
        return Self{
            .values = values,
            .width = width,
            .allocator = allocator,
        };
    }

    pub fn initFromSerializedData(allocator: *util.Allocator, serialized_data: []const u8) !Self {
        var width: u32 = 0;
        const values = blk: {
            var values_list = util.List(u32).init(allocator);
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

    pub fn riskToGoalMap(self: Self) !Self {
        // Create equivalently sized map
        var goal_map = try Self.init(self.allocator, self.width, self.getHeight());
        errdefer goal_map.deinit();
        const end = util.Point(i32){ .x = @intCast(i32, goal_map.width - 1), .y = @intCast(i32, goal_map.getHeight() - 1) };

        // Max out all values except for end, since we'll set end as the goal
        std.mem.set(u32, goal_map.values, std.math.maxInt(u32));
        goal_map.setValue(end, 0);

        // Create queue for pathing
        var queue = std.PriorityQueue(PointNode, PointNode.lessThan).init(self.allocator);
        defer queue.deinit();

        // Add end to queue
        try queue.add(PointNode{ .position = end, .priority = 0 });

        while (queue.count() != 0) {
            // Pop minimum element
            var cur_node = queue.remove();

            // If this is the case, this is a duplicate element; so we can skip it since we already
            // processed it with a lower priority
            if (cur_node.priority != goal_map.getValue(cur_node.position)) continue;

            // This path better than the one we had previously for this node, and is potentially
            // good for reaching nodes around it; queue up neighbors, if the path is better
            // depending on their entry cost.
            for (util.cardinalNeighbors) |direction| {
                const neighbor = util.Point(i32).add(cur_node.position, direction);
                if (neighbor.x < 0 or neighbor.x >= self.width or neighbor.y < 0 or neighbor.y >= self.getHeight()) continue;
                const neighbor_risk_value = self.getValue(neighbor);
                const neighbor_priority = goal_map.getValue(neighbor);

                // Calculate distance to reach adjacent neighbor using its risk cost
                const cost = cur_node.priority + neighbor_risk_value;

                // If the current path is better than the best one we've queued through thus far,
                // add to queue and update goal map.  Not efficient because the priority queue
                // implementation isn't efficient at finding nodes, but fine for this purpose
                if (cost < neighbor_priority) {
                    const new_neighbor_node = PointNode{ .position = neighbor, .priority = cost };

                    try queue.add(new_neighbor_node);

                    goal_map.setValue(neighbor, cost);
                }
            }
        }

        return goal_map;
    }

    pub fn getValue(self: Self, pos: util.Point(i32)) u32 {
        return self.values[pos.toIndex(self.width)];
    }

    pub fn setValue(self: *Self, pos: util.Point(i32), value: u32) void {
        self.values[pos.toIndex(self.width)] = value;
    }

    pub fn getHeight(self: Self) u32 {
        return @intCast(u32, self.values.len / self.width);
    }

    pub fn display(self: Self) void {
        var y: i32 = 0;
        while (y < self.getHeight()) : (y += 1) {
            var x: i32 = 0;
            while (x < self.width) : (x += 1) {
                util.print("{d:2} ", .{self.getValue(.{ .x = x, .y = y })});
            }
            util.print("\n", .{});
        }
    }
};

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Part 1 only; part 2 is similar algorithm but interprets the map differently.
    {
        // Read in risk map from input
        var risk_map = try GridMap.initFromSerializedData(util.gpa, data);
        defer risk_map.deinit();

        util.print("Size is: {d}x{d}\n", .{ risk_map.width, risk_map.getHeight() });

        // Translate map to a goal map
        var goal_map = try risk_map.riskToGoalMap();
        defer goal_map.deinit();

        // Roll downhill on goal map from start to goal, adding risk value of path along the way.
        var cur_pos = util.Point(i32){ .x = 0, .y = 0 };
        const end = util.Point(i32){ .x = @intCast(i32, goal_map.width - 1), .y = @intCast(i32, goal_map.getHeight() - 1) };

        var risk: u32 = 0;
        while (!std.meta.eql(cur_pos, end)) {
            // Find minimum neighbor and select it
            var min_pos: util.Point(i32) = cur_pos;
            for (util.cardinalNeighbors) |direction| {
                const neighbor = util.Point(i32).add(cur_pos, direction);
                if (neighbor.x < 0 or neighbor.x >= goal_map.width or neighbor.y < 0 or neighbor.y >= goal_map.getHeight()) continue;

                if (goal_map.getValue(neighbor) < goal_map.getValue(min_pos)) {
                    min_pos = neighbor;
                }
            }

            // Add minimum cost to risk value and move to neighbor
            risk += risk_map.getValue(min_pos);
            cur_pos = min_pos;
        }

        util.print("Risk value of best path is: {d}\n", .{risk});
    }
}
