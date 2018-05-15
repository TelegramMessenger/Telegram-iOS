//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BufferOutputStream.h"
#include <stdexcept>
#include <string.h>

using namespace tgvoip;

BufferOutputStream::BufferOutputStream(size_t size){
	buffer=(unsigned char*) malloc(size);
	offset=0;
	this->size=size;
	bufferProvided=false;
}

BufferOutputStream::BufferOutputStream(unsigned char *buffer, size_t size){
	this->buffer=buffer;
	this->size=size;
	offset=0;
	bufferProvided=true;
}

BufferOutputStream::~BufferOutputStream(){
	if(!bufferProvided)
		free(buffer);
}

void BufferOutputStream::WriteByte(unsigned char byte){
	this->ExpandBufferIfNeeded(1);
	buffer[offset++]=byte;
}

void BufferOutputStream::WriteInt32(int32_t i){
	this->ExpandBufferIfNeeded(4);
	buffer[offset+3]=(unsigned char)((i >> 24) & 0xFF);
	buffer[offset+2]=(unsigned char)((i >> 16) & 0xFF);
	buffer[offset+1]=(unsigned char)((i >> 8) & 0xFF);
	buffer[offset]=(unsigned char)(i & 0xFF);
	offset+=4;
}

void BufferOutputStream::WriteInt64(int64_t i){
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

void BufferOutputStream::WriteInt16(int16_t i){
	this->ExpandBufferIfNeeded(2);
	buffer[offset+1]=(unsigned char)((i >> 8) & 0xFF);
	buffer[offset]=(unsigned char)(i & 0xFF);
	offset+=2;
}

void BufferOutputStream::WriteBytes(unsigned char *bytes, size_t count){
	this->ExpandBufferIfNeeded(count);
	memcpy(buffer+offset, bytes, count);
	offset+=count;
}

unsigned char *BufferOutputStream::GetBuffer(){
	return buffer;
}

size_t BufferOutputStream::GetLength(){
	return offset;
}

void BufferOutputStream::ExpandBufferIfNeeded(size_t need){
	if(offset+need>size){
		if(bufferProvided){
			throw std::out_of_range("buffer overflow");
		}
		if(need<1024){
			buffer=(unsigned char *) realloc(buffer, size+1024);
			size+=1024;
		}else{
			buffer=(unsigned char *) realloc(buffer, size+need);
			size+=need;
		}
	}
}


void BufferOutputStream::Reset(){
	offset=0;
}

void BufferOutputStream::Rewind(size_t numBytes){
	if(numBytes>offset)
		throw std::out_of_range("buffer underflow");
	offset-=numBytes;
}
