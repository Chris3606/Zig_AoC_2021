const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day10.txt");

pub const ChunkType = enum {
    Paren,
    Bracket,
    CurlyBrace,
    Angle,
};

/// Given a valid chunk-opening character, map it to the enum type for the type of chunk it is starting.
fn openingType(char: u8) ChunkType {
    return switch (char) {
        '(' => .Paren,
        '[' => .Bracket,
        '{' => .CurlyBrace,
        '<' => .Angle,
        else => unreachable,
    };
}

// Given a chunk-closing character, map it to the enum type for the type of chunk it is closing.
fn closingType(char: u8) ChunkType {
    return switch (char) {
        ')' => .Paren,
        ']' => .Bracket,
        '}' => .CurlyBrace,
        '>' => .Angle,
        else => unreachable,
    };
}

/// Given a chunk type, return the score for that chunk if it is found to be invalid, as per part 1
/// problem statement.
fn invalidScore(chunk_type: ChunkType) u32 {
    return switch (chunk_type) {
        .Paren => 3,
        .Bracket => 57,
        .CurlyBrace => 1197,
        .Angle => 25137,
    };
}

/// Given a chunk type, return the score for that chunk if it is found to be incomplete, as per part 2
/// problem statement.
fn incompleteScore(chunk_type: ChunkType) u64 {
    return switch (chunk_type) {
        .Paren => 1,
        .Bracket => 2,
        .CurlyBrace => 3,
        .Angle => 4,
    };
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    // Go through each line and parse appropriately
    var it = util.tokenize(u8, data, "\n");
    var invalid_close = util.List(ChunkType).init(util.gpa);
    defer invalid_close.deinit();
    var incomplete_scores = util.List(u64).init(util.gpa);
    defer incomplete_scores.deinit();

    line_loop: while (it.next()) |line| {
        var queue = std.ArrayList(ChunkType).init(util.gpa);
        defer queue.deinit();

        for (line) |ch| {
            switch (ch) {
                '(', '[', '{', '<' => |val| try queue.append(openingType(val)),
                ')', ']', '}', '>' => |val| {
                    const closing = closingType(val);

                    // Found invalid character; add to list for later and move on to next line
                    if (closing != queue.items[queue.items.len - 1]) {
                        try invalid_close.append(closing);
                        continue :line_loop;
                    } else { // Pop off character so we can deal with the next
                        _ = queue.pop();
                    }
                },
                ',' => continue,
                else => return error.InvalidInput,
            }
        }

        // If we get here, line is either correct or incomplete; if it's incomplete, the queue will
        // not be empty, and the characters we need to finish it are simply the characters that are
        // in the queue (in order).  So we'll calculate the total score for incomplete.
        // Score tracked for incomplete lines, per part 2 problem description
        var incomplete_score: u64 = 0;
        while (queue.items.len != 0) {
            const item = queue.pop();
            incomplete_score *= 5;
            incomplete_score += incompleteScore(item);
        }

        if (incomplete_score != 0) {
            try incomplete_scores.append(incomplete_score);
        }
    }

    // Sum up invalid scores
    var invalid_score: u32 = 0;
    for (invalid_close.items) |invalid_value| {
        invalid_score += invalidScore(invalid_value);
    }
    util.print("Part 1: Total score of invalid chunks is: {d}\n", .{invalid_score});

    // Sort incomplete scores and select middle one
    if (incomplete_scores.items.len % 2 != 1) return error.InvalidInput;
    util.sort(u64, incomplete_scores.items, {}, comptime util.asc(u64));
    util.print("Part 2: Middle score of incomplete chunks is: {d}\n", .{incomplete_scores.items[incomplete_scores.items.len / 2]});
}
