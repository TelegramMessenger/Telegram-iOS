//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BufferInputStream.h"
#include <assert.h>
#include <string.h>
#include <exception>
#include <stdexcept>

using namespace tgvoip;

BufferInputStream::BufferInputStream(unsigned char* data, size_t length){
	this->buffer=data;
	this->length=length;
	offset=0;
}

BufferInputStream::~BufferInputStream(){

}


void BufferInputStream::Seek(size_t offset){
	if(offset>length){
		throw std::out_of_range("Not enough bytes in buffer");
	}
	this->offset=offset;
}

size_t BufferInputStream::GetLength(){
	return length;
}

size_t BufferInputStream::GetOffset(){
	return offset;
}

size_t BufferInputStream::Remaining(){
	return length-offset;
}

unsigned char BufferInputStream::ReadByte(){
	EnsureEnoughRemaining(1);
	return (unsigned char)buffer[offset++];
}

int32_t BufferInputStream::ReadInt32(){
	EnsureEnoughRemaining(4);
	int32_t res=((int32_t)buffer[offset] & 0xFF) |
			(((int32_t)buffer[offset+1] & 0xFF) << 8) |
			(((int32_t)buffer[offset+2] & 0xFF) << 16) |
			(((int32_t)buffer[offset+3] & 0xFF) << 24);
	offset+=4;
	return res;
}

int64_t BufferInputStream::ReadInt64(){
	EnsureEnoughRemaining(8);
	int64_t res=((int64_t)buffer[offset] & 0xFF) |
			(((int64_t)buffer[offset+1] & 0xFF) << 8) |
			(((int64_t)buffer[offset+2] & 0xFF) << 16) |
			(((int64_t)buffer[offset+3] & 0xFF) << 24) |
			(((int64_t)buffer[offset+4] & 0xFF) << 32) |
			(((int64_t)buffer[offset+5] & 0xFF) << 40) |
			(((int64_t)buffer[offset+6] & 0xFF) << 48) |
			(((int64_t)buffer[offset+7] & 0xFF) << 56);
	offset+=8;
	return res;
}

int16_t BufferInputStream::ReadInt16(){
	EnsureEnoughRemaining(2);
	int16_t res=(uint16_t)buffer[offset] | ((uint16_t)buffer[offset+1] << 8);
	offset+=2;
	return res;
}


int32_t BufferInputStream::ReadTlLength(){
	unsigned char l=ReadByte();
	if(l<254)
		return l;
	assert(length-offset>=3);
	EnsureEnoughRemaining(3);
	int32_t res=((int32_t)buffer[offset] & 0xFF) |
				(((int32_t)buffer[offset+1] & 0xFF) << 8) |
				(((int32_t)buffer[offset+2] & 0xFF) << 16);
	offset+=3;
	return res;
}

void BufferInputStream::ReadBytes(unsigned char *to, size_t count){
	EnsureEnoughRemaining(count);
	memcpy(to, buffer+offset, count);
	offset+=count;
}

BufferInputStream BufferInputStream::GetPartBuffer(size_t length, bool advance){
	EnsureEnoughRemaining(length);
	BufferInputStream s=BufferInputStream(buffer+offset, length);
	if(advance)
		offset+=length;
	return s;
}

void BufferInputStream::EnsureEnoughRemaining(size_t need){
	if(length-offset<need){
		throw std::out_of_range("Not enough bytes in buffer");
	}
}
