#import <DctHuffman/DctHuffman.h>

#include <functional>
#include <vector>

namespace DctHuffman {
    typedef std::function<void(unsigned char)> WRITE_ONE_BYTE;
}

namespace
{

using uint8_t  = unsigned char;
using uint16_t = unsigned short;
using int16_t = short;
using int32_t = int;

const uint8_t ZigZagInv[8*8] = {
    0, 1, 8,16, 9, 2, 3, 10,
    17,24,32,25,18,11, 4, 5,
    12,19,26,33,40,48,41,34,
    27,20,13, 6, 7,14,21,28,
    35,42,49,56,57,50,43,36,
    29,22,15,23,30,37,44,51,
    58,59,52,45,38,31,39,46,
    53,60,61,54,47,55,62,63
};

const uint8_t ZigZag[] = {
    0, 1, 5, 6,14,15,27,28,
    2, 4, 7,13,16,26,29,42,
    3, 8,12,17,25,30,41,43,
    9,11,18,24,31,40,44,53,
    10,19,23,32,39,45,52,54,
    20,22,33,38,46,51,55,60,
    21,34,37,47,50,56,59,61,
    35,36,48,49,57,58,62,63
};

// Huffman definitions for first DC/AC tables (luminance / Y channel)
const uint8_t DcLuminanceCodesPerBitsize[16]   = { 0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0 };   // sum = 12
const uint8_t DcLuminanceValues         [12]   = { 0,1,2,3,4,5,6,7,8,9,10,11 };         // => 12 codes
const uint8_t AcLuminanceCodesPerBitsize[16]   = { 0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,125 }; // sum = 162
const uint8_t AcLuminanceValues        [162]   =                                        // => 162 codes
{ 0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,0x22,0x71,0x14,0x32,0x81,0x91,0xA1,0x08, // 16*10+2 symbols because
    0x23,0x42,0xB1,0xC1,0x15,0x52,0xD1,0xF0,0x24,0x33,0x62,0x72,0x82,0x09,0x0A,0x16,0x17,0x18,0x19,0x1A,0x25,0x26,0x27,0x28, // upper 4 bits can be 0..F
    0x29,0x2A,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x53,0x54,0x55,0x56,0x57,0x58,0x59, // while lower 4 bits can be 1..A
    0x5A,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x83,0x84,0x85,0x86,0x87,0x88,0x89, // plus two special codes 0x00 and 0xF0
    0x8A,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9A,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xB2,0xB3,0xB4,0xB5,0xB6, // order of these symbols was determined empirically by JPEG committee
    0xB7,0xB8,0xB9,0xBA,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0xE1,0xE2,
    0xE3,0xE4,0xE5,0xE6,0xE7,0xE8,0xE9,0xEA,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA };
// Huffman definitions for second DC/AC tables (chrominance / Cb and Cr channels)
const uint8_t DcChrominanceCodesPerBitsize[16] = { 0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0 };   // sum = 12
const uint8_t DcChrominanceValues         [12] = { 0,1,2,3,4,5,6,7,8,9,10,11 };         // => 12 codes (identical to DcLuminanceValues)
const uint8_t AcChrominanceCodesPerBitsize[16] = { 0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,119 }; // sum = 162
const uint8_t AcChrominanceValues        [162] =                                        // => 162 codes
{ 0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91, // same number of symbol, just different order
    0xA1,0xB1,0xC1,0x09,0x23,0x33,0x52,0xF0,0x15,0x62,0x72,0xD1,0x0A,0x16,0x24,0x34,0xE1,0x25,0xF1,0x17,0x18,0x19,0x1A,0x26, // (which is more efficient for AC coding)
    0x27,0x28,0x29,0x2A,0x35,0x36,0x37,0x38,0x39,0x3A,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x53,0x54,0x55,0x56,0x57,0x58,
    0x59,0x5A,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x82,0x83,0x84,0x85,0x86,0x87,
    0x88,0x89,0x8A,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9A,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xB2,0xB3,0xB4,
    0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,
    0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xE8,0xE9,0xEA,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA };
const int16_t CodeWordLimit = 2048; // +/-2^11, maximum value after DCT

// represent a single Huffman code
struct BitCode {
    BitCode() = default; // undefined state, must be initialized at a later time
    BitCode(uint16_t code_, uint8_t numBits_)
    : code(code_), numBits(numBits_) {}
    uint16_t code;       // JPEG's Huffman codes are limited to 16 bits
    uint8_t  numBits;    // number of valid bits
};

// wrapper for bit output operations
struct BitWriter {
    // user-supplied callback that writes/stores one byte
    DctHuffman::WRITE_ONE_BYTE output;
    // initialize writer
    explicit BitWriter(DctHuffman::WRITE_ONE_BYTE output_) : output(output_) {}
    
