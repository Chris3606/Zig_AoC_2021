const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day18.txt");

pub const Number = union(enum) {
    literal: u32,
    pair: Pair,
};

pub const Pair = struct {
    num1: Number,
    num2: Number,

    pub fn deserialize(reader: *std.io.Reader) void {}
};

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }
}
