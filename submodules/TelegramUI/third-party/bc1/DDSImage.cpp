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

#include "DDSImage.h"
#include <iostream>
#include <algorithm>
#include <fstream>

namespace DTX1CompressorDecompressor
{
	BC1DDSImage::BC1DDSImage() : Image()
	{
	}

	BC1DDSImage::BC1DDSImage(const BC1DDSImage & other)
	{
		m_width = other.m_width;
		m_height = other.m_height;
		m_header = other.m_header;
		m_dwMagic = other.m_dwMagic;

		if (other.m_data == nullptr)
			m_data = nullptr;
		else
		{
			unsigned int nBlocks = (m_width / 4) * (m_height / 4);
			unsigned int blockSize = 8;
			unsigned int dataByteSize = nBlocks * blockSize;
			std::memcpy(m_data, other.m_data, dataByteSize);
		}
	}

	BC1DDSImage::BC1DDSImage(BC1DDSImage && other) : Image()
	{
		Swap(*this, other);
	}

	BC1DDSImage & BC1DDSImage::operator=(BC1DDSImage other)
	{
		Swap(*this, other);
		return *this;
	}

	void Swap(BC1DDSImage & img1, BC1DDSImage & img2)
	{
		using std::swap;

		swap(img1.m_dwMagic, img2.m_dwMagic);
		swap(img1.m_header, img2.m_header);
		swap(img1.m_width, img2.m_width);
		swap(img1.m_height, img2.m_height);
		swap(img1.m_data, img2.m_data);
	}

	BC1DDSImage::~BC1DDSImage()
	{
	}

	bool BC1DDSImage::InitWithData(unsigned char * data, unsigned int width, unsigned int height)
	{
		// checks for valid data
		if (data == nullptr)
		{
			std::cout << "BC1DDSImage::InitWithData:: data is null !" << std::endl;
			return false;
		}

		// check for image size width and height multiples of 4
		if (width % 4 != 0 || height % 4 != 0)
		{
			std::cout << "BC1DDSImage::InitWithData:: the image is not supported. It needs width and height multiple of 4..." << std::endl;
			return false;
		}

		// we will overwrite previous data contained in this BMPImage instance
		ReleaseImageMemory();

		// take ownership of the data
		m_data = data;
		m_width = width;
		m_height = height;

		// populate headers
		DWORD sizeOfHeader = sizeof(DDS_HEADER);
		DWORD sizeOfPixelFormat = sizeof(DDS_PIXELFORMAT);
		DWORD blockSize = 8; // 8 bytes

		m_dwMagic = DDS_FORMAT_TAG;

		m_header.dwSize = sizeOfHeader;
		m_header.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT;
		m_header.dwHeight = height;
		m_header.dwWidth = width;
		m_header.dwPitchOrLinearSize = 0;
		m_header.dwDepth = 0;
		m_header.dwMipMapCount = 0;
		m_header.dwCaps1 = DDSCAPS_TEXTURE;
		m_header.dwCaps2 = 0;

		m_header.ddspf.dwSize = sizeOfPixelFormat;
		m_header.ddspf.dwFlags = DDPF_FOURCC;
		m_header.ddspf.dwFourCC = DXT1;
		m_header.ddspf.dwRGBBitCount = 0;
		m_header.ddspf.dwRBitMask = 0;
		m_header.ddspf.dwGBitMask = 0;
		m_header.ddspf.dwBBitMask = 0;
		m_header.ddspf.dwABitMask = 0;
		
		return true;
	}

	bool BC1DDSImage::ReadFromFile(const char * fileName)
	{
		std::ifstream imgFile(fileName, std::ifstream::binary);

		if (imgFile.is_open())
		{
			// read magic number to DDS FORMAT
			imgFile.read(reinterpret_cast<char*>(&m_dwMagic), sizeof(m_dwMagic));

			if (m_dwMagic != DDS_FORMAT_TAG)
			{
				std::cout << " file was not found to be a valid DDS image... " << std::endl;
				return false;
			}

			// read header
			imgFile.read(reinterpret_cast<char*>(&m_header), sizeof(m_header));

			// check is DTX1
			if (m_header.ddspf.dwFlags != DDPF_FOURCC || m_header.ddspf.dwFourCC != DXT1)
			{
				std::cout << " the image is not a valid DXT1 image file ..." << std::endl;
				return false;
			}

			// check for image size width and height multiples of 4
			if (m_header.dwHeight % 4 != 0 || m_header.dwWidth % 4 != 0)
			{
				std::cout << " the image is not supported. It needs width and height multiple of 4..." << std::endl;
				return false;
			}

			// make sure we delete memory for any previous image we had loaded into this instance
			ReleaseImageMemory();

			// allocate the memory needed for all our data
			m_width = static_cast<unsigned int>(m_header.dwWidth);
			m_height = static_cast<unsigned int>(m_header.dwHeight);

			unsigned int nBlocks = (m_width / 4) * (m_height / 4);
			unsigned int blockSize = 8;
			unsigned int dataByteSize = nBlocks * blockSize;

			m_data = new unsigned char[dataByteSize];

			// read color data 
			imgFile.read(reinterpret_cast<char*>(m_data), dataByteSize);

			// release the file
			imgFile.close();
		}
		else
		{
			std::cout << std::endl << " cannot read file : " << fileName << std::endl;
			return false;
		}

		return true;
	}

	bool BC1DDSImage::SaveToFile(const char * fileName)
	{
		if (m_data == nullptr)
			return false;

		std::ofstream imgFile(fileName, std::ifstream::binary);

		if (imgFile.is_open())
		{
			// write headers
			imgFile.write(reinterpret_cast<char*>(&m_dwMagic), sizeof(m_dwMagic));
			imgFile.write(reinterpret_cast<char*>(&m_header), sizeof(m_header));

			// write data
			unsigned int nBlocks = (m_width / 4) * (m_height / 4);
			unsigned int blockSize = 8;
			unsigned int dataByteSize = nBlocks * blockSize;

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