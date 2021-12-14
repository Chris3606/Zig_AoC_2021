const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day13.txt");

pub const FoldAxis = union(enum) {
    horizontal: i32,
    vertical: i32,
};

/// Structure used to store which cells have dots on the paper grid.  Because the input we were given
/// is _sparse_ (eg. the number of points with dots is very few compared to the overall total
/// number of points on the grid), we'll store dots in a map instead of some sort of array structure.
pub const Paper = struct {
    const Self = @This();
    dots: util.Map(util.Point(i32), void),
    fold_buffer: util.List(util.Point(i32)),

    pub fn init(allocator: *util.Allocator) Self {
        return .{
            .dots = util.Map(util.Point(i32), void).init(allocator),
            .fold_buffer = util.List(util.Point(i32)).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.dots.deinit();
        self.fold_buffer.deinit();
    }

    pub fn addDot(self: *Self, point: util.Point(i32)) !void {
        try self.dots.put(point, {});
    }

    pub fn performFold(self: *Self, fold: FoldAxis) !void {
        // TODO: Fix lots of duplication of code
        switch (fold) {
            .horizontal => |val| {
                // Create a list of the points affected by the fold, so we can iterate over them
                // and also change the map inthe process
                var values_it = self.dots.keyIterator();
                while (values_it.next()) |dot| {
                    if (dot.y > val) {
                        try self.fold_buffer.append(dot.*);
                    }
                }

                for (self.fold_buffer.items) |dot| {
                    // Calculate how far the dot is from the fold line on the appropriate axis,
                    // and calculate its mirrored position on the other side of the fold line.
                    const diff = dot.y - val;
                    const mirror_y = val - diff;

                    // If the folded point isn't off the edge of the map, place it
                    if (mirror_y >= 0) {
                        try self.addDot(.{ .x = dot.x, .y = mirror_y });
                    }

                    // Remove the original dot from the map
                    _ = self.dots.remove(dot);
                }
            },
            .vertical => |val| {
                // Create a list of the points affected by the fold, so we can iterate over them
                // and also change the map inthe process
                var values_it = self.dots.keyIterator();
                while (values_it.next()) |dot| {
                    if (dot.x > val) {
                        try self.fold_buffer.append(dot.*);
                    }
                }

                for (self.fold_buffer.items) |dot| {
                    // Calculate how far the dot is from the fold line on the appropriate axis,
                    // and calculate its mirrored position on the other side of the fold line.
                    const diff = dot.x - val;
                    const mirror_x = val - diff;

                    // If the folded point isn't off the edge of the map, place it
                    if (mirror_x >= 0) {
                        try self.addDot(.{ .x = mirror_x, .y = dot.y });
                    }

                    // Remove the original dot from the map
                    _ = self.dots.remove(dot);
                }
            },
        }

        // Clear fold buffer for next time
        self.fold_buffer.clearRetainingCapacity();
    }

    /// Displays the map in the format AoC demonstrates.
    pub fn display(self: Self) void {
        // Find x/y max
        var max = util.Point(i32){ .x = 0, .y = 0 };
        var it = self.dots.keyIterator();
        while (it.next()) |dot| {
            if (dot.x > max.x) max.x = dot.x;
            if (dot.y > max.y) max.y = dot.y;
        }

        // Print
        var y: i32 = 0;
        while (y <= max.y) : (y += 1) {
            var x: i32 = 0;
            while (x <= max.x) : (x += 1) {
                const ch: u8 = if (self.dots.get(.{ .x = x, .y = y })) |_| '#' else '.';
                util.print("{c}", .{ch});
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

    // Our map structure.
    var map = Paper.init(util.gpa);
    defer map.deinit();

    // List of axis to fold on
    var folds = util.List(FoldAxis).init(util.gpa);
    defer folds.deinit();

    // Parse input
    var it = util.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        // Handle fold or point as applicable
        if (std.mem.startsWith(u8, line, "fold along")) {
            var fold_it = util.tokenize(u8, line, " =");
            // Ignore "fold" and "along"
            _ = fold_it.next() orelse return error.InvalidInput;
            _ = fold_it.next() orelse return error.InvalidInput;

            const axis = fold_it.next() orelse return error.InvalidInput;
            const value = util.parseInt(i32, fold_it.next() orelse return error.InvalidInput, 10) catch {
                return error.InvalidInput;
            };

            if (axis.len != 1) return error.InvalidInput;
            const fold = switch (axis[0]) {
                'x' => FoldAxis{ .vertical = value },
                'y' => FoldAxis{ .horizontal = value },
                else => return error.InvalidInput,
            };
            try folds.append(fold);
        } else {
            var xy_it = util.tokenize(u8, line, ",");
            const point = util.Point(i32){
                .x = util.parseInt(i32, xy_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
                .y = util.parseInt(i32, xy_it.next() orelse return error.InvalidInput, 10) catch {
                    return error.InvalidInput;
                },
            };
            try map.addDot(point);
        }
    }
    if (folds.items.len == 0) return error.InvalidInput;

    // Perform all folds
    var dots_after_first: usize = 0;
    for (folds.items) |fold, idx| {
        // Perform fold
        try map.performFold(fold);

        // Record answer to part 1 as we go
        if (idx == 0) dots_after_first = map.dots.count();
    }

    util.print("Part 1: dots after first fold: {d}\n", .{dots_after_first});

    util.print("Part 2: Displayed value:\n", .{});
    map.display();
}