    // store the most recently encoded bits that are not written yet
    struct BitBuffer
    {
        int32_t data    = 0; // actually only at most 24 bits are used
        uint8_t numBits = 0; // number of valid bits (the right-most bits)
    } buffer;
    
    // write Huffman bits stored in BitCode, keep excess bits in BitBuffer
    BitWriter& operator<<(const BitCode& data)
    {
        // append the new bits to those bits leftover from previous call(s)
        buffer.numBits += data.numBits;
        buffer.data   <<= data.numBits;
        buffer.data    |= data.code;
        
        // write all "full" bytes
        while (buffer.numBits >= 8)
        {
            // extract highest 8 bits
            buffer.numBits -= 8;
            auto oneByte = uint8_t(buffer.data >> buffer.numBits);
            output(oneByte);
            
            if (oneByte == 0xFF) // 0xFF has a special meaning for JPEGs (it's a block marker)
                output(0);         // therefore pad a zero to indicate "nope, this one ain't a marker, it's just a coincidence"
            
            // note: I don't clear those written bits, therefore buffer.bits may contain garbage in the high bits
            //       if you really want to "clean up" (e.g. for debugging purposes) then uncomment the following line
            //buffer.bits &= (1 << buffer.numBits) - 1;
        }
        return *this;
    }
    
    // write all non-yet-written bits, fill gaps with 1s (that's a strange JPEG thing)
    void flush()
    {
        // at most seven set bits needed to "fill" the last byte: 0x7F = binary 0111 1111
        *this << BitCode(0x7F, 7); // I should set buffer.numBits = 0 but since there are no single bits written after flush() I can safely ignore it
    }
    
    // NOTE: all the following BitWriter functions IGNORE the BitBuffer and write straight to output !
    // write a single byte
    BitWriter& operator<<(uint8_t oneByte)
    {
        output(oneByte);
        return *this;
    }
    
    // write an array of bytes
    template <typename T, int Size>
    BitWriter& operator<<(T (&manyBytes)[Size])
    {
        for (auto c : manyBytes)
            output(c);
        return *this;
    }
    
