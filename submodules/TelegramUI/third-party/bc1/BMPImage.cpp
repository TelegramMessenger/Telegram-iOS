//-----------------------------------------------------------------------------
// Copyright (c) 2017 Ricardo David CM (http://ricardo-david.com),
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//-----------------------------------------------------------------------------

#include "BMPImage.h"
#include <iostream>
#include <fstream>

namespace DTX1CompressorDecompressor
{
	BMPImage::BMPImage() : Image()
	{
	}

	BMPImage::BMPImage(const BMPImage & other)
	{
		m_width = other.m_width;
		m_height = other.m_height;
		m_fileHeader = other.m_fileHeader;
		m_bitMapInfoHeader = other.m_bitMapInfoHeader;

		if (other.m_data == nullptr)
			m_data = nullptr;
		else
			std::memcpy(m_data, other.m_data, other.m_bitMapInfoHeader.biSizeImage);
	}

	BMPImage::BMPImage(BMPImage && other) : Image()
	{
		// initializes this with other data, and resets other with the "Image()" default data 
		Swap(*this, other); 
	}

	BMPImage & BMPImage::operator=(BMPImage other)
	{
		// copy and swap idiom 
		// here 'other' is a copy (since has been passed here by value) that is constructed either using the copy constructor or the move constructor, depending if it is an rvalue or a lvalue
		Swap(*this, other);
		return *this;
	}

	void Swap(BMPImage & img1, BMPImage & img2)
	{
		using std::swap;

		swap(img1.m_fileHeader, img2.m_fileHeader);
		swap(img1.m_bitMapInfoHeader, img2.m_bitMapInfoHeader);
		swap(img1.m_width, img2.m_width);
		swap(img1.m_height, img2.m_height);
		swap(img1.m_data, img2.m_data);
	}

	BMPImage::~BMPImage()
	{
	}

	bool BMPImage::InitWithData(unsigned char* data, unsigned int width, unsigned int height)
	{
		// checks for valid data
		if (data == nullptr)
		{
			std::cout << "BMPImage::InitWithData:: data is null !" << std::endl;
			return false;
		}

		// check for image size width and height multiples of 4
		if (width % 4 != 0 || height % 4 != 0)
		{
			std::cout << "BMPImage::InitWithData:: the image is not supported. It needs width and height multiple of 4..." << std::endl;
			return false;
		}

		// we will overwrite previous data contained in this BMPImage instance
		ReleaseImageMemory();

		// take ownership of the data
		m_data = data;
		m_width = width;
		m_height = height;

		// populate headers
		DWORD bothHeadersSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
		DWORD infoHeaderSize = sizeof(BITMAPINFOHEADER);
		DWORD dataSize = 3 * width * height; // 3 bytes per pixel 
		WORD bitCount = 24;
		LONG prefferedResOnX = 3780; // TODO : make this one and the next one as arguments ?
		LONG prefferedResOnY = 3780; 

		m_fileHeader.bfType = BM_FORMAT_TAG;
		m_fileHeader.bfSize = bothHeadersSize + dataSize;
		m_fileHeader.bfReserved1 = 0;
		m_fileHeader.bfReserved2 = 0;
		m_fileHeader.bfOffBits = bothHeadersSize; // header offset to the actual data (both headers sizes = 54 bytes)

		m_bitMapInfoHeader.biSize = infoHeaderSize;
		m_bitMapInfoHeader.biWidth = static_cast<LONG>(width);
		m_bitMapInfoHeader.biHeight = static_cast<LONG>(height);
		m_bitMapInfoHeader.biPlanes = 1;
		m_bitMapInfoHeader.biBitCount = bitCount;
		m_bitMapInfoHeader.biCompression = 0;
		m_bitMapInfoHeader.biSizeImage = dataSize;
		m_bitMapInfoHeader.biXPelsPerMeter = prefferedResOnX;  
		m_bitMapInfoHeader.biYPelsPerMeter = prefferedResOnY; 
		m_bitMapInfoHeader.biClrUsed = 0;
		m_bitMapInfoHeader.biClrImportant = 0;

		return true;
	}

	bool BMPImage::ReadFromFile(const char * fileName)
	{
		std::ifstream imgFile(fileName, std::ifstream::binary);
		
		if (imgFile.is_open())
		{
			// read header bytes
			imgFile.read(reinterpret_cast<char*>(&m_fileHeader), sizeof(m_fileHeader));
			imgFile.read(reinterpret_cast<char*>(&m_bitMapInfoHeader), sizeof(m_bitMapInfoHeader));

			// check the type of file
			if (m_fileHeader.bfType != BM_FORMAT_TAG)
			{
				std::cout << " file was not found to be on BMP format... " << std::endl;
				return false;
			}

			// check for image size width and height multiples of 4
			if (m_bitMapInfoHeader.biWidth % 4 != 0 || m_bitMapInfoHeader.biHeight % 4 != 0)
			{
				std::cout << " the image is not supported. It needs width and height multiple of 4..." << std::endl;
				return false;
			}

			// check for 24 bit bitmaps only
			if (m_bitMapInfoHeader.biBitCount != 24)
			{
				std::cout << " the image is not supported. It needs to be RGB-24 bit (8 bits per pixel) ..." << std::endl;
				return false;
			}
			
			// make sure we delete memory for any previous image we had loaded into this instance
			ReleaseImageMemory();

			// allocate the memory needed for all our data
			m_width = static_cast<unsigned int>(m_bitMapInfoHeader.biWidth);
			m_height = static_cast<unsigned int>(m_bitMapInfoHeader.biHeight);
			
			unsigned int dataByteSize = 3 * m_width * m_height;
			m_data = new unsigned char[dataByteSize];

			// read color data 
			imgFile.read(reinterpret_cast<char*>(m_data), dataByteSize);
		
			// release the file
			imgFile.close();
		}
		else
		{
			std::cout << std::endl <<" cannot read file : " << fileName << std::endl;
			return false;
		}

		return true;
	}

	bool BMPImage::SaveToFile(const char * fileName) 
	{
		if (m_data == nullptr)
			return false;

		std::ofstream imgFile(fileName, std::ifstream::binary);

		if(imgFile.is_open())
		{
			// write headers
			imgFile.write(reinterpret_cast<char*>(&m_fileHeader), sizeof(m_fileHeader));
			imgFile.write(reinterpret_cast<char*>(&m_bitMapInfoHeader), sizeof(m_bitMapInfoHeader));

			// write data
			unsigned int dataByteSize = 3 * m_width * m_height;
			imgFile.write(reinterpret_cast<char*>(m_data), dataByteSize);

			// release file
			imgFile.close();
		}
		else
		{
			std::cout << std::endl << "error creating or opening file : " << fileName << std::endl;
			return false;
		}

		return true;
	}
	
}
