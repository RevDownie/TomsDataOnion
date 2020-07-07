/// Tom's Data Onion - Layer 6
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solve the final layer of the puzzle which is a VM to run a decryption program
///
/// To RUN: swift layer6.swift
///
func main() {
    let decoded = ascii85Decode(encodedData: Array("<~7W3Ei7W3Ei7VR$W7VR$W;e^I~>".utf8))
    let string = String(decoding: decoded, as: UTF8.self)
    print(string)
}

/// https://en.wikipedia.org/wiki/Ascii85
///
/// - Work in blocks of 5 (padding the last 5 tuple with 'u' characters) (4 characters are encoded in 5)
/// - Subtract 33 to convert ascii range
/// - Get the 32 bit value (Big endian) of the block
/// - Each byte will have the decoded ascii value (4 values)
///
/// NOTE: If a group has all zeros it is encoded as a single character 'z' so decoding converts 'z' to 0000. 
///     The data didn't require this - has been omitted
///
/// NOTE: Acii85 data gets wrapped in <~ ~> delimeters
///
func ascii85Decode(encodedData: [UInt8]) -> [UInt8] {

    //Slice off the delimeters
    let encodedDataSlice = encodedData[2..<encodedData.count - 2]

    let alignedLen = encodedDataSlice.count / 5 * 5
    var block = [UInt32](repeating: 0, count: 5)

    let decodedDataLen = encodedDataSlice.count - ceilDivide(encodedDataSlice.count, 5)
    var decodedData = [UInt8](repeating: 0, count: decodedDataLen)

    var srcIdx = encodedDataSlice.startIndex
    var destIdx = 0

    //Convert the full 5 block chunks (unrolled)
    for _ in stride(from: 0, to: alignedLen, by: 5) {
        block[0] = UInt32(encodedDataSlice[srcIdx])
        block[1] = UInt32(encodedDataSlice[srcIdx + 1])
        block[2] = UInt32(encodedDataSlice[srcIdx + 2])
        block[3] = UInt32(encodedDataSlice[srcIdx + 3])
        block[4] = UInt32(encodedDataSlice[srcIdx + 4])
        srcIdx += 5

        let packed = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33)

        decodedData[destIdx] = UInt8(truncatingIfNeeded: packed >> 24)
        decodedData[destIdx + 1] = UInt8(truncatingIfNeeded: packed >> 16)
        decodedData[destIdx + 2] = UInt8(truncatingIfNeeded: packed >> 8)
        decodedData[destIdx + 3] = UInt8(truncatingIfNeeded: packed)
        destIdx += 4
    }

    //Tackle the remaining block (if there is one) that requires padding
    let remaining = encodedDataSlice.count % 5
    if remaining > 0 {
        for blockIdx in 0..<remaining {
            block[blockIdx] = UInt32(encodedDataSlice[srcIdx])
            srcIdx += 1
        }
        for blockIdx in remaining..<5 {
            block[blockIdx] = 117
        }

        let packed = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33)

        var shift = 24
        while destIdx < decodedDataLen {
            decodedData[destIdx] = UInt8(truncatingIfNeeded: packed >> shift)
            destIdx += 1
            shift -= 8
        }
    }

    return decodedData
}

/// Integer divide and ceil (rounded up)
///
func ceilDivide(_ a: Int, _ b: Int) -> Int {
    (a + b - 1) / b
}

main()
