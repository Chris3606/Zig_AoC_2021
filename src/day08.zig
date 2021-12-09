const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day08.txt");

/// Mapping where each index contains a string representing the segments that digit should normally
/// be using.
const digitMap = [_][]const u8{ "abcefg", "cf", "acdeg", "acdfg", "bcdf", "abdfg", "abdefg", "acf", "abcdefg", "abcdfg" };

const NoteEntry = struct {
    const Self = @This();

    /// Series of 10 unique combination of segments seen on this LCD
    inputs: [][]const u8,
    /// The 4 output digits seen on this LCD (represented by the segments on in that output)
    digits: [][]const u8,
    /// A map of the LCD's segment to the actual segment it corresponds to in the actual configuration
    segment_map: util.Map(u8, u8),
    /// Allocator used for memory allocation.
    allocator: *util.Allocator,

    pub fn initFromSerializedEntry(allocator: *util.Allocator, serialized_data: []const u8) !Self {
        // Create input/output list structures
        var inputs = util.List([]const u8).init(allocator);
        defer inputs.deinit();

        var digits = util.List([]const u8).init(allocator);
        defer digits.deinit();

        // Parse input and output sections out of text
        var in_out_it = util.tokenize(u8, serialized_data, "|");
        const input_data = in_out_it.next() orelse return error.InvalidInput;
        const digits_data = in_out_it.next() orelse return error.InvalidInput;

        // Parse through input and output sections
        try appendSlicesFromInputSection(input_data, &inputs);
        if (inputs.items.len != 10) return error.InvalidInput;
        try appendSlicesFromInputSection(digits_data, &digits);
        if (digits.items.len != 4) return error.InvalidInput;

        // Create an appropriate structure
        var result = Self{
            .inputs = inputs.toOwnedSlice(),
            .digits = digits.toOwnedSlice(),
            .segment_map = util.Map(u8, u8).init(allocator),
            .allocator = allocator,
        };
        errdefer result.deinit();

        // Create the segment map for the entry
        try result.createSegmentMapping();

        // Return created entry
        return result;
    }

    /// Deinitializes the entry and performs necessary deallocation.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.inputs);
        self.allocator.free(self.digits);
        self.segment_map.deinit();
    }

    // Creates mapping from input to output numbers
    fn createSegmentMapping(self: *Self) !void {
        // Identify a handful of easy numbers that use unique number of segments.
        var one: ?[]const u8 = null;
        var four: ?[]const u8 = null;
        var seven: ?[]const u8 = null;
        var eight: ?[]const u8 = null;
        for (self.inputs) |input| {
            switch (input.len) {
                2 => one = input,
                3 => seven = input,
                4 => four = input,
                7 => eight = input,
                else => {},
            }
        }
        if (one == null or four == null or seven == null or eight == null) return error.InvalidInput;

        // There is precisely 1 segment active in 7 but not in 1; segment A.  Therefore, we can
        // identify segment A by comparing.
        for (seven.?) |char| {
            if (!util.contains(u8, one.?, char)) {
                try self.segment_map.put(char, 'a');
                break;
            }
        } else return error.InvalidInput;

        // Create a map of the frequency of each character in the input set, since 3 can be identified
        // uniquely (and the other 4 broken into groups of 2) exclusively based on this
        var frequency = util.Map(u8, u8).init(self.allocator);
        defer frequency.deinit();

        for (self.inputs) |input| {
            for (input) |ch| {
                try frequency.put(ch, (frequency.get(ch) orelse 0) + 1);
            }
        }

        // B, E, and F are uniquely identified based on their frequency in the inputs; so add those
        // to our map.
        var it = frequency.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                4 => try self.segment_map.put(entry.key_ptr.*, 'e'),
                6 => try self.segment_map.put(entry.key_ptr.*, 'b'),
                9 => try self.segment_map.put(entry.key_ptr.*, 'f'),
                else => {},
            }
        }

        // 1 contains precisely segments C and F, in some order.  We've identified F but not C,
        // so whatever is in 1 that doesn't already have a key in our decoded map has to be C.
        for (one.?) |char| {
            if (!self.segment_map.contains(char)) {
                try self.segment_map.put(char, 'c');
                break;
            }
        } else return error.InvalidInput;

        // Only segments D and G remain to be identified.  4 contains D but not G; so since we have
        // identified everything else, the one thing we find in 4 that we haven't already identified
        // has to be D.
        for (four.?) |char| {
            if (!self.segment_map.contains(char)) {
                try self.segment_map.put(char, 'd');
                break;
            }
        } else return error.InvalidInput;

        // We now only have D left to ID; so D is whatever identifier between a and g that we haven't
        // already used in our map.
        for ("abcdefg") |char| {
            if (!self.segment_map.contains(char)) {
                try self.segment_map.put(char, 'g');
                break;
            }
        } else return error.InvalidInput;

        if (self.segment_map.count() != 7) return error.InvalidInput;
    }

    /// Given the entry and the determined mappings for the LCD, produce an integer representing
    /// the number that the submarine is trying to display on the LCD.
    pub fn getDisplayedNumber(self: Self) !u32 {
        std.debug.assert(self.digits.len == 4);

        var number: u32 = 0;
        for (self.digits) |digit_segments, idx| {
            // Find which digit this is, using the mapping of the standard segments to digits, and
            // our segment translation map.
            digit_loop: for (digitMap) |actual_digit_segments, actual_digit| {
                if (digit_segments.len != actual_digit_segments.len) continue :digit_loop;
                for (digit_segments) |ch| {
                    const digit_from_mapping = self.segment_map.get(ch) orelse return error.InvalidInput;
                    if (!util.contains(u8, actual_digit_segments, digit_from_mapping)) continue :digit_loop;
                }

                // Found digit, so move it to its proper place in output.
                number += @intCast(u32, actual_digit) * std.math.pow(u32, 10, @intCast(u32, self.digits.len - idx - 1));
                break;
            } else unreachable;
        }

        return number;
    }

    fn appendSlicesFromInputSection(input_section: []const u8, list: *util.List([]const u8)) !void {
        var slices_it = util.tokenize(u8, input_section, " ");
        while (slices_it.next()) |slice| {
            try list.append(slice);
        }
    }
};

