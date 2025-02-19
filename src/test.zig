comptime {

}

test {
    @import("std").testing.refAllDecls(@This());
}
