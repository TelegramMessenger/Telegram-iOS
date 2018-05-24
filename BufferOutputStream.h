//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BUFFEROUTPUTSTREAM_H
#define LIBTGVOIP_BUFFEROUTPUTSTREAM_H

#include <stdlib.h>
#include <stdint.h>

namespace tgvoip{
class BufferOutputStream{

public:
	BufferOutputStream(size_t size);
	BufferOutputStream(unsigned char* buffer, size_t size);
	~BufferOutputStream();
	void WriteByte(unsigned char byte);
	void WriteInt64(int64_t i);
	void WriteInt32(int32_t i);
	void WriteInt16(int16_t i);
	void WriteBytes(unsigned char* bytes, size_t count);
	unsigned char* GetBuffer();
	size_t GetLength();
	void Reset();
	void Rewind(size_t numBytes);

private:
	void ExpandBufferIfNeeded(size_t need);
	unsigned char* buffer;
	size_t size;
	size_t offset;
	bool bufferProvided;
};
}

#endif //LIBTGVOIP_BUFFEROUTPUTSTREAM_H
