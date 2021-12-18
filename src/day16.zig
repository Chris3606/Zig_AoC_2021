const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day16.txt");

pub const InitError = error{ OutOfMemory, InvalidInput };
pub const ValueError = error{InvalidInput};

const LiteralPacketData = struct {
    const Self = @This();

    value: u32,
    bits_used: usize,

    pub fn initFromSerialized(allocator: *util.Allocator, serialized_data: []const u8) InitError!Self {
        var current_data = serialized_data;

        var num_buf = util.List(u8).init(allocator);
        defer num_buf.deinit();

        var literal = Self{ .value = 0, .bits_used = 0 };
        while (current_data.len >= 5) {
            const bit_group = current_data[0..5];
            literal.bits_used += 5;

            const int_val = util.parseInt(u4, bit_group[1..], 2) catch {
                return error.InvalidInput;
            };
            literal.value <<= 4;
            literal.value |= int_val;
            if (bit_group[0] == '0') break;

            current_data = current_data[5..];
        } else return error.InvalidInput;

        return literal;
    }
};

const OperatorPacketData = struct {
    const Self = @This();

    packets: util.List(Packet),
    bits_used: usize,

    pub fn initFromSerialized(allocator: *util.Allocator, serialized_data: []const u8) InitError!Self {
        var self = Self{ .packets = util.List(Packet).init(allocator), .bits_used = 0 };
        errdefer self.deinit();

        if (serialized_data.len == 0) return error.InvalidInput;

        // Length type ID
        self.bits_used += 1;
        switch (serialized_data[0]) {
            // Next 15 bits are a number that represents total length in bits of sub-packets
            '0' => {
                self.bits_used += 15;
                if (serialized_data.len < 16) return error.InvalidInput;
                const bits_of_packets = util.parseInt(u15, serialized_data[1..16], 2) catch {
                    return error.InvalidInput;
                };

                // Increment bits used for sub-packets
                self.bits_used += bits_of_packets;

                // Read packets until we've gotten all the data
                var current_data = serialized_data[16 .. 16 + bits_of_packets];
                while (current_data.len > 0) {
                    const packet = try Packet.initFromSerialized(allocator, current_data);
                    try self.packets.append(packet);
                    current_data = current_data[packet.bits_used()..];
                }
            },
            // Next 11 bits are a number that represents number of sub-packets immediately contained
            // by this packet
            '1' => {
                self.bits_used += 11;
                if (serialized_data.len < 12) return error.InvalidInput;
                const num_of_subpackets = util.parseInt(u11, serialized_data[1..12], 2) catch {
                    return error.InvalidInput;
                };

                // Read in the specified number of sub-packets
                var current_data = serialized_data[12..];
                while (self.packets.items.len < num_of_subpackets) {
                    const packet = try Packet.initFromSerialized(allocator, current_data);
                    try self.packets.append(packet);
                    current_data = current_data[packet.bits_used()..];
                }

                // Make sure we update bits used
                for (self.packets.items) |packet| {
                    self.bits_used += packet.bits_used();
                }
            },
            else => return error.InvalidInput,
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.packets.items) |*packet| {
            packet.deinit();
        }

        self.packets.deinit();
    }
};

const PacketData = union(enum) {
    const Self = @This();

    literal: LiteralPacketData,
    operator: OperatorPacketData,

    pub fn initFromSerialized(allocator: *util.Allocator, header: PacketHeader, serialized_data: []const u8) InitError!Self {
        return switch (header.type_id) {
            4 => .{ .literal = try LiteralPacketData.initFromSerialized(allocator, serialized_data) },
            else => .{ .operator = try OperatorPacketData.initFromSerialized(allocator, serialized_data) },
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .operator => self.operator.deinit(),
            else => {},
        }
    }

    pub fn bits_used(self: Self) usize {
        return switch (self) {
            .literal => |val| val.bits_used,
            .operator => |val| val.bits_used,
        };
    }
};

