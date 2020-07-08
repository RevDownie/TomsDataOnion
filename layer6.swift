import Foundation

struct Registers {
    var regs8bit = [UInt8](repeating: 0, count: 6)
    var regs32bit = [UInt32](repeating: 0, count: 6)

    var a: UInt8 { get { regs8bit[0] } set { regs8bit[0] = newValue } }
    var b: UInt8 { get { regs8bit[1] } set { regs8bit[1] = newValue } }
    var c: UInt8 { get { regs8bit[2] } set { regs8bit[2] = newValue } }
    var d: UInt8 { get { regs8bit[3] } set { regs8bit[3] = newValue } }
    var e: UInt8 { get { regs8bit[4] } set { regs8bit[4] = newValue } }
    var f: UInt8 { get { regs8bit[5] } set { regs8bit[5] = newValue } }

    var la: UInt32 { get { regs32bit[0] } set { regs32bit[0] = newValue } }
    var lb: UInt32 { get { regs32bit[1] } set { regs32bit[1] = newValue } }
    var lc: UInt32 { get { regs32bit[2] } set { regs32bit[2] = newValue } }
    var ld: UInt32 { get { regs32bit[3] } set { regs32bit[3] = newValue } }
    var ptr: UInt32 { get { regs32bit[4] } set { regs32bit[4] = newValue } }
    var pc: UInt32 { get { regs32bit[5] } set { regs32bit[5] = newValue } }
}

typealias Instruction = (_ registers: inout Registers, _ memory: inout [UInt8], _ outputStream: OutputStream) throws -> Void

enum InstructionError: Error {
    case invalidOpCode
}

/// Tom's Data Onion - Layer 6
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solve the final layer of the puzzle which is a VM to run a decryption program
///
/// To RUN: swift layer6.swift
///
func main() {
    var instructions = [Instruction](repeating: mvRouteInstruction, count: 0xFF)
    instructions[0xC2] = addInstruction
    instructions[0xE1] = aptrInstruction
    instructions[0xC1] = cmpInstruction
    instructions[0x21] = jezInstruction
    instructions[0x22] = jnzInstruction
    instructions[0x02] = outInstruction
    instructions[0xC3] = subInstruction
    instructions[0xC4] = xorInstruction

    var registers = Registers()

    let encoded = try! String(contentsOfFile: "layer6_payload.txt", encoding: .utf8)
    var memory = ascii85Decode(encodedData: Array(encoded.utf8))

    // //Test "Hello, World!" program
    // var memory: [UInt8] = [0x50, 0x48, 0xC2, 0x02, 0xA8, 0x4D, 0x00, 0x00, 0x00, 0x4F, 0x02, 0x50, 0x09, 0xC4,
    // 0x02, 0x02, 0xE1, 0x01, 0x4F, 0x02, 0xC1, 0x22, 0x1D, 0x00, 0x00, 0x00, 0x48, 0x30, 0x02, 0x58, 0x03, 0x4F,
    // 0x02, 0xB0, 0x29, 0x00, 0x00, 0x00, 0x48, 0x31, 0x02, 0x50, 0x0C, 0xC3, 0x02, 0xAA, 0x57, 0x48, 0x02, 0xC1,
    // 0x21, 0x3A, 0x00, 0x00, 0x00, 0x48, 0x32, 0x02, 0x48, 0x77, 0x02, 0x48, 0x6F, 0x02, 0x48, 0x72, 0x02, 0x48,
    // 0x6C, 0x02, 0x48, 0x64, 0x02, 0x48, 0x21, 0x02, 0x01, 0x65, 0x6F, 0x33, 0x34, 0x2C]

    let outputUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("core.txt")
    let outputStream = OutputStream(url: outputUrl, append: false)!
    outputStream.open()

    while true {
        let opcode = memory[Int(registers.pc)]
        if opcode == 0x01 {
            break
        }
        try! instructions[Int(opcode)](&registers, &memory, outputStream)
    }

    outputStream.close()
}

/// Move instructions have a 2 bit identifier so need to mask it off, we essentially treat any
/// non-explicit instruction as a potential move and use this function to route or error
///
func mvRouteInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    let opcode = memory[Int(registers.pc)] & 0xC0
    switch opcode {
    case 0x40:
        try mvInstruction(registers: &registers, memory: &memory, outputStream: outputStream)
    case 0x80:
        try mv32Instruction(registers: &registers, memory: &memory, outputStream: outputStream)
    default:
        throw InstructionError.invalidOpCode
    }
}

/// Sets `a` to the sum of `a` and `b`, modulo 255.
///
func addInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    registers.pc += 1
    registers.a = registers.a &+ registers.b
}

/// Sets `ptr` to the sum of `ptr` and `imm8`. Overflow behaviour is undefined.
///
func aptrInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    let imm8 = memory[Int(registers.pc) + 1]
    registers.pc += 2
    registers.ptr += UInt32(imm8)
}

/// Sets `f` to zero if `a` and `b` are equal, otherwise sets `f` to 0x01.
///
func cmpInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    registers.pc += 1
    registers.f = registers.a == registers.b ? 0 : 0x01
}

