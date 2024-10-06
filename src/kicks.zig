//! A kick function returns the possible kicks (x and y offsets) for a
//! particular piece and rotation, in order. The first kick that results in a
//! valid position is used. The (0, 0) kick is not implied and must be
//! explicitly returned, if it exists.

const std = @import("std");
const assert = std.debug.assert;

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
    for (std.enums.values(PieceKind)) |piece_kind| {
        for (std.enums.values(Facing)) |facing| {
            for (std.enums.values(Rotation)) |rotation| {
                const piece = Piece{
                    .facing = facing,
                    .kind = piece_kind,
                };
                const i = kickTableIndex(piece, rotation);
                table[i] = kickFn(piece, rotation);
            }
        }
    }
    return table;
}

pub fn kickTableIndex(piece: Piece, rotation: Rotation) u7 {
    const p: u7 = @intFromEnum(piece.kind);
    const f: u7 = @intFromEnum(piece.facing);
    const r: u7 = @intFromEnum(rotation);
    return @intCast((p *
        @typeInfo(Facing).Enum.fields.len + f) *
        @typeInfo(Rotation).Enum.fields.len + r);
}

/// Returns a new kick function that uses a table to look up the kicks. May
/// give better performance.
pub fn tabulariseKicks(kickFn: KickFn) KickFn {
    return (struct {
        const table = makeKickTable(kickFn);
        pub fn getKicks(piece: Piece, rotation: Rotation) []const Position {
            return table[kickTableIndex(piece, rotation)];
        }
    }).getKicks;
}

test {
    @import("std").testing.refAllDecls(@This());
}
