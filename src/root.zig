const FlagSpec = @import("flag.zig");
const OptionSpec = @import("option.zig");
const SubcommandSpec = @import("subcommand.zig");

pub const ParseError = @import("error.zig").ParseError;
pub const Config = @import("parse.zig").Config;
pub const parseInto = @import("parse.zig").parseInto;

pub fn Flag(comptime spec: FlagSpec) type {
    return struct {
        pub const __argparse_flag__ = spec;
        value: bool,
    };
}

pub fn Option(T: type, comptime spec: OptionSpec) type {
    return struct {
        pub const __argparse_option__ = spec;
        pub const __argparse_type__ = T;
        value: T,
    };
}

pub fn Positional(T: type) type {
    return struct {
        pub const __argparse_option__ = .{ .positional = true };
        pub const __argparse_type__ = T;
        value: T,
    };
}

pub fn Subcommand(T: type, comptime spec: SubcommandSpec) type {
    return struct {
        pub const __argparse_subcommand__ = spec;
        pub const __argparse_type__ = T;
        value: T,
    };
}
