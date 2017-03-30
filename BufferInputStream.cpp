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

CBufferInputStream::CBufferInputStream(unsigned char* data, size_t length){
	this->buffer=data;
	this->length=length;
	offset=0;
}

CBufferInputStream::~CBufferInputStream(){

}


void CBufferInputStream::Seek(size_t offset){
	if(offset>length){
		throw std::out_of_range("Not enough bytes in buffer");
	}
	this->offset=offset;
}

size_t CBufferInputStream::GetLength(){
	return length;
}

size_t CBufferInputStream::GetOffset(){
	return offset;
}

size_t CBufferInputStream::Remaining(){
	return length-offset;
}

unsigned char CBufferInputStream::ReadByte(){
	EnsureEnoughRemaining(1);
	return (unsigned char)buffer[offset++];
}

int32_t CBufferInputStream::ReadInt32(){
	EnsureEnoughRemaining(4);
	int32_t res=((int32_t)buffer[offset] & 0xFF) |
			(((int32_t)buffer[offset+1] & 0xFF) << 8) |
			(((int32_t)buffer[offset+2] & 0xFF) << 16) |
			(((int32_t)buffer[offset+3] & 0xFF) << 24);
	offset+=4;
	return res;
}

int64_t CBufferInputStream::ReadInt64(){
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

int16_t CBufferInputStream::ReadInt16(){
	EnsureEnoughRemaining(2);
	int16_t res=(uint16_t)buffer[offset] | ((uint16_t)buffer[offset+1] << 8);
	offset+=2;
	return res;
}


int32_t CBufferInputStream::ReadTlLength(){
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

void CBufferInputStream::ReadBytes(unsigned char *to, size_t count){
	EnsureEnoughRemaining(count);
	memcpy(to, buffer+offset, count);
	offset+=count;
}


void CBufferInputStream::EnsureEnoughRemaining(size_t need){
	if(length-offset<need){
		throw std::out_of_range("Not enough bytes in buffer");
	}
}
