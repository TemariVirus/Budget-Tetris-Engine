const root = @import("../root.zig");
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = root.kicks.Rotation;
const srs = @import("srs.zig").srs;

const double_kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

/// Classic SRS kicks, with 180 rotations but no kicks.
pub fn srs180(piece: Piece, rotation: Rotation) []const Position {
    if (rotation == .half and piece.kind != .o) {
        return &double_kicks;
    }

    return srs(piece, rotation);
}
