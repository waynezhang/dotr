const std = @import("std");

pub fn parse(alloc: std.mem.Allocator, arg: [*:0]u8) ![]const u8 {
    return try std.fmt.allocPrint(alloc, "{s}", .{arg});
}
