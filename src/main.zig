const std = @import("std");
const builtin = @import("builtin");
const zutils = @import("zutils");
const log = zutils.log;
const args = @import("args.zig");
const version = @import("version.zig");
const include = @import("dotfile/action/include.zig");
const action = @import("dotfile/action/action.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) unreachable;
    }
    const alloc = gpa.allocator();

    var reverse = false;
    var filename: ?[]const u8 = null;
    defer {
        if (filename) |f| {
            alloc.free(f);
        }
    }

    log.init();

    for (std.os.argv[1..]) |arg| {
        const s = try args.parse(alloc, arg);
        defer alloc.free(s);

        if (std.mem.eql(u8, s, "-v")) {
            log.setLevel(.debug);
        } else if (std.mem.eql(u8, s, "-r")) {
            reverse = true;
        } else if (filename == null) {
            filename = try alloc.dupe(u8, s);
        } else {
            log.err("Invalid argument {s}", .{s});
        }
    }

    try runFile(alloc, filename orelse "dotfile", reverse);
}

fn runFile(alloc: std.mem.Allocator, filename: []const u8, reverse: bool) !void {
    const incl: action.Action = .{ .include = .{} };
    try incl.do(alloc, reverse, ".", &[_][]const u8{filename});
}
