comptime {
    _ = @import("dotfile/action/encrypt.zig");
    _ = @import("dotfile/action/link.zig");
    _ = @import("dotfile/dotfile.zig");
}

test {
    @import("std").testing.refAllDecls(@This());
}
