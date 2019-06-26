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

#include "BC1Compression.h"
#include "ColorVec.h"
#include <iostream>
#include <cstring>
#include <climits>

namespace DTX1CompressorDecompressor
{
	bool BC1Compression::Compress(const BMPImage & bmpImage, BC1DDSImage & ddsImage)
	{
		unsigned char* dtaPtr = bmpImage.GetData();
		if (dtaPtr == nullptr)
		{
			return false; // should return an error code
		}

		const unsigned int width = bmpImage.GetWidth();
		const unsigned int height = bmpImage.GetHeight();
		const unsigned int nBlocks = (width / 4) * (height / 4); 

		// reserve memory for the ddsImage
		unsigned char* ddsImageData = new unsigned char[nBlocks * m_blockSize];

		// TODO: this first pass over the image may not be needed, for now we use it as to get things working first
		// here we get data of the bmp image as pixels array
		std::vector<Pixel24Bit> pixelData(width * height);
		for (unsigned int row = 0; row < height; ++row)
		{
			for (unsigned int col = 0; col < width; ++col)
			{
				unsigned int index = (height - 1 - row) * width + col; // image is reversed in rows (upside down), so row = 0 is the bottom of the image
				std::memcpy(&pixelData[index].bgra, dtaPtr, 3);
				dtaPtr += 4;
			}
		}

		// compress all 4x4 blocks of the bmpImage
		unsigned char* ddsDataPtr = ddsImageData;
		for (unsigned int row = 0; row < height; row += 4)
		{
			for (unsigned int col = 0; col < width; col += 4)
			{
				// TODO : potentially we could use multiple threads to compress multiple blocks in parallel
				CompressBlock(pixelData, row, col, width, ddsDataPtr);
				ddsDataPtr += m_blockSize;
			}
		}

		// finialize dds image initialization (headers + data)
		if(!ddsImage.InitWithData(ddsImageData, width, height))
		{
			if(ddsImageData != nullptr)
				delete[] ddsImageData;

			return false; // should return an error code
		}

		return true;
	}

	bool BC1Compression::DeCompress(const BC1DDSImage & ddsImage, BMPImage & bmpImage)
	{
		unsigned char* ddsDataPtr = ddsImage.GetData();
		if (ddsDataPtr == nullptr)
		{
			return false; // should return an error code
		}

		const unsigned int width = ddsImage.GetWidth();
		const unsigned int height = ddsImage.GetHeight();

		// similar to compression we use the aid of a pixel array 										
		std::vector<Pixel24Bit> pixelData(width * height);

		// de-compress all 4x4 blocks of the ddsImage
		for (unsigned int row = 0; row < height; row += 4)
		{
			for (unsigned int col = 0; col < width; col += 4)
			{
				// TODO : potentially we could use multiple threads to de-compress multiple blocks in parallel
				DeCompressBlock(pixelData, row, col, width, ddsDataPtr);
				ddsDataPtr += m_blockSize;
			}
		}

		// copy pixel data to the actual bmp image
		unsigned char* bmpImgData = new unsigned char[4 * width * height];
        memset(bmpImgData, 0xff, 4 * width * height);
		unsigned char* bmpDataPtr = bmpImgData;

		for (unsigned int row = 0; row < height; ++row)
		{
			for (unsigned int col = 0; col < width; ++col)
			{
				unsigned int index = (height - 1 - row) * width + col; // image is reversed in rows (upside down), so row = 0 is the bottom of the image
				std::memcpy(bmpDataPtr, &pixelData[index].bgra, 3);
				bmpDataPtr += 4;
			}
		}

		// finialize bmp image initialization (headers + data)
		if (!bmpImage.InitWithData(bmpImgData, width, height))
		{
			if (bmpImgData != nullptr)
				delete[] bmpImgData;

			return false;
		}

		return true;
	}

