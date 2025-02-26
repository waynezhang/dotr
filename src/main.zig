const std = @import("std");
const builtin = @import("builtin");
const pargs = @import("parg");
const zutils = @import("zutils");
const log = zutils.log;
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

    log.init();

    var reverse = false;
    var verbose = false;
    var filename: ?[]const u8 = null;

    const help = "dotr " ++ version.Version ++
        \\
        \\
        \\USAGE:
        \\  dotr [OPTIONS] [FILENAME]
        \\
        \\OPTIONS
        \\  --reverse|-r    Reverse the commands (Link → Unlink, Encrypt → Decrypt).
        \\  --verbose|-v    Verbose mode.
    ;

    const cb = struct {
        fn showHelp() void {
            log.info("{s}", .{help});
            std.process.exit(0);
        }
    };

    var p = try pargs.parseProcess(alloc, .{});
    defer p.deinit();
    _ = p.nextValue(); // skip executable name

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isLong("verbose") or flag.isShort("v")) {
                    verbose = true;
                } else if (flag.isLong("reverse") or flag.isShort("r")) {
                    reverse = true;
                } else if (flag.isLong("help") or flag.isShort("h")) {
                    cb.showHelp();
                }
            },
            .arg => |val| {
                if (filename != null) {
                    log.err("Only one file is supported", .{});
                    std.process.exit(0);
                }
                filename = val;
            },
            .unexpected_value => @panic("Invalid argumnts"),
        }
    }

    if (verbose) log.setLevel(.debug);

    try runFile(alloc, filename orelse "dotfile", reverse);
}

fn runFile(alloc: std.mem.Allocator, filename: []const u8, reverse: bool) !void {
    const incl: action.Action = .{ .include = .{} };
    try incl.do(alloc, &.{}, &[_][]const u8{filename}, ".", reverse);
}
