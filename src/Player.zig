const std = @import("std");

const nterm = @import("nterm");
const Colors = nterm.Colors;
const View = nterm.View;

const root = @import("root.zig");
const ClearInfo = root.attack.ClearInfo;
const KickTable = root.kicks.KickTable;
const Piece = root.pieces.Piece;
const Settings = root.GameSettings;
const Stat = root.GameSettings.Stat;

const animations = @import("player/animations.zig");
pub const ColorArray = @import("player/ColorArray.zig");

pub const SfxFn = fn (sfx: Sfx) void;
pub const Sfx = enum(u8) {
    move,
    rotate,
    hard_drop,
    hold,
    pause,
    landing,
    garbage_small,
    garbage_large,
    single_clear,
    double_clear,
    tetris_clear,
    triple_clear,
    t_spin,
    perfect_clear,
};

pub const IncomingGarbage = packed struct {
    /// The x position of the hole in the garbage.
    hole: u4,
    /// The number of lines of garbage.
    lines: u16,
    /// The time in miliseconds at which the garbage should be added.
    time: u44,
};
// Use a bounded array to avoid dynamic allocation
pub const GarbageQueue = std.BoundedArray(IncomingGarbage, 25);

pub fn Player(comptime BagImpl: type) type {
    return struct {
        const Self = @This();
        pub const GameState = root.GameState(BagImpl);
        pub const Bag = root.bags.Bag(BagImpl);

        pub const DISPLAY_W = 44;
        pub const DISPLAY_H = 24;

        const AlivePlayers = struct {
            players: []Self,

            pub fn count(self: AlivePlayers) usize {
                var result: usize = 0;
                for (self.players) |p| {
                    if (p.alive()) {
                        result += 1;
                    }
                }
                return result;
            }

            pub fn iter(self: AlivePlayers) AlivePlayersIterator {
                return AlivePlayersIterator{ .players = self.players };
            }

            pub fn getAt(self: AlivePlayers, index: usize) *Self {
                var i: usize = 0;
                for (self.players) |*p| {
                    if (p.alive()) {
                        if (i == index) {
                            return p;
                        }
                        i += 1;
                    }
                }
                unreachable;
            }

            pub fn getAtButSelf(self: AlivePlayers, index: usize, self_index: usize) *Self {
                var i: usize = 0;
                for (self.players, 0..) |*p, j| {
                    if (p.alive() and j != self_index) {
                        if (i == index) {
                            return p;
                        }
                        i += 1;
                    }
                }
                unreachable;
            }
        };

        const AlivePlayersIterator = struct {
            players: []Self,
            index: usize = 0,

            pub fn next(self: *AlivePlayersIterator) ?*Self {
                while (self.index < self.players.len) {
                    defer self.index += 1;
                    if (self.players[self.index].alive()) {
                        return &self.players[self.index];
                    }
                }
                return null;
            }
        };

        name: []const u8,
        state: GameState,
        last_clear_info: ClearInfo = .{
            .b2b = false,
            .cleared = 0,
            .pc = false,
            .t_spin = .none,
        },
        /// The number of nanoseconds since the game started when the last clear info was displayed.
        last_clear_time: u64 = 0,
        playfield_colors: ColorArray = ColorArray{},
        garbage_queue: GarbageQueue = GarbageQueue{},
        settings: Settings,

        already_held: bool = false,
        last_kick: i8 = -1,
        move_count: u8 = 0,
        /// The number of nanoseconds since the game started when the last move was made.
        last_move_time: u64 = 0,
        soft_dropping: bool = false,
        vel: f32 = 0.0,

        view: View,
        anim_time: u64 = 0,
        clear_anim_start: u64 = 0,
        death_anim_start: u64 = 0,
        playSfx: *const SfxFn,

        /// The number of nanoseconds since the game started. Stops increasing when the
        /// game is paused or the player is dead.
        time: u64 = 0,
        lines_cleared: u32 = 0,
        garbage_cleared: u32 = 0,
        pieces_placed: u32 = 0,
        lines_sent: u32 = 0,
        lines_received: u32 = 0,
        score: u64 = 0,
        current_piece_keys: u32 = 0,
        keys_pressed: u32 = 0,
        finesse: u32 = 0,

        pub fn init(
            name: []const u8,
            bag: BagImpl,
            kicks: *const KickTable,
            settings: Settings,
            view: View,
            playSfx: *const SfxFn,
        ) Self {
            return Self{
                .name = name,
                .state = GameState.init(bag, kicks),
                .settings = settings,
                .view = view,
                .playSfx = playSfx,
            };
        }

        pub fn alive(self: Self) bool {
            return self.death_anim_start == 0;
        }

        pub fn frozen(self: Self) bool {
            return self.clear_anim_start != 0 or !self.alive();
        }

        /// Holds the current piece, or does nothing if the piece has already been held.
        pub fn hold(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            self.current_piece_keys +|= 1;
            if (self.already_held) {
                return;
            }

            self.state.hold();
            self.already_held = true;
            self.last_kick = -1;
            self.move_count = 0;
            self.last_move_time = self.time;
            self.playSfx(.hold);
        }

        pub fn moveLeft(self: *Self, das: bool) void {
            if (self.frozen()) {
                return;
            }

            if (!das) {
                self.current_piece_keys +|= 1;
            }

            if (self.state.slide(-1) == 0) {
                return;
            }

            self.last_kick = -1;
            if (self.move_count < self.settings.autolock_grace) {
                if (!das) {
                    self.move_count +|= 1;
                }
                self.last_move_time = self.time;
            }

            self.playSfx(.move);
        }

        /// Assumes that the move was caused by DAS and does not count as an extra keypress.
        pub fn moveLeftAll(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            if (self.state.slide(-10) == 0) {
                return;
            }

            self.last_kick = -1;
            if (self.move_count < self.settings.autolock_grace) {
                self.last_move_time = self.time;
            }

            self.playSfx(.move);
        }

        pub fn moveRight(self: *Self, das: bool) void {
            if (self.frozen()) {
                return;
            }

            if (!das) {
                self.current_piece_keys +|= 1;
            }

            if (self.state.slide(1) == 0) {
                return;
            }

            self.last_kick = -1;
            if (self.move_count < self.settings.autolock_grace) {
                if (!das) {
                    self.move_count +|= 1;
                }
                self.last_move_time = self.time;
            }

            self.playSfx(.move);
        }

        /// Assumes that the move was caused by DAS and does not count as an extra keypress.
        pub fn moveRightAll(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            if (self.state.slide(10) == 0) {
                return;
            }

            self.last_kick = -1;
            if (self.move_count < self.settings.autolock_grace) {
                self.last_move_time = self.time;
            }

            self.playSfx(.move);
        }

        pub fn rotateCw(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            self.current_piece_keys +|= 1;
            const kick = self.state.rotate(.quarter_cw);
            if (kick == -1) {
                return;
            }

            self.last_kick = kick;
            if (self.move_count < self.settings.autolock_grace) {
                self.move_count +|= 1;
                self.last_move_time = self.time;
            }

            self.playSfx(.rotate);
        }

        pub fn rotateDouble(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            self.current_piece_keys +|= 1;
            const kick = self.state.rotate(.half);
            if (kick == -1) {
                return;
            }

            self.last_kick = kick;
            if (self.move_count < self.settings.autolock_grace) {
                self.move_count +|= 1;
                self.last_move_time = self.time;
            }

            self.playSfx(.rotate);
        }

        pub fn rotateCcw(self: *Self) void {
            if (self.frozen()) {
                return;
            }

            self.current_piece_keys +|= 1;
            const kick = self.state.rotate(.quarter_ccw);
            if (kick == -1) {
                return;
            }

            self.last_kick = kick;
            if (self.move_count < self.settings.autolock_grace) {
                self.move_count +|= 1;
                self.last_move_time = self.time;
            }

            self.playSfx(.rotate);
        }

        pub fn softDrop(self: *Self) void {
            if (self.frozen() or self.soft_dropping) {
                return;
            }
            self.soft_dropping = true;
        }

        pub fn hardDrop(self: *Self, self_index: usize, players: []Self) void {
            if (self.frozen()) {
                return;
            }

            const dropped = self.state.dropToGround();
            self.score += @intCast(dropped * 2);
            if (dropped > 0) {
                self.last_kick = -1;
            }

            self.playSfx(.hard_drop);
            self.placeCurrent(self_index, players);
        }

        fn placeCurrent(self: *Self, self_index: usize, players: []Self) void {
            const clear_info = self.lockCurrent();
            self.handleGarbage(clear_info.info.cleared > 0, clear_info.attack, self_index, players);
            self.updateStats(clear_info.info, clear_info.score, clear_info.attack);

            // Only overwrite the last clear info if there's something interesting to display
            if (clear_info.info.cleared > 0 or clear_info.info.pc or clear_info.info.t_spin != .none) {
                self.last_clear_info = clear_info.info;
                self.last_clear_time = self.anim_time;
            }

            self.state.nextPiece();
            self.already_held = false;
            self.last_kick = -1;
            self.move_count = 0;
            self.last_move_time = self.time;
            self.soft_dropping = false;
            self.vel = 0.0;

            if (clear_info.info.pc) {
                self.playSfx(.perfect_clear);
            } else if (clear_info.info.t_spin != .none) {
                self.playSfx(.t_spin);
            } else if (clear_info.info.cleared > 0) {
                self.playSfx(switch (clear_info.info.cleared) {
                    1 => .single_clear,
                    2 => .double_clear,
                    3 => .triple_clear,
                    4 => .tetris_clear,
                    else => unreachable,
                });
            }

            if (self.state.playfield.collides(self.state.current.mask(), self.state.pos) or // Block out
                (self.settings.use_lockout and self.state.pos.y - self.state.current.bottom() >= 20)) // Lock out
            {
                self.death_anim_start = self.anim_time;
            } else if (self.settings.clear_delay == 0 or clear_info.info.cleared == 0) {
                // Skip clear animation if no clear delay or if no clears
                self.finishClear();
            } else {
                self.clear_anim_start = self.anim_time;
            }
        }

        fn lockCurrent(self: *Self) struct { info: ClearInfo, score: u64, attack: u16 } {
            // Place piece in playfield colors
            const start: u8 = @max(0, self.state.pos.y);
            for (start..@intCast(self.state.pos.y + 4)) |y| {
                var row = self.state.current.mask().rows[@intCast(@as(isize, @intCast(y)) - self.state.pos.y)];
                row = if (self.state.pos.x > 0)
                    row >> @intCast(self.state.pos.x)
                else
                    row << @intCast(-self.state.pos.x);

                for (0..10) |x| {
                    if ((row >> @intCast(10 - x)) & 1 == 1) {
                        self.playfield_colors.set(x, y, self.state.current.kind.color());
                    }
                }
            }

            // Scoring values taken from Tetris.wiki
            // https://tetris.wiki/Scoring#Recent_guideline_compatible_games
            const info = self.state.lockCurrent(self.last_kick);
            var clear_score = ([_]u64{ 0, 100, 300, 500, 800 })[info.cleared];
            clear_score += switch (info.t_spin) {
                .mini => 100,
                .full => ([_]u64{ 400, 700, 900, 1100 })[info.cleared],
                .none => 0,
            };
            if (info.b2b) {
                clear_score += clear_score / 2;
            }
            if (info.pc) {
                clear_score += ([_]u64{ 800, 1200, 1800, 2000 })[info.cleared - 1];
                if (info.b2b and info.cleared == 4) {
                    clear_score += 1200;
                }
            }
            if (self.state.combo > 1) {
                clear_score += 50 * (self.state.combo - 1);
            }
            const attack = self.settings.attack_table.getAttack(info, self.state.b2b, self.state.combo);

            return .{
                .info = info,
                .score = clear_score,
                .attack = attack,
            };
        }

        fn handleGarbage(
            self: *Self,
            cleared: bool,
            attack: u16,
            self_index: usize,
            players: []Self,
        ) void {
            // Counter garbage
            var i: usize = 0;
            var remaining_attack = attack;
            while (remaining_attack > 0 and i < self.garbage_queue.len) : (i += 1) {
                const garbage = &self.garbage_queue.buffer[i];
                const countered = @min(remaining_attack, garbage.lines);
                remaining_attack -= countered;
                garbage.lines -= countered;
                if (garbage.lines > 0) {
                    break;
                }
            }

            // Send remaining attack
            const alive_players = AlivePlayers{ .players = players };
            switch (self.settings.target_mode) {
                .none => {},
                .random => {
                    const index = std.crypto.random.uintLessThan(usize, alive_players.count());
                    alive_players.getAt(index).queueGarbage(
                        null,
                        remaining_attack,
                        self.time + self.settings.garbage_delay * std.time.ns_per_ms,
                    );
                },
                .random_but_self => blk: {
                    const alive_count = if (self.alive()) alive_players.count() - 1 else alive_players.count();
                    if (alive_count == 0) {
                        break :blk;
                    }

                    const index = std.crypto.random.uintLessThan(usize, alive_count);
                    alive_players.getAtButSelf(index, self_index).queueGarbage(
                        null,
                        remaining_attack,
                        self.time + self.settings.garbage_delay * std.time.ns_per_ms,
                    );
                },
                .all => {
                    var iter = alive_players.iter();
                    while (iter.next()) |p| {
                        p.queueGarbage(
                            null,
                            remaining_attack,
                            self.time + self.settings.garbage_delay * std.time.ns_per_ms,
                        );
                    }
                },
                .all_but_self => {
                    var iter = alive_players.iter();
                    while (iter.next()) |p| {
                        if (iter.index == self_index) {
                            continue;
                        }
                        p.queueGarbage(
                            null,
                            remaining_attack,
                            self.time + self.settings.garbage_delay * std.time.ns_per_ms,
                        );
                    }
                },
                .self => {
                    players[self_index].queueGarbage(
                        null,
                        remaining_attack,
                        self.time + self.settings.garbage_delay * std.time.ns_per_ms,
                    );
                },
            }

            // Receive garbage
            if (!cleared) {
                var remaining_garbage = self.settings.garbage_cap;
                while (remaining_garbage > 0 and i < self.garbage_queue.len) : (i += 1) {
                    const garbage = &self.garbage_queue.buffer[i];
                    if (self.time < @as(u64, garbage.time) * std.time.ns_per_ms) {
                        break;
                    }

                    const received = @min(remaining_garbage, garbage.lines);
                    self.addGarbage(garbage.hole, received);
                    remaining_garbage -= received;
                    garbage.lines -= received;
                    if (garbage.lines > 0) {
                        break;
                    }
                }
            }

            for (0..self.garbage_queue.len - i) |j| {
                self.garbage_queue.buffer[j] = self.garbage_queue.buffer[i + j];
            }
            self.garbage_queue.len -= @intCast(i);
        }

        fn updateStats(self: *Self, info: ClearInfo, score: u64, attack: u16) void {
            self.score += score * self.level();
            self.lines_cleared += info.cleared;
            self.pieces_placed += 1;
            self.lines_sent += attack;
            // TODO: Calculate finesse
            self.keys_pressed += self.current_piece_keys;
            self.current_piece_keys = 0;
        }

        fn finishClear(self: *Self) void {
            self.clear_anim_start = 0;

            // Clear full lines in playfield colors
            var clears: usize = 0;
            var i: usize = 0;
            while (i + clears < ColorArray.HEIGHT) {
                self.playfield_colors.copyRow(i, i + clears);
                if (!self.playfield_colors.isRowFull(i)) {
                    i += 1;
                    continue;
                }

                clears += 1;
                if (self.playfield_colors.isRowGarbage(i)) {
                    self.garbage_cleared += 1;
                }
            }
            while (i < ColorArray.HEIGHT) : (i += 1) {
                self.playfield_colors.emptyRow(i);
            }
        }

        /// Queues garbage to be added to the playfield.
        pub fn queueGarbage(self: *Self, hole: ?u4, lines: u16, time: u64) void {
            const resolved_hole = hole orelse std.crypto.random.uintLessThan(u4, 10);
            if (self.garbage_queue.len < self.garbage_queue.capacity()) {
                self.garbage_queue.appendAssumeCapacity(.{
                    .hole = resolved_hole,
                    .lines = lines,
                    .time = @intCast(time / std.time.ns_per_ms),
                });
            } else {
                // Add extra garbage to last item if we run out of space
                self.garbage_queue.buffer[self.garbage_queue.len - 1].lines +|= lines;
            }
        }

        /// Adds garbage to the bottom of the playfield. `hole` is the x position of the
        /// hole, and `lines` is the number of lines of garbage to add.
        pub fn addGarbage(self: *Self, hole: u4, lines: u16) void {
            if (lines == 0) {
                return;
            }

            self.lines_received += lines;
            self.state.addGarbage(hole, lines);

            var i: usize = ColorArray.HEIGHT;
            while (i > lines) {
                i -= 1;
                self.playfield_colors.copyRow(i, i - lines);
            }

            for (0..ColorArray.WIDTH) |x| {
                self.playfield_colors.set(x, 0, if (x == hole)
                    ColorArray.EMPTY_COLOR
                else
                    ColorArray.GARBAGE_COLOR);
            }
            for (1..lines) |y| {
                self.playfield_colors.copyRow(y, 0);
            }
        }

        /// Advances the game.
        pub fn tick(self: *Self, nanoseconds: u64, self_index: usize, players: []Self) void {
            if (self.clear_anim_start != 0) {
                // Reset clear animation when it's done
                const clear_anim_time = self.anim_time - self.clear_anim_start;
                if (clear_anim_time >= @as(u64, @intCast(self.settings.clear_delay)) * std.time.ns_per_ms) {
                    self.finishClear();
                }
            }

            self.anim_time += nanoseconds;
            if (self.frozen()) {
                if (self.alive()) {
                    self.soft_dropping = false;
                }
                return;
            }

            const now = self.anim_time; // Time is not updated when forzen, use anim_time to catch up
            const g = self.settings.g + if (self.soft_dropping) self.settings.soft_g else 0.0;
            self.vel += g * @as(f32, @floatFromInt(nanoseconds)) / std.time.ns_per_s;

            // Handle autolocking
            if (self.state.onGround()) {
                self.vel = 0.0;

                if (self.move_count > self.settings.autolock_grace or
                    now -| self.last_move_time >= @as(u64, self.settings.lock_delay) * std.time.ns_per_ms)
                {
                    self.placeCurrent(self_index, players);
                    self.playSfx(.landing);
                }
            }

            // Handle gravity
            const dropped = self.state.drop(@intFromFloat(@min(255, self.vel)));
            self.vel -= @floatFromInt(dropped);
            if (self.soft_dropping) {
                self.score += dropped;
            }
            if (dropped > 0) {
                self.last_kick = -1;
                self.last_move_time = now;
            }

            self.time = now;
            self.soft_dropping = false;
        }

        /// Restarts the game with the given seed. If `seed` is `null`, the seed is
        /// unchanged.
        pub fn restart(self: *Self, seed: ?u64) void {
            if (seed) |s| {
                self.state.bag.setSeed(s);
            }
            self.* = init(
                self.name,
                self.state.bag.context,
                self.state.kicks,
                self.settings,
                self.view,
                self.playSfx,
            );
        }

        /// Returns the current level
        pub fn level(self: Self) u64 {
            return (self.lines_cleared / 10) + 1;
        }

        /// Returns the current Attack Per Line (APL)
        pub fn apl(self: Self) f32 {
            if (self.lines_sent == 0) {
                return 0.0;
            }
            return @as(f32, @floatFromInt(self.lines_sent)) / @as(f32, @floatFromInt(self.lines_cleared));
        }

        /// Returns the current Attack Per Minute (APM)
        pub fn apm(self: Self) f32 {
            if (self.lines_sent == 0.0) {
                return 0.0;
            }
            return @as(f32, @floatFromInt(self.lines_sent)) / @as(f32, @floatFromInt(self.time)) * std.time.ns_per_min;
        }

        /// Returns the current Attack Per Piece (APP)
        pub fn app(self: Self) f32 {
            if (self.lines_sent == 0) {
                return 0.0;
            }
            return @as(f32, @floatFromInt(self.lines_sent)) / @as(f32, @floatFromInt(self.pieces_placed));
        }

        /// Returns the current Keys Per Piece (KPP)
        pub fn kpp(self: Self) f32 {
            if (self.pieces_placed == 0) {
                return 0.0;
            }
            return @as(f32, @floatFromInt(self.keys_pressed)) / @as(f32, @floatFromInt(self.pieces_placed));
        }

        /// Returns the current Pieces Per Second (PPS)
        pub fn pps(self: Self) f32 {
            if (self.pieces_placed == 0) {
                return 0.0;
            }
            return @as(f32, @floatFromInt(self.pieces_placed)) / @as(f32, @floatFromInt(self.time)) * std.time.ns_per_s;
        }

        /// Returns the current VS Score
        pub fn vsScore(self: Self) f32 {
            const sent_cleared: f32 = @floatFromInt(self.lines_sent + self.garbage_cleared);
            if (sent_cleared == 0.0) {
                return 0.0;
            }
            return 100.0 * sent_cleared / @as(f32, @floatFromInt(self.time)) * std.time.ns_per_s;
        }

        /// Draws the game elements to the game's allocated view.
        pub fn draw(self: Self) void {
            self.drawNameLines();
            self.drawHold();
            self.drawScoreLevel();
            self.drawClearInfo();
            self.drawMatrix();
            self.drawGarbageMeter();
            self.drawNext();
            for (self.settings.display_stats, 0..) |stat, i| {
                self.drawStat(stat, @intCast(i));
            }
        }

        fn drawNameLines(self: Self) void {
            self.view.printAligned(.center, 0, Colors.WHITE, null, "{s}", .{self.name});
            self.view.printAligned(.center, 1, Colors.WHITE, null, "LINES - {d}", .{self.lines_cleared});
        }

        fn drawPiece(view: View, x: i8, y: i8, piece: Piece, solid: bool) void {
            const mask = piece.mask();
            const color = piece.kind.color();
            for (0..4) |dy| {
                for (0..4) |dx| {
                    if (!mask.get(dx, dy)) {
                        continue;
                    }
                    const x2 = x + @as(i8, @intCast(dx * 2));
                    const y2 = y - @as(i8, @intCast(dy));
                    if (x2 < 0 or y2 < 0 or x2 >= view.width or y2 >= view.height) {
                        continue;
                    }

                    if (solid) {
                        _ = view.writeText(@intCast(x2), @intCast(y2), 0, color, "  ");
                    } else {
                        _ = view.writeText(@intCast(x2), @intCast(y2), color, null, "▒▒");
                    }
                }
            }
        }

        fn drawHold(self: Self) void {
            const LEFT = 0;
            const TOP = 2;
            const WIDTH = 10;
            const HEIGHT = 5;

            const hold_box = self.view.sub(LEFT, TOP, WIDTH, HEIGHT);
            hold_box.drawBox(0, 0, WIDTH, HEIGHT, Colors.WHITE, null);
            _ = hold_box.writeText(3, 0, Colors.WHITE, null, "HOLD");
            if (self.state.hold_kind) |hold_kind| {
                const hold_piece = Piece{
                    .facing = .up,
                    .kind = hold_kind,
                };
                const y: i8 = if (hold_kind == .i) 4 else 3;
                drawPiece(hold_box, 1, y, hold_piece, true);
            }
        }

        fn drawScoreLevel(self: Self) void {
            const LEFT = 0;
            const TOP = 8;
            const WIDTH = 10;
            const HEIGHT = 6;

            const score_level_box = self.view.sub(LEFT, TOP, WIDTH, HEIGHT);
            score_level_box.drawBox(0, 0, WIDTH, HEIGHT, Colors.WHITE, null);
            _ = score_level_box.writeText(1, 1, Colors.WHITE, null, "SCORE");
            printGlitchyU64(score_level_box, 1, 2, self.score);
            _ = score_level_box.writeText(1, 3, Colors.WHITE, null, "LEVEL");
            printGlitchyU64(score_level_box, 1, 4, self.level());
        }

        fn drawClearInfo(self: Self) void {
            const LEFT = 0;
            const TOP = 15;
            const WIDTH = 10;
            const HEIGHT = 5;
            if (self.clear_anim_start == 0 and self.anim_time - self.last_clear_time >= self.settings.clear_erase_dalay * std.time.ns_per_ms) {
                return;
            }

            const clear_info_box = self.view.sub(LEFT, TOP, WIDTH, HEIGHT);
            if (self.last_clear_info.b2b) {
                clear_info_box.writeAligned(.center, 0, Colors.WHITE, null, "B2B");
            }
            switch (self.last_clear_info.t_spin) {
                .none => {},
                .mini => clear_info_box.writeAligned(.center, 1, Colors.WHITE, null, "T-SPIN MINI"),
                .full => clear_info_box.writeAligned(.center, 1, Colors.WHITE, null, "T-SPIN"),
            }
            switch (self.last_clear_info.cleared) {
                1 => clear_info_box.writeAligned(.center, 2, Colors.WHITE, null, "SINGLE"),
                2 => clear_info_box.writeAligned(.center, 2, Colors.WHITE, null, "DOUBLE"),
                3 => clear_info_box.writeAligned(.center, 2, Colors.WHITE, null, "TRIPLE"),
                4 => clear_info_box.writeAligned(.center, 2, Colors.WHITE, null, "TETRIS"),
                else => {},
            }
            if (self.state.combo > 1) {
                clear_info_box.printAligned(.center, 3, Colors.WHITE, null, "{d} COMBO!", .{self.state.combo - 1});
            }
            if (self.last_clear_info.pc) {
                clear_info_box.writeAligned(.center, 4, Colors.WHITE, null, "ALL CLEAR!");
            }
        }

        fn printGlitchyU64(view: View, x: u8, y: u8, value: u64) void {
            if (value < 100_000_000) {
                // Print in decimal if the value is small enough
                view.printAt(x, y, Colors.WHITE, null, "{d}", .{value});
            } else if (value < 0x1_0000_0000) {
                // Print in hexadecimal if the value is too large
                view.printAt(x, y, Colors.WHITE, null, "{x}", .{value});
            } else {
                // Map bytes directly to characters if the value is still too large,
                // because glitched text is cool
                var bytes = [_]u16{undefined} ** 8;
                for (0..8) |i| {
                    const byte: u8 = @truncate(value >> @intCast(i * 8));
                    // Make sure byte is printable
                    bytes[7 - i] = if (byte < 95)
                        @as(u16, byte) + 32
                    else
                        @as(u16, byte) + 66;
                }
                const start = @clz(value) / 8;
                view.printAt(x, y, Colors.WHITE, null, "{s}", .{std.unicode.fmtUtf16le(bytes[start..8])});
            }
        }

        fn drawMatrix(self: Self) void {
            const LEFT = 11;
            const TOP = 2;
            const WIDTH = 22;
            const HEIGHT = 22;

            const matrix_box = self.view.sub(LEFT, TOP, WIDTH, HEIGHT);
            const matrix_box_inner = matrix_box.sub(1, 1, WIDTH - 2, HEIGHT - 2);
            matrix_box.drawBox(0, 0, WIDTH, HEIGHT, Colors.WHITE, null);
            for (0..20) |y| {
                for (0..10) |x| {
                    const color = self.playfield_colors.get(x, y);
                    _ = matrix_box_inner.writeText(@intCast(x * 2), @intCast(19 - y), 0, color, "  ");
                }
            }

            if (self.clear_anim_start == 0) {
                // Ghost piece
                var state = self.state;
                const dropped = state.dropToGround();
                drawPiece(matrix_box_inner, state.pos.x * 2, 19 - state.pos.y, state.current, false);

                // Current piece
                state.pos.y += @intCast(dropped);
                drawPiece(matrix_box_inner, state.pos.x * 2, 19 - state.pos.y, state.current, true);
            }

            // Clear animation
            if (self.clear_anim_start != 0) {
                for (0..20) |y| {
                    if (self.playfield_colors.isRowFull(y)) {
                        _ = animations.clearAnimation(
                            self.anim_time - self.clear_anim_start,
                            self.settings.clear_delay,
                            self.view,
                            @intCast(y),
                        ).forceRender();
                    }
                }
            }

            // Death animation
            if (self.death_anim_start != 0) {
                _ = animations.deathAnimation(
                    self.anim_time - self.death_anim_start,
                    matrix_box_inner,
                ).forceRender();
            }
        }

        fn drawGarbageMeter(self: Self) void {
            const LEFT = 33;
            const TOP = 3;
            const WIDTH = 1;
            const HEIGHT = 20;

            const view = self.view.sub(LEFT, TOP, WIDTH, HEIGHT);

            var y: u16 = HEIGHT - 1;
            for (self.garbage_queue.slice()) |garbage| outer: {
                for (0..garbage.lines) |_| {
                    _ = view.writeText(
                        0,
                        y,
                        0,
                        if (@as(u64, garbage.time) * std.time.ns_per_ms <= self.time) Colors.RED else Colors.WHITE,
                        "  ",
                    );

                    if (y == 0) {
                        break :outer;
                    }
                    y -= 1;
                }
            }
        }

        fn drawNext(self: Self) void {
            const LEFT = 34;
            const TOP = 2;
            const WIDTH = 10;

            if (self.settings.show_next_count == 0) {
                return;
            }

            const height = @as(u16, @intCast(self.settings.show_next_count)) * 3 + 1;
            const next_box = self.view.sub(LEFT, TOP, WIDTH, height);
            next_box.drawBox(0, 0, WIDTH, height, Colors.WHITE, null);
            _ = next_box.writeText(3, 0, Colors.WHITE, null, "NEXT");

            for (0..self.settings.show_next_count) |i| {
                const piece = Piece{
                    .facing = .up,
                    .kind = self.state.next_pieces[i],
                };
                const y: i8 = if (piece.kind == .i) 4 else 3;
                drawPiece(next_box, 1, y + @as(i8, @intCast(i * 3)), piece, true);
            }
        }

        fn drawStat(self: Self, stat: Stat, slot: u16) void {
            const top = 21 + slot;
            // Don't draw if stat slot is outside of view
            if (top >= self.view.height) {
                return;
            }

            const view = self.view.sub(0, top, 10, 1);
            switch (stat) {
                .apl => view.printAt(0, 0, Colors.WHITE, null, "APL: {d:.3}", .{self.apl()}),
                .apm => view.printAt(0, 0, Colors.WHITE, null, "APM: {d:.3}", .{self.apm()}),
                .app => view.printAt(0, 0, Colors.WHITE, null, "APP: {d:.3}", .{self.app()}),
                .finesse => view.printAt(0, 0, Colors.WHITE, null, "FIN: {d}", .{self.finesse}),
                .keys => view.printAt(0, 0, Colors.WHITE, null, "KEYS: {d}", .{self.keys_pressed + self.current_piece_keys}),
                .kpp => view.printAt(0, 0, Colors.WHITE, null, "KPP: {d:.3}", .{self.kpp()}),
                .level => view.printAt(0, 0, Colors.WHITE, null, "LEVEL: {d}", .{self.level()}),
                .lines => view.printAt(0, 0, Colors.WHITE, null, "LINES: {d}", .{self.lines_cleared}),
                .pps => view.printAt(0, 0, Colors.WHITE, null, "PPS: {d:.3}", .{self.pps()}),
                .received => view.printAt(0, 0, Colors.WHITE, null, "REC: {d}", .{self.lines_received}),
                .score => view.printAt(0, 0, Colors.WHITE, null, "SCORE: {d}", .{self.score}),
                .sent => view.printAt(0, 0, Colors.WHITE, null, "SENT: {d}", .{self.lines_sent}),
                .time => view.printAt(0, 0, Colors.WHITE, null, "TIME: {}", .{std.fmt.fmtDuration(self.time)}),
                .vs_score => view.printAt(0, 0, Colors.WHITE, null, "VS: {d:.4}", .{self.vsScore()}),
            }
        }
    };
}
