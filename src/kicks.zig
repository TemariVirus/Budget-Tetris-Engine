const std = @import("std");
const assert = std.debug.assert;

const root = @import("root.zig");
const Facing = root.pieces.Facing;
const Piece = root.pieces.Piece;
const PieceKind = root.pieces.PieceKind;
const Position = root.pieces.Position;

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

pub const KickFn = fn (Piece, Rotation) []const Position;

/// A kick table stores the possible kicks (x and y offsets) for a particular
/// piece and rotation, in order. The first kick that results in a valid
/// position is used. The (0, 0) kick is not implied and must be explicitly
/// stored, if it exists. When implementing your own kick table, note that a
/// value of up to only 127 kicks is supported by `Player`.
pub const KickTable = [emumVariantCount(PieceKind)][emumVariantCount(Facing)][emumVariantCount(Rotation)][]const Position;

fn emumVariantCount(E: type) usize {
    return @typeInfo(E).Enum.fields.len;
}

/// Converts a function that returns kicks to a lookup table.
pub fn makeKickTable(kickFn: KickFn) KickTable {
    @setEvalBranchQuota(10_000);
    var table: KickTable = undefined;
    for (@typeInfo(PieceKind).Enum.fields) |piece_kind| {
        for (@typeInfo(Facing).Enum.fields) |facing| {
            for (@typeInfo(Rotation).Enum.fields) |rotation| {
                table[piece_kind.value][facing.value][rotation.value] = kickFn(
                    Piece{
                        .facing = @enumFromInt(facing.value),
                        .kind = @enumFromInt(piece_kind.value),
                    },
                    @enumFromInt(rotation.value),
                );
            }
        }
    }
    return table;
}

/// Convinience function to get the kicks for a piece and rotation from a kick table.
pub fn getKicks(table: *const KickTable, piece: Piece, rotation: Rotation) []const Position {
    return table[@intFromEnum(piece.kind)][@intFromEnum(piece.facing)][@intFromEnum(rotation)];
}

test {
    @import("std").testing.refAllDecls(@This());
}
