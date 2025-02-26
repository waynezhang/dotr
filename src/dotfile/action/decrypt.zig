const std = @import("std");
const zutils = @import("zutils");
const encrypt = @import("encrypt.zig");
const action = @import("action.zig");
const log = zutils.log;

pub fn do(
    _: @This(),
    alloc: std.mem.Allocator,
    options: []const []const u8,
    parameters: []const []const u8,
    cwd: []const u8,
    is_reverse: bool,
) anyerror!void {
    const enc: action.Action = .{ .encrypt = .{} };
    const swapped: []const []const u8 = &[_][]const u8{
        parameters[1],
        parameters[0],
    };
    try enc.do(alloc, options, swapped, cwd, !is_reverse);
}

pub fn requiredParams(_: @This()) i16 {
    return 2;
}
