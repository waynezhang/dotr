const std = @import("std");
const link = @import("link.zig");
const encrypt = @import("encrypt.zig");
const decrypt = @import("decrypt.zig");
const sh = @import("sh.zig");
const include = @import("include.zig");

pub const Action = union(enum) {
    link: link,
    encrypt: encrypt,
    decrypt: decrypt,
    sh: sh,
    include: include,

    pub fn do(self: Action, alloc: std.mem.Allocator, is_reverse: bool, cwd: []const u8, parameters: []const []const u8) anyerror!void {
        switch (self) {
            inline else => |case| {
                try case.do(alloc, is_reverse, cwd, parameters);
            },
        }
    }

    pub fn requiredParams(self: Action) i16 {
        switch (self) {
            inline else => |case| {
                return case.requiredParams();
            },
        }
    }

    pub fn toString(self: Action) []const u8 {
        return @tagName(self);
    }
};

pub fn fromString(s: []const u8) ?Action {
    return all.get(s);
}

const all = std.StaticStringMap(Action).initComptime(blk: {
    const tags = std.meta.tags(Action);
    var ret: [tags.len]struct { []const u8, Action } = undefined;
    for (tags, 0..) |tag, i| {
        const name = @tagName(tag);
        ret[i] = .{ name, @unionInit(Action, name, .{}) };
    }
    break :blk ret;
});
