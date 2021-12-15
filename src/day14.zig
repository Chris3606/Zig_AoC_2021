const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day14.txt");

pub const PolymerSequence = struct {
    const Self = @This();

    polymer: util.List(u8),
    insertion_rules: util.StrMap(u8),

    pub fn init(allocator: *util.Allocator, polymer_template: []const u8) !Self {
        var self = Self{
            .polymer = util.List(u8).init(allocator),
            .insertion_rules = util.StrMap(u8).init(allocator),
        };

        try self.polymer.appendSlice(polymer_template);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.polymer.deinit();
        self.insertion_rules.deinit();
    }

    pub fn addInsertionRule(self: *Self, pair: []const u8, value: u8) !void {
        util.assert(pair.len == 2);
        try self.insertion_rules.put(pair, value);
    }

    pub fn polymerize(self: *Self) !void {
        var i: usize = 0;
        while (i <= self.polymer.items.len - 2) : (i += 1) {
            const cur_pair = self.polymer.items[i .. i + 2];

            const map_val = self.insertion_rules.get(cur_pair);
            if (map_val) |value| {
                try self.polymer.insert(i + 1, value);
                i += 1; // Increment past the value we just added so we only compare the next original pair
            }
        }
    }
};

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Read in the polymer template
    var it = util.tokenize(u8, data, "\n");
    const polymer_template = it.next() orelse return error.InvalidInput;

    var polymer = try PolymerSequence.init(util.gpa, polymer_template);
    defer polymer.deinit();

    // Read in insertion rules
    while (it.next()) |line| {
        var rule_it = util.tokenize(u8, line, " ->");

        const pair = rule_it.next() orelse return error.InvalidInput;
        if (pair.len != 2) return error.InvalidInput;

        const insert_value = rule_it.next() orelse return error.InvalidInput;
        if (insert_value.len != 1) return error.InvalidInput;

        try polymer.addInsertionRule(pair, insert_value[0]);
    }

    // Polymerize 10 times as per part 1
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try polymer.polymerize();
    }

    // Create frequency map
    var frequency_map = util.Map(u8, usize).init(util.gpa);
    defer frequency_map.deinit();

    for (polymer.polymer.items) |ch| {
        try frequency_map.put(ch, (frequency_map.get(ch) orelse 0) + 1);
    }

    // Find min and max values (the items they correspond to are irrelevant)
    var min: usize = std.math.maxInt(usize);
    var max: usize = 0;
    var value_it = frequency_map.valueIterator();
    while (value_it.next()) |value| {
        if (value.* < min) min = value.*;
        if (value.* > max) max = value.*;
    }

    // Subtract min from max to get score
    const score = max - min;
    util.print("Part 1: Score is: {d}\n", .{score});

    // Notes:
    // We can maybe get away with an O(n)-per-step solution (and in fact I don't think there's a
    // better one); but we _must_ stay away from an O(n*m) solution (where n is len polymer chain and
    // m is number of replacement rules).  So parse data into a StringMap(Pair -> InsertionValue) so
    // that, for a given pair, we can look up the proper insertion value in O(1).
    //
    // Also note, simultenous replacements can happen; so it seems most beneficial to iterate over
    // the list backwards while doing polymer chain insertions (to avoid interrupt).  Could also
    // iterate forward but would need to skip indices to get around insertions.
}
