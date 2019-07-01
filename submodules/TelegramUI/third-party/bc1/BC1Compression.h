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

#ifndef RL_BC1_COMPRESSION_H
#define RL_BC1_COMPRESSION_H

#include "TypeDefinitions.h"
#include "BMPImage.h"
#include "DDSImage.h"
#include <vector>

namespace DTX1CompressorDecompressor
{
	// class for handlling BC1 compression of BMP Textures
	class BC1Compression
	{
	public:
		bool Compress(const BMPImage & bmpImage, BC1DDSImage & ddsImage);
		bool DeCompress(const BC1DDSImage & ddsImage, BMPImage & bmpImage);

	private:
		void CompressBlock(const std::vector<Pixel24Bit> & pixelData, unsigned int row, unsigned int col, unsigned int width, unsigned char* ddsDataPtr) const;
		void DeCompressBlock(std::vector<Pixel24Bit> & pixelData, unsigned int row, unsigned int col, unsigned int width, unsigned char* ddsDataPtr) const;

		// a compressed BC1 block is 8 bytes
		const unsigned int m_blockSize = 8;
	};

}

#endif // !RL_BC1_COMPRESSION_H