	void BC1Compression::CompressBlock(const std::vector<Pixel24Bit> & pixelData, unsigned int row, unsigned int col, unsigned int width, unsigned char* ddsDataPtr) const
	{
		// find the min-max
		int maxVal = -1;
		Pixel24Bit maxColor;

		int minVal = INT_MAX;
		Pixel24Bit minColor;

		for (unsigned int r = row; r < row + 4; ++r)
		{
			for (unsigned int c = col; c < col + 4; ++c)
			{
				unsigned int pixelIndex = r * width + c;
				int l = pixelData[pixelIndex].GetLuminance();

				if (l > maxVal)
				{
					maxColor.SetPixel24Bit(pixelData[pixelIndex]);
					maxVal = l;
				}

				if (l < minVal)
				{
					minColor.SetPixel24Bit(pixelData[pixelIndex]);
					minVal = l;
				}
			}
		}

		// fix the end points colors min and max based on their RGB565 values
		unsigned short minColorRGB565 = minColor.ConvertTo565();
		unsigned short maxColorRGB565 = maxColor.ConvertTo565();
		if (minColorRGB565 > maxColorRGB565)
		{
			std::swap(minColor, maxColor);
			std::swap(minColorRGB565, maxColorRGB565);
		}

		// set the first two colors to compressed block
		std::memcpy(ddsDataPtr, &maxColorRGB565, 2);
		ddsDataPtr += 2;

		std::memcpy(ddsDataPtr, &minColorRGB565, 2);
		ddsDataPtr += 2;

		// fix : min and max colors can be collapsed to the same color! i.e. maxColorRGB565 == minColorRGB565 
		// therefore we use the reverted 24 bit colors for the enconding below
		maxColor.LoadFrom565(maxColorRGB565);
		minColor.LoadFrom565(minColorRGB565);

		// intermediate colors (check BC1 Section on https://msdn.microsoft.com/en-us/library/windows/desktop/bb694531(v=vs.85).aspx)
		Pixel24Bit color2, color3;
		for (unsigned int i = 0; i < 3; ++i)
		{
			color2.bgra[i] = (2 * maxColor.bgra[i] + 1 * minColor.bgra[i]) / 3;
			color3.bgra[i] = (1 * maxColor.bgra[i] + 2 * minColor.bgra[i]) / 3;
		}
		
		// find the closest color for each color and set its offset bit
		unsigned int pixelCount = 0;
		unsigned int encodedOffsets = 0;
		for (unsigned int r = row; r < row + 4; ++r)
		{
			for (unsigned int c = col; c < col + 4; ++c)
			{
				unsigned int pixelIndex = r * width + c;
				
				Pixel24Bit color;
				color.SetPixel24Bit(pixelData[pixelIndex]);

				int minD = color.SqrDistanceTo(maxColor);
				unsigned int offset = 0;

				int d = color.SqrDistanceTo(minColor);
				if (d < minD)
				{
					minD = d;
					offset = 1;
				}
						
				d = color.SqrDistanceTo(color2);
				if (d < minD)
				{
					minD = d;
					offset = 2;
				}

				d = color.SqrDistanceTo(color3);
				if (d < minD)
				{
					minD = d;
					offset = 3;
				}

				// here the offsets are set in a way that the final enconded set of bits are :
				// pixel 16 offset | pixel 15 offset | ....... | pixel 0 offset
				// each offset is 2 bit, the resulting econded offsets is 32bit = 16bit * 2 = 4 bytes
				unsigned int shift = (unsigned int)(pixelCount << 1);
				encodedOffsets |= (offset << shift );
				pixelCount++;
			}
		}

		// write the whole enconded offsets 4 byte word to the compressed block
		std::memcpy(ddsDataPtr, &encodedOffsets, 4);
		ddsDataPtr += 4;
	}

	void BC1Compression::DeCompressBlock(std::vector<Pixel24Bit> & pixelData, unsigned int row, unsigned int col, unsigned int width, unsigned char* ddsDataPtr) const
	{
		// get the first two colors from compressed block
		Pixel24Bit minColor, maxColor;
		
		unsigned short maxColorRGB565;
		std::memcpy(&maxColorRGB565, ddsDataPtr, 2);
		ddsDataPtr += 2;
		maxColor.LoadFrom565(maxColorRGB565);

		unsigned short minColorRGB565;
		std::memcpy(&minColorRGB565, ddsDataPtr, 2);
		ddsDataPtr += 2;
		minColor.LoadFrom565(minColorRGB565);

		// interpolate the other two colors
		Pixel24Bit color2, color3;
		for (unsigned int i = 0; i < 3; ++i)
		{
			color2.bgra[i] = (2 * maxColor.bgra[i] + 1 * minColor.bgra[i]) / 3;
			color3.bgra[i] = (1 * maxColor.bgra[i] + 2 * minColor.bgra[i]) / 3;
		}
		
		// get the encoded offset 
		unsigned int encodedOffsets;
		std::memcpy(&encodedOffsets, ddsDataPtr, 4);
		ddsDataPtr += 4;

		// set for each pixel their color according to the 2bit offset in the compressed block
		for (unsigned int r = row; r < row + 4; ++r)
		{
			for (unsigned int c = col; c < col + 4; ++c)
			{
				unsigned int offset = (encodedOffsets & (unsigned int) 0x03); // the two right hand side bits
				encodedOffsets = encodedOffsets >> 2;
				
				// get the color according to the offset
				Pixel24Bit color;
				if(offset == 0)
					color.SetPixel24Bit(maxColor);

				else if(offset == 1)
					color.SetPixel24Bit(minColor);

				else if(offset == 2)
					color.SetPixel24Bit(color2);
						
				else if(offset == 3)
					color.SetPixel24Bit(color3);

				// set the color
				unsigned int pixelIndex = r * width + c;
				pixelData[pixelIndex].SetPixel24Bit(color);
			}
		}
	}

}
