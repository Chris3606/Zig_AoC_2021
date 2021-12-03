const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;
const Str = []const u8;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("../data/day03.txt");

pub const GammaEpsilon = struct {
    gamma: u32 = 0,
    epsilon: u32 = 0,
};

pub const Ratings = struct {
    o2: u32 = 0,
    co2: u32 = 0,
};

/// Set that represents most common bits in a set, of numbers by position, with ties having both set.
pub const MostCommonBitSet = struct {
    zero: u32 = 0,
    one: u32 = 0,
};

pub fn getMostCommonBitSet(num_bits: u5, inputs: []u32) MostCommonBitSet {
    var result = MostCommonBitSet{};

    var i: u5 = 0;
    while (i < num_bits) : (i += 1) {
        var ones: u32 = 0;
        for (inputs) |input| {
            if ((@as(u32, 1) << i) & input != 0) ones += 1;
        }

        // More ones than not (or equal)
        if (inputs.len - ones <= ones) {
            result.one |= (@as(u32, 1) << i);
        }

        // More zeros than not (or equal)
        if (inputs.len - ones >= ones) {
            result.zero |= (@as(u32, 1) << i);
        }
    }

    return result;
}

pub fn getGammaAndEpsilon(inputs: []u32, num_bits: u5) GammaEpsilon {
    var result = GammaEpsilon{};
    const mostCommon = getMostCommonBitSet(num_bits, inputs);

    var i: u5 = 0;
    while (i < num_bits) : (i += 1) {
        if ((mostCommon.one & (@as(u32, 1) << i)) != 0) {
            result.gamma |= (@as(u32, 1) << i);
        } else {
            result.epsilon |= (@as(u32, 1) << i);
        }

        if (i == 31) break;
    }

    return result;
}

pub fn getO2Rating(inputs: []u32, num_bits: u5) !u32 {
    var o2_values = List(u32).fromOwnedSlice(gpa, try gpa.dupe(u32, inputs));
    defer o2_values.deinit();

    var bit: u5 = num_bits - 1;
    while (bit >= 0) : (bit -= 1) {
        var most_common_set = getMostCommonBitSet(num_bits, o2_values.items);

        var most_common = most_common_set.one & (@as(u32, 1) << bit);

        var idx = o2_values.items.len - 1;
        while (idx >= 0) : (idx -= 1) {
            var item = o2_values.items[idx];

            if ((item & (@as(u32, 1) << bit)) != most_common) {
                _ = o2_values.orderedRemove(idx);
            }
            if (o2_values.items.len == 1) return o2_values.items[0];
            if (idx == 0) break;
        }

        // Violates invariants we're given; there _has_ to be one left
        if (bit == 0) unreachable;
    }

    unreachable;
}

pub fn getCO2Rating(inputs: []u32, num_bits: u5) !u32 {
    var co2_values = List(u32).fromOwnedSlice(gpa, try gpa.dupe(u32, inputs));
    defer co2_values.deinit();

    var bit: u5 = num_bits - 1;
    while (bit >= 0) : (bit -= 1) {
        var most_common_set = getMostCommonBitSet(num_bits, co2_values.items);

        var most_common = ~most_common_set.one & (@as(u32, 1) << bit);

        var idx = co2_values.items.len - 1;
        while (idx >= 0) : (idx -= 1) {
            var item = co2_values.items[idx];

            if ((item & (@as(u32, 1) << bit)) != most_common) {
                _ = co2_values.orderedRemove(idx);
            }
            if (co2_values.items.len == 1) return co2_values.items[0];
            if (idx == 0) break;
        }

        // Violates invariants we're given; there _has_ to be one left
        if (bit == 0) unreachable;
    }

    unreachable;
}

pub fn main() !void {
    defer if (util.gpa_impl.deinit()) unreachable;

    var inputs = List(u32).init(gpa);
    defer inputs.deinit();

    var it = std.mem.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        try inputs.append(try parseInt(u32, line, 2));
    }

    var result_pt1 = getGammaAndEpsilon(inputs.items, 12);
    print("Pt 1 Gamma-Epsilon: {}\n", .{result_pt1});
    print("Pt 1 Gamma * Epsilon: {d}\n", .{result_pt1.gamma * result_pt1.epsilon});

    var o2_rating = try getO2Rating(inputs.items, 12);
    print("O2 Rating: {}\n", .{o2_rating});
    var co2_rating = try getCO2Rating(inputs.items, 12);
    print("CO2 Rating: {}\n", .{co2_rating});

    print("O2 * CO2: {d}\n", .{o2_rating * co2_rating});
}

// Useful stdlib functions
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const min = std.math.min;
const min3 = std.math.min3;
const max = std.math.max;
const max3 = std.math.max3;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.sort;
const asc = std.sort.asc;
const desc = std.sort.desc;
