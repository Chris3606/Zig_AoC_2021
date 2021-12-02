const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;
const Str = []const u8;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("../data/day02.txt");

const Point = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const MoveCommand = union(enum) {
    up_down: i32,
    forward: i32,
};

fn followCommandsPt1(commands: []const MoveCommand) Point {
    var point = Point{};

    for (commands) |command| {
        switch (command) {
            .forward => |val| point.x += val,
            .up_down => |val| point.y += val,
        }
    }

    return point;
}

fn followCommandsPt2(commands: []const MoveCommand) Point {
    var aim: i32 = 0;
    var position = Point{};

    for (commands) |command| {
        switch (command) {
            .forward => |val| {
                position.x += val;
                position.y += (aim * val);
            },
            .up_down => |val| aim += val,
        }
    }

    return position;
}

pub fn main() !void {
    defer if (util.gpa_impl.deinit()) unreachable;

    var commands = List(MoveCommand).init(gpa);
    defer commands.deinit();

    var it = tokenize(u8, data, "\n");
    while (it.next()) |line| {
        var line_it = tokenize(u8, line, " ");
        const dir = line_it.next().?;
        const val = try parseInt(i32, line_it.next().?, 10);

        if (std.mem.eql(u8, dir, "forward")) {
            try commands.append(.{ .forward = val });
        } else if (std.mem.eql(u8, dir, "down")) {
            try commands.append(.{ .up_down = val });
        } else if (std.mem.eql(u8, dir, "up")) {
            try commands.append(.{ .up_down = -val });
        } else unreachable;
    }

    // Part 1
    const end_pos_pt1 = followCommandsPt1(commands.items);
    print("Part 1: {d}, mult: {d}\n", .{ end_pos_pt1, end_pos_pt1.x * end_pos_pt1.y });

    // Part 2
    const end_pos_pt2 = followCommandsPt2(commands.items);
    print("Part 2: {d}, mult: {d}\n", .{ end_pos_pt2, end_pos_pt2.x * end_pos_pt2.y });
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
