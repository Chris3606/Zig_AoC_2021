const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day17_sample.txt");

pub const Rectangle = struct {
    top_left: util.Point(i32),
    bot_right: util.Point(i32),
};

pub const VelocityTimePair = struct {
    velocity: util.Point(i32),
    time: i32,
};

// Given the target area, a pair with an x inside the area and the corresponding t value, the function
// will add any applicable y-values for the pair to the pair_list.
pub fn addPairsForX(target_area: Rectangle, x_pair: VelocityTimePair, pair_list: util.List(VelocityTimePair)) void {
    var dy: i32 = 0;
    util.print("Checking x-pair: {}\n", .{x_pair});

    while (true) : (dy += 1) {
        // Find y-value for the given t
        var y_val = util.geometricSummation(dy) - util.geometricSummation(x_pair.time - dy - 1);
        util.print("    Trying dy={d}; y-value for t={d} is {d}\n", .{ dy, x_pair.time, y_val });
        util.print("        Rect: {}\n", .{target_area});
        // We're short of the target at the required t; so the starting y-velocity was too high.
        if (y_val > target_area.top_left.y) break;

        // Otherwise, if we're in range, count it, and in any case move on to the next
        if (y_val >= target_area.bot_right.y) {
            try pair_list.append(VelocityTimePair{ .velocity = .{ .x = pair.velocity.x, .y = dy }, .time = pair.time });
        }
    }
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Parse out target area
    var it = util.tokenize(u8, data, "targetarea :,");

    // Parse actual data
    const x_data = it.next() orelse return error.InvalidInput;
    const y_data = it.next() orelse return error.InvalidInput;

    // Get integers from the x and y groups
    var x_it = util.tokenize(u8, x_data, "x=..");
    const x_min = try util.parseInt(i32, x_it.next() orelse return error.InvalidInput, 10);
    const x_max = try util.parseInt(i32, x_it.next() orelse return error.InvalidInput, 10);

    var y_it = util.tokenize(u8, y_data, "y=..");
    const y_max = try util.parseInt(i32, y_it.next() orelse return error.InvalidInput, 10);
    const y_min = try util.parseInt(i32, y_it.next() orelse return error.InvalidInput, 10);

    // Create rectangle
    const target_area = Rectangle{
        .top_left = util.Point(i32){ .x = x_min, .y = y_min },
        .bot_right = util.Point(i32){ .x = x_max, .y = y_max },
    };

    // Any x velocity that can possibly land us in the box must be between 0 and x_max; so we can
    // check all the values.  We'll come up with a list of all t (time-step) values and their x-
    // values that can land inside the box.
    var x_pairs = util.List(VelocityTimePair).init(util.gpa);
    defer x_pairs.deinit();

    // No x-value lower than this can possibly even reach the box, by definition of geometric sum.
    var dx: i32 = 1;
    while (dx <= target_area.bot_right.x) : (dx += 1) {
        // If this value can't possibly reach the box, then we can just skip it.
        const sum_x = util.geometricSummation(dx);
        if (sum_x < target_area.top_left.x) continue;

        // For anything that _could_ reach the box at max, try all possible time values until we
        // overshoot the max x.  We can calculate the x value for a given t in constant time because
        // the x value for a t is a geometric sum, which has a closed-form solution.
        var t: i32 = 1;
        while (t <= dx) : (t += 1) {
            const x_at_time = sum_x - util.geometricSummation(dx - t);
            if (x_at_time > target_area.bot_right.x) break;
            if (x_at_time < target_area.top_left.x) continue;

            // We've found some x-velocity that works.
            //util.print("Valid solution for x={d}: dx={d}, t={d}\n", .{ x_at_time, cur_x, t });
            try x_pairs.append(VelocityTimePair{
                .velocity = .{ .x = dx, .y = 0 },
                .time = t,
            });
        }
    }

    // Now, for each x-velocity that _could_ reach the target, attempt to find some y-value
    // that will get the probe to the box at that time-value.
    var pairs = util.List(VelocityTimePair).init(util.gpa);
    defer pairs.deinit();

    for (x_pairs.items) |*pair| {
        // We'll assume the solution is positive, for the time being.
        var dy: i32 = 0;
        util.print("Checking x-pair: {}\n", .{pair.*});

        while (true) : (dy += 1) {
            // Find y-value for the given t
            var y_val = util.geometricSummation(dy) - util.geometricSummation(pair.time - dy - 1);
            util.print("    Trying dy={d}; y-value for t={d} is {d}\n", .{ dy, pair.time, y_val });
            util.print("        Rect: {}\n", .{target_area});
            // We're short of the target at the required t; so the starting y-velocity was too high.
            // However, if the initial x-velocity is equal to the time-step, that means that by the
            // time the probe has gotten to the target x, it is already falling straight down;
            // so actually, _any_ timestep greater than the one we found will also work, up until
            // the point where we overshoot the target area entirely.   TODO: Think about effect
            // in overall loop, this implementation isn't quite correct.  Think we need to be _outside_
            // of the current y-check
            if (y_val > target_area.top_left.y) break;
            // if (y_val > target_area.top_left.y) {
            //     if (pair.velocity.x == pair.time) {
            //         var t = pair.time + 1;
            //         while (true) : (t += 1) {
            //             var y_val1 = util.geometricSummation(dy) - util.geometricSummation(t - dy - 1);
            //             if (y_val1 > target_area.top_left.y) continue;
            //             // Otherwise, if we're in range, count it, and in any case move on to the next
            //             if (y_val1 >= target_area.bot_right.y) {
            //                 try pairs.append(VelocityTimePair{ .velocity = .{ .x = pair.velocity.x, .y = dy }, .time = t });
            //             } else break;
            //         }
            //     }
            //     break;
            // }

            // Otherwise, if we're in range, count it, and in any case move on to the next
            if (y_val >= target_area.bot_right.y) {
                try pairs.append(VelocityTimePair{ .velocity = .{ .x = pair.velocity.x, .y = dy }, .time = pair.time });
            }
        }
        // TODO: NOW if the pair qualifies under x_velocity == time, do the thing again with all new time values until you overshoot
    }

    // Now, find the pair that reaches the maximum y value; which is just the geometric summation
    // of the y-velocity (since we know the y-velocity is positive)
    util.print("Pairs: {d}\n", .{pairs.items.len});
    var max: i32 = std.math.minInt(i32);
    var optimal_velocity: util.Point(i32) = undefined;
    for (pairs.items) |pair| {
        //util.print("Checking: {}\n", .{pair});
        const highest_y = util.geometricSummation(pair.velocity.y);
        if (highest_y > max) {
            max = highest_y;
            optimal_velocity = pair.velocity;
        }
    }

    util.print("Part 1: Optimal trajectory is {}, with a max y-value of {d}\n", .{ optimal_velocity, max });
}
