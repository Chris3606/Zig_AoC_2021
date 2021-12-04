const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day01.txt");

pub fn part1(nums: []u32) usize {
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

pub fn part2(allocator: *util.Allocator, nums: []u32) !usize {
    var sliding_windows = util.List(u32).init(allocator);
    defer sliding_windows.deinit();

    var i: usize = 0;
    while (i <= nums.len - 3) : (i += 1) {
        const sum = nums[i] + nums[i + 1] + nums[i + 2];
        try sliding_windows.append(sum);
    }

    return part1(sliding_windows.items);
}

pub fn test1() bool {
    std.log.err("Did.", .{});
    return false;
}

pub fn main() !void {
    defer std.debug.assert(!util.gpa_impl.deinit());

    var nums = util.List(u32).init(util.gpa);
    defer nums.deinit();

    var it = util.tokenize(u8, data, "\n");

    while (it.next()) |line| {
        const num = util.parseInt(u32, line, 10) catch {
            return error.InvalidInput;
        };
        try nums.append(num);
    }

    const part1_result = part1(nums.items);
    util.print("Part 1 - Increases: {d}\n", .{part1_result});

    const part2_result = try part2(util.gpa, nums.items);
    util.print("Part 2 - Increases: {d}\n", .{part2_result});
}
