const assert = @import("std").debug.assert;

const nterm = @import("nterm");
const Color = nterm.Color;
const Colors = nterm.Colors;

const Self = @This();

pub const WIDTH = 10;
pub const HEIGHT = 40;
pub const EMPTY_COLOR = Colors.BLACK;
pub const GARBAGE_COLOR = Colors.WHITE;
const EMPTY_BYTE = (@as(u8, @intFromEnum(PackedColor.empty)) << 4) | @intFromEnum(PackedColor.empty);

pub const PackedColor = enum(u4) {
    empty,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    garbage,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
};

data: [WIDTH * HEIGHT / 2]u8 = [_]u8{EMPTY_BYTE} ** (WIDTH * HEIGHT / 2),

pub fn pack(color: ?Color) PackedColor {
    if (color) |c| {
        return switch (c) {
            Colors.BLACK => .empty,
            Colors.RED => .red,
            Colors.GREEN => .green,
            Colors.YELLOW => .yellow,
            Colors.BLUE => .blue,
            Colors.MAGENTA => .magenta,
            Colors.CYAN => .cyan,
            Colors.WHITE => .garbage,
            Colors.BRIGHT_BLACK => .bright_black,
            Colors.BRIGHT_RED => .bright_red,
            Colors.BRIGHT_GREEN => .bright_green,
            Colors.BRIGHT_YELLOW => .bright_yellow,
            Colors.BRIGHT_BLUE => .bright_blue,
            Colors.BRIGHT_MAGENTA => .bright_magenta,
            Colors.BRIGHT_CYAN => .bright_cyan,
            Colors.BRIGHT_WHITE => .bright_white,
            else => unreachable,
        };
    }
    return .empty;
}

pub fn unpack(color: PackedColor) ?Color {
    return switch (color) {
        .empty => null,
        .red => Colors.RED,
        .green => Colors.GREEN,
        .yellow => Colors.YELLOW,
        .blue => Colors.BLUE,
        .magenta => Colors.MAGENTA,
        .cyan => Colors.CYAN,
        .garbage => Colors.WHITE,
        .bright_black => Colors.BRIGHT_BLACK,
        .bright_red => Colors.BRIGHT_RED,
        .bright_green => Colors.BRIGHT_GREEN,
        .bright_yellow => Colors.BRIGHT_YELLOW,
        .bright_blue => Colors.BRIGHT_BLUE,
        .bright_magenta => Colors.BRIGHT_MAGENTA,
        .bright_cyan => Colors.BRIGHT_CYAN,
        .bright_white => Colors.BRIGHT_WHITE,
    };
}

pub fn get(self: Self, x: usize, y: usize) ?Color {
    assert(x < WIDTH and y < HEIGHT);

    const i = (y * WIDTH + x) / 2;
    const color = if (x % 2 == 0)
        self.data[i] & 0xF
    else
        self.data[i] >> 4;
    return unpack(@enumFromInt(color));
}

pub fn set(self: *Self, x: usize, y: usize, color: ?Color) void {
    assert(x < WIDTH and y < HEIGHT);

    const i = (y * WIDTH + x) / 2;
    const packed_color: u8 = @intFromEnum(pack(color));
    if (x % 2 == 0) {
        self.data[i] = (self.data[i] & 0xF0) | packed_color;
    } else {
        self.data[i] = (packed_color << 4) | (self.data[i] & 0x0F);
    }
}

pub fn copyRow(self: *Self, dst: usize, src: usize) void {
    assert(src < HEIGHT and dst < HEIGHT);

    const src_index = src * WIDTH / 2;
    const dst_index = dst * WIDTH / 2;
    for (0..WIDTH / 2) |i| {
        self.data[dst_index + i] = self.data[src_index + i];
    }
}

pub fn isRowFull(colors: Self, y: usize) bool {
    assert(y < HEIGHT);
    const empty = @intFromEnum(PackedColor.empty);

    const i = y * WIDTH / 2;
    for (colors.data[i .. i + WIDTH / 2]) |color| {
        const high = color >> 4;
        const low = color & 0xF;
        if (high == empty or low == empty) {
            return false;
        }
    }
    return true;
}

pub fn isRowGarbage(colors: Self, y: usize) bool {
    assert(y < HEIGHT);
    const garbage = @intFromEnum(PackedColor.garbage);

    const i = y * WIDTH / 2;
    for (colors.data[i .. i + WIDTH / 2]) |color| {
        const high = color >> 4;
        const low = color & 0xF;
        if (high == garbage or low == garbage) {
            return true;
        }
    }
    return false;
}

pub fn emptyRow(self: *Self, y: usize) void {
    assert(y < HEIGHT);

    const i = y * WIDTH / 2;
    for (self.data[i .. i + WIDTH / 2]) |*color| {
        color.* = EMPTY_BYTE;
    }
}
