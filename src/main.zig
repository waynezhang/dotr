const std = @import("std");
const builtin = @import("builtin");
const pargs = @import("parg");
const zutils = @import("zutils");
const log = zutils.log;
const version = @import("version.zig");
const include = @import("dotfile/action/include.zig");
const action = @import("dotfile/action/action.zig");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    const alloc, const is_debug = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    log.init();

    var reverse = false;
    var verbose = false;
    var filename: ?[]const u8 = null;
    var command: std.ArrayList([]const u8) = .init(alloc);
    defer command.deinit();

    const cb = struct {
        fn showHelp() void {
            const help =
                \\usage: dotr [flags] <command>
                \\
                \\<command>              
                \\  run                  Run the default dotfile or the file indicated by -f flag
                \\  shell-command        A convenient way to run shell commands in the directory where dotfile exists
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
                try command.append(val);
                while (p.nextValue()) |v| {
                    try command.append(v);
                }
            },
            .unexpected_value => @panic("Invalid argumnts"),
        }
    }

    if (verbose) log.setLevel(.debug);

    if (command.items.len == 0) {
        cb.showHelp();
        return;
    }

    try run(alloc, filename, reverse, command.items);
}

fn run(alloc: std.mem.Allocator, filename: ?[]const u8, reverse: bool, command: []const []const u8) !void {
    const fallbacked = try fallbackFile(alloc, filename);
    defer alloc.free(fallbacked);

    if (std.mem.eql(u8, command[0], "run")) {
        const incl: action.Action = .{ .include = .{} };
        try incl.do(alloc, &.{}, &[_][]const u8{fallbacked}, ".", reverse);
    } else {
        const joined = try std.mem.join(alloc, " ", command);
        defer alloc.free(joined);

        const sh: action.Action = .{ .sh = .{} };
        try sh.do(alloc, &.{}, &.{joined}, std.fs.path.dirname(fallbacked) orelse ".", reverse);
    }
}

fn fallbackFile(alloc: std.mem.Allocator, filename: ?[]const u8) ![]const u8 {
    if (filename) |file| return try alloc.dupe(u8, file);
    if (std.process.getEnvVarOwned(alloc, "DOTR_FILE")) |file| {
        return file;
    } else |_| {}
    return try alloc.dupe(u8, "dotfile");
}
