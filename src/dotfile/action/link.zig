const std = @import("std");
const zutils = @import("zutils");
const log = zutils.log;

pub fn do(_: @This(), alloc: std.mem.Allocator, is_reverse: bool, cwd: []const u8, parameters: []const []const u8) !void {
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
    if (!zutils.fs.isExisting(dst)) {
        return error.FileNotFound;
    }

    const is_link = try zutils.fs.isSymLink(dst);
    if (!is_link) {
        return error.FileIsNotLink;
    }

    try std.fs.deleteFileAbsolute(dst);
}
