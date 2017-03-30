//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BufferOutputStream.h"
#include <string.h>

CBufferOutputStream::CBufferOutputStream(size_t size){
	buffer=(unsigned char*) malloc(size);
	offset=0;
	this->size=size;
}

CBufferOutputStream::~CBufferOutputStream(){
	free(buffer);
}

void CBufferOutputStream::WriteByte(unsigned char byte){
	this->ExpandBufferIfNeeded(1);
	buffer[offset++]=byte;
}

void CBufferOutputStream::WriteInt32(int32_t i){
	this->ExpandBufferIfNeeded(4);
	buffer[offset+3]=(unsigned char)((i >> 24) & 0xFF);
	buffer[offset+2]=(unsigned char)((i >> 16) & 0xFF);
	buffer[offset+1]=(unsigned char)((i >> 8) & 0xFF);
	buffer[offset]=(unsigned char)(i & 0xFF);
	offset+=4;
}

void CBufferOutputStream::WriteInt64(int64_t i){
	this->ExpandBufferIfNeeded(8);
	buffer[offset+7]=(unsigned char)((i >> 56) & 0xFF);
	buffer[offset+6]=(unsigned char)((i >> 48) & 0xFF);
	buffer[offset+5]=(unsigned char)((i >> 40) & 0xFF);
	buffer[offset+4]=(unsigned char)((i >> 32) & 0xFF);
	buffer[offset+3]=(unsigned char)((i >> 24) & 0xFF);
	buffer[offset+2]=(unsigned char)((i >> 16) & 0xFF);
	buffer[offset+1]=(unsigned char)((i >> 8) & 0xFF);
	buffer[offset]=(unsigned char)(i & 0xFF);
	offset+=8;
}

void CBufferOutputStream::WriteInt16(int16_t i){
	this->ExpandBufferIfNeeded(2);
	buffer[offset+1]=(unsigned char)((i >> 8) & 0xFF);
	buffer[offset]=(unsigned char)(i & 0xFF);
	offset+=2;
}

void CBufferOutputStream::WriteBytes(unsigned char *bytes, size_t count){
	this->ExpandBufferIfNeeded(count);
	memcpy(buffer+offset, bytes, count);
	offset+=count;
}

unsigned char *CBufferOutputStream::GetBuffer(){
	return buffer;
}

size_t CBufferOutputStream::GetLength(){
	return offset;
}

void CBufferOutputStream::ExpandBufferIfNeeded(size_t need){
	if(offset+need>size){
		if(need<1024){
			buffer=(unsigned char *) realloc(buffer, size+1024);
			size+=1024;
		}else{
			buffer=(unsigned char *) realloc(buffer, size+need);
			size+=need;
		}
	}
}


void CBufferOutputStream::Reset(){
	offset=0;
}

