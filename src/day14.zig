const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day14.txt");

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }
}
