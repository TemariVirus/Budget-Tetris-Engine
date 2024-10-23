const root = @import("../root.zig");
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = root.kicks.Rotation;

/// No kicks. No 180 rotations.
pub const none = root.kicks.makeKickTable(noneFn);

const kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

pub fn noneFn(piece: Piece, rotation: Rotation) []const Position {
    return &if (piece.kind == .o or rotation == .half)
        .{}
    else
        kicks;
}