    // start a new JFIF block
    void addMarker(uint8_t id, uint16_t length)
    {
        output(0xFF); output(id);     // ID, always preceded by 0xFF
        output(uint8_t(length >> 8)); // length of the block (big-endian, includes the 2 length bytes as well)
        output(uint8_t(length & 0xFF));
    }
};

// ////////////////////////////////////////
// functions / templates

// same as std::min()
template <typename Number>
Number minimum(Number value, Number maximum)
{
    return value <= maximum ? value : maximum;
}

// restrict a value to the interval [minimum, maximum]
template <typename Number, typename Limit>
Number clamp(Number value, Limit minValue, Limit maxValue)
{
    if (value <= minValue) return minValue; // never smaller than the minimum
    if (value >= maxValue) return maxValue; // never bigger  than the maximum
    return value;                           // value was inside interval, keep it
}

int16_t encodeDCTBlock(BitWriter& writer, float block64[64], int16_t lastDC,
                       const BitCode huffmanDC[256], const BitCode huffmanAC[256], const BitCode* codewords) {
    // encode DC (the first coefficient is the "average color" of the 8x8 block)
    auto DC = int(block64[0] + (block64[0] >= 0 ? +0.5f : -0.5f)); // C++11's nearbyint() achieves a similar effect
    
    // quantize and zigzag the other 63 coefficients
    auto posNonZero = 0; // find last coefficient which is not zero (because trailing zeros are encoded differently)
    int16_t quantized[8*8];
    for (auto i = 1; i < 8*8; i++) // start at 1 because block64[0]=DC was already processed
    {
        auto value = block64[ZigZagInv[i]];
        // round to nearest integer
        quantized[i] = int(value + (value >= 0 ? +0.5f : -0.5f)); // C++11's nearbyint() achieves a similar effect
        // remember offset of last non-zero coefficient
        if (quantized[i] != 0)
            posNonZero = i;
    }
    
    // same "average color" as previous block ?
    auto diff = DC - lastDC;
    if (diff == 0)
        writer << huffmanDC[0x00];   // yes, write a special short symbol
    else
    {
        auto bits = codewords[diff]; // nope, encode the difference to previous block's average color
        writer << huffmanDC[bits.numBits] << bits;
    }
    
    // encode ACs (quantized[1..63])
    auto offset = 0; // upper 4 bits count the number of consecutive zeros
    for (auto i = 1; i <= posNonZero; i++) // quantized[0] was already written, skip all trailing zeros, too
    {
        // zeros are encoded in a special way
        while (quantized[i] == 0) // found another zero ?
        {
            offset    += 0x10; // add 1 to the upper 4 bits
            // split into blocks of at most 16 consecutive zeros
            if (offset > 0xF0) // remember, the counter is in the upper 4 bits, 0xF = 15
            {
                writer << huffmanAC[0xF0]; // 0xF0 is a special code for "16 zeros"
                offset = 0;
            }
            i++;
        }
        
        auto encoded = codewords[quantized[i]];
        // combine number of zeros with the number of bits of the next non-zero value
        writer << huffmanAC[offset + encoded.numBits] << encoded; // and the value itself
        offset = 0;
    }
    
    // send end-of-block code (0x00), only needed if there are trailing zeros
    if (posNonZero < 8*8 - 1) // = 63
        writer << huffmanAC[0x00];
    
    return DC;
}

// Jon's code includes the pre-generated Huffman codes
// I don't like these "magic constants" and compute them on my own :-)
void generateHuffmanTable(const uint8_t numCodes[16], const uint8_t* values, BitCode result[256])
{
    // process all bitsizes 1 thru 16, no JPEG Huffman code is allowed to exceed 16 bits
    auto huffmanCode = 0;
    for (auto numBits = 1; numBits <= 16; numBits++)
    {
        // ... and each code of these bitsizes
        for (auto i = 0; i < numCodes[numBits - 1]; i++) // note: numCodes array starts at zero, but smallest bitsize is 1
            result[*values++] = BitCode(huffmanCode++, numBits);
        
        // next Huffman code needs to be one bit wider
        huffmanCode <<= 1;
    }
}

} // end of anonymous namespace

// -------------------- externally visible code --------------------

