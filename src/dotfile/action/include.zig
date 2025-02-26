const std = @import("std");
const zutils = @import("zutils");
const log = zutils.log;
const dotfile = @import("../dotfile.zig");

pub fn do(_: @This(), alloc: std.mem.Allocator, is_reverse: bool, cwd: []const u8, parameters: []const []const u8) !void {
    const path = try zutils.fs.toAbsolutePathAlloc(alloc, parameters[0], cwd);
    defer alloc.free(path);

    const desp = try zutils.fs.contractTildeAlloc(alloc, path);
    defer alloc.free(desp);

    var it = dotfile.openFile(path) catch |err| {
        log.err("Failed to open file {s} due to {s}", .{ desp, @errorName(err) });
        return;
    };
    defer it.close();

    const file_cwd = std.fs.path.dirname(path) orelse ".";

    while (try it.next(alloc)) |act| {
        defer act.deinit(alloc);

        log.debug("{s}{s}: {s}", .{
            act.action.toString(),
            if (is_reverse) "(reverse)" else "",
            act.parameters,
        });

        act.action.do(alloc, is_reverse, file_cwd, act.parameters) catch |err| {
            log.err("Failed to run {s}:{d} due to {s}.", .{ desp, act.line_no, @errorName(err) });
        };
    }
}

pub fn requiredParams(_: @This()) i16 {
    return 1;
}
