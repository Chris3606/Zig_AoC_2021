const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day06.txt");

/// Simulates lanternfish according to specified algorithm.  Returns number of lanternfish after
/// simulation completes.
pub fn simulateLanternfish2(allocator: *util.Allocator, initial_lanternfish: []const u8, days: u32) !u64 {
    // Use array of each possible lifetime value (0-8) to track lanternfish.
    const lifetime_states = try allocator.alloc(u64, 9);
    defer allocator.free(lifetime_states);

    // Zero out initial values
    std.mem.set(u64, lifetime_states, 0);

    // Initialize with the given starting fish.
    for (initial_lanternfish) |lifetime_state| {
        lifetime_states[lifetime_state] += 1;
    }

    // Temporary variable we'll use for existing fish whose lifetime is reset (which spawns a new fish
    // as well)
    var resetting_fish: u64 = 0;

    var day: u32 = 1;
    while (day <= days) : (day += 1) {
        // Iterate through the other lifetimes and simply move the values down since all the values
        // decrement
        for (lifetime_states) |num_fish, idx| {
            //util.print("Handling: {d} w/ {d}:\n", .{ idx, num_fish });
            if (idx == 0) {
                // Handle resetting fish and spawning new ones.  each 0 resets to 6 and spawns a new fish
                // with a state of 8.  We store it in a temporary value so we can avoid overwriting this day's
                // 6 and 8 values until we've processed them.
                resetting_fish = num_fish;
            } else {
                // Simply move fish in the current lifetime state down to the next one.
                lifetime_states[idx - 1] = num_fish;
            }
        }

        // Add the new fish that were created, as well as the ones that reset their states
        lifetime_states[6] += resetting_fish;
        lifetime_states[8] = resetting_fish;
    }

    // Sum up fish in each state to get the total number of fish
    var sum: u64 = 0;
    for (lifetime_states) |num_fish| {
        sum += num_fish;
    }

    return sum;
}

pub fn main() !void {
    defer std.debug.assert(!util.gpa_impl.deinit());

    var lanternfish = util.List(u8).init(util.gpa);
    defer lanternfish.deinit();

    // Parse initial list of ages
    var it = util.tokenize(u8, data, ",");
    while (it.next()) |num_data| {
        try lanternfish.append(util.parseInt(u8, num_data, 10) catch {
            return error.InvalidInput;
        });
    }

    const days_pt1 = 80;
    const num_fish_pt1 = try simulateLanternfish2(util.gpa, lanternfish.items, days_pt1);
    util.print("Part 1: After {d} days, there are {d} lanternfish.\n", .{ days_pt1, num_fish_pt1 });

    const days_pt2 = 256;
    const num_fish_pt2 = try simulateLanternfish2(util.gpa, lanternfish.items, days_pt2);
    util.print("Part 2: After {d} days, there are {d} lanternfish.\n", .{ days_pt2, num_fish_pt2 });
}