namespace DctHuffman {

bool readMoreData(std::vector<uint8_t> const &bytes, int &readPosition, unsigned int &data, unsigned int &currentDataLength) {
    unsigned char binaryData;
    
    // Detect errors
    if (currentDataLength > 24) { // Unsigned int can hold at most 32 = 24+8 bits
        //cout << "ERROR: Code value not found in Huffman table: "<<data<<endl;
        
        // Truncate data one by one bit in hope that we will eventually find a correct code
        data = data - ((data >> (currentDataLength-1)) << (currentDataLength-1));
        currentDataLength--;
        return true;
    }
    
    if (readPosition + 1 >= bytes.size()) {
        return false;
    }
    binaryData = bytes[readPosition];
    readPosition++;
    
    // We read byte and put it in low 8 bits of variable data
    if (binaryData == 0xFF) {
        data = (data << 8) + binaryData;
        currentDataLength += 8; // Increase current data length for 8 because we read one new byte
        
        if (readPosition + 1 >= bytes.size()) {
            return false;
        }
        binaryData = bytes[readPosition];
        readPosition++;
        
        // End of Image marker
        if (binaryData == 0xd9) {
            // Drop 0xFF from data
            data = data >> 8;
            currentDataLength -= 8;
#if DEBUGLEVEL>1
            cout << "End of image marker"<<endl;
#endif
            return false;
        }
        
        // Restart marker means data goes blank
        if (binaryData >= 0xd0 && binaryData <= 0xd7) {
            /*#if DEBUGLEVEL>1
             cout << "Restart marker"<<endl;
             #endif*/
            
            data = 0;
            currentDataLength = 0;
            /*for (uint i=0; i < components.size(); i++)
             previousDC[i]=0;*/
        }
        
        // If after FF byte comes 0x00 byte, we ignore it, 0xFF is part of data (byte stuffing)
        else if (binaryData != 0) {
            data = (data << 8) + binaryData;
            currentDataLength += 8; //Increase current data length for 8 because we read one new byte
#if DEBUGLEVEL>1
            cout << "Stuffing"<<endl;
#endif
        }
    }
    else {
        data = (data << 8) + binaryData;
        currentDataLength += 8;
    }
    return true;
}

bool readHuffmanBlock(std::vector<uint8_t> const &bytes, int &readPosition, int *dataBlock, unsigned int &data, unsigned int &currentDataLength, int currentComponent, BitCode const *componentTablesDC, BitCode const *componentTablesAC, int &previousDC) {
    // Debugging
    static unsigned int byteno = 0;
    
    // Description of the 8x8 block currently being read
    enum { AC, DC } ACDC = DC;
    
    // How many AC elements should we read?
    int ACcount = 64 - 1;
    
    int m = 0; // Index into dataBlock
    
    // Fill block with zeros
    memset ((char*)dataBlock, 0, sizeof(int)*64);
    
    bool endOfFile = false;
    
    // Main loop
    do {
        // 3 bits is too small for a code
        if (currentDataLength<3) {
            continue;
        }
        
        // Some stats
        byteno++;
        
        // Current Huffman table
        BitCode const *htable = componentTablesDC;
        if (ACDC == AC) {
            htable = componentTablesAC;
        }
        
        // Every one of 256 elements of the current Huffman table potentially has value, so we must go through all of them
        for (int i = 0; i < 256; i++) {
            // If code for i-th element is -1, then there is no Huffman code for i-th element
            if (htable[i].numBits == 0) {
                continue;
            }
            
            // If current data length is greater or equal than n, compare first n bits (n - length of current Huffman code)
            uint n = htable[i].numBits;
            
            if (currentDataLength < n) {
                continue;
            }
            
            if (currentDataLength >= n && htable[i].code == data >> (currentDataLength - n)) {
                // Remove first n bits from data;
                currentDataLength -= n;
                data = data - (htable[i].code << currentDataLength);
                
                // Reading of DC coefficients
                if (ACDC == DC) {
                    unsigned char bitLength = i; // Next i bits represent DC coefficient value
                    
                    // Do we need to read more bits of data?
                    while (currentDataLength<bitLength) {
                        if (!readMoreData(bytes, readPosition, data, currentDataLength)) {
                            endOfFile = true;
                            break;
                        }
                        byteno++;
                    }
                    
                    // Read out DC coefficient
                    int DCCoeficient = data >> (currentDataLength-bitLength);
                    currentDataLength -= bitLength;
                    data = data - (DCCoeficient << currentDataLength);
                    
                    // If MSB in DC coefficient starts with 0, then substract value of DC with 2^bitlength+1
                    //cout << "Before substract "<<DCCoeficient<<" BL "<<int(bitLength)<<endl;
                    if ( bitLength != 0 && (DCCoeficient>>(bitLength-1)) == 0 ) {
                        DCCoeficient = DCCoeficient - (2 << (bitLength-1)) + 1;
                    }
                    //cout << "After substract "<<DCCoeficient<<" previousDC "<<previousDC[currentComponent]<<endl;
                    
                    previousDC = DCCoeficient + previousDC;
                    dataBlock[m] = previousDC;
                    
                    m++;
                    
                    // No AC coefficients required?
                    if (ACcount == 0) {
                        return endOfFile;
                    }
                    
                    // We generated our DC coefficient, next one is AC coefficient
                    ACDC = AC;
                    if (currentDataLength < 3) // If currentData length is < than 3, we need to read new byte, so leave this for loop
                        break;
                    i = -1; // CurrentDataLength is not zero, set i=0 to start from first element of array
                    htable = componentTablesAC;
                } else {
                    // Reading of AC coefficients
                    unsigned char ACElement=i;
                    
                    /* Every AC component is composite of 4 bits (RRRRSSSS). R bits tells us relative position of
                     non zero element from the previous non zero element (number of zeros between two non zero elements)
                     SSSS bits tels us magnitude range of AC element
                     Two special values:
                     00 is END OF BLOCK (all AC elements are zeros)
                     F0 is 16 zeroes */
                    
                    if (ACElement == 0x00) {
                        return endOfFile;
                    }
                    
                    else if (ACElement == 0xF0) {
                        for (int k=0;k<16;k++) {
                            dataBlock[m] = 0;
                            m++;
                            if (m >= ACcount+1) {
                                //qDebug() << "Huffman error: 16 AC zeros requested, but only "<<k<<" left in block!";
                                return endOfFile;
                            }
                        }
                    }
                    else {
                        /* If AC element is 0xAB for example, then we have to separate it in two nibbles
                         First nible is RRRR bits, second are SSSS bits
                         RRRR bits told us how many zero elements are before this element
                         SSSS bits told us how many binary digits our AC element has (if 1001 then we have to read next 9 elements from file) */
                        
                        // Let's separate byte to two nibles
                        unsigned char Rbits = ACElement >> 4;
                        unsigned char Sbits = ACElement & 0x0F;
                        
                        // Before our element there is Rbits zero elements
                        for (int k=0; k<Rbits; k++) {
                            if (m >= ACcount) {
                                //qDebug() << "Huffman error: "<<Rbits<<" preceeding AC zeros requested, but only "<<k<<" left in block!";
                                // in case of error, doing the other stuff will just do more errors so return here
                                return endOfFile;
                            }
                            dataBlock[m] = 0;
                            m++;
                        }
                        
                        // Do we need to read more bits of data?
                        while (currentDataLength<Sbits) {
                            if (!readMoreData(bytes, readPosition, data, currentDataLength)) {
                                endOfFile = true;
                                //qDebug() << "End of file encountered inside a Huffman code!";
                                break;
                            }
                            byteno++;
                        }
                        
                        // Read out AC coefficient
                        int ACCoeficient = data >> (currentDataLength-Sbits);
                        currentDataLength -= Sbits;
                        data = data - (ACCoeficient<<currentDataLength);
                        
                        // If MSB in AC coefficient starts with 0, then substract value of AC with 2^bitLength+1
                        if ( Sbits != 0 && (ACCoeficient>>(Sbits-1)) == 0 ) {
                            ACCoeficient = ACCoeficient - (2 << (Sbits-1)) + 1;
                        }
                        dataBlock[m] = ACCoeficient;
                        m++;
                    }
                    
                    // End of block
                    if (m >= ACcount+1)
                        return endOfFile;
                    
                    if (currentDataLength<3) // If currentData length is < 3, we need to read new byte, so leave this for loop
                        break;
                    i = -1; // currentDataLength is not zero, set i=0 to start from first element of array
                }
                
            }
        }
    } while(readMoreData(bytes, readPosition, data, currentDataLength));
    
    endOfFile = true; // We reached an end
    return endOfFile;
}

NSData * _Nullable writeDCTBlocks(int width, int height, float const *coefficients) {
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:width * 4 * height];
    BitWriter bitWriter([result](unsigned char byte) {
        [result appendBytes:&byte length:1];
    });
    
