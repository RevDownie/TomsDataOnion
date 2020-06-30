#include <memory>
#include <cstdio>
#include <cmath>
#include <fstream>

#define BSWAP_16(x) ((x & 0x00FF) << 8) | ((x & 0xFF00) >> 8)
#define BSWAP_32(x) ((x & 0x000000FF) << 24) | ((x & 0x0000FF00) <<  8) | ((x & 0x00FF0000) >>  8) | ((x & 0xFF000000) >> 24)

struct DecodeResult
{
    std::unique_ptr<uint8_t[]> m_data;
    size_t m_length;
};

struct IPv4Header
{
    //We don't actually need to decode anything other than this
    uint8_t m_protocol;
    uint32_t m_sourceAddress;
    uint32_t m_destAddress;
};

struct UDPHeader
{
    uint16_t m_sourcePort;
    uint16_t m_destPort;
    uint16_t m_length;
    uint16_t m_checksum;
};

//--Function Prototypes
DecodeResult Ascii85Decode(const uint8_t*, size_t);
IPv4Header IPv4HeaderUnpack(const uint8_t*);
UDPHeader UDPHeaderUnpack(const uint8_t*);
bool ValidateIPv4HeaderChecksum(const void*);
bool ValidateUDPChecksum(uint32_t, uint32_t, uint16_t, const UDPHeader&, const void*, uint16_t);

/// Tom's Data Onion - Layer 4
/// https://www.tomdalling.com/toms-data-onion/
///
/// Solve the nexy layer of the puzzle which is Ascii85 conversion followed by
/// unpacking UDP packets and discarding corrupted ones
///
/// NOTE: Compiled with C++17
/// To RUN: clang layer4.cpp -std=c++17 -lstdc++ -o layer4 && ./layer4
///
int main()
{
    //---Read the payload data
    std::ifstream payloadFile("layer4_payload.txt");
    payloadFile.seekg(0, std::ifstream::end);
    size_t payloadLength = payloadFile.tellg();
    payloadFile.seekg(0, std::ifstream::beg);
    uint8_t* const encodedData = new uint8_t[payloadLength];
    std::copy(std::istreambuf_iterator<char>(payloadFile), std::istreambuf_iterator<char>(), encodedData);
    payloadFile.close();

    //---Ascii85 decode the data
    auto decodedDataResult = Ascii85Decode(encodedData, payloadLength);
    uint8_t* const decodedData = decodedDataResult.m_data.get();
    delete[] encodedData;

    //---Packet processing
    const uint8_t* nextIn = decodedData;
    const uint8_t* endIn = nextIn + decodedDataResult.m_length;
    uint8_t* const processedData = new uint8_t[decodedDataResult.m_length];
    uint8_t* nextOut = processedData;

    //Just used the MacOS calculator to convert the ip addresses
    const uint32_t validSrcIP = 167837962;  //10.1.1.10 
    const uint32_t validDstIP = 167838152; //10.1.1.200 
    const uint16_t validDstPort = 42069;

    while(nextIn < endIn)
    {
        const IPv4Header ipHeader = IPv4HeaderUnpack(nextIn);
        const bool ipChecksumValid = ValidateIPv4HeaderChecksum(nextIn);
        nextIn += 20; //Header is guaranteed to be 20 bytes

        const UDPHeader udpHeader = UDPHeaderUnpack(nextIn);
        const uint16_t dataLength = udpHeader.m_length - 8; //Length includes the header size
        const bool udpChecksumValid = ValidateUDPChecksum(ipHeader.m_sourceAddress, ipHeader.m_destAddress, ipHeader.m_protocol, udpHeader, nextIn + 8, dataLength);        
        nextIn += 8; //UDP header is 8 bytes

        //Discard (don't write out) any packet data that fails validation
        if(ipHeader.m_destAddress == validDstIP && ipHeader.m_sourceAddress == validSrcIP && udpHeader.m_destPort == validDstPort && ipChecksumValid && udpChecksumValid)
        {
            std::copy(nextIn, nextIn + dataLength, nextOut);
            nextOut += dataLength;
        }
        nextIn += dataLength;
    }

    //---Output the instructions for the next layer
    std::ofstream instructionsFile("layer5_instructions.txt", std::ios::out | std::ios::trunc);
    instructionsFile.write((const char*)processedData, nextOut - processedData);
    instructionsFile.close();
    delete[] processedData;

    return 0;
}

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
DecodeResult Ascii85Decode(const uint8_t* encodedData, size_t encodedDataLength)
{
    encodedDataLength -= 4; //Discount delimeters

    //Calculate the decoded size (ignoring z compression) 5 bytes => 4 bytes but taking into account padding
    const size_t decodedDataLength = encodedDataLength - std::ceil(encodedDataLength / 5.0f);
    uint8_t* decodedData = new uint8_t[decodedDataLength];

    const size_t n = encodedDataLength / 5 * 5;
    size_t o = 0;
    uint8_t block[5];

    //Convert the full 5 block chunks (unrolled)
    size_t i=2; //Slice off the start delimeter by starting at 2
    for(; i<n; i+=5) 
    {
        block[0] = encodedData[i];
        block[1] = encodedData[i+1];
        block[2] = encodedData[i+2];
        block[3] = encodedData[i+3];
        block[4] = encodedData[i+4];

        const uint32_t p = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33);

        decodedData[o++] = (p >> 24) & 0xFF;
        decodedData[o++] = (p >> 16) & 0xFF;
        decodedData[o++] = (p >> 8) & 0xFF;
        decodedData[o++] = p & 0xFF;
    }

    //Handle any remaining bytes by padding the final block
    const size_t remaining = encodedDataLength % 5;
    if (remaining > 0) 
    {
        size_t j = 0;
        for(; j<remaining; ++j)
        {
            block[j] = encodedData[i++];
        }
        for (; j<5; ++j) 
        {
            block[j] = 'u';
        }

        const uint32_t p = (block[0] - 33) * 52200625 + (block[1] - 33) * 614125 + (block[2] - 33) * 7225 + (block[3] - 33) * 85 + (block[4] - 33);

        for(size_t k=0; k<remaining-1; ++k) 
        {
            decodedData[o++] = (p >> (24-8*k)) & 0xFF;
        }
    }

    DecodeResult result;
    result.m_data = std::unique_ptr<uint8_t[]>(decodedData);
    result.m_length = decodedDataLength;
    return result;
}

