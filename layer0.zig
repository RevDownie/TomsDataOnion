const std = @import("std");
const io = std.io;
const fs = std.fs;
const ascii85 = @import("ascii85");

/// Tom's Data Onion - Layer 0
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solve the initial layer of the puzzle which is simple Ascii85 conversion
///
/// To RUN: zig run layer0.zig --pkg-begin ascii85 ascii85.zig --pkg-end
///
pub fn main() !void {
    const layer0_encoded_file = try fs.cwd().openFile("layer0_payload.txt", .{});
    defer layer0_encoded_file.close();

    var encode_buffer: [500 * 1024]u8 = undefined;
    const layer0_encoded_len = try layer0_encoded_file.readAll(&encode_buffer);

    var decode_buffer: [500 * 1024]u8 = undefined;
    const layer0_decoded_len = ascii85.decode(encode_buffer[0..layer0_encoded_len], decode_buffer[0..decode_buffer.len]);

    //Output layer 1 which gives us the next part of the puzzle
    try fs.cwd().writeFile("layer1_instructions.txt", decode_buffer[0..layer0_decoded_len]);
}