    BitCode  codewordsArray[2 * CodeWordLimit];          // note: quantized[i] is found at codewordsArray[quantized[i] + CodeWordLimit]
    BitCode* codewords = &codewordsArray[CodeWordLimit]; // allow negative indices, so quantized[i] is at codewords[quantized[i]]
    uint8_t numBits = 1; // each codeword has at least one bit (value == 0 is undefined)
    int32_t mask    = 1; // mask is always 2^numBits - 1, initial value 2^1-1 = 2-1 = 1
    for (int16_t value = 1; value < CodeWordLimit; value++)
    {
        // numBits = position of highest set bit (ignoring the sign)
        // mask    = (2^numBits) - 1
        if (value > mask) // one more bit ?
        {
            numBits++;
            mask = (mask << 1) | 1; // append a set bit
        }
        codewords[-value] = BitCode(mask - value, numBits); // note that I use a negative index => codewords[-value] = codewordsArray[CodeWordLimit  value]
        codewords[+value] = BitCode(       value, numBits);
    }
    
    BitCode huffmanLuminanceDC[256];
    BitCode huffmanLuminanceAC[256];
    memset(huffmanLuminanceDC, 0, sizeof(BitCode) * 256);
    memset(huffmanLuminanceAC, 0, sizeof(BitCode) * 256);
    generateHuffmanTable(DcLuminanceCodesPerBitsize, DcLuminanceValues, huffmanLuminanceDC);
    generateHuffmanTable(AcLuminanceCodesPerBitsize, AcLuminanceValues, huffmanLuminanceAC);
    
    int16_t lastYDC = 0;
    float Y[8 * 8];
    
