const std = @import("std");
const log = @import("zutils").log;

pub fn do(_: @This(), alloc: std.mem.Allocator, _: bool, cwd: []const u8, parameters: []const []const u8) !void {
    const argv = [_][]const u8{
        "sh",
        "-c",
        parameters[0],
    };

    log.info("Running shell command {s} {s}", .{ "sh -c", parameters[0] });

    var child = std.process.Child.init(&argv, alloc);
    child.cwd = cwd;

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
