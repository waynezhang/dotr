const std = @import("std");
const action = @import("action/action.zig");
const zutils = @import("zutils");
const log = zutils.log;

pub const Command = struct {
    action: action.Action,
    parameters: []const []const u8,
    line_no: i16,

    pub fn deinit(self: Command, alloc: std.mem.Allocator) void {
        for (self.parameters) |p| alloc.free(p);
        alloc.free(self.parameters);
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

    const act_end = std.mem.indexOf(u8, line, " ") orelse trimmed.len;
    const lowercased = try std.ascii.allocLowerString(alloc, trimmed[0..act_end]);
    defer alloc.free(lowercased);

    const act = action.fromString(lowercased) orelse {
        return error.InvalidAction;
    };

    var arr = std.ArrayList([]u8).init(alloc);
    defer arr.deinit();
    errdefer {
        for (arr.items) |i| alloc.free(i);
    }

    if (act_end < trimmed.len) {
        var it = std.mem.splitScalar(u8, trimmed[act_end..], ':');
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
    }

    const parameters = try arr.toOwnedSlice();

    return .{
        .action = act,
        .parameters = parameters,
        .line_no = line_no,
    };
}

const require = @import("protest").require;

test "parseLIne" {
    const alloc = std.testing.allocator;

    {
        const act = try parseLine(alloc, "", 1);
        try require.isNull(act);
    }
    {
        const act = try parseLine(alloc, "", 1);
        try require.isNull(act);
    }
    {
        const act = try parseLine(alloc, " # some comment", 1);
        try require.isNull(act);
    }
    {
        const act = try parseLine(alloc, "LINK file1 : file2", 88) orelse unreachable;
        defer act.deinit(alloc);

        try require.equal(act.line_no, @as(i16, 88));
        try require.equal(act.action.toString(), "link");
        try require.equal(act.parameters[0], "file1");
        try require.equal(act.parameters[1], "file2");
    }
    {
        const act = try parseLine(alloc, "link     file1 : file2", 88) orelse unreachable;
        defer act.deinit(alloc);

        try require.equal(act.line_no, @as(i16, 88));
        try require.equal(act.action.toString(), "link");
        try require.equal(act.parameters[0], "file1");
        try require.equal(act.parameters[1], "file2");
    }
    {
        if (parseLine(alloc, "link file1", 88)) |_| {
            try require.fail("unreachable");
        } else |err| {
            try require.equalError(error.InvalidParameters, err);
        }
    }
    {
        if (parseLine(alloc, "link file1:", 88)) |_| {
            try require.fail("unreachable");
        } else |err| {
            try require.equalError(error.InvalidParameters, err);
        }
    }
    {
        if (parseLine(alloc, "link :file1", 88)) |_| {
            try require.fail("unreachable");
        } else |err| {
            try require.equalError(error.InvalidParameters, err);
        }
    }
    {
        if (parseLine(alloc, "link :file1:", 88)) |_| {
            try require.fail("unreachable");
        } else |err| {
            try require.equalError(error.InvalidParameters, err);
        }
    }
}