const Packet = struct {
    const Self = @This();

    header: PacketHeader,
    data: PacketData,

    pub fn initFromSerialized(allocator: *util.Allocator, serialized_data: []const u8) InitError!Self {
        const header = try PacketHeader.initFromSerialized(serialized_data[0..6]);

        return Self{
            .header = header,
            .data = try PacketData.initFromSerialized(allocator, header, serialized_data[6..]),
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn bits_used(self: Self) usize {
        return self.header.bits_used + self.data.bits_used();
    }

    pub fn value(self: Self) ValueError!usize {
        switch (self.data) {
            .literal => |val| return val.value,
            .operator => |val| {
                switch (self.header.type_id) {
                    // Sum packet
                    0 => {
                        var sum: usize = 0;
                        for (val.packets.items) |sub_pkt| {
                            sum += try sub_pkt.value();
                        }

                        return sum;
                    },
                    // Product packet
                    1 => {
                        var prod: usize = 1;
                        for (val.packets.items) |sub_pkt| {
                            prod *= try sub_pkt.value();
                        }

                        return prod;
                    },
                    // Min packet
                    2 => {
                        var min: usize = std.math.maxInt(usize);
                        for (val.packets.items) |sub_pkt| {
                            const sub_value = try sub_pkt.value();
                            if (sub_value < min) min = sub_value;
                        }

                        return min;
                    },
                    // Max packet
                    3 => {
                        var max: usize = 0;
                        for (val.packets.items) |sub_pkt| {
                            const sub_value = try sub_pkt.value();
                            if (sub_value > max) max = sub_value;
                        }

                        return max;
                    },
                    // Literal packet, not an operator packet
                    4 => unreachable,
                    // Greater-than packet; must have exactly 2 sub-packets
                    5 => {
                        if (val.packets.items.len != 2) return error.InvalidInput;
                        return if ((try val.packets.items[0].value()) > (try val.packets.items[1].value())) 1 else 0;
                    },
                    // Less-than packet; must have exactly 2 sub-packets
                    6 => {
                        if (val.packets.items.len != 2) return error.InvalidInput;
                        return if ((try val.packets.items[0].value()) < (try val.packets.items[1].value())) 1 else 0;
                    },
                    // Equal-to packet; must have exactly 2 sub-packets
                    7 => {
                        if (val.packets.items.len != 2) return error.InvalidInput;
                        return if ((try val.packets.items[0].value()) == (try val.packets.items[1].value())) 1 else 0;
                    },
                }
            },
        }
    }
};

const PacketHeader = struct {
    const Self = @This();

    version: u3,
    type_id: u3,
    bits_used: usize,

    pub fn initFromSerialized(serialized_data: []const u8) InitError!Self {
        if (serialized_data.len != 6) return error.InvalidInput;

        return Self{
            .version = util.parseInt(u3, serialized_data[0..3], 2) catch {
                return error.InvalidInput;
            },
            .type_id = util.parseInt(u3, serialized_data[3..], 2) catch {
                return error.InvalidInput;
            },
            .bits_used = 6,
        };
    }
};

/// Takes in a hex string, and returns a binary string representing the same number.
pub fn hexStringToBinaryString(allocator: *util.Allocator, hex: []const u8) ![]const u8 {
    var binary = util.List(u8).init(allocator);
    defer binary.deinit();

    for (hex) |digit| {
        const binary_mapping = try switch (digit) {
            '0' => "0000",
            '1' => "0001",
            '2' => "0010",
            '3' => "0011",
            '4' => "0100",
            '5' => "0101",
            '6' => "0110",
            '7' => "0111",
            '8' => "1000",
            '9' => "1001",
            'A' => "1010",
            'B' => "1011",
            'C' => "1100",
            'D' => "1101",
            'E' => "1110",
            'F' => "1111",
            else => error.InvalidInput,
        };
        try binary.appendSlice(binary_mapping);
    }

    return binary.toOwnedSlice();
}

/// Sums the version of this packet, and any sub-packets.
pub fn sum_versions(root_packet: Packet) usize {
    var version_sum: usize = root_packet.header.version;

    switch (root_packet.data) {
        .literal => {},
        .operator => |val| {
            for (val.packets.items) |packet| {
                version_sum += sum_versions(packet);
            }
        },
    }

    return version_sum;
}

pub fn displayPacket(packet: Packet) void {
    switch (packet.data) {
        .literal => |val| util.print("Literal: {d}\n", .{val.value}),
        .operator => |val| {
            util.print("Op ID: {d}, sub: {d}\n", .{ packet.header.type_id, val.packets.items.len });
            for (val.packets.items) |itm| {
                displayPacket(itm);
            }
            util.print("\n", .{});
        },
    }
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
        _ = leaks;
    }

    const binary = try hexStringToBinaryString(util.gpa, data);
    defer util.gpa.free(binary);

    var initial_packet = try Packet.initFromSerialized(util.gpa, binary);
    defer initial_packet.deinit();

    const packet_version_sum = sum_versions(initial_packet);
    util.print("Part 1: Version sum is: {d}\n", .{packet_version_sum});

    const packet_value = initial_packet.value();
    util.print("Part 2: Value is {d}\n", .{packet_value});

    displayPacket(initial_packet);
}
