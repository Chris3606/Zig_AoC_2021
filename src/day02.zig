const std = @import("std");
const util = @import("util.zig");

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
    defer std.debug.assert(!util.gpa_impl.deinit());

    var commands = util.List(MoveCommand).init(util.gpa);
    defer commands.deinit();

    var it = util.tokenize(u8, data, "\n");
    while (it.next()) |line| {
        var line_it = util.tokenize(u8, line, " ");
        const dir = line_it.next() orelse return error.InvalidInput;
        const val = util.parseInt(i32, line_it.next() orelse return error.InvalidInput, 10) catch {
            return error.InvalidInput;
        };

        if (std.mem.eql(u8, dir, "forward")) {
            try commands.append(.{ .forward = val });
        } else if (std.mem.eql(u8, dir, "down")) {
            try commands.append(.{ .up_down = val });
        } else if (std.mem.eql(u8, dir, "up")) {
            try commands.append(.{ .up_down = -val });
        } else return error.InvalidInput;
    }

    // Part 1
    const end_pos_pt1 = followCommandsPt1(commands.items);
    util.print("Part 1: {d}, mult: {d}\n", .{ end_pos_pt1, end_pos_pt1.x * end_pos_pt1.y });

    // Part 2
    const end_pos_pt2 = followCommandsPt2(commands.items);
    util.print("Part 2: {d}, mult: {d}\n", .{ end_pos_pt2, end_pos_pt2.x * end_pos_pt2.y });
}
