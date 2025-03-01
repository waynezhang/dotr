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
    var external_command = std.ArrayList(u8).init(alloc);
    defer external_command.deinit();

    const cb = struct {
        fn showHelp() void {
            const help =
                \\usage: dotr [flags] [shell command]
                \\
                \\[shell command]        A convenient way to run shell commands in the directory where dotfile exists
                \\
                \\flags:
                \\  -f, --file           `dotfile` will be used by default(use environment variable `DOTR_FILE` to override)
                \\  -r, --reverse        Reverse the commands (Link → Unlink, Encrypt → Decrypt)
                \\  -v, --verbose        Verbose mode
                \\  --version            Show version information
                \\  -h, --help           Show this help message
            ;
            log.info("{s}", .{help});
            std.process.exit(0);
        }
        fn showVersion() void {
            log.info("{s}", .{version.FullDescription});
            std.process.exit(0);
        }
    };

    var p = try pargs.parseProcess(alloc, .{});
    defer p.deinit();
    _ = p.nextValue(); // skip executable name

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isLong("file") or flag.isShort("f")) {
                    filename = p.nextValue() orelse {
                        log.fatal("--file requires value", .{});
                        unreachable;
                    };
                } else if (flag.isLong("verbose") or flag.isShort("v")) {
                    verbose = true;
                } else if (flag.isLong("reverse") or flag.isShort("r")) {
                    reverse = true;
                } else if (flag.isLong("help") or flag.isShort("h")) {
                    cb.showHelp();
                } else if (flag.isLong("version")) {
                    cb.showVersion();
                }
            },
            .arg => |val| {
                // the following tokens are for external command
                try external_command.appendSlice(val);
                while (p.nextValue()) |v| {
                    try external_command.append(' ');
                    try external_command.appendSlice(v);
                }
            },
            .unexpected_value => @panic("Invalid argumnts"),
        }
    }

    if (verbose) log.setLevel(.debug);

    try run(alloc, filename, reverse, external_command.items);
}

fn run(alloc: std.mem.Allocator, filename: ?[]const u8, reverse: bool, external_command: []const u8) !void {
    const fallbacked = try fallbackFile(alloc, filename);
    defer alloc.free(fallbacked);

    if (external_command.len > 0) {
        const sh: action.Action = .{ .sh = .{} };
        try sh.do(alloc, &.{}, &.{external_command}, std.fs.path.dirname(fallbacked) orelse ".", reverse);
        return;
    }

    const incl: action.Action = .{ .include = .{} };
    try incl.do(alloc, &.{}, &[_][]const u8{fallbacked}, ".", reverse);
}

fn fallbackFile(alloc: std.mem.Allocator, filename: ?[]const u8) ![]const u8 {
    if (filename) |file| return try alloc.dupe(u8, file);
    if (std.process.getEnvVarOwned(alloc, "DOTR_FILE")) |file| {
        return file;
    } else |_| {}
    return try alloc.dupe(u8, "dotfile");
}