    for (auto blockY = 0; blockY < height; blockY += 8) {
        for (auto blockX = 0; blockX < width; blockX += 8) {
            for (auto y = 0; y < 8; y++)  {
                for (auto x = 0; x < 8; x++)  {
                    Y[y * 8 + x] = coefficients[(blockY + y) * width + blockX + x];
                }
            }
            
            lastYDC = encodeDCTBlock(bitWriter, Y, lastYDC, huffmanLuminanceDC, huffmanLuminanceAC, codewords);
        }
    }
    
    //bitWriter.flush();
    
    return result;
}

} // namespace TooJpeg

extern "C"
NSData * _Nullable writeDCTBlocks(int width, int height, float const *coefficients) {
    NSData *result = DctHuffman::writeDCTBlocks(width, height, coefficients);
    
    /*std::vector<uint8_t> bytes((uint8_t *)result.bytes, ((uint8_t *)result.bytes) + result.length);
     int readPosition = 0;
     
     int targetY[8 * 8];
     int Y[8 * 8];
     int Yzig[8 * 8];
     int previousDC = 0;
     
     unsigned int data = 0;
     unsigned int currentDataLength = 0;
     
     BitCode huffmanLuminanceDC[256];
     BitCode huffmanLuminanceAC[256];
     memset(huffmanLuminanceDC, 0, sizeof(BitCode) * 256);
     memset(huffmanLuminanceAC, 0, sizeof(BitCode) * 256);
     generateHuffmanTable(DcLuminanceCodesPerBitsize, DcLuminanceValues, huffmanLuminanceDC);
     generateHuffmanTable(AcLuminanceCodesPerBitsize, AcLuminanceValues, huffmanLuminanceAC);
     
     for (auto blockY = 0; blockY < height; blockY += 8) {
     for (auto blockX = 0; blockX < width; blockX += 8) {
     for (auto y = 0; y < 8; y++)  {
     for (auto x = 0; x < 8; x++)  {
     targetY[y * 8 + x] = coefficients[(blockY + y) * width + blockX + x];
     }
     }
     
     TooJpeg::readHuffmanBlock(bytes, readPosition, Yzig, data, currentDataLength, 0, huffmanLuminanceDC, huffmanLuminanceAC, previousDC);
     for (int i = 0; i < 64; i++) {
     Y[i] = Yzig[ZigZag[i]];
     }
     
     for (auto y = 0; y < 8; y++)  {
     for (auto x = 0; x < 8; x++) {
     if (Y[y * 8 + x] != targetY[y * 8 + x]) {
     printf("fail\n");
     }
     }
     }
     }
     }*/
    
    return result;
}

extern "C"
void readDCTBlocks(int width, int height, NSData * _Nonnull blockData, float *coefficients, int elementsPerRow) {
    std::vector<uint8_t> bytes((uint8_t *)blockData.bytes, ((uint8_t *)blockData.bytes) + blockData.length);
    int readPosition = 0;
    
    int Yzig[8 * 8];
    int previousDC = 0;
    
    unsigned int data = 0;
    unsigned int currentDataLength = 0;
    
    BitCode huffmanLuminanceDC[256];
    BitCode huffmanLuminanceAC[256];
    memset(huffmanLuminanceDC, 0, sizeof(BitCode) * 256);
    memset(huffmanLuminanceAC, 0, sizeof(BitCode) * 256);
    generateHuffmanTable(DcLuminanceCodesPerBitsize, DcLuminanceValues, huffmanLuminanceDC);
    generateHuffmanTable(AcLuminanceCodesPerBitsize, AcLuminanceValues, huffmanLuminanceAC);
    
    for (auto blockY = 0; blockY < height; blockY += 8) {
        for (auto blockX = 0; blockX < width; blockX += 8) {
            DctHuffman::readHuffmanBlock(bytes, readPosition, Yzig, data, currentDataLength, 0, huffmanLuminanceDC, huffmanLuminanceAC, previousDC);
            for (int i = 0; i < 64; i++) {
                coefficients[(blockY + (i / 8)) * elementsPerRow + blockX + (i % 8)] = Yzig[ZigZag[i]];
            }
        }
    }
    
    for (auto blockY = height - 8; blockY < height; blockY += 8) {
        for (auto blockX = width - 8; blockX < width; blockX += 8) {
            for (int i = 0; i < 64; i++) {
                coefficients[(blockY + (i / 8)) * elementsPerRow + blockX + (i % 8)] = 0.0f;
            }
        }
    }
}
