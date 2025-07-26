const std = @import("std");
const lib = @import("zigzion");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
