const std = @import("std");
const zutils = @import("zutils");
const log = zutils.log;

const require = @import("protest").require;

pub fn do(
    _: @This(),
    alloc: std.mem.Allocator,
    _: []const []const u8,
    parameters: []const []const u8,
    cwd: []const u8,
    is_reverse: bool,
) anyerror!void {
    const src = try zutils.fs.toAbsolutePathAlloc(alloc, parameters[0], cwd);
    defer alloc.free(src);
    const src_desp = try zutils.fs.contractTildeAlloc(alloc, src);
    defer alloc.free(src_desp);

    const dst = try zutils.fs.toAbsolutePathAlloc(alloc, parameters[1], cwd);
    defer alloc.free(dst);
    const dst_desp = try zutils.fs.contractTildeAlloc(alloc, dst);
    defer alloc.free(dst_desp);

    if (is_reverse) {
        log.info("Unlinking {s}", .{dst_desp});

        unlink(dst) catch |err| {
            log.err("Failed to unlink {s} due to {s}", .{ dst_desp, @errorName(err) });
        };
    } else {
        log.info("Link {s} to {s}", .{ src_desp, dst_desp });

        link(src, dst) catch |err| {
            log.err("Failed to link {s} due to {s}", .{ src_desp, @errorName(err) });
        };
    }
}

pub fn requiredParams(_: @This()) i16 {
    return 2;
}

fn link(src: []const u8, dst: []const u8) !void {
    if (!zutils.fs.isExisting(src)) {
        return error.FileNotFound;
    }
    if (zutils.fs.isExisting(dst)) {
        return error.TargetFileExists;
    }

    if (std.fs.path.dirname(dst)) |parent| {
        std.fs.cwd().makePath(parent) catch {};
    }

    try std.fs.symLinkAbsolute(src, dst, .{});
}

fn unlink(dst: []const u8) !void {
    std.fs.deleteFileAbsolute(dst) catch |err| {
        log.err("Failed to unlink {s}", .{@errorName(err)});
    };
}

test "link" {
    const alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(path);

    try tmp.dir.writeFile(.{
        .sub_path = "src_file",
        .data = "some dummy data",
        .flags = .{},
    });

    const act = @This(){};
    try act.do(alloc, &.{}, &.{ "src_file", "dst_file" }, path, false);

    const dst_path = try std.fs.path.join(alloc, &.{ path, "dst_file" });
    defer alloc.free(dst_path);

    try require.isTrue(try zutils.fs.isSymLink(dst_path));

    try act.do(alloc, &.{}, &.{ "src_file", "dst_file" }, path, true);
    try require.isFalse(zutils.fs.isExisting(dst_path));
}
