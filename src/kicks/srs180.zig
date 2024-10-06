const root = @import("../root.zig");
const kicks = root.kicks;
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = kicks.Rotation;
const srs = @import("srs.zig").srsRaw;

const double_kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

/// Classic SRS kicks, with 180 rotations but no kicks.
pub const srs180 = kicks.tabulariseKicks(srs180Raw);

pub fn srs180Raw(piece: Piece, rotation: Rotation) []const Position {
    if (rotation == .half and piece.kind != .o) {
        return &double_kicks;
    }

    return srs(piece, rotation);
}
