const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day07.txt");

// Type of fuel calculation to use for finding alignment positions.
const FuelCalculation = enum {
    // Fuel cost is the equal to the distance moved
    Linear,
    // Fuel cost is the geometric summation of all terms between 1 and the distance moved.
    GeometricSum,
};

/// Utilizes a closed-form solution to find a geometric sum of all terms between 1 and n.
///
/// For example, for n = 3, the function returns 1 + 2 + 3 = 6 via the standard closed-form solution
/// n * (n-1) / 2.
pub fn geometricSummation(n: u32) u32 {
    return @floatToInt(u32, @intToFloat(f32, n) * (@intToFloat(f32, n) + 1.0) / 2.0);
}

// Find the fuel cost of the alignment position with the lowest fuel cost, given the current positions.
// Fuel usage will be calculated according to the given algorithm.
pub fn findEasiestAlignmentPosition(positions: []const u32, fuel_calculation: FuelCalculation) !u32 {
    const min = util.sliceMin(u32, positions);
    const max = util.sliceMax(u32, positions);

    var minFuel: u32 = std.math.maxInt(u32);

    var i: u32 = min;
    cur_align_pos: while (i <= max) : (i += 1) {
        var fuel: u32 = 0;
        for (positions) |pos| {
            const move_distance = util.absCast(@intCast(i32, pos) - @intCast(i32, i));
            fuel += switch (fuel_calculation) {
                .Linear => move_distance,
                .GeometricSum => geometricSummation(move_distance),
            };
            if (fuel >= minFuel) continue :cur_align_pos;
        }

        minFuel = fuel;
    }

    return minFuel;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    var positions = util.List(u32).init(util.gpa);
    defer positions.deinit();

    // Parse initial list of positions
    var it = util.tokenize(u8, data, ",");
    while (it.next()) |num_data| {
        try positions.append(util.parseInt(u32, num_data, 10) catch {
            return error.InvalidInput;
        });
    }
    if (positions.items.len == 0) return error.InvalidInput;

    // Part 1
    const align_pt1 = try findEasiestAlignmentPosition(positions.items, .Linear);
    util.print("Part 1: Alignment with least fuel is: {d}.\n", .{align_pt1});

    // Part 2
    const align_pt2 = try findEasiestAlignmentPosition(positions.items, .GeometricSum);
    util.print("Part 2: Alignment with least fuel is: {d}.\n", .{align_pt2});
}
