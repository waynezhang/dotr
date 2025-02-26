const std = @import("std");
const zutils = @import("zutils");
const encrypt = @import("encrypt.zig");
const action = @import("action.zig");
const log = zutils.log;

pub fn do(_: @This(), alloc: std.mem.Allocator, is_reverse: bool, cwd: []const u8, parameters: []const []const u8) !void {
    const enc: action.Action = .{ .encrypt = .{} };
    const swapped: []const []const u8 = &[_][]const u8{
        parameters[1],
        parameters[0],
    };
    try enc.do(alloc, !is_reverse, cwd, swapped);
}

pub fn requiredParams(_: @This()) i16 {
    return 2;
}
