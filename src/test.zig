comptime {
    _ = @import("dotfile/dotfile.zig");
}

test {
    @import("std").testing.refAllDecls(@This());
}
