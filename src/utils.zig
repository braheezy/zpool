const std = @import("std");

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

pub fn asTypeId(comptime typeInfo: std.builtin.Type) std.builtin.TypeId {
    return @as(std.builtin.TypeId, typeInfo);
}

pub fn typeIdOf(comptime T: type) std.builtin.TypeId {
    return asTypeId(@typeInfo(T));
}

pub fn isStruct(comptime T: type) bool {
    return typeIdOf(T) == std.builtin.TypeId.@"struct";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// UInt(bits) returns an unsigned integer type of the requested bit width.
pub fn UInt(comptime bits: u8) type {
    return @Int(.unsigned, bits);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// Returns an unsigned integer type with ***at least*** `min_bits`,
/// that is also large enough to be addressable by a normal pointer.
/// The returned type will always be one of the following:
/// * `u8`
/// * `u16`
/// * `u32`
/// * `u64`
/// * `u128`
/// * `u256`
pub fn AddressableUInt(comptime min_bits: u8) type {
    return switch (min_bits) {
        0...8 => u8,
        9...16 => u16,
        17...32 => u32,
        33...64 => u64,
        65...128 => u128,
        129...255 => u256,
    };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// Given: `Struct = struct { foo: u32, bar: u64 }`
/// Returns: `StructOfSlices = struct { foo: []u32, bar: []u64 }`
pub fn StructOfSlices(comptime Struct: type) type {
    // same number of fields in the new struct
    const info = @typeInfo(Struct).@"struct";
    var field_types: [info.field_names.len]type = undefined;

    inline for (info.field_types, info.field_attrs, &field_types) |element_type, attrs, *Type| {
        // u32 -> []u32

        const FieldType = @Pointer(
            .slice,
            .{
                .@"align" = attrs.@"align",
            },
            element_type,
            null,
        );

        Type.* = FieldType;
    }

    return @Struct(
        .auto,
        null,
        info.field_names,
        &field_types,
        &@splat(.{}),
    );
}

test "StructOfSlices" {
    const expectEqual = std.testing.expectEqual;

    const Struct = struct { a: u16, b: u16, c: u16 };
    try expectEqual(@sizeOf(u16) * 3, @sizeOf(Struct));

    const SOS = StructOfSlices(Struct);
    try expectEqual(@sizeOf([]u16) * 3, @sizeOf(SOS));
}

test "StructOfSlices preserves field types and explicit alignment" {
    const Struct = struct { byte: u8, wide: u64 align(16), flag: bool };
    const SOS = StructOfSlices(Struct);

    try std.testing.expectEqual([]u8, @FieldType(SOS, "byte"));
    try std.testing.expectEqual([]align(16) u64, @FieldType(SOS, "wide"));
    try std.testing.expectEqual([]bool, @FieldType(SOS, "flag"));
    try std.testing.expectEqual(0, @typeInfo(StructOfSlices(struct {})).@"struct".field_names.len);
}
