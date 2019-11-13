//
//  ASHashing.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASHashing.h>

#define ELF_STEP(B) T1 = (H << 4) + B; T2 = T1 & 0xF0000000; if (T2) T1 ^= (T2 >> 24); T1 &= (~T2); H = T1;

/**
 * The hashing algorithm copied from CoreFoundation CFHashBytes function.
 * https://opensource.apple.com/source/CF/CF-1153.18/CFUtilities.c.auto.html
 */
NSUInteger ASHashBytes(void *bytesarg, size_t length) {
  /* The ELF hash algorithm, used in the ELF object file format */
  uint8_t *bytes = (uint8_t *)bytesarg;
  UInt32 H = 0, T1, T2;
  SInt32 rem = (SInt32)length;
  while (3 < rem) {
    ELF_STEP(bytes[length - rem]);
    ELF_STEP(bytes[length - rem + 1]);
    ELF_STEP(bytes[length - rem + 2]);
    ELF_STEP(bytes[length - rem + 3]);
    rem -= 4;
  }
  switch (rem) {
    case 3:  ELF_STEP(bytes[length - 3]);
    case 2:  ELF_STEP(bytes[length - 2]);
    case 1:  ELF_STEP(bytes[length - 1]);
    case 0:  ;
  }
  return H;
}

#undef ELF_STEP
