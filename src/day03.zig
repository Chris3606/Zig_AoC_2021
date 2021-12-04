const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day03.txt");
const one = @as(u32, 1);

// Wrapper struct for gamma and epsilon
pub const GammaEpsilon = struct {
    gamma: u32 = 0,
    epsilon: u32 = 0,
};

/// Get an integer representing the most common bit-values in the input set.
///
/// The resulting number will have a 1 in a given bit-position if the inputs have mostly 1's at that
/// position, or an equal number of 1's as 0's in that position.  The resulting number will have a 0
/// in that bit position otherwise.
pub fn getMostCommonBitSet(num_bits: u5, inputs: []u32) u32 {
    var result: u32 = 0;

    var i: @TypeOf(num_bits) = 0;
    while (i < num_bits) : (i += 1) {
        var ones: u32 = 0;
        for (inputs) |input| {
            if ((one << i) & input != 0) ones += 1;
        }

        // More ones than not (or equal)
        if (inputs.len - ones <= ones) {
            result |= (one << i);
        }
    }

    return result;
}

/// Calculate gamma and epsilon as per part 1 algorithm.
pub fn getGammaAndEpsilon(inputs: []u32, num_bits: u5) GammaEpsilon {
    var result = GammaEpsilon{};
    const most_common = getMostCommonBitSet(num_bits, inputs);

    var i: u5 = 0;
    while (i < num_bits) : (i += 1) {
        const current_bit = one << i;
        if ((most_common & current_bit) != 0) {
            result.gamma |= current_bit;
        } else {
            result.epsilon |= current_bit;
        }

        if (i == 31) break;
    }

    return result;
}

/// Reduces the given inputs down to a single value, according to the part 2 algorithm.  If
/// use_most_common is true, the _most_ common bit is the one that is taken at any given position;
/// otherwise, the _least_ common bit is taken.  Ties are broken as described in the part 2 algorithm.
pub fn reduceInputsToCommonalitySet(allocator: *util.Allocator, inputs: []u32, num_bits: u5, use_most_common: bool) !u32 {
    // Duplicate input values so we can start eliminating them
    var remaining_inputs = util.List(u32).fromOwnedSlice(allocator, try allocator.dupe(u32, inputs));
    defer remaining_inputs.deinit();

    var bit: u5 = num_bits - 1;
    while (bit >= 0) : (bit -= 1) {
        const cur_bit = (one << bit);
        var most_common_set = getMostCommonBitSet(num_bits, remaining_inputs.items);
        var most_common = if (use_most_common) most_common_set & cur_bit else ~most_common_set & cur_bit;

        var idx = remaining_inputs.items.len - 1;
        while (idx >= 0) : (idx -= 1) {
            var item = remaining_inputs.items[idx];

            if ((item & cur_bit) != most_common) {
                _ = remaining_inputs.orderedRemove(idx);
            }
            if (remaining_inputs.items.len == 1) return remaining_inputs.items[0];
            if (idx == 0) break;
        }

        // Violates invariants we're given; there _has_ to be one left
        if (bit == 0) return error.InvalidInput;
    }
}

pub fn main() !void {
    defer std.debug.assert(!util.gpa_impl.deinit());

    var inputs = util.List(u32).init(util.gpa);
    defer inputs.deinit();

    var it = std.mem.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        try inputs.append(util.parseInt(u32, line, 2) catch {
            return error.InvalidInput;
        });
    }

    var result_pt1 = getGammaAndEpsilon(inputs.items, 12);
    util.print("Pt 1 Gamma-Epsilon: {}\n", .{result_pt1});
    util.print("Pt 1 Gamma * Epsilon: {d}\n", .{result_pt1.gamma * result_pt1.epsilon});

    var o2_rating = try reduceInputsToCommonalitySet(util.gpa, inputs.items, 12, true);
    util.print("O2 Rating: {}\n", .{o2_rating});
    var co2_rating = try reduceInputsToCommonalitySet(util.gpa, inputs.items, 12, false);
    util.print("CO2 Rating: {}\n", .{co2_rating});

    util.print("O2 * CO2: {d}\n", .{o2_rating * co2_rating});
}
