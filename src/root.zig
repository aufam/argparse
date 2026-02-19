const F = @import("flag.zig");
const O = @import("option.zig");

pub const ParseError = @import("error.zig").ParseError;
pub const Config = @import("parse.zig").Config;
pub const parseInto = @import("parse.zig").parseInto;

pub fn Flag(comptime spec: F) type {
    return struct {
        pub const __argparse_flag__ = spec;
        value: bool,
    };
}

pub fn Option(T: type, comptime spec: O) type {
    return struct {
        pub const __argparse_option__ = spec;
        pub const __argparse_type__ = T;
        value: T,
    };
}
