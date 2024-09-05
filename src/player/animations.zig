const std = @import("std");

const nterm = @import("nterm");
const Animation = nterm.Animation;
const Color = nterm.Color;
const Colors = nterm.Colors;
const Pixel = nterm.Pixel;
const View = nterm.View;

const TRANSPERENT_PIXEL = Pixel{ .fg = null, .bg = null, .char = 0 };
const TRANSPERENT_ROW = [_]Pixel{TRANSPERENT_PIXEL} ** 20;
const BLACK_PIXEL = Pixel{ .fg = 0, .bg = Colors.BLACK, .char = ' ' };
const BLACK_ROW = [_]Pixel{BLACK_PIXEL} ** 20;

pub const CLEAR_WIDTH = 20;
pub const CLEAR_HEIGHT = 1;
pub const CLEAR_FRAMES = blk: {
    var frames = [_][]const Pixel{undefined} ** 5;
    for (0..frames.len) |i| {
        frames[i] = &[_]Pixel{TRANSPERENT_PIXEL} ** (2 * (5 - i)) ++
            [_]Pixel{BLACK_PIXEL} ** (4 * i) ++
            [_]Pixel{TRANSPERENT_PIXEL} ** (2 * (5 - i));
    }
    break :blk frames;
};
pub fn clearTimes(clear_delay: u32) [5]u64 {
    var times = [_]u64{undefined} ** 5;
    for (0..times.len - 1) |i| {
        times[i] = std.time.ns_per_ms / 5 * @as(u64, @intCast(i + 1)) * clear_delay;
    }
    times[4] = std.math.maxInt(u64);
    return times;
}

pub fn clearAnimation(time: u64, clear_delay: u32, view: View, y: u16) Animation {
    return .{
        .time = time,
        .frames = &CLEAR_FRAMES,
        .frame_times = &clearTimes(clear_delay),
        .size = .{ .width = CLEAR_WIDTH, .height = CLEAR_HEIGHT },
        .view = view.sub(12, @intCast(22 - y), CLEAR_WIDTH, CLEAR_HEIGHT),
    };
}

pub const DEATH_WIDTH = 20;
pub const DEATH_HEIGHT = 20;
pub const DEATH_FRAMES = blk: {
    var frames = [_][]const Pixel{undefined} ** 21;
    for (0..frames.len - 1) |i| {
        frames[i] = &TRANSPERENT_ROW ** (frames.len - i - 1) ++ BLACK_ROW ** i;
    }

    const last_frame = blk2: {
        var pixels = BLACK_ROW ** 20;
        // Add dead face
        var x = 7;
        var face = std.unicode.Utf8Iterator{ .bytes = "(x╭╮x)", .i = 0 };
        while (face.nextCodepoint()) |c| {
            pixels[7 * DEATH_WIDTH + x] = .{ .fg = Colors.WHITE, .bg = Colors.BLACK, .char = c };
            x += 1;
        }
        break :blk2 pixels;
    };
    frames[frames.len - 1] = &last_frame;

    break :blk frames;
};
pub const DEATH_TIMES = blk: {
    var times = [_]u64{undefined} ** 21;
    for (0..times.len - 1) |i| {
        times[i] = @as(u64, @intCast(i + 1)) * 100 * std.time.ns_per_ms;
    }
    times[times.len - 1] = std.math.maxInt(u64);
    break :blk times;
};

pub fn deathAnimation(time: u64, view: View) Animation {
    return .{
        .time = time,
        .frames = &DEATH_FRAMES,
        .frame_times = &DEATH_TIMES,
        .size = .{ .width = DEATH_WIDTH, .height = DEATH_HEIGHT },
        .view = view.sub(0, 0, DEATH_WIDTH, DEATH_HEIGHT),
    };
}
