///! A ring queue used to keep track of timings to calculate the FPS.
///!
///! This queue has not been implemented with thread safety in mind, and
///! therefore should not be assumed to be suitable for use cases involving
///! separate reader and writer threads.
const std = @import("std");

/// Stores timestamps in microseconds.
data: []i64,
head: usize = 0,
tail: usize = 0,

pub const Error = error{Full};

/// Returns `index` modulo the length of the backing slice.
pub fn mask(self: @This(), index: usize) usize {
    return index % self.data.len;
}

/// Returns `index` modulo twice the length of the backing slice.
pub fn mask2(self: @This(), index: usize) usize {
    return index % (2 * self.data.len);
}

/// Enqueues `item` into the queue. Returns `error.Full` if the queue
/// is full.
pub fn enqueue(self: *@This(), item: i64) Error!void {
    if (self.isFull()) return error.Full;
    self.data[self.mask(self.head)] = item;
    self.head = self.mask2(self.head + 1);
}

/// Dequeues the first item from the queue and return it. Returns `null` if the
/// queue is empty.
pub fn dequeue(self: *@This()) ?i64 {
    if (self.isEmpty()) return null;
    const item = self.data[self.mask(self.tail)];
    self.tail = self.mask2(self.tail + 1);
    return item;
}

/// Reads the item at `index` from the queue and returns it without dequeuing.
/// Returns `null` if `index` is out of bounds.
pub fn peekIndex(self: @This(), index: usize) ?i64 {
    if (index >= self.len()) return null;
    return self.data[self.mask(self.tail + index)];
}

/// The FPS based on the first and last items in the queue. If the queue is
/// empty, returns NaN.
pub fn fps(self: @This()) f64 {
    if (self.isEmpty()) {
        return std.math.nan(f64);
    }

    const elapsed: f64 = @floatFromInt(std.time.microTimestamp() - self.peekIndex(0).?);
    return std.time.us_per_s * @as(f64, @floatFromInt(self.len())) / elapsed;
}

/// Updates the queue with the current timestamp. If the queue is full, the
/// oldest item is dequeued.
pub fn nextFrame(self: *@This()) void {
    if (self.isFull()) {
        _ = self.dequeue();
    }
    self.enqueue(std.time.microTimestamp()) catch unreachable;
}

/// Returns `true` if the queue is empty and `false` otherwise.
pub fn isEmpty(self: @This()) bool {
    return self.head == self.tail;
}

/// Returns `true` if the queue is full and `false` otherwise.
pub fn isFull(self: @This()) bool {
    return self.mask2(self.head + self.data.len) == self.tail;
}

/// Returns the length of the queue.
pub fn len(self: @This()) usize {
    const wrap_offset = 2 * self.data.len * @intFromBool(self.head < self.tail);
    const adjusted_head = self.head + wrap_offset;
    return adjusted_head - self.tail;
}
