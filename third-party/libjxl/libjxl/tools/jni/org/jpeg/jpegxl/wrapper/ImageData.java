// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package org.jpeg.jpegxl.wrapper;

import java.nio.Buffer;

/** POJO that contains necessary image data (dimensions, pixels,...). */
public class ImageData {
  final int width;
  final int height;
  final Buffer pixels;
  final Buffer icc;
  final PixelFormat pixelFormat;

  ImageData(int width, int height, Buffer pixels, Buffer icc, PixelFormat pixelFormat) {
    this.width = width;
    this.height = height;
    this.pixels = pixels;
    this.icc = icc;
    this.pixelFormat = pixelFormat;
  }
}
