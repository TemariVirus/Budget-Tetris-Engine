//! Functions encoding various kick tables.
//! The (0, 0) kick is always implied as the first kick, and thus is not returned.

const root = @import("root.zig");
const Facing = root.pieces.Facing;
const Piece = root.pieces.Piece;
const PieceKind = root.pieces.PieceKind;
const Position = root.pieces.Position;

pub const KickFn = fn (Piece, Rotation) []const Position;

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

pub const KICK_TABLE_SIZE = @typeInfo(PieceKind).Enum.fields.len *
    @typeInfo(Facing).Enum.fields.len *
    @typeInfo(Rotation).Enum.fields.len;
pub fn makeKickTable(kickFn: KickFn) [KICK_TABLE_SIZE][]const Position {
    @setEvalBranchQuota(10_000);

    var table: [KICK_TABLE_SIZE][]const Position = undefined;
    for (@typeInfo(PieceKind).Enum.fields) |piece_kind| {
        for (@typeInfo(Facing).Enum.fields) |facing| {
            for (@typeInfo(Rotation).Enum.fields) |rotation| {
                const piece = Piece{
                    .facing = @enumFromInt(facing.value),
                    .kind = @enumFromInt(piece_kind.value),
                };
                const i = kickTableIndex(piece, @enumFromInt(rotation.value));
                table[i] = kickFn(piece, @enumFromInt(rotation.value));
            }
        }
    }
    return table;
}

pub fn kickTableIndex(piece: Piece, rotation: Rotation) u7 {
    return @intCast(@as(u7, @as(u5, @bitCast(piece))) *
        @typeInfo(Rotation).Enum.fields.len +
        @intFromEnum(rotation));
}

test {
    @import("std").testing.refAllDecls(@This());
}
