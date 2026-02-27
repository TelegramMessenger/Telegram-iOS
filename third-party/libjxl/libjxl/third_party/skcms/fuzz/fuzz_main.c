/*
 * Copyright 2018 Google Inc.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// This main() can be used to run libfuzzer targets as standalone binaries.

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const uint8_t*, size_t);

int main(int argc, char** argv) {
    if (argc != 2) {
        printf("usage: %s <ICC filename>\n", argv[0]);
        return 1;
    }
    FILE* fp = fopen(argv[1], "rb");
    if (!fp) {
        printf("Unable to open input file");
        return 1;
    }
    fseek(fp, 0L, SEEK_END);
    long slen = ftell(fp);
    if (slen <= 0) {
        printf("ftell failed");
        return 1;
    }
    size_t len = (size_t)slen;
    rewind(fp);
    void* data = malloc(len);
    if (!data) {
        return 1;
    }
    size_t size = fread(data, 1, len, fp);
    fclose(fp);
    if (size != len) {
        printf("Unable to read file");
        return 1;
    }

    return LLVMFuzzerTestOneInput(data, size);
}
