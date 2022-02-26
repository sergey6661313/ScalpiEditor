const CharsDecFromU64 = @This();

const std = @import("std");
const expect = std.testing.expect;

pub const MAX_LEN = "18446744073709551615".len; // UINT64_MAX
pub const last_digit = MAX_LEN - 1;
pub const hex_table = "0123456789abcdef".*;
const zeroed = "00000000000000000000";

buff: [MAX_LEN]u8,
start: usize,
end: usize,

pub fn init() CharsDecFromU64 {
    return .{
        .buff = zeroed.*,
        .start = last_digit,
        .end = last_digit,
    };
}

pub fn reset(self: *CharsDecFromU64) void {
    self.buff = zeroed.*;
    self.end = last_digit;
    self.start = last_digit;
}

pub fn set(self: *CharsDecFromU64, _num: u64) void {
    self.reset();

    var num = _num;
    while (true) {
        const remainder = num % 10;
        self.buff[self.start] = hex_table[remainder];
        num = num / 10;
        if (num == 0) break;
        self.start -= 1;
    }
}

pub fn get(self: *CharsDecFromU64) error{Unexpected} ![]u8 {
    if (self.start > self.end) return error.Unexpected;
    if (self.end > last_digit) return error.Unexpected;
    return self.buff[self.start .. self.end + 1];
}

pub fn getDigit(self: *CharsDecFromU64, wigth: usize) error{ Overflow, Unexpected }![]u8 {
    if (self.start > self.end) return error.Unexpected;
    if (self.end > last_digit) return error.Overflow;
    if (wigth > MAX_LEN) return error.Overflow;
    return self.buff[MAX_LEN - wigth .. MAX_LEN];
}

pub fn getMinWidth(self: *CharsDecFromU64, wigth: usize) error{ Overflow, Unexpected }![]u8 {
    if (wigth < self.end - self.start + 1) return try self.get();
    return try self.getDigit(wigth);
}

fn printedTest(expected: []const u8, data: u64) !void {
    var itoa: CharsDecFromU64 = undefined;
    itoa.set(data);
    const result = try itoa.get();
    std.log.info("expected {s} received {s}", .{ expected, result });
    try expect(std.mem.eql(u8, expected, result));
}

pub fn tests() !void {
    try printedTest("0", 0);
    try printedTest("1", 1);
    try printedTest("10", 10);
    try printedTest("2", 2);
    try printedTest("20", 20);
    try printedTest("200", 200);
    try printedTest("8", 8);
    try printedTest("16", 16);
    try printedTest("32", 32);
    try printedTest("64", 64);
    try printedTest("128", 128);
    try printedTest("256", 256);
    try printedTest("9223372036854775807", 9223372036854775807);
    try printedTest("9223372036854775808", 9223372036854775808);
    try printedTest("18446744073709551615", 18446744073709551615);
}
