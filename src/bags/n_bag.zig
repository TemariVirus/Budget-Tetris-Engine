const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

const root = @import("../root.zig");
const PieceKind = root.pieces.PieceKind;
const SplitMix64 = root.bags.SplitMix64;

/// Draws from a bag of N pieces without replacement. The bag is refilled with
/// all pieces evenly. If `N` is not a multiple of 7, the excess pieces will be
/// drawn randomly from a 7-bag.
pub fn NBag(comptime N: usize) type {
    return struct {
        const Self = @This();

        pieces: [N]PieceKind = undefined,
        index: usize = N,
        random: SplitMix64,

        pub fn init(seed: u64) Self {
            return Self{ .random = SplitMix64.init(seed) };
        }

        fn refill(self: *Self) void {
            var pieces: [7]PieceKind = .{ .i, .o, .t, .s, .z, .j, .l };
            const random = self.random.random();

            random.shuffle(PieceKind, &pieces);
            for (0..self.pieces.len) |i| {
                self.pieces[i] = pieces[i % 7];
            }
            random.shuffle(PieceKind, &self.pieces);
        }

        /// Returns the next piece in the bag.
        pub fn next(self: *Self) PieceKind {
            if (self.index >= self.pieces.len) {
                self.refill();
                self.index = 0;
            }

            defer self.index += 1;
            return self.pieces[self.index];
        }

        /// Sets the seed of the bag. The current bag will be discarded and refilled.
        pub fn setSeed(self: *Self, seed: u64) void {
            self.* = init(seed);
        }
    };
}

test "N-bag (100) randomizer" {
    var bag = NBag(100).init(42);

    var actual = std.AutoHashMap(PieceKind, i32).init(testing.allocator);
    defer actual.deinit();

    // Exhaust the bag
    for (0..100) |_| {
        const piece = bag.next();
        const count = actual.get(piece) orelse 0;
        try actual.put(piece, count + 1);
    }

    // Should have 14 or 15 of each piece
    const expected = [_]PieceKind{ .i, .o, .t, .s, .z, .j, .l };
    for (expected) |piece| {
        const count = actual.get(piece) orelse 0;
        try expect(count == 14 or count == 15);
    }
}
