const root = @import("../root.zig");
const kicks = root.kicks;
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = kicks.Rotation;
const srsFn = @import("srs.zig").srsFn;

/// The modified SRS kicks that Tetr.io uses. Introduces some 180 kicks.
pub const srsTetrio = kicks.makeKickTable(srsTetrioFn);

const no_kicks = [0]Position{};

const double_kicks = [4][6]Position{
    [6]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 0, .y = 1 },
        Position{ .x = 1, .y = 1 },
        Position{ .x = -1, .y = 1 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = -1, .y = 0 },
    },
    [6]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = 1, .y = 2 },
        Position{ .x = 1, .y = 1 },
        Position{ .x = 0, .y = 2 },
        Position{ .x = 0, .y = 1 },
    },
    [6]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 0, .y = -1 },
        Position{ .x = -1, .y = -1 },
        Position{ .x = 1, .y = -1 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = 1, .y = 0 },
    },
    [6]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = -1, .y = 2 },
        Position{ .x = -1, .y = 1 },
        Position{ .x = 0, .y = 2 },
        Position{ .x = 0, .y = 1 },
    },
};

const double_i_kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

pub fn srsTetrioFn(piece: Piece, rotation: Rotation) []const Position {
    if (rotation == .half) {
        return &switch (piece.kind) {
            .i => double_i_kicks,
            .o => no_kicks,
            .t, .s, .z, .j, .l => double_kicks[@intFromEnum(piece.facing)],
        };
    }
    return srsFn(piece, rotation);
}
