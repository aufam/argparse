pub const ParseError = error{
    Help,
    Unmatched,
    MissingValue,
    MissingRequiredField,
    UnsupportedType,
    InvalidEnumValue,
    ConversionFailure,
    UnknownFlag,
    OutOfMemory,
};
