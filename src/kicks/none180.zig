const root = @import("../root.zig");
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = root.kicks.Rotation;

/// No kicks. 180 rotations are allowed.
pub const none180 = root.kicks.makeKickTable(none180Fn);

const kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

pub fn none180Fn(piece: Piece, _: Rotation) []const Position {
    return &if (piece.kind == .o)
        .{}
    else
        kicks;
}
