const root = @import("../root.zig");
const kicks = root.kicks;
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;
const Rotation = kicks.Rotation;
const srsFn = @import("srs.zig").srsFn;

/// Classic SRS kicks, with 180 rotations but no 180 kicks.
pub const srs180 = kicks.makeKickTable(srs180Fn);

const double_kicks = [1]Position{
    Position{ .x = 0, .y = 0 },
};

pub fn srs180Fn(piece: Piece, rotation: Rotation) []const Position {
    if (rotation == .half and piece.kind != .o) {
        return &double_kicks;
    }
    return srsFn(piece, rotation);
}
