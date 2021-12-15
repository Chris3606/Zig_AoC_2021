const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day14.txt");

/// Represents a polymer pair.
pub const Pair = struct {
    pub const Self = @This();

    item1: u8,
    item2: u8,

    pub fn initFromSlice(pair: []const u8) Self {
        util.assert(pair.len == 2);
        return .{ .item1 = pair[0], .item2 = pair[1] };
    }
};

pub const PolymerSequence = struct {
    const Self = @This();

    polymer_template: []const u8,
    insertion_rules: util.Map(Pair, u8),
    element_frequency: [26]usize,
    allocator: *util.Allocator,

    pub fn init(allocator: *util.Allocator, polymer_template: []const u8) Self {
        util.assert(polymer_template.len % 2 == 0);

        return .{
            .polymer_template = polymer_template,
            .insertion_rules = util.Map(Pair, u8).init(allocator),
            .element_frequency = std.mem.zeroes([26]usize),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.insertion_rules.deinit();
    }

    pub fn addInsertionRule(self: *Self, pair: Pair, value: u8) !void {
        try self.insertion_rules.put(pair, value);
    }

    pub fn polymerize(self: *Self, times: usize) !void {
        // Map of each pair to how often that pair occurs
        var pair_counts = util.Map(Pair, usize).init(self.allocator);
        defer pair_counts.deinit();

        // Break initial template down into its pairs
        {
            var i: usize = 0;
            while (i <= self.polymer_template.len - 2) : (i += 1) {
                const pair = Pair.initFromSlice(self.polymer_template[i .. i + 2]);
                try pair_counts.put(pair, (pair_counts.get(pair) orelse 0) + 1);
            }
        }

        // Perform polymerization via the following steps:
        //    1. For each pair, examine its mapping in our rules
        //    2. If it maps, add the two resulting pairs to the new map
        //    3. If it doesn't map, simply transcribe it over
        {
            var cur_time: usize = 0;

            // Temporary map we will use to keep track of the current set of pairs we're computing
            // (since all replacements happen simultaneously, and we cannot modify the original list
            // as we are iterating through it).
            var new_pair_counts = util.Map(Pair, usize).init(self.allocator);
            defer new_pair_counts.deinit();
            while (cur_time < times) : (cur_time += 1) {
                // Go through each current pair
                var pairs_it = pair_counts.iterator();
                while (pairs_it.next()) |entry| {
                    // Get value to be inserted, if any
                    const inserted_value = self.insertion_rules.get(entry.key_ptr.*);

                    // Pair translates to something new, so add the two new pairs
                    if (inserted_value) |value| {
                        const p1 = Pair{ .item1 = entry.key_ptr.item1, .item2 = value };
                        const p2 = Pair{ .item1 = value, .item2 = entry.key_ptr.item2 };
                        try new_pair_counts.put(p1, (new_pair_counts.get(p1) orelse 0) + entry.value_ptr.*);
                        try new_pair_counts.put(p2, (new_pair_counts.get(p2) orelse 0) + entry.value_ptr.*);
                    } else { // No translation, just translate over existing pair
                        try new_pair_counts.put(entry.key_ptr.*, entry.value_ptr.*);
                    }
                }

                // Switch new with old and set up to re-use old buffer to save on allocation
                var temp = pair_counts;
                pair_counts = new_pair_counts;
                new_pair_counts = temp;
                new_pair_counts.clearRetainingCapacity();
            }
        }

        // Update count of elements in the polymer.
        //
        // Because pairs overlap in the polymer (eg. the second letter of one pair is the first)
        // letter of the next, we'll only look at the first element of the pair when we're counting
        // to avoid double counting elements.
        self.element_frequency = std.mem.zeroes(@TypeOf(self.element_frequency));

        var pairs_it = pair_counts.iterator();
        while (pairs_it.next()) |entry| {
            self.element_frequency[entry.key_ptr.item1 - 'A'] += entry.value_ptr.*;
        }

        // Because we only counted the first set in each pair, the only element we missed counting
        // is the last element in the resulting polymer chain (because it's the only one that isn't
        // part of the first element of _some_ pair).  Fortunately, we know what the last one is
        // (because it hasn't changed from what it was in the original polymer template), so we'll
        // offset the count accordingly.
        self.element_frequency[self.polymer_template[self.polymer_template.len - 1] - 'A'] += 1;
    }
};

pub fn getScoreForPolymer(polymer: PolymerSequence) usize {
    // Find min and max values (the items they correspond to are irrelevant)
    const max = util.sliceMax(usize, polymer.element_frequency[0..]);

    // The min value must ignore 0, so we'll find it manually
    const min: usize = blk: {
        var min: usize = std.math.maxInt(usize);
        for (polymer.element_frequency[0..]) |elem| {
            if (elem != 0 and elem < min) min = elem;
        }
        break :blk min;
    };

    // Subtract min from max to get score
    return max - min;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Read in the polymer template (which must be a series of pairs)
    var it = util.tokenize(u8, data, "\n");
    const polymer_template = it.next() orelse return error.InvalidInput;
    if (polymer_template.len % 2 != 0) return error.InvalidInput;

    var polymer = PolymerSequence.init(util.gpa, polymer_template);
    defer polymer.deinit();

    // Read in insertion rules
    while (it.next()) |line| {
        var rule_it = util.tokenize(u8, line, " ->");

        const pair = rule_it.next() orelse return error.InvalidInput;
        if (pair.len != 2) return error.InvalidInput;

        const insert_value = rule_it.next() orelse return error.InvalidInput;
        if (insert_value.len != 1) return error.InvalidInput;

        try polymer.addInsertionRule(Pair.initFromSlice(pair), insert_value[0]);
    }

    // Polymerize x times (change for part 1/part 2 appropriately)
    try polymer.polymerize(40);

    // Calculate score
    const score = getScoreForPolymer(polymer);
    util.print("Score is: {d}\n", .{score});
}
