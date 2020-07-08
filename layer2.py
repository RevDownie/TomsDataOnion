import base64

"""
 Tom's Data Onion - Layer 2
 https://www.tomdalling.com/toms-data-onion/

 Solve the next layer of the puzzle which is Ascii85 conversion followed by:
    1. Discarding bytes where the parity bit (LSB) isn't correct
    2. Parity bit is calculated as 1 if the sum of all 1 bits is odd, 0 otherwise


 Requires Python3
 To RUN: python layer2.py
"""

SET_BITS_COUNT_LUT = (b'\x00\x01\x01\x02\x01\x02\x02\x03\x01\x02\x02\x03\x02\x03\x03\x04'
                      b'\x01\x02\x02\x03\x02\x03\x03\x04\x02\x03\x03\x04\x03\x04\x04\x05'
                      b'\x01\x02\x02\x03\x02\x03\x03\x04\x02\x03\x03\x04\x03\x04\x04\x05'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x01\x02\x02\x03\x02\x03\x03\x04\x02\x03\x03\x04\x03\x04\x04\x05'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x03\x04\x04\x05\x04\x05\x05\x06\x04\x05\x05\x06\x05\x06\x06\x07'
                      b'\x01\x02\x02\x03\x02\x03\x03\x04\x02\x03\x03\x04\x03\x04\x04\x05'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x03\x04\x04\x05\x04\x05\x05\x06\x04\x05\x05\x06\x05\x06\x06\x07'
                      b'\x02\x03\x03\x04\x03\x04\x04\x05\x03\x04\x04\x05\x04\x05\x05\x06'
                      b'\x03\x04\x04\x05\x04\x05\x05\x06\x04\x05\x05\x06\x05\x06\x06\x07'
                      b'\x03\x04\x04\x05\x04\x05\x05\x06\x04\x05\x05\x06\x05\x06\x06\x07'
                      b'\x04\x05\x05\x06\x05\x06\x06\x07\x05\x06\x06\x07\x06\x07\x07\x08')


def has_correct_parity(v):
    """
    Sums the set bits. If odd, parity bit should be 1 otherwise 0
    """

    # Ignore the least significant bit as that is the parity bit
    discard_lsb = v & ~1
    set_bits = SET_BITS_COUNT_LUT[discard_lsb]
    parity = set_bits % 2
    parity_check = v & 1
    return parity == parity_check


def strip_parity_bits(byte_data):
    """
    Strip out the parity bit and pack the data 8 byte chunks are packed into 7 bytes

    "To make this layer a little bit easier, the byte size of the payload is guaranteed to be a multiple of eight. Every group
    of eight bytes contains 64 bits total, including 8 parity bits. Removing the 8 parity bits leaves behind 56 data
    bits, which is exactly seven bytes."
    """

    in_len = len(byte_data)
    out_len = in_len - (in_len >> 3)

    output = bytearray(out_len)
    output_idx = 0

    for i in range(0, in_len, 8):
        # We don't care about the LSB and we only want 7 bits packed hence >> 1 << 7N
        pack_64 = (byte_data[i] >> 1 << 49) | (byte_data[i+1] >> 1 << 42) | (byte_data[i+2] >> 1 << 35) | (byte_data[i+3] >> 1 << 28) | (byte_data[i+4] >> 1 << 21) | (byte_data[i+5] >> 1 << 14) | (byte_data[i+6] >> 1 << 7) | (byte_data[i+7] >> 1)
        bytes_7 = pack_64.to_bytes(7, 'big')

        for j in range(7):
            output[output_idx] = bytes_7[j]
            output_idx += 1

    return output


def run():
    with open("layer2_payload.txt") as payload:

        # Slice off the delimeters and decode the ascii85
        decoded = base64.a85decode(payload.read()[2:-2])

        # Filter out the bytes that don't have the correct parity
        filtered = filter(has_correct_parity, decoded)

        # Strip out the parity bit and pack the data 8 byte chunks are packed into 7 bytes
        # "To make this layer a little bit easier, the byte size of the payload is guaranteed to be a multiple of eight. Every group
        # of eight bytes contains 64 bits total, including 8 parity bits. Removing the 8 parity bits leaves behind 56 data
        # bits, which is exactly seven bytes."
        stripped = strip_parity_bits(list(filtered))

        # Write out the instructions for the next layer
        with open("layer3_instructions.txt", 'w') as instructions:
            instructions.write(stripped.decode('ascii'))


if __name__ == '__main__':
    run()
