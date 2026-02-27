/*
 * Copyright 2018 Google Inc.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// This fuzz target parses an ICCProfile and then queries several pieces
// of info from it.

#include "../skcms.h"
#include "../skcms_internal.h"

static volatile uint32_t g_FoolTheOptimizer = 0;

// Read the first and last byte of any tables present in the curve
static uint32_t read_table_extents(const skcms_Curve* c) {
    uint32_t x = 0;
    if (c->table_entries) {
        if (c->table_8) {
            x += c->table_8[0] + c->table_8[c->table_entries - 1];
        }
        if (c->table_16) {
            x += c->table_16[0] + c->table_16[2 * c->table_entries - 1];
        }
    }
    return x;
}

int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size);
int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    skcms_ICCProfile p;
    if (!skcms_Parse(data, size, &p)) {
        return 0;
    }

    // Instead of testing all tags, just test that we can read the first and last.
    // This does _not_ imply all the middle will work fine, but these calls should
    // be enough for the fuzzer to find a way to break us.
    if (p.tag_count > 0) {
        skcms_ICCTag tag;
        skcms_GetTagByIndex(&p,               0, &tag);
        skcms_GetTagByIndex(&p, p.tag_count - 1, &tag);
    }

    // For TRC tables, test that we can read the first and last entries of each table.
    if (p.has_trc) {
        for (int i = 0; i < 3; ++i) {
            g_FoolTheOptimizer += read_table_extents(&p.trc[i]);
        }
    }

    // For A2B data, test that we can read the first and last entries of each table.
    if (p.has_A2B) {
        uint32_t x = 0;

        for (uint32_t i = 0; i < p.A2B.input_channels; ++i) {
            x += read_table_extents(&p.A2B.input_curves[i]);
        }

        if (p.A2B.input_channels) {
            uint64_t grid_size = p.A2B.output_channels;
            for (uint32_t i = 0; i < p.A2B.input_channels; ++i) {
                grid_size *= p.A2B.grid_points[i];
            }

            if (p.A2B.grid_8) {
                x += p.A2B.grid_8[0] + p.A2B.grid_8[grid_size - 1];
            }

            if (p.A2B.grid_16) {
                x += p.A2B.grid_16[0] + p.A2B.grid_16[2 * grid_size - 1];
            }
        }

        for (uint32_t i = 0; i < p.A2B.output_channels; ++i) {
            x += read_table_extents(&p.A2B.matrix_curves[i]);
        }

        for (uint32_t i = 0; i < p.A2B.output_channels; ++i) {
            x += read_table_extents(&p.A2B.output_curves[i]);
        }

        g_FoolTheOptimizer = x;
    }

    return 0;
}
