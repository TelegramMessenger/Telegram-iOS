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

#ifndef RL_BMP_IMAGE_H
#define RL_BMP_IMAGE_H

#include "Image.h"

namespace DTX1CompressorDecompressor
{
	// class for loading and handling BMP images
	class BMPImage : public Image
	{
	public:
		BMPImage();
		BMPImage(const BMPImage & other);
		BMPImage(BMPImage && other);
		BMPImage& operator=(BMPImage other);
		friend void Swap(BMPImage & img1, BMPImage & img2);
		~BMPImage();
		

		// a initalizator with data loaded from other sources (for example, from a decompressed DDS image), 
		// if color data in this image instance is already set, it will be ovewritten
		// this instance will take ownership of the data
		bool InitWithData(unsigned char* data, unsigned int width, unsigned int height);

		// populates the headers and the color data (if color data is already set, it will be ovewritten with the data of the file being loaded)
		bool ReadFromFile(const char* fileName);
		
		// saves this data to disc ( will create a BMP image : fileName.bmp )
		bool SaveToFile(const char* fileName);

	private:
		BITMAPFILEHEADER m_fileHeader;
		BITMAPINFOHEADER m_bitMapInfoHeader;
	};
}

#endif // !BMP_ IMAGE_H
