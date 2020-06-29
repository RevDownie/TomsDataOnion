use std::fs::File;
use std::io::Read;
use std::io::Write;

/// Tom's Data Onion - Layer 1
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solves the next layer of the puzzle by again peforming an ascii85 conversion and then:
///  1. Flip every second bit
///  2. Rotate the bits one position to the right
///
/// To RUN: rustc layer1.rs && ./layer1
///
fn main() {
    let mut payload_file = File::open("layer1_payload.txt").unwrap();
    let mut payload = Vec::new();
    payload_file.read_to_end(&mut payload).expect(
        "Failed to read to end of file",
    );

    let ascii85_decode_generator = generate_ascii85_decoder(&*payload);
    let decoded: Vec<u8> = ascii85_decode_generator
        .map(|n| (n ^ 0b01010101) >> 1)
        .collect();

    //Write out the instructions for the next layer
    let mut layer2_payload_file = File::create("layer2_instructions.txt").unwrap();
    layer2_payload_file.write(&*decoded).expect(
        "Failed to write to file",
    );
}

/// https://en.wikipedia.org/wiki/Ascii85
///
/// - Work in blocks of 5 (padding the last 5 tuple with 'u' characters) (4 characters are encoded in 5)
/// - Subtract 33 to convert ascii range
/// - Get the 32 bit value (Big endian) of the block
/// - Each byte will have the decoded ascii value (4 values)
///
/// NOTE: If a group has all zeros it is encoded as a single character 'z' so decoding converts 'z' to 0000. The data didn't require this has been omitted
/// NOTE: Data didn't require padding so omitted it
/// NOTE: Acii85 data gets wrapped in <~ ~> delimeters
///
/// Returns an iterator
///
fn generate_ascii85_decoder(encoded_data: &[u8]) -> impl Iterator<Item = u8> + '_ {
    //Slice off the delimeters
    let encoded_data_slice = &encoded_data[2..encoded_data.len() - 2];

    //Split into 5 byte chunks for each chunk peform the ascii conversion and pack 32 bits. Then unpack big endian into 4 1-byte decoded characters
    encoded_data_slice.chunks(5).flat_map(|chunk| {
        chunk
            .iter()
            .enumerate()
            .map(|(i, n)| (n - 33) as u32 * u32::pow(85, (4 - i) as u32))
            .sum::<u32>()
            .to_be_bytes()
            .to_vec()
    })
}
