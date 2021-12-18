const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day16.txt");

const ParseError = error{ InvalidInput, OutOfMemory, EndOfStream };

const Reader = std.io.BitReader(.Big, std.io.FixedBufferStream([]u8).Reader);

const BitReader = struct {
    const Self = @This();
    reader: Reader,
    bits_read: usize = 0,

    /// Bit-reading function that records number of bytes read
    pub fn readBitsNoEof(self: *Self, comptime U: type, bits: usize) !U {
        self.bits_read += bits;
        return self.reader.readBitsNoEof(U, bits);
    }
};

pub const PacketHeader = struct {
    const Self = @This();
    version: u3,
    type_id: u3,

    pub fn deserialize(reader: *BitReader) ParseError!Self {
        return Self{
            .version = try reader.readBitsNoEof(u3, 3),
            .type_id = try reader.readBitsNoEof(u3, 3),
        };
    }
};

pub const Literal = struct {
    const Self = @This();
    value: u32,

    pub fn deserialize(reader: *BitReader) ParseError!Self {
        var self = Self{ .value = 0 };

        while (true) {
            // Read lead bit of varint
            const lead_bit = try reader.readBitsNoEof(u1, 1);

            // Read group of 4 into number
            self.value <<= 4;
            self.value |= try reader.readBitsNoEof(u4, 4);

            // Exit on last group
            if (lead_bit == 0) break;
        }

        return self;
    }
};

pub const Operator = struct {
    const Self = @This();
    operands: []Packet,
    allocator: *util.Allocator,

    pub fn deserialize(reader: *BitReader, allocator: *util.Allocator) ParseError!Self {
        var operands = util.List(Packet).init(allocator);
        errdefer operands.deinit();

        const length_type_id = try reader.readBitsNoEof(u1, 1);
        switch (length_type_id) {
            // Next 15 bits are a number == total length in bits of sub-packets
            0 => {
                const bit_length = try reader.readBitsNoEof(u15, 15);
                const starting_length = reader.bits_read;
                while (reader.bits_read - starting_length < bit_length) {
                    const packet = try Packet.deserialize(reader, allocator);
                    try operands.append(packet);
                }
                if (reader.bits_read - starting_length != bit_length) return error.InvalidInput;
            },
            // Next 11 bits are a number == number of sub-packets immediately contained in this packet.
            1 => {
                const num_packets = try reader.readBitsNoEof(u11, 11);
                while (operands.items.len < num_packets) {
                    const packet = try Packet.deserialize(reader, allocator);
                    try operands.append(packet);
                }
            },
        }

        return Self{
            .operands = operands.toOwnedSlice(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.operands) |*operand| {
            operand.deinit();
        }
        self.allocator.free(self.operands);
    }
};

pub const PacketData = union(enum) {
    literal: Literal,
    operator: Operator,
};

pub const Packet = struct {
    const Self = @This();

    header: PacketHeader,
    data: PacketData,

    pub fn deserialize(reader: *BitReader, allocator: *util.Allocator) ParseError!Self {
        const header = try PacketHeader.deserialize(reader);

        return Self{
            .header = header,
            .data = switch (header.type_id) {
                4 => PacketData{ .literal = try Literal.deserialize(reader) },
                else => PacketData{ .operator = try Operator.deserialize(reader, allocator) },
            },
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.data) {
            .operator => |*op| op.deinit(),
            .literal => {},
        }
    }

    pub fn value(self: Self) ParseError!u64 {
        switch (self.data) {
            .literal => |val| return val.value,
            .operator => |op_data| {
                switch (self.header.type_id) {
                    // Add
                    0 => {
                        var sum: u64 = 0;
                        for (op_data.operands) |operand| {
                            sum += try operand.value();
                        }

                        return sum;
                    },
                    // Product
                    1 => {
                        var prod: u64 = 1;
                        for (op_data.operands) |operand| {
                            prod *= try operand.value();
                        }

                        return prod;
                    },
                    // Min
                    2 => {
                        var min: u64 = std.math.maxInt(u64);
                        for (op_data.operands) |operand| {
                            const val = try operand.value();
                            if (val < min) min = val;
                        }

                        return min;
                    },
                    // Max
                    3 => {
                        var max: u64 = 0;
                        for (op_data.operands) |operand| {
                            const val = try operand.value();
                            if (val > max) max = val;
                        }

                        return max;
                    },
                    // Literal (not an operator)
                    4 => unreachable,
                    // Greater than
                    5 => {
                        if (op_data.operands.len != 2) return error.InvalidInput;

                        const val1 = try op_data.operands[0].value();
                        const val2 = try op_data.operands[1].value();
                        return if (val1 > val2) 1 else 0;
                    },
                    // Less than
                    6 => {
                        if (op_data.operands.len != 2) return error.InvalidInput;

                        const val1 = try op_data.operands[0].value();
                        const val2 = try op_data.operands[1].value();
                        return if (val1 < val2) 1 else 0;
                    },
                    // Equality
                    7 => {
                        if (op_data.operands.len != 2) return error.InvalidInput;

                        const val1 = try op_data.operands[0].value();
                        const val2 = try op_data.operands[1].value();
                        return if (val1 == val2) 1 else 0;
                    },
                }
            },
        }
    }
};

pub fn sumPacketVersions(root_packet: Packet) usize {
    var sum: usize = root_packet.header.version;

    switch (root_packet.data) {
        .literal => {},
        .operator => |packet_data| {
            for (packet_data.operands) |operand| {
                sum += sumPacketVersions(operand);
            }
        },
    }

    return sum;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
        _ = leaks;
    }

    // Allocate buffer for hex value
    var buf = try util.gpa.alloc(u8, data.len / 2);
    defer util.gpa.free(buf);

    // Get bytes for hex number and a reader to read big-endian numbers from it
    const bytes = try std.fmt.hexToBytes(buf, data);
    var reader = BitReader{ .reader = std.io.bitReader(.Big, std.io.fixedBufferStream(bytes).reader()) };

    // Parse root packet
    var root_packet = try Packet.deserialize(&reader, util.gpa);
    defer root_packet.deinit();

    // Part 1
    const version_sum = sumPacketVersions(root_packet);
    util.print("Part 1: {d}\n", .{version_sum});

    // Part 2
    const value = root_packet.value();
    util.print("Part 2: {d}\n", .{value});
}
