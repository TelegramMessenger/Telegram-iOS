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

#ifndef RL_TYPE_DEF_H
#define RL_TYPE_DEF_H

namespace DTX1CompressorDecompressor
{

	// 19778 = 0x4D42 = 'BM' for bitmap format , 0x20534444 = "DDS" for DDS format
	// check https://msdn.microsoft.com/en-us/library/vs/alm/dd183374(v=vs.85).aspx  (BMP)
	// https://msdn.microsoft.com/en-us/library/windows/desktop/bb943991(v=vs.85).aspx (DDS)
	#define BM_FORMAT_TAG 0x4D42  
	#define DDS_FORMAT_TAG 0x20534444

	// DDS flags : https://msdn.microsoft.com/en-us/library/windows/desktop/bb943982(v=vs.85).aspx
	#define DDSD_CAPS 0x1
	#define DDSD_HEIGHT 0x2
	#define DDSD_WIDTH 0x4
	#define DDSD_PIXELFORMAT 0x1000
	#define DDSCAPS_TEXTURE 0x1000

	#define DWRMASK 0xF800
	#define DWGMASK 0x7E0
	#define DWBMASK 0x1F
    
	#define DDPF_FOURCC 0x4
	#define DXT1 0x31545844

	typedef int LONG; // 4 bytes
	typedef unsigned short WORD; // 2 bytes
	typedef unsigned int DWORD; // 4 bytes
	
// this pragma is needed for memory alignment 
// without this the WORDs of the structs below will be padded to 4 bytes, then the structs will be bigger than we want

#pragma pack(2) 

	// Adapted from the Microsoft documentation:
	// https://msdn.microsoft.com/en-us/library/vs/alm/dd183392(v=vs.85).aspx

	// 14 bytes
	struct BITMAPFILEHEADER 
	{
		WORD  bfType;
		DWORD bfSize;
		WORD  bfReserved1;
		WORD  bfReserved2;
		DWORD bfOffBits;
	};

	// 40 bytes
	struct BITMAPINFOHEADER 
	{
		DWORD biSize;
		LONG  biWidth;
		LONG  biHeight;
		WORD  biPlanes;
		WORD  biBitCount;
		DWORD biCompression;
		DWORD biSizeImage;
		LONG  biXPelsPerMeter;
		LONG  biYPelsPerMeter;
		DWORD biClrUsed;
		DWORD biClrImportant;
	};

	// Adapted from the Microsoft documentation:
	// https://msdn.microsoft.com/en-us/library/windows/desktop/bb943984(v=vs.85).aspx
	// https://msdn.microsoft.com/en-us/library/windows/desktop/bb943982(v=vs.85).aspx

	// 32 bytes
	struct DDS_PIXELFORMAT
	{
		DWORD dwSize;
		DWORD dwFlags;
		DWORD dwFourCC;
		DWORD dwRGBBitCount;
		DWORD dwRBitMask;
		DWORD dwGBitMask;
		DWORD dwBBitMask;
		DWORD dwABitMask;
	};

	// 124 bytes 
	struct DDS_HEADER
	{
		DWORD dwSize;
		DWORD dwFlags;
		DWORD dwHeight;
		DWORD dwWidth;
		DWORD dwPitchOrLinearSize;
		DWORD dwDepth;
		DWORD dwMipMapCount;
		DWORD dwReserved1[11];
		DDS_PIXELFORMAT ddspf;
		DWORD dwCaps1;
		DWORD dwCaps2;
		DWORD dwReserved2[3];
	};

#pragma pack() 

}

#endif // !RL_TYPE_DEF_H

