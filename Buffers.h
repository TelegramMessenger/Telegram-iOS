//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BUFFERINPUTSTREAM_H
#define LIBTGVOIP_BUFFERINPUTSTREAM_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdexcept>
#include "threading.h"

namespace tgvoip{
	class Buffer;

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
		BufferInputStream GetPartBuffer(size_t length, bool advance);

	private:
		void EnsureEnoughRemaining(size_t need);
		unsigned char* buffer;
		size_t length;
		size_t offset;
	};

	class BufferOutputStream{
	friend class Buffer;
	public:
		BufferOutputStream(size_t size);
		BufferOutputStream(unsigned char* buffer, size_t size);
		~BufferOutputStream();
		void WriteByte(unsigned char byte);
		void WriteInt64(int64_t i);
		void WriteInt32(int32_t i);
		void WriteInt16(int16_t i);
		void WriteBytes(unsigned char* bytes, size_t count);
		void WriteBytes(Buffer& buffer);
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

	class BufferPool{
	public:
		BufferPool(unsigned int size, unsigned int count);
		~BufferPool();
		unsigned char* Get();
		void Reuse(unsigned char* buffer);
		size_t GetSingleBufferSize();
		size_t GetBufferCount();

	private:
		uint64_t usedBuffers;
		int bufferCount;
		size_t size;
		unsigned char* buffers[64];
		Mutex mutex;
	};

	class Buffer{
	public:
		Buffer(size_t capacity){
			data=(unsigned char *) malloc(capacity);
			length=capacity;
		};
		Buffer(const Buffer& other)=delete;
		Buffer(Buffer&& other) noexcept {
			data=other.data;
			length=other.length;
			other.data=NULL;
		};
		Buffer(BufferOutputStream&& stream){
			data=stream.buffer;
			length=stream.offset;
			stream.buffer=NULL;
		}
		Buffer(){
			data=NULL;
			length=0;
		}
		~Buffer(){
			if(data)
				free(data);
		};
		Buffer& operator=(Buffer&& other){
			if(this!=&other){
				if(data)
					free(data);
				data=other.data;
				length=other.length;
				other.data=NULL;
			}
			return *this;
		}
		unsigned char& operator[](size_t i){
			if(i>=length)
				throw std::out_of_range("");
			return data[i];
		}
		const unsigned char& operator[](size_t i) const{
			if(i>=length)
				throw std::out_of_range("");
			return data[i];
		}
		unsigned char* operator*(){
			return data;
		}
		const unsigned char* operator*() const{
			return data;
		}
		void CopyFrom(Buffer& other, size_t count, size_t srcOffset=0, size_t dstOffset=0){
			if(!other.data)
				throw std::invalid_argument("CopyFrom can't copy from NULL");
			if(other.length<srcOffset+count || length<dstOffset+count)
				throw std::out_of_range("Out of offset+count bounds of either buffer");
			memcpy(data+dstOffset, other.data+srcOffset, count);
		}
		void CopyFrom(const void* ptr, size_t dstOffset, size_t count){
			if(length<dstOffset+count)
				throw std::out_of_range("Offset+count is out of bounds");
			memcpy(data+dstOffset, ptr, count);
		}
		void Resize(size_t newSize){
			data=(unsigned char *) realloc(data, newSize);
			length=newSize;
		}
		size_t Length(){
			return length;
		}
	private:
		unsigned char* data;
		size_t length;
	};
}

#endif //LIBTGVOIP_BUFFERINPUTSTREAM_H
