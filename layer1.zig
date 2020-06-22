const std = @import("std");
const io = std.io;
const fs = std.fs;
const ascii85 = @import("ascii85");

/// Tom's Data Onion - Layer 1
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solve the first layer of the puzzle which is simple Ascii85 conversion
///
/// To RUN: zig run layer1.zig --pkg-begin ascii85 ascii85.zig --pkg-end
///
pub fn main() !void {
    const layer1_encoded_file = try fs.cwd().openFile("layer1.txt", .{});
    defer layer1_encoded_file.close();

    var encode_buffer: [100 * 1024]u8 = undefined;
    const layer1_encoded_len = try layer1_encoded_file.read(encode_buffer[0..encode_buffer.len]);

    var decode_buffer: [100 * 1024]u8 = undefined;
    const layer1_decoded_len = ascii85.decode(encode_buffer[0..layer1_encoded_len], decode_buffer[0..decode_buffer.len]);

    //Output layer 2 which gives us the next part of the puzzle
    try fs.cwd().writeFile("layer2.txt", decode_buffer[0..layer1_decoded_len]);
}
