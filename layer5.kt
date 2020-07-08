package main

import java.io.File
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.math.ceil

/**
* Tom's Data Onion - Layer 5
* https://www.tomdalling.com/toms-data-onion/
*
* Solve the next layer of the puzzle which is Ascii85 conversion followed by
* AES 256 CBC decryption
*
* To RUN: kotlinc layer5.kt -include-runtime -d layer5.jar && java -jar layer5.jar
**/
fun main() {
    // Read the ascii85 payload
    val encodedPayload = File("layer5_payload.txt").readBytes()
    val decodedPayload = ascii85Decode(encodedPayload)
    val decodedPayloadStream = decodedPayload.inputStream()

    // Decrypt the key. First 32 bytes are the kek, 8 byte 64-bit IV and 40 byte key
    val kek = ByteArray(32); decodedPayloadStream.read(kek, 0, kek.size)
    val ivKey = ByteArray(8); decodedPayloadStream.read(ivKey, 0, ivKey.size)
    val encryptedKey = ByteArray(40); decodedPayloadStream.read(encryptedKey, 0, encryptedKey.size)
    val decryptedKey = decryptKey(encryptedKey, ivKey, kek)
    check(decryptedKey != null) { "Key decryption failed" }

    // Decrypt the payload using the decrypted key. First 16 bytes are the IV and the remainder is the payload
    val ivPayload = ByteArray(16); decodedPayloadStream.read(ivPayload, 0, ivPayload.size)
    val payloadSize = decodedPayload.size - (kek.size + ivKey.size + encryptedKey.size + ivPayload.size)
    val payloadSizeAligned = payloadSize + (16 - (payloadSize % 16))
    val encryptedPayload = ByteArray(payloadSizeAligned); decodedPayloadStream.read(encryptedPayload, 0, payloadSize)
    decodedPayloadStream.close()

    val cipher = Cipher.getInstance("AES/CBC/NoPadding")
    cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(decryptedKey, "AES"), IvParameterSpec(ivPayload))
    val decryptedPayload = cipher.doFinal(encryptedPayload).sliceArray(0 until payloadSize)

    // Write out the next layer's instructions
    File("layer6_instructions.txt").writeText(String(decryptedPayload))
}

/**
* https://en.wikipedia.org/wiki/Ascii85
*
* - Work in blocks of 5 (padding the last 5 tuple with 'u' characters) (4 characters are encoded in 5)
* - Subtract 33 to convert ascii range
* - Get the 32 bit value (Big endian) of the block
* - Each byte will have the decoded ascii value (4 values)
*
* NOTE: If a group has all zeros it is encoded as a single character 'z' so decoding converts 'z' to 0000. The data didn't require this has been omitted
* NOTE: Acii85 data gets wrapped in <~ ~> delimeters
**/
fun ascii85Decode(encodedData: ByteArray): ByteArray {
    val b = (2..encodedData.size - 2).map { encodedData[it] }.asIterable() // Slice the delimeters
        .chunked(5) // Split into 5 byte chunks
        .flatMap {
            it.mapIndexed { i, n -> (n - 33) * 85.pow(4 - i) } // Convert to base85 range
                .sum() // Pack the 5 bytes into a 32bit int
                .toBytes().asIterable() // Unpack into 4 bytes
        }

    val encodedDataLen = encodedData.size - 4
    val decodedDataLen = encodedDataLen - ceil(encodedDataLen / 5.0).toInt()
    return b.take(decodedDataLen).toByteArray() // Drop the padding
}

/**
* Convert integer to array of 4 bytes
**/
fun Int.toBytes(): ByteArray {
    var bytes = ByteArray(4)
    bytes[0] = ((this shr 24) and 0xFF).toByte()
    bytes[1] = ((this shr 16) and 0xFF).toByte()
    bytes[2] = ((this shr 8) and 0xFF).toByte()
    bytes[3] = (this and 0xFF).toByte()
    return bytes
}