/// Assuming output values as per the problem statement, counts the number of times where
/// unique numbers of segments are used (corresponding to 1, 4, 7, or 8).  We could also find this
/// by simply counting the number of times 1, 4, 7, and 8 appear in the output since we can also
/// decode that, but for the sake of doing this as you would in part 1, we'll do it this way.
pub fn countOutputsUsingUniqueNumOfSegments(entries: []const NoteEntry) u32 {
    var sum: u32 = 0;
    for (entries) |*entry| {
        for (entry.digits) |digit| {
            if (digit.len == 2 or digit.len == 3 or digit.len == 4 or digit.len == 7) {
                sum += 1;
            }
        }
    }

    return sum;
}

/// Sums up all of the LCD values being displayed on the LCDs represented by these entries, as per
/// part 2 problem description.
pub fn sumAllLCDValues(entries: []const NoteEntry) !u32 {
    var sum: u32 = 0;
    for (entries) |*entry| {
        sum += try entry.getDisplayedNumber();
    }

    return sum;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Store note entries in list
    var note_entries = util.List(NoteEntry).init(util.gpa);
    defer {
        for (note_entries.items) |*entry| {
            entry.deinit();
        }

        note_entries.deinit();
    }

    // Parse and create note entries
    var it = util.tokenize(u8, data, "\n");
    while (it.next()) |note_entry_data| {
        try note_entries.append(try NoteEntry.initFromSerializedEntry(util.gpa, note_entry_data));
    }

    const uniqueSegmentInstances = countOutputsUsingUniqueNumOfSegments(note_entries.items);
    util.print("Part 1: {} segments.\n", .{uniqueSegmentInstances});

    const lcdValueSum = try sumAllLCDValues(note_entries.items);
    util.print("Part 2: Sum of entries on LCD Displays: {d}\n", .{lcdValueSum});
}