/// Bitstream decode of IPv4 header. Header is guaranteed 20 bytes
/// Header is packed big endian (all my machines are little endian so just switching from network order).
/// We actually only need a portion of the header so not bothering decoding anything else
///
IPv4Header IPv4HeaderUnpack(const uint8_t* packedHeader)
{
    IPv4Header header;

    //Start at the block containing the protocol
    const uint32_t* next = ((const uint32_t*)packedHeader) + 2;

    header.m_protocol = (*next) >> 8;
    ++next;

    header.m_sourceAddress = BSWAP_32(*next);
    ++next;

    header.m_destAddress = BSWAP_32(*next);
    ++next;

    return header;
}

/// Fortunately the UDP header is 2-byte aligned so all we need to do is swap endian 
/// (all my machines are little endian so just switching from network order).
///
UDPHeader UDPHeaderUnpack(const uint8_t* packedHeader)
{
    UDPHeader header;

    const uint16_t* next = ((const uint16_t*)packedHeader);
    header.m_sourcePort = BSWAP_16(*next);
    ++next;

    header.m_destPort = BSWAP_16(*next);
    ++next;

    header.m_length = BSWAP_16(*next);
    ++next;

    header.m_checksum = BSWAP_16(*next);

    return header;
}

/// Sums all 16 bit values (handling the carry if overflowing 16 bits) then 1's complement.
/// If zero then valid otherwise corrupted
///
/// NOTE: Data must be in network order (BE)
///
bool ValidateIPv4HeaderChecksum(const void* headerDataNetOrder)
{
    const uint16_t* chunks16 = (const uint16_t*)headerDataNetOrder;
    uint32_t sum = chunks16[0] + chunks16[1] + chunks16[2] + chunks16[3] + chunks16[4] + chunks16[5] + chunks16[6] + chunks16[7] + chunks16[8] + chunks16[9];

    //Carrying might generate at most one more carry
    sum = (sum & 0xFFFF) + (sum >> 16);
    sum = (sum & 0xFFFF) + (sum >> 16);

    uint16_t valid = ~sum;
    return valid == 0;
}

/// UDP checksum operates over a pseudo-header, full UDP header and payload.
/// Pseudo header is formed from the source address, dest address and protocol from IP header with the UDP length
/// Payload is zero padded until it is 2 byte aligned
/// Sums all 16 bit values (handling the carry if overflowing 16 bits) then 1's complement.
/// If zero then valid otherwise corrupted
///
bool ValidateUDPChecksum(uint32_t srcAddr, uint32_t dstAddr, uint16_t proto, const UDPHeader& udpHeader, const void* payload, uint16_t payloadLength)
{
    //Pseudo header
    uint32_t sum = (srcAddr & 0xFFFF) + (srcAddr >> 16 & 0xFFFF) + (dstAddr & 0xFFFF) + (dstAddr >> 16 & 0xFFFF) + proto + udpHeader.m_length;

    //UDP Header
    sum += udpHeader.m_sourcePort + udpHeader.m_destPort + udpHeader.m_length + udpHeader.m_checksum;

    //Payload
    const uint16_t* chunks16Payload = (const uint16_t*)payload;
    const size_t alignedPayloadLen = payloadLength / 2;
    for(size_t i=0; i<alignedPayloadLen; ++i)
    {
        sum += BSWAP_16(chunks16Payload[i]);
    }

    //Payload remainder (can only be 1 needs padded to 2 bytes with 0s)
    if((payloadLength % 2) > 0)
    {
        sum += BSWAP_16(chunks16Payload[alignedPayloadLen]) & 0xFF00;
    }

    //Carrying might generate at most one more carry
    sum = (sum & 0xFFFF) + (sum >> 16);
    sum = (sum & 0xFFFF) + (sum >> 16);

    uint16_t valid = ~sum;
    return valid == 0;
}
