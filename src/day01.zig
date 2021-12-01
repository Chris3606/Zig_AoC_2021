const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;
const Str = []const u8;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("../data/day01.txt");

pub fn part1(nums: []u32) !usize {
    var num_increments: usize = 0;
    var last_num: u32 = ~@as(u32, 0);
    for (nums) |num| {
        if (num > last_num) {
            num_increments += 1;
        }

        last_num = num;
    }

    return num_increments;
}

pub fn part2(allocator: *Allocator, nums: []u32) !usize {
    var sliding_windows = List(u32).init(allocator);
    defer sliding_windows.deinit();

    var i: usize = 0;
    while (i <= nums.len - 3) : (i += 1) {
        const sum = nums[i] + nums[i + 1] + nums[i + 2];
        try sliding_windows.append(sum);
    }

    return part1(sliding_windows.items);
}

pub fn main() !void {
    defer if (util.gpa_impl.deinit()) unreachable;

    var nums = List(u32).init(gpa);
    defer nums.deinit();

    var it = tokenize(u8, data, "\n");

    while (it.next()) |line| {
        const num = try parseInt(u32, line, 10);
        try nums.append(num);
    }

    const part1_result = try part1(nums.items);
    print("Part 1 - Increases: {d}\n", .{part1_result});

    const part2_result = try part2(gpa, nums.items);
    print("Part 2 - Increases: {d}\n", .{part2_result});
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
