const std = @import("std");
const zutils = @import("zutils");
const log = zutils.log;

pub fn do(
    _: @This(),
    alloc: std.mem.Allocator,
    _: []const []const u8,
    parameters: []const []const u8,
    cwd: []const u8,
    _: bool,
) anyerror!void {
    const argv = [_][]const u8{
        "sh",
        "-c",
        parameters[0],
    };
    const abs_cwd = try zutils.fs.toAbsolutePathAlloc(alloc, cwd, null);
    defer alloc.free(abs_cwd);

    log.info("Running shell command {s} {s} in {s}", .{ "sh -c", parameters[0], cwd });

    var child = std.process.Child.init(&argv, alloc);
    child.cwd = abs_cwd;

    runCommand(&child) catch |err| {
        log.err("Failed to run shell command due to {s}", .{@errorName(err)});
    };
}

pub fn requiredParams(_: @This()) i16 {
    return 1;
}

fn runCommand(child: *std.process.Child) !void {
    try child.spawn();
    _ = try child.wait();
}
