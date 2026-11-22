// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package org.jpeg.jpegxl.wrapper;

import java.nio.Buffer;

/**
 * Low level JNI wrapper.
 *
 * This class is package-private, should be only be used by high level wrapper.
 */
class DecoderJni {
  private static native void nativeGetBasicInfo(int[] context, Buffer data);
  private static native void nativeGetPixels(int[] context, Buffer data, Buffer pixels, Buffer icc);

  static Status makeStatus(int statusCode) {
    switch (statusCode) {
      case 0:
        return Status.OK;
      case -1:
        return Status.INVALID_STREAM;
      case 1:
        return Status.NOT_ENOUGH_INPUT;
      default:
        throw new IllegalStateException("Unknown status code");
    }
  }

  static StreamInfo makeStreamInfo(int[] context) {
    StreamInfo result = new StreamInfo();
    result.status = makeStatus(context[0]);
    result.width = context[1];
    result.height = context[2];
    result.pixelsSize = context[3];
    result.iccSize = context[4];
    result.alphaBits = context[5];
    return result;
  }

  /** Decode stream information. */
  static StreamInfo getBasicInfo(Buffer data, PixelFormat pixelFormat) {
    if (!data.isDirect()) {
      throw new IllegalArgumentException("data must be direct buffer");
    }
    int[] context = new int[6];
    context[0] = (pixelFormat == null) ? -1 : pixelFormat.ordinal();
    nativeGetBasicInfo(context, data);
    return makeStreamInfo(context);
  }

  /** One-shot decoding. */
  static Status getPixels(Buffer data, Buffer pixels, Buffer icc, PixelFormat pixelFormat) {
    if (!data.isDirect()) {
      throw new IllegalArgumentException("data must be direct buffer");
    }
    if (!pixels.isDirect()) {
      throw new IllegalArgumentException("pixels must be direct buffer");
    }
    if (!icc.isDirect()) {
      throw new IllegalArgumentException("icc must be direct buffer");
    }
    int[] context = new int[1];
    context[0] = pixelFormat.ordinal();
    nativeGetPixels(context, data, pixels, icc);
    return makeStatus(context[0]);
  }

  /** Utility library, disable object construction. */
  private DecoderJni() {}
}
