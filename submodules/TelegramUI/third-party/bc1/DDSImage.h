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

#ifndef RL_DDS_IMAGE_H
#define RL_DDS_IMAGE_H

#include "Image.h" 

namespace DTX1CompressorDecompressor
{
	// class for loading and handling BC1 DDS images
	class BC1DDSImage : public Image
	{
	public:
		BC1DDSImage();
		BC1DDSImage(const BC1DDSImage & other);
		BC1DDSImage(BC1DDSImage && other);
		BC1DDSImage& operator=(BC1DDSImage other);
		friend void Swap(BC1DDSImage & img1, BC1DDSImage & img2);
		~BC1DDSImage();

		// Image interface implementation
		bool InitWithData(unsigned char* data, unsigned int width, unsigned int height);
		bool ReadFromFile(const char* fileName);
		bool SaveToFile(const char* fileName);

	private:
		DWORD m_dwMagic;
		DDS_HEADER m_header;
	};
}
#endif