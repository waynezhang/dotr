const std = @import("std");
const action = @import("action/action.zig");
const zutils = @import("zutils");
const log = zutils.log;

pub const Command = struct {
    action: action.Action,
    options: []const []const u8,
    parameters: []const []const u8,
    line_no: i16,

    pub fn deinit(self: Command, alloc: std.mem.Allocator) void {
        for (self.parameters) |p| alloc.free(p);
        alloc.free(self.parameters);
        for (self.options) |o| alloc.free(o);
        alloc.free(self.options);
    }
};

pub const Iterator = struct {
    file: std.fs.File,
    path: [1024]u8,
    buffered: std.io.BufferedReader(4096, std.fs.File.Reader),
    current_line: i16 = 0,

    pub fn next(self: *Iterator, alloc: std.mem.Allocator) !?Command {
        const buf = try alloc.alloc(u8, 4096);
        defer alloc.free(buf);

        while (true) {
            self.current_line += 1;

            const line = self.buffered.reader().readUntilDelimiter(buf, '\n') catch |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            };

            if (parseLine(alloc, line, self.current_line)) |act| {
                if (act) |a| return a;
            } else |err| {
                const desp = try zutils.fs.contractTildeAlloc(alloc, &self.path);
                defer alloc.free(desp);
                log.err("Failed to parse {s}:{d} due to {s}", .{ desp, self.current_line, @errorName(err) });
            }
        }
    }

    pub fn close(self: *Iterator) void {
        self.file.close();
    }
};

pub fn openFile(filename: []const u8) !Iterator {
    const file = try std.fs.cwd().openFile(filename, .{});
    const buf_reader = std.io.bufferedReader(file.reader());

    const ite: Iterator = .{
        .file = file,
        .buffered = buf_reader,
        .path = [_]u8{0} ** 1024,
    };
    std.mem.copyBackwards(u8, @constCast(ite.path[0..1024]), filename);
    return ite;
}

fn parseLine(alloc: std.mem.Allocator, line: []const u8, line_no: i16) !?Command {
    const trimmed = std.mem.trim(u8, line, " ");
    if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) {
        return null;
    }

    var opt_start: usize = 0;
    var opt_end: usize = 0;
    var act_end = std.mem.indexOf(u8, line, " ") orelse return error.InvalidAction;
    if (std.mem.indexOf(u8, line[0..act_end], "(")) |open| {
        const close = std.mem.indexOf(u8, line[open..act_end], ")") orelse return error.InvalidAction;
        opt_start = open + 1;
        opt_end = open + close;

        act_end = open;
    }
    const lower_act = try std.ascii.allocLowerString(alloc, std.mem.trim(u8, line[0..act_end], " "));
    defer alloc.free(lower_act);

    const act = action.fromString(lower_act) orelse {
        return error.InvalidAction;
    };

    var arr = std.ArrayList([]u8).init(alloc);
    defer arr.deinit();
    errdefer for (arr.items) |i| alloc.free(i);

    if (opt_start > 0) {
        var it = std.mem.splitScalar(u8, line[opt_start..opt_end], ',');
        while (it.next()) |p| {
            const trimmed_p = std.mem.trim(u8, p, " ");
            if (trimmed_p.len == 0) {
                continue;
            }
            try arr.append(try alloc.dupe(u8, trimmed_p));
        }
    }

    const options = try arr.toOwnedSlice();
    errdefer for (options) |opt| alloc.free(opt);

    const param_start = @max(act_end, opt_end) + 1;
    var it = std.mem.splitScalar(u8, line[param_start..], ':');
    while (it.next()) |p| {
        const trimmed_p = std.mem.trim(u8, p, " ");
        if (trimmed_p.len == 0) {
            continue;
        }
        try arr.append(try alloc.dupe(u8, trimmed_p));
    }

    if (arr.items.len != act.requiredParams()) {
        return error.InvalidParameters;
    }

    const parameters = try arr.toOwnedSlice();
    return .{
        .action = act,
        .options = options,
        .parameters = parameters,
        .line_no = line_no,
    };
}

const require = @import("protest").require;

test "parseLine empty" {
    const act = try parseLine(std.testing.allocator, "", 1);
    try require.isNull(act);
}

test "parseLine # some comment" {
    const act = try parseLine(std.testing.allocator, " # some comment", 1);
    try require.isNull(act);
}

test "parseLine LINK file1 : file2" {
    const act = try parseLine(std.testing.allocator, "LINK file1 : file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal(@as(i16, 88), act.line_no);
    try require.equal("link", act.action.toString());
    try require.equal(@as(usize, 0), act.options.len);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link     file1 : file2" {
    const act = try parseLine(std.testing.allocator, "link     file1 : file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal(@as(i16, 88), act.line_no);
    try require.equal(act.action.toString(), "link");
    try require.equal(@as(usize, 0), act.options.len);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link file1" {
    if (parseLine(std.testing.allocator, "link file1", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidParameters, err);
    }
}

test "parseLine link file1:" {
    if (parseLine(std.testing.allocator, "link file1:", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidParameters, err);
    }
}

test "parseLine link :file1" {
    if (parseLine(std.testing.allocator, "link :file1", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidParameters, err);
    }
}

test "parseLine link :file1:" {
    if (parseLine(std.testing.allocator, "link :file1:", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidParameters, err);
    }
}

test "parseLine link(options) file1:file2" {
    const act = try parseLine(std.testing.allocator, "link(options) file1:file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal("link", act.action.toString());
    try require.equal("options", act.options[0]);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link ( options ) file1:file2" {
    const act = try parseLine(std.testing.allocator, "link(options) file1:file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal("link", act.action.toString());
    try require.equal("options", act.options[0]);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link (opt1,opt2) file1:file2" {
    const act = try parseLine(std.testing.allocator, "link(opt1,opt2) file1:file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal("link", act.action.toString());
    try require.equal(@as(usize, 2), act.options.len);
    try require.equal("opt1", act.options[0]);
    try require.equal("opt2", act.options[1]);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link() file1:file2" {
    const act = try parseLine(std.testing.allocator, "link() file1:file2", 88) orelse unreachable;
    defer act.deinit(std.testing.allocator);

    try require.equal("link", act.action.toString());
    try require.equal(@as(usize, 0), act.options.len);
    try require.equal("file1", act.parameters[0]);
    try require.equal("file2", act.parameters[1]);
}

test "parseLine link ( opt1, ) file1:file2" {
    if (parseLine(std.testing.allocator, "link( opt1, ) file1:file2", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidAction, err);
    }
}

test "parseLine link()file1:file2" {
    if (parseLine(std.testing.allocator, "link()file1:file2", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidAction, err);
    }
}

test "parseLine link( file1:file2" {
    if (parseLine(std.testing.allocator, "link( file1:file2", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidAction, err);
    }
}
test "parseLine link) file1:file2" {
    if (parseLine(std.testing.allocator, "link) file1:file2", 88)) |_| {
        try require.fail("unreachable");
    } else |err| {
        try require.equalError(error.InvalidAction, err);
    }
}
