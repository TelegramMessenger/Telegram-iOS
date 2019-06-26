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

#ifndef RL_IMAGE_H
#define RL_IMAGE_H

#include "TypeDefinitions.h"
#include "ColorVec.h"

namespace DTX1CompressorDecompressor
{
	// base class for all images
	class Image
	{
	public:
		virtual ~Image();
		
		// frees the image data if any
		void ReleaseImageMemory();

		// a initalizator with data loaded from other sources
		virtual bool InitWithData(unsigned char* data, unsigned int width, unsigned int height) = 0;

		// initializator from file 
		virtual bool ReadFromFile(const char* fileName) = 0;

		// saves the image to disc
		virtual bool SaveToFile(const char* fileName) = 0;

		// gets the width in pixels of the loaded image
		inline unsigned int GetWidth() const
		{
			return m_width;
		}

		// gets the height in pixels of the loaded image
		inline unsigned int GetHeight() const
		{
			return m_height;
		}

		// gets the data pointer
		inline unsigned char* GetData() const
		{
			return m_data;
		}

	public:
		Image() : m_data(nullptr), m_width(0), m_height(0) {};

        bool m_ownData;
		unsigned char* m_data;
		unsigned int m_width;
		unsigned int m_height;
	};

}


#endif // !RL_IMAGE_H
