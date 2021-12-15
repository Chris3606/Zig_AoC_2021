const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day14_sample.txt");

pub const PolymerSequence = struct {
    const Self = @This();

    polymer_template: []const u8,
    insertion_rules: util.StrMap(u8),
    polymerization_buffer: util.List(u8),
    output_frequency: util.Map(u8, u64),

    pub fn init(allocator: *util.Allocator, polymer_template: []const u8) Self {
        return .{
            .polymer_template = polymer_template,
            .insertion_rules = util.StrMap(u8).init(allocator),
            .polymerization_buffer = util.List(u8).init(allocator),
            .output_frequency = util.Map(u8, u64).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.polymerization_buffer.deinit();
        self.insertion_rules.deinit();
        self.output_frequency.deinit();
    }

    pub fn addInsertionRule(self: *Self, pair: []const u8, value: u8) !void {
        util.assert(pair.len == 2);
        try self.insertion_rules.put(pair, value);
    }

    pub fn polymerize(self: *Self, times: usize) !void {
        // We'll polymerize a pair at a time to limit the input size
        var i: usize = 0;
        while (i <= self.polymer_template.len - 2) : (i += 1) {
            //std.log.err("Moving to pair {d}.", .{i});
            defer self.polymerization_buffer.clearRetainingCapacity();

            // Set input buffer to current pair
            try self.polymerization_buffer.appendSlice(self.polymer_template[i .. i + 2]);

            // Polymerize current buffer correct number of times
            var time: usize = 0;
            while (time < times) : (time += 1) {
                //std.log.err("    Step {d}", .{time});
                try self.polymerize_buffer();
            }

            // Count frequency of items in resulting buffer.  Omit the beginning and end
            // value, since they are counted as part of the original template later
            for (self.polymerization_buffer.items[1 .. self.polymerization_buffer.items.len - 1]) |ch| {
                try self.output_frequency.put(ch, (self.output_frequency.get(ch) orelse 0) + 1);
            }
        }

        // Count letters occuring in initial polymer template, since we omitted those from above
        for (self.polymer_template) |ch| {
            try self.output_frequency.put(ch, (self.output_frequency.get(ch) orelse 0) + 1);
        }
    }

    fn polymerize_buffer(self: *Self) !void {
        var i: usize = 0;
        while (i <= self.polymerization_buffer.items.len - 2) : (i += 1) {
            const cur_pair = self.polymerization_buffer.items[i .. i + 2];

            const map_val = self.insertion_rules.get(cur_pair);
            if (map_val) |value| {
                try self.polymerization_buffer.insert(i + 1, value);
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

    var polymer = PolymerSequence.init(util.gpa, polymer_template);
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
    try polymer.polymerize(10);

    // Find min and max values (the items they correspond to are irrelevant)
    var min: u64 = std.math.maxInt(usize);
    var max: u64 = 0;
    var value_it = polymer.output_frequency.valueIterator();
    while (value_it.next()) |value| {
        if (value.* < min) min = value.*;
        if (value.* > max) max = value.*;
    }

    // Subtract min from max to get score
    const score = max - min;
    util.print("Part 1: Score is: {d}\n", .{score});
}
