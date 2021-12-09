const std = @import("std");
const util = @import("util.zig");

const data = @embedFile("../data/day04.txt");

const Tile = struct {
    number: u8,
    marked: bool = false,
};

const Board = struct {
    const Self = @This();
    const board_size = 5;

    tiles: [board_size * board_size]Tile,

    pub fn initFromSerializedBoard(serialized_board: []const u8) !Self {
        var result: Board = undefined;

        var it = util.tokenize(u8, serialized_board, "\n ");
        var idx: usize = 0;
        while (it.next()) |board_num_data| {
            defer idx += 1;

            if (idx >= result.tiles.len) return error.InvalidInput;

            const board_num = util.parseInt(u8, board_num_data, 10) catch {
                return error.InvalidInput;
            };
            result.tiles[idx] = Tile{ .number = board_num };
        }
        if (idx != result.tiles.len) return error.InvalidInput;

        return result;
    }

    /// Maps a board location to the index in the tiles array containing its tile.
    pub fn toIndex(x: u8, y: u8) usize {
        return util.Point(u8).xyToIndex(x, y, board_size);
    }

    /// Checks rows/columns as per part 1 problem statement
    pub fn isWinningState(self: Self) bool {
        // Check rows
        {
            var y: u8 = 0;
            while (y < board_size) : (y += 1) {
                var x: u8 = 0;
                var row_filled = while (x < board_size) : (x += 1) {
                    if (!self.tiles[toIndex(x, y)].marked) break false;
                } else true;

                if (row_filled) return true;
            }
        }

        // Check columns
        {
            var x: u8 = 0;
            while (x < board_size) : (x += 1) {
                var y: u8 = 0;
                var col_filled = while (y < board_size) : (y += 1) {
                    if (!self.tiles[toIndex(x, y)].marked) break false;
                } else true;

                if (col_filled) return true;
            }
        }

        return false;
    }

    /// Produces the sum of all numbers on the board that are not marked.
    pub fn sumUnmarkedNumbers(self: Self) u16 {
        var sum: u16 = 0;
        for (self.tiles) |tile| {
            if (!tile.marked) sum += tile.number;
        }

        return sum;
    }
};

/// The board that won, its index in the boards slice given to the sim function, and the number it won on,
/// as well as that number's index in the numbers array given.
const WinnerInfo = struct {
    /// Board that won.
    board: *Board,
    /// Index of the winning board in the list of boards that was processed.
    board_idx: usize,
    /// Final number called before the winning board won.
    number: u8,
    /// Index of the final number called before the winning board won.
    number_idx: usize,
};

/// Simulates bingo on the boards given using the given numbers until a winner is found; then
/// returns information about the winning values.
fn simulateBingo(numbers: []const u8, boards: []*Board) !WinnerInfo {
    for (numbers) |number, number_idx| {
        // Mark number on all boards, assuming it only occurs once per board
        for (boards) |board, board_idx| {
            const marked = for (board.tiles) |*tile| {
                if (tile.number == number) {
                    tile.marked = true;
                    break true;
                }
            } else false;

            // If we marked something, check for winner
            if (marked and board.isWinningState()) return WinnerInfo{
                .board = board,
                .board_idx = board_idx,
                .number = number,
                .number_idx = number_idx,
            };
        }
    }

    // No winner
    return error.InvalidInput;
}

pub fn main() !void {
    defer {
        const leaks = util.gpa_impl.deinit();
        std.debug.assert(!leaks);
    }

    var it = util.split(u8, data, "\n\n");

    // Read in number list
    const numbers = blk: {
        var numbers_list = util.List(u8).init(util.gpa);
        defer numbers_list.deinit();

        var numbers_data = it.next() orelse return error.InvalidInput;

        var numbers_it = util.tokenize(u8, numbers_data, ",");
        while (numbers_it.next()) |num_data| {
            try numbers_list.append(util.parseInt(u8, num_data, 10) catch {
                return error.InvalidInput;
            });
        }

        break :blk numbers_list.toOwnedSlice();
    };
    defer util.gpa.free(numbers);
    if (numbers.len == 0) return error.InvalidInput;

    // Read in boards
    var boards = blk: {
        var boards_list = util.List(Board).init(util.gpa);
        defer boards_list.deinit();
        while (it.next()) |board_data| {
            try boards_list.append(try Board.initFromSerializedBoard(board_data));
        }

        break :blk boards_list.toOwnedSlice();
    };
    defer util.gpa.free(boards);
    if (boards.len == 0) return error.InvalidInput;

    // Duplicate board list so we can track winners repeatedly
    var current_boards = try util.List(*Board).initCapacity(util.gpa, boards.len);
    defer current_boards.deinit();
    for (boards) |*board| {
        try current_boards.append(board);
    }

    // We also need to track what numbers we've used; just move the slice along as we go
    var current_numbers = numbers[0..];

    // We'll track the first winner (for part 1), and last winner (for part 2).
    var first_winner: ?WinnerInfo = null;
    var last_winner: WinnerInfo = undefined; // This is safe; we assert that there is at least one board previously.
    while (current_boards.items.len > 0) {
        // Simulate until bingo and remove the numbers we used
        last_winner = try simulateBingo(current_numbers, current_boards.items);
        current_numbers = current_numbers[last_winner.number_idx..];

        // Record first winner as needed
        if (first_winner == null) first_winner = last_winner;

        // Remove current winning board from list for next sim step
        _ = current_boards.swapRemove(last_winner.board_idx);
    }

    // Print first winner and score (as per part 1)
    if (first_winner) |winner| {
        util.print("Winning board score is: {d}\n", .{winner.board.sumUnmarkedNumbers() * winner.number});
    } else unreachable;

    // Print losing board and score (as per part 2)
    util.print("Losing board score is: {d}\n", .{last_winner.board.sumUnmarkedNumbers() * last_winner.number});
}
