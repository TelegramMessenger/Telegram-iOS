// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package org.jpeg.jpegxl.wrapper;

/** POJO that wraps some fields of JxlBasicInfo. */
public class StreamInfo {
  public Status status;
  public int width;
  public int height;
  public int alphaBits;

  // package-private
  int pixelsSize;
  int iccSize;
}
