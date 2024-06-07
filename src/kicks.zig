//! Functions encoding various kick tables.
//! The (0, 0) kick is always implied as the first kick, and thus is not returned.

const root = @import("root.zig");
const Position = root.pieces.Position;
const Piece = root.pieces.Piece;

pub const KickFn = fn (Piece, Rotation) []const Position;

// TODO: Automatically generate tables from functions and test performance
pub const none = @import("kicks/none.zig").none;
pub const none180 = @import("kicks/none180.zig").none180;
pub const srs = @import("kicks/srs.zig").srs;
pub const srs180 = @import("kicks/srs180.zig").srs180;
// The srsTetrio and srsPlus kick tables were taken directly from Tetr.io's source code (https://tetr.io/js/tetrio.js)
pub const srsTetrio = @import("kicks/srs_tetrio.zig").srsTetrio;
pub const srsPlus = @import("kicks/srs_plus.zig").srsPlus;

/// Represents a piece rotation.
pub const Rotation = enum {
    /// A 90 degree clockwise rotation.
    quarter_cw,
    /// A 180 degree rotation.
    half,
    /// A 90 degree counter-clockwise rotation.
    quarter_ccw,
};

test {
    @import("std").testing.refAllDecls(@This());
}
