const root = @import("../root.zig");
const kicks = root.kicks;
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = kicks.Rotation;
const srsTetrio = kicks.srsTetrio;

const cw_i_kicks = [4][5]Position{
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = -2, .y = 0 },
        Position{ .x = -2, .y = -1 },
        Position{ .x = 1, .y = 2 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = 2, .y = 0 },
        Position{ .x = -1, .y = 2 },
        Position{ .x = 2, .y = -1 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 2, .y = 0 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = 2, .y = 1 },
        Position{ .x = -1, .y = -2 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = -2, .y = 0 },
        Position{ .x = 1, .y = -2 },
        Position{ .x = -2, .y = 1 },
    },
};

const double_i_kicks = [4][2]Position{
    [2]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 0, .y = 1 },
    },
    [2]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 1, .y = 0 },
    },
    [2]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 0, .y = -1 },
    },
    [2]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -1, .y = 0 },
    },
};

const ccw_i_kicks = [4][5]Position{
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = 2, .y = 0 },
        Position{ .x = 2, .y = -1 },
        Position{ .x = -1, .y = 2 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -1, .y = 0 },
        Position{ .x = 2, .y = 0 },
        Position{ .x = -1, .y = -2 },
        Position{ .x = 2, .y = 1 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = -2, .y = 0 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = -2, .y = 1 },
        Position{ .x = 1, .y = -2 },
    },
    [5]Position{
        Position{ .x = 0, .y = 0 },
        Position{ .x = 1, .y = 0 },
        Position{ .x = -2, .y = 0 },
        Position{ .x = 1, .y = 2 },
        Position{ .x = -2, .y = -1 },
    },
};

/// Tetr.io's SRS+ kicks. Modifies the I kicks from `srsTetrio`.
pub fn srsPlus(piece: Piece, rotation: Rotation) []const Position {
    const table = comptime kicks.makeKickTable(srsPlusRaw);
    return table[kicks.kickTableIndex(piece, rotation)];
}

fn srsPlusRaw(piece: Piece, rotation: Rotation) []const Position {
    if (piece.kind == .i) {
        return &switch (rotation) {
            .quarter_cw => cw_i_kicks[@intFromEnum(piece.facing)],
            .half => double_i_kicks[@intFromEnum(piece.facing)],
            .quarter_ccw => ccw_i_kicks[@intFromEnum(piece.facing)],
        };
    }

    return srsTetrio(piece, rotation);
}