/**
* Concat 2 64bit numbers into a byte array representing 128bit number
**/
fun concatTo16Bytes(a: Long, b: Long): ByteArray {
    var bytes = ByteArray(16)
    bytes[0] = ((a shr 56) and 0xFF).toByte()
    bytes[1] = ((a shr 48) and 0xFF).toByte()
    bytes[2] = ((a shr 40) and 0xFF).toByte()
    bytes[3] = ((a shr 32) and 0xFF).toByte()
    bytes[4] = ((a shr 24) and 0xFF).toByte()
    bytes[5] = ((a shr 16) and 0xFF).toByte()
    bytes[6] = ((a shr 8) and 0xFF).toByte()
    bytes[7] = (a and 0xFF).toByte()
    bytes[8] = ((b shr 56) and 0xFF).toByte()
    bytes[9] = ((b shr 48) and 0xFF).toByte()
    bytes[10] = ((b shr 40) and 0xFF).toByte()
    bytes[11] = ((b shr 32) and 0xFF).toByte()
    bytes[12] = ((b shr 24) and 0xFF).toByte()
    bytes[13] = ((b shr 16) and 0xFF).toByte()
    bytes[14] = ((b shr 8) and 0xFF).toByte()
    bytes[15] = (b and 0xFF).toByte()
    return bytes
}

/**
* Integer power of function
**/
fun Int.pow(e: Int): Int {
    var r = 1
    for (i in 0 until e) {
        r *= this
    }
    return r
}

/**
* Pack 8 byte array to a long
**/
fun ByteArray.packLong(): Long {
    return ((this[0].toLong() and 0xFFL) shl 56) or
        ((this[1].toLong() and 0xFFL) shl 48) or
        ((this[2].toLong() and 0xFFL) shl 40) or
        ((this[3].toLong() and 0xFFL) shl 32) or
        ((this[4].toLong() and 0xFFL) shl 24) or
        ((this[5].toLong() and 0xFFL) shl 16) or
        ((this[6].toLong() and 0xFFL) shl 8) or
        (this[7].toLong() and 0xFFL)
}

/**
* Convert array of 64bit to 8bits splitting the msb and lsb across bytes
* MSB first
**/
fun LongArray.toBytes(): ByteArray {
    var b = ByteArray(this.size * 8)
    var i = 0
    for (l in this) {
        b[i++] = ((l shr 56) and 0xFF).toByte()
        b[i++] = ((l shr 48) and 0xFF).toByte()
        b[i++] = ((l shr 40) and 0xFF).toByte()
        b[i++] = ((l shr 32) and 0xFF).toByte()
        b[i++] = ((l shr 24) and 0xFF).toByte()
        b[i++] = ((l shr 16) and 0xFF).toByte()
        b[i++] = ((l shr 8) and 0xFF).toByte()
        b[i++] = (l and 0xFF).toByte()
    }
    return b
}

/**
* Based on RFC 3394 Key unwrap. Unwraps the AES key. Decryption done using Java crypto lib
**/
fun decryptKey(encryptedKey: ByteArray, iv: ByteArray, kek: ByteArray): ByteArray? {
    require(encryptedKey.size % 8 == 0) { "Key must be 64bit aligned" }
    val n = encryptedKey.size / 8 - 1
    val c = encryptedKey.asIterable().chunked(8).map { it.toByteArray().packLong() }.toLongArray()
    var a = c[0]
    var r = c.copyOf()
    val cipher = Cipher.getInstance("AES/ECB/NoPadding")
    cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(kek, "AES"))

    for (j in 5 downTo 0) {
        for (i in n downTo 1) {
            val t = (n * j + i).toLong()
            val block = concatTo16Bytes(a xor t, r[i])
            val b = cipher.doFinal(block)
            check(b.size == 16) { "Cipher failed to return correct block size" }
            a = b.packLong()
            r[i] = b.sliceArray(8 until 16).packLong()
        }
    }

    return if (a == iv.packLong()) r.sliceArray(1 until r.size).toBytes() else null
}
