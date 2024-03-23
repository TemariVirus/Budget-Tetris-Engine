const std = @import("std");

const nterm = @import("nterm");
const Animation = nterm.Animation;
const Color = nterm.Color;
const Frame = nterm.Frame;
const Pixel = nterm.Pixel;
const View = nterm.View;

const TRANSPERENT_PIXEL = Pixel{ .fg = Color.none, .bg = Color.none, .char = 0 };
const TRANSPERENT_ROW = [_]Pixel{TRANSPERENT_PIXEL} ** 20;
const BLACK_PIXEL = Pixel{ .fg = Color.black, .bg = Color.black, .char = ' ' };
const BLACK_ROW = [_]Pixel{BLACK_PIXEL} ** 20;

pub const CLEAR_WIDTH = 20;
pub const CLEAR_HEIGHT = 1;
pub const CLEAR_FRAMES = blk: {
    var frames = [_]Frame{undefined} ** 5;
    for (0..frames.len) |i| {
        var pixels = [_]Pixel{TRANSPERENT_PIXEL} ** (2 * (5 - i)) ++ [_]Pixel{BLACK_PIXEL} ** (4 * i) ++ [_]Pixel{TRANSPERENT_PIXEL} ** (2 * (5 - i));
        frames[i] = .{
            .size = .{ .width = CLEAR_WIDTH, .height = CLEAR_HEIGHT },
            .pixels = &pixels,
        };
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
        .view = view.sub(12, @intCast(22 - y), CLEAR_WIDTH, CLEAR_HEIGHT),
    };
}

pub const DEATH_WIDTH = 20;
pub const DEATH_HEIGHT = 20;
pub const DEATH_FRAMES = blk: {
    var frames = [_]Frame{undefined} ** 21;
    for (0..frames.len) |i| {
        var pixels = TRANSPERENT_ROW ** (frames.len - i - 1) ++ BLACK_ROW ** i;
        frames[i] = .{
            .size = .{ .width = DEATH_WIDTH, .height = DEATH_HEIGHT },
            .pixels = &pixels,
        };
    }

    // Add dead face
    var x = 7;
    var face = std.unicode.Utf8Iterator{ .bytes = "(x╭╮x)", .i = 0 };
    while (face.nextCodepoint()) |c| {
        frames[frames.len - 1].set(x, 7, .{ .fg = Color.white, .bg = Color.black, .char = c });
        x += 1;
    }

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
        .view = view.sub(0, 0, DEATH_WIDTH, DEATH_HEIGHT),
    };
}
