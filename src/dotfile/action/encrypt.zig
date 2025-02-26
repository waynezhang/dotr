const std = @import("std");
const zutils = @import("zutils");
const age = @import("age");
const log = zutils.log;

var _passphrase_storage = [_]u8{0} ** 256;
var _passphrase: ?[]const u8 = null;

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
        log.info("Decrypting {s} to {s}", .{ dst_desp, src_desp });

        decrypt(alloc, src, dst) catch |err| {
            log.err("Failed to decrypt {s} due to {s}", .{ dst_desp, @errorName(err) });
        };
    } else {
        log.info("Encrypting {s} to {s}", .{ src_desp, dst_desp });

        encrypt(alloc, src, dst) catch |err| {
            log.err("Failed to encrypt {s} due to {s}", .{ src_desp, @errorName(err) });
        };
    }
}

pub fn requiredParams(_: @This()) i16 {
    return 2;
}

fn encrypt(alloc: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const passphrase = _passphrase orelse blk: {
        while (true) {
            const p1 = try promptPassphrase(alloc, "Password: ");
            defer alloc.free(p1);
            const p2 = try promptPassphrase(alloc, "Confirm Password: ");
            defer alloc.free(p2);
            if (!std.mem.eql(u8, p1, p2)) {
                log.info("Password doesn't match", .{});
                continue;
            }

            std.mem.copyBackwards(u8, @constCast(_passphrase_storage[0..256]), p1);
            _passphrase = _passphrase_storage[0..p1.len];
            break :blk _passphrase.?;
        }
    };

    const plain_file = try std.fs.cwd().openFile(src, .{});
    defer plain_file.close();

    if (std.fs.path.dirname(dst)) |parent| {
        std.fs.cwd().makePath(parent) catch {};
    }

    const encrypted_file = try std.fs.cwd().createFile(dst, .{});
    defer encrypted_file.close();
    const recipient = try age.scrypt.ScryptRecipient.create(alloc, passphrase, null);
    const any_recipient = recipient.any();
    defer any_recipient.destroy();

    var encryptor = try age.AgeEncryptor.encryptInit(alloc, &.{any_recipient}, encrypted_file.writer().any());

    var plain_reader = std.io.bufferedReader(plain_file.reader());
    var buffer: [8192]u8 = undefined;
    while (true) {
        const len = try plain_reader.read(&buffer);
        if (len == 0) {
            break;
        }
        try encryptor.update(buffer[0..len]);
    }

    try encryptor.finish();
}

fn decrypt(alloc: std.mem.Allocator, plain: []const u8, enc: []const u8) !void {
    const passphrase = _passphrase orelse blk: {
        const p = try promptPassphrase(alloc, "Password: ");
        defer alloc.free(p);

        std.mem.copyBackwards(u8, @constCast(_passphrase_storage[0..256]), p);
        _passphrase = _passphrase_storage[0..p.len];
        break :blk _passphrase.?;
    };

    const tmp_filepath = try std.fmt.allocPrint(alloc, "{s}.tmp", .{plain});
    defer alloc.free(tmp_filepath);

    if (std.fs.path.dirname(tmp_filepath)) |parent| {
        std.fs.cwd().makePath(parent) catch {};
    }

    const tmp_file = try std.fs.cwd().createFile(tmp_filepath, .{});
    errdefer {
        std.fs.deleteFileAbsolute(tmp_filepath) catch {};
        tmp_file.close();
    }

    const encrypted_file = try std.fs.cwd().openFile(enc, .{});
    defer encrypted_file.close();

    const identity = try age.scrypt.ScryptIdentity.create(alloc, passphrase);
    defer identity.any().destroy();

    try age.AgeDecryptor.decryptFromReaderToWriter(
        alloc,
        &.{identity.any()},
        tmp_file.writer().any(),
        encrypted_file.reader().any(),
    );

    tmp_file.close();
    try std.fs.renameAbsolute(tmp_filepath, plain);
}

fn promptPassphrase(alloc: std.mem.Allocator, prompt: []const u8) ![]const u8 {
    var arr = std.ArrayList(u8).init(alloc);
    defer arr.deinit();

    while (true) {
        _ = try std.io.getStdOut().write(prompt);
        setTTYEcho(false);
        try std.io.getStdIn().reader().streamUntilDelimiter(arr.writer(), '\n', null);
        setTTYEcho(true);

        _ = try std.io.getStdOut().write("\n");
        if (arr.items.len > 0) {
            break;
        }
    }

    return arr.toOwnedSlice();
}

fn setTTYEcho(enable: bool) void {
    var termios = std.posix.tcgetattr(std.posix.STDIN_FILENO) catch {
        return;
    };
    termios.lflag.ECHO = enable;
    std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, termios) catch {};
}
