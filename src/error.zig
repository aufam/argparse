pub const ParseError = error{
    Unmatched,
    MissingValue,
    MissingRequiredField,
    UnsupportedType,
    InvalidEnumValue,
    ConversionFailure,
    UnknownFlag,
    OutOfMemory,
};
