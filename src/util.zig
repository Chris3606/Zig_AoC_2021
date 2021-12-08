const std = @import("std");
pub const Allocator = std.mem.Allocator;
pub const List = std.ArrayList;
pub const Map = std.AutoHashMap;
pub const StrMap = std.StringHashMap;
pub const BitSet = std.DynamicBitSet;
pub const Str = []const u8;

pub var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = &gpa_impl.allocator;

// Input-handling errors.
pub const Error = error{InvalidInput};

// Basic point for a 2D integral grid.
pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T = 0,
        y: T = 0,

        /// Given known grid width, maps a location to a unique 1D array index that represents its location.
        pub fn toIndex(self: Self, width: u32) usize {
            return width * self.y + self.x;
        }

        /// Given known grid width, maps a location to a unique 1D array index that represents its location.
        pub fn xyToIndex(x: T, y: T, width: u32) usize {
            return width * y + x;
        }

        /// Adds the two given points together and returns a new point.
        pub fn add(p1: Point(T), p2: Point(T)) Point(T) {
            return .{ .x = p1.x + p2.x, .y = p1.y + p2.y };
        }

        pub fn subtract(p1: Point(T), p2: Point(T)) Point(T) {
            return .{ .x = p1.x - p2.x, .y = p1.y - p2.y };
        }
    };
}

/// Basic bearings of lines
pub const LineType = enum {
    Horizontal,
    Vertical,
    Diagonal,
};

/// Line consisting of 2 points
pub fn Line(comptime T: type) type {
    return struct {
        const Self = @This();

        start: Point(T),
        end: Point(T),

        pub fn getType(self: Self) LineType {
            if (self.start.x == self.end.x) return .Vertical;
            if (self.start.y == self.end.y) return .Horizontal;

            return .Diagonal;
        }
    };
}

/// Returns the first integer larger than or equal to x, casted to an integer of the given type.
pub fn ceilCast(comptime T: type, x: anytype) T {
    return @floatToInt(T, std.math.ceil(x));
}

// Useful stdlib functions
pub const tokenize = std.mem.tokenize;
pub const split = std.mem.split;
pub const indexOf = std.mem.indexOfScalar;
pub const indexOfAny = std.mem.indexOfAny;
pub const indexOfStr = std.mem.indexOfPosLinear;
pub const lastIndexOf = std.mem.lastIndexOfScalar;
pub const lastIndexOfAny = std.mem.lastIndexOfAny;
pub const lastIndexOfStr = std.mem.lastIndexOfLinear;
pub const trim = std.mem.trim;
pub const sliceMin = std.mem.min;
pub const sliceMax = std.mem.max;

pub const parseInt = std.fmt.parseInt;
pub const parseFloat = std.fmt.parseFloat;

pub const min = std.math.min;
pub const min3 = std.math.min3;
pub const max = std.math.max;
pub const max3 = std.math.max3;
pub const absInt = std.math.absInt;
pub const absCast = std.math.absCast;

pub const print = std.debug.print;
pub const assert = std.debug.assert;

pub const sort = std.sort.sort;
pub const asc = std.sort.asc;
pub const desc = std.sort.desc;