/// If `f` is equal to zero, sets `pc` to `imm32`. Otherwise does nothing.
///
func jezInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    if registers.f == 0 {
        let imm0: UInt32 = UInt32(memory[Int(registers.pc) + 1]) & 0xFF
        let imm8: UInt32 = UInt32(memory[Int(registers.pc) + 2]) & 0xFF
        let imm16: UInt32 = UInt32(memory[Int(registers.pc) + 3]) & 0xFF
        let imm24: UInt32 = UInt32(memory[Int(registers.pc) + 4]) & 0xFF
        let imm32: UInt32 = (imm24 << 24) | (imm16 << 16) | (imm8 << 8) | imm0
        registers.pc = imm32
    } else {
        registers.pc += 5
    }
}

/// If `f` is not equal to zero, sets `pc` to `imm32`. Otherwise does nothing.
///
func jnzInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    if registers.f != 0 {
        let imm0: UInt32 = UInt32(memory[Int(registers.pc) + 1]) & 0xFF
        let imm8: UInt32 = UInt32(memory[Int(registers.pc) + 2]) & 0xFF
        let imm16: UInt32 = UInt32(memory[Int(registers.pc) + 3]) & 0xFF
        let imm24: UInt32 = UInt32(memory[Int(registers.pc) + 4]) & 0xFF
        let imm32: UInt32 = (imm24 << 24) | (imm16 << 16) | (imm8 << 8) | imm0
        registers.pc = imm32
    } else {
        registers.pc += 5
    }
}

/// Sets `{dest}` to the value of `{src}`.
///
/// 0b01DDDSSS
///
/// Both `{dest}` and `{src}` are 3-bit unsigned integers that
/// correspond to an 8-bit register or pseudo-register. In the
/// opcode format above, the "DDD" bits are `{dest}`, and the
/// "SSS" bits are `{src}`. Below are the possible valid
/// values (in decimal) and their meaning.
///
///   1 => `a`
///   2 => `b`
///   3 => `c`
///   4 => `d`
///   5 => `e`
///   6 => `f`
///   7 => `(ptr+c)`
///
/// A zero `{src}` indicates an MVI instruction, not MV.
///
func mvInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    let opcode = memory[Int(registers.pc)]
    let src = opcode & 0x7
    let dst = (opcode >> 3) & 0x7
    var valToWrite: UInt8

    if src == 0 {
        valToWrite = memory[Int(registers.pc) + 1]
        registers.pc += 2
    } else {
        //ptr+c is actually an alias for a memory address
        valToWrite = src != 7 ? registers.regs8bit[Int(src)-1] : memory[Int(registers.ptr) + Int(registers.c)]
        registers.pc += 1
    }

    //ptr+c is actually an alias for a memory address
    if dst != 7 {
        registers.regs8bit[Int(dst)-1] = valToWrite
    } else {
        memory[Int(registers.ptr) + Int(registers.c)] = valToWrite
    }
}

/// Sets `{dest}` to the value of `{src}`.
///
/// 0b10DDDSSS
///
/// Both `{dest}` and `{src}` are 3-bit unsigned integers that
/// correspond to a 32-bit register. In the opcode format
/// above, the "DDD" bits are `{dest}`, and the "SSS" bits are
/// `{src}`. Below are the possible valid values (in decimal)
/// and their meaning.
///
///   1 => `la`
///   2 => `lb`
///   3 => `lc`
///   4 => `ld`
///   5 => `ptr`
///   6 => `pc`
/// A zero `{src}` indicates an MVI instruction, not MV.
///
func mv32Instruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    let opcode = memory[Int(registers.pc)]
    let src = opcode & 0x7
    let dst = (opcode >> 3) & 0x7

    //NOTE: We increment the PC first because the MV might actually assign to it
    if src == 0 {
        let imm0: UInt32 = UInt32(memory[Int(registers.pc) + 1]) & 0xFF
        let imm8: UInt32 = UInt32(memory[Int(registers.pc) + 2]) & 0xFF
        let imm16: UInt32 = UInt32(memory[Int(registers.pc) + 3]) & 0xFF
        let imm24: UInt32 = UInt32(memory[Int(registers.pc) + 4]) & 0xFF
        let imm32: UInt32 = (imm24 << 24) | (imm16 << 16) | (imm8 << 8) | imm0
        registers.pc += 5
        registers.regs32bit[Int(dst)-1] = imm32
    } else {
        registers.pc += 1
        registers.regs32bit[Int(dst)-1] = registers.regs32bit[Int(src)-1]
    }
}

/// Appends the value of `a` to the output stream.
///
func outInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    registers.pc += 1
    outputStream.write(&registers.a, maxLength: 1)
}

/// Sets `a` to the result of subtracting `b` from `a`. If subtraction would result in a negative number, 255 is
/// added to ensure that the result is non-negative.
///
func subInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    registers.pc += 1
    registers.a = registers.a &- registers.b
}

/// Sets `a` to the bitwise exclusive OR of `a` and `b`.
///
func xorInstruction(registers: inout Registers, memory: inout [UInt8], outputStream: OutputStream) throws {
    registers.pc += 1
    registers.a = registers.a ^ registers.b
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
func ceilDivide(_ dividend: Int, _ divisor: Int) -> Int {
    (dividend + divisor - 1) / divisor
}

main()
