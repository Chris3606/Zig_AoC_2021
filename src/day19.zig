const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day19_sample.txt");

pub const Scanner = struct {
    pub const Self = @This();
    id: u32,
    beacons: []const util.Point3d(i32),
    allocator: *util.Allocator,

    pub fn deserialize(allocator: *util.Allocator, scanner_data: []const u8) !Self {
        var beacons = util.List(util.Point3d(i32)).init(allocator);
        defer beacons.deinit();

        var it = std.mem.tokenize(u8, scanner_data, "\n");

        // Parse ID
        var id_data = it.next() orelse return error.InvalidInput;
        var id_it = std.mem.tokenize(u8, id_data, "scanner -");
        var id = util.parseInt(u32, id_it.next() orelse return error.InvalidInput, 10) catch {
            return error.InvalidInput;
        };

        // Parse points
        while (it.next()) |line| {
            var val_it = util.tokenize(u8, line, ",");
            const x = util.parseInt(i32, val_it.next() orelse return error.InvalidInput, 10) catch {
                return error.InvalidInput;
            };
            const y = util.parseInt(i32, val_it.next() orelse return error.InvalidInput, 10) catch {
                return error.InvalidInput;
            };
            const z = util.parseInt(i32, val_it.next() orelse return error.InvalidInput, 10) catch {
                return error.InvalidInput;
            };

            try beacons.append(util.Point3d(i32){ .x = x, .y = y, .z = z });
        }

        return Self{
            .id = id,
            .beacons = beacons.toOwnedSlice(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.beacons);
    }
};

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    var scanners = util.List(Scanner).init(util.gpa);
    defer {
        for (scanners.items) |*scanner| {
            scanner.deinit();
        }

        scanners.deinit();
    }

    // Parse scanners from input
    var it = util.split(u8, data, "\n\n");
    while (it.next()) |scanner_data| {
        const scanner = try Scanner.deserialize(util.gpa, scanner_data);
        try scanners.append(scanner);
    }

    // Check each scanner for potential overlap
    for (scanners.items) |*scanner1, idx| {
        for (scanners.items[idx + 1 ..]) |*scanner2| {
            // For each pair of scanners, iterate through all orientations

        }
    }
}
