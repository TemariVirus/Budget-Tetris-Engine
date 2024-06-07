const root = @import("../root.zig");
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = root.kicks.Rotation;

const kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

/// No kicks.
pub fn none180(piece: Piece, _: Rotation) []const Position {
    return &if (piece.kind == .o)
        .{}
    else
        kicks;
}
