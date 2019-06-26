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

#ifndef RL_COLOR_VEC_H
#define RL_COLOR_VEC_H

#include "TypeDefinitions.h"
#include <iostream>

namespace DTX1CompressorDecompressor
{
    const unsigned short RED_MASK = DWRMASK;
	const unsigned short GREEN_MASK = DWGMASK;
	const unsigned short BLUE_MASK = DWBMASK;

	// structure to represent a pixel
	// 3 bytes = 24 bits per pixel (but is going to be padded to 4 bytes anyway so we make it explicit)
	struct Pixel24Bit
	{
		unsigned char bgra[4]; // 4 to make explicit the padding

		Pixel24Bit()
		{
			bgra[0] = 0;
			bgra[1] = 0;
			bgra[2] = 0;
			bgra[3] = 0;
		}

		void SetPixel24Bit(const Pixel24Bit & other)
		{
			bgra[0] = other.bgra[0];
			bgra[1] = other.bgra[1];
			bgra[2] = other.bgra[2];
			bgra[3] = 0;
		}

		const int SqrDistanceTo(const Pixel24Bit & other) const
		{
			int db = (bgra[0] - other.bgra[0]);
			int dg = (bgra[1] - other.bgra[1]);
			int dr = (bgra[2] - other.bgra[2]);
			return db*db + dg*dg + dr*dr;
		}

		const int GetLuminance() const
		{
			return (bgra[2] + bgra[1] * 2 + bgra[0]);
		}

		unsigned short ConvertTo565() 
		{
			// Adapted from : 
			// https://msdn.microsoft.com/en-us/library/windows/desktop/dd390989(v=vs.85).aspx

			return ((bgra[2] >> 3) << 11) | ((bgra[1] >> 2) << 5) | (bgra[0] >>	3);
		}

		void LoadFrom565(unsigned short rgb)
		{
			// Adapted from : 
			// https://msdn.microsoft.com/en-us/library/windows/desktop/dd390989(v=vs.85).aspx

			unsigned char redVal = ((rgb & RED_MASK) >> 11) << 3;
			unsigned char greenVal = ((rgb & GREEN_MASK) >> 5) << 2;
			unsigned char blueVal = (rgb & BLUE_MASK) << 3;

			bgra[0] = blueVal;
			bgra[1] = greenVal;
			bgra[2] = redVal;
			bgra[3] = 0;
		}

		void PrintColor() const
		{
			std::cout << "(B,G,R) = (" << (int)bgra[0] << ", " << (int)bgra[1] << " , " << (int)bgra[2] << ");" << std::endl;
		}
	};

}


#endif // !RL_COLOR_VEC_H

