const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day11.txt");

pub fn main() !void {
    defer std.debug.assert(!util.gpa_impl.deinit());
}
