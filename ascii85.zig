const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

/// https://en.wikipedia.org/wiki/Ascii85
///
/// - Work in blocks of 5 (padding the last 5 tuple with 'u' characters) (4 characters are encoded in 5)
/// - Subtract 33 to convert ascii range
/// - Get the 32 bit value (Big endian) of the block
/// - Each byte will have the decoded ascii value (4 values)
///
/// NOTE: If a group has all zeros it is encoded as a single character 'z' so decoding converts 'z' to 0000. The data didn't require this has been omitted
/// NOTE: Acii85 data gets wrapped in <~ ~> delimeters
///
pub fn decode(encoded_data: []const u8, decoded_data: []u8) usize {
    //Slice off the delimeters
    const encoded_data_slice = encoded_data[2 .. encoded_data.len - 2];

    const n = encoded_data_slice.len / 5 * 5;
    var i: usize = 0;
    var o: usize = 0;
    var block: [5]u32 = undefined;

    //Convert the full 5 block chunks (unrolled)
    while (i < n) : (i += 5) {
        block[0] = encoded_data_slice[i];
        block[1] = encoded_data_slice[i + 1];
        block[2] = encoded_data_slice[i + 2];
        block[3] = encoded_data_slice[i + 3];
        block[4] = encoded_data_slice[i + 4];

        const p = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33);

        decoded_data[o] = @truncate(u8, p >> 24) & 0xFF;
        decoded_data[o + 1] = @truncate(u8, p >> 16) & 0xFF;
        decoded_data[o + 2] = @truncate(u8, p >> 8) & 0xFF;
        decoded_data[o + 3] = @truncate(u8, p) & 0xFF;

        o += 4;
    }

    //Tackle the remaining block (if there is one) that requires padding
    const remaining = encoded_data_slice.len % 5;
    if (remaining > 0) {
        var j: usize = 0;
        while (j < remaining) : (j += 1) {
            block[j] = encoded_data_slice[i];
            i += 1;
        }
        while (j < 5) : (j += 1) {
            block[j] = 'u';
        }

        const p = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33);

        decoded_data[o] = @truncate(u8, p >> 24) & 0xFF;
        decoded_data[o + 1] = @truncate(u8, p >> 16) & 0xFF;
        decoded_data[o + 2] = @truncate(u8, p >> 8) & 0xFF;
        decoded_data[o + 3] = @truncate(u8, p) & 0xFF;

        o += remaining - 1;
    }

    return o;
}

test "ascii85 decode ascii aligned" {
    var output: [1024]u8 = undefined;
    const len = decode("<~7W3Ei7W3Ei7VR$W7VR$W~>", output[0..output.len]);
    const slice = output[0..len];
    expect(mem.eql(u8, slice, "FourFourFiveFive"));
}

test "ascii85 decode ascii unaligned" {
    var output: [1024]u8 = undefined;
    const len = decode("<~7W3Ei7W3Ei7VR$W7VR$W;e^I~>", output[0..output.len]);
    const slice = output[0..len];
    expect(mem.eql(u8, slice, "FourFourFiveFiveSix"));
}
