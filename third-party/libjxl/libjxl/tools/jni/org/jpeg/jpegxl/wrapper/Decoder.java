// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package org.jpeg.jpegxl.wrapper;

import java.nio.Buffer;
import java.nio.ByteBuffer;

/** JPEG XL JNI decoder wrapper. */
public class Decoder {
  /** Utility library, disable object construction. */
  private Decoder() {}

  /** One-shot decoding. */
  public static ImageData decode(Buffer data, PixelFormat pixelFormat) {
    StreamInfo basicInfo = DecoderJni.getBasicInfo(data, pixelFormat);
    if (basicInfo.status != Status.OK) {
      throw new IllegalStateException("Decoding failed");
    }
    if (basicInfo.width < 0 || basicInfo.height < 0 || basicInfo.pixelsSize < 0
        || basicInfo.iccSize < 0) {
      throw new IllegalStateException("JNI has returned negative size");
    }
    Buffer pixels = ByteBuffer.allocateDirect(basicInfo.pixelsSize);
    Buffer icc = ByteBuffer.allocateDirect(basicInfo.iccSize);
    Status status = DecoderJni.getPixels(data, pixels, icc, pixelFormat);
    if (status != Status.OK) {
      throw new IllegalStateException("Decoding failed");
    }
    return new ImageData(basicInfo.width, basicInfo.height, pixels, icc, pixelFormat);
  }

  public static StreamInfo decodeInfo(byte[] data) {
    return decodeInfo(ByteBuffer.wrap(data));
  }

  public static StreamInfo decodeInfo(byte[] data, int offset, int length) {
    return decodeInfo(ByteBuffer.wrap(data, offset, length));
  }

  public static StreamInfo decodeInfo(Buffer data) {
    return DecoderJni.getBasicInfo(data, null);
  }
}
