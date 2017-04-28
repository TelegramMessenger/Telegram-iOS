//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BUFFERINPUTSTREAM_H
#define LIBTGVOIP_BUFFERINPUTSTREAM_H

#include <stdio.h>
#include <stdint.h>

namespace tgvoip{
class BufferInputStream{

public:
	BufferInputStream(unsigned char* data, size_t length);
	~BufferInputStream();
	void Seek(size_t offset);
	size_t GetLength();
	size_t GetOffset();
	size_t Remaining();
	unsigned char ReadByte();
	int64_t ReadInt64();
	int32_t ReadInt32();
	int16_t ReadInt16();
	int32_t ReadTlLength();
	void ReadBytes(unsigned char* to, size_t count);

private:
	void EnsureEnoughRemaining(size_t need);
	unsigned char* buffer;
	size_t length;
	size_t offset;
};
}

#endif //LIBTGVOIP_BUFFERINPUTSTREAM_H
