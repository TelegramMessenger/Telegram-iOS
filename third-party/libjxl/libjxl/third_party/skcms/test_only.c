/*
 * Copyright 2018 Google Inc.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifdef _MSC_VER
    #define _CRT_SECURE_NO_WARNINGS
#endif

#include "skcms.h"
#include "skcms_internal.h"
#include "test_only.h"
#include <stdlib.h>
#include <string.h>

static void print_shortest_float(FILE* fp, float x) {
    char buf[80];
    int digits;
    for (digits = 0; digits < 12; digits++) {
        snprintf(buf, sizeof(buf), "%.*f", digits, x);
        float back;
        if (1 != sscanf(buf, "%f", &back) || back == x) {
            break;
        }
    }

    // We've found the smallest number of digits that roundtrips our float.
    // That'd be the ideal thing to print, but sadly fprintf() rounding is
    // implementation specific, so results vary in the last digit.
    //
    // So we'll print out one _extra_ digit, then chop that off.
    //
    // (0x1.7p-6 == 0x3cb80000 is a good number to test this sort of thing with.)

    int chars = snprintf(buf, sizeof(buf), "%.*f", digits+1, x);
    fprintf(fp, "%.*s", chars-1, buf);
}

static void dump_transform_to_XYZD50(FILE* fp,
                                     const skcms_ICCProfile* profile) {
    // Interpret as RGB_888 if data color space is RGB or GRAY, RGBA_8888 if CMYK.
    skcms_PixelFormat fmt = skcms_PixelFormat_RGB_888;
    size_t npixels = 84;
    if (profile->data_color_space == 0x434D594B/*CMYK*/) {
        fmt = skcms_PixelFormat_RGBA_8888;
        npixels = 63;
    }

    float xyz[252];

    if (!skcms_Transform(
                skcms_252_random_bytes,    fmt, skcms_AlphaFormat_Unpremul, profile,
                xyz, skcms_PixelFormat_RGB_fff, skcms_AlphaFormat_Unpremul, skcms_XYZD50_profile(),
                npixels)) {
        fprintf(fp, "We can parse this profile, but not transform it to XYZD50!\n");
        return;
    }

    fprintf(fp, "252 random bytes transformed to %zu linear XYZD50 pixels:", npixels);
    for (size_t i = 0; i < npixels; i++) {
        if (i % 4 == 0) { fprintf(fp, "\n"); }
        fprintf(fp, "    % .2f % .2f % .2f", xyz[3*i+0], xyz[3*i+1], xyz[3*i+2]);
    }
    fprintf(fp, "\n");

    skcms_ICCProfile dstProfile = *profile;
    if (skcms_MakeUsableAsDestination(&dstProfile)) {
        uint8_t back[252];

        if (!skcms_Transform(
                xyz, skcms_PixelFormat_RGB_fff, skcms_AlphaFormat_Unpremul, skcms_XYZD50_profile(),
                back,                      fmt, skcms_AlphaFormat_Unpremul, &dstProfile,
                npixels)) {
            fprintf(fp, "skcms_MakeUsableAsDestination() was true but skcms_Transform() failed!\n");
            return;
        }

        int max_err = 0;
        for (int i = 0; i < 252; i++) {
            int err = abs((int)back[i] - (int)skcms_252_random_bytes[i]);
            if (max_err < err) {
                max_err = err;
            }
        }

        fprintf(fp, "%d max error transforming back from XYZ:", max_err);
        for (int i = 0; i < 252; i++) {
            if (i % 21 == 0) { fprintf(fp, "\n   "); }
            int err = abs((int)back[i] - (int)skcms_252_random_bytes[i]);
            fprintf(fp, " %3d", err);
        }
        fprintf(fp, "\n");

    }
}

static void dump_transform_to_sRGBA(FILE* fp,
                                    const skcms_ICCProfile* profile) {
    // Let's just transform all combinations of 0x00, 0x7f, and 0xff inputs to 32-bit sRGB.
    // This helps catch issues with alpha, and is mildly interesting on its own.

    uint32_t src[81],
             dst[81];
    for (int i = 0; i < 81; i++) {
        src[i] = (uint32_t)((i/1   % 3) * 127.5f) <<  0
               | (uint32_t)((i/3   % 3) * 127.5f) <<  8
               | (uint32_t)((i/9   % 3) * 127.5f) << 16
               | (uint32_t)((i/27  % 3) * 127.5f) << 24;
    }

    // No matter profile->data_color_space, this should be fine, either RGBA itself or CMYK.
    const skcms_PixelFormat pf = skcms_PixelFormat_RGBA_8888;
    const skcms_AlphaFormat af = skcms_AlphaFormat_Unpremul;

    if (!skcms_Transform(src, pf,af, profile,
                         dst, pf,af, skcms_sRGB_profile(), 81)) {
        fprintf(fp, "We can parse this profile, but not transform it to sRGB!\n");
        return;
    }
    fprintf(fp, "81 edge-case pixels transformed to sRGB 8888 (unpremul):\n");

    for (int i = 0; i < 9; i++) {
        fprintf(fp, "\t%08x %08x %08x  %08x %08x %08x  %08x %08x %08x\n",
                dst[9*i+0], dst[9*i+1], dst[9*i+2],
                dst[9*i+3], dst[9*i+4], dst[9*i+5],
                dst[9*i+6], dst[9*i+7], dst[9*i+8]);
    }
}


static void signature_to_string(uint32_t sig, char* str) {
    str[0] = (char)((sig >> 24) & 0xFF);
    str[1] = (char)((sig >> 16) & 0xFF);
    str[2] = (char)((sig >>  8) & 0xFF);
    str[3] = (char)((sig >>  0) & 0xFF);
    str[4] = 0;
}

static void dump_sig_field(FILE* fp, const char* name, uint32_t val) {
    char valStr[5];
    signature_to_string(val, valStr);
    fprintf(fp, "%20s : 0x%08X : '%s'\n", name, val, valStr);
}

static void dump_transfer_function(FILE* fp, const char* name,
                                   const skcms_TransferFunction* tf, float max_error) {
    fprintf(fp, "%4s : %.7g, %.7g, %.7g, %.7g, %.7g, %.7g, %.7g", name,
            tf->g, tf->a, tf->b, tf->c, tf->d, tf->e, tf->f);

    if (max_error > 0) {
        fprintf(fp, " (Max error: %.6g)", max_error);
    }

    if (tf->d > 0) {
        // Has both linear and nonlinear sections, include the discontinuity at D
        float l_at_d = (tf->c * tf->d + tf->f);
        float n_at_d = powf_(tf->a * tf->d + tf->b, tf->g) + tf->e;
        fprintf(fp, " (D-gap: %.6g)", (n_at_d - l_at_d));
    }

    fprintf(fp, " (f(1) = %.6g)", skcms_TransferFunction_eval(tf, 1.0f));

    skcms_Curve curve;
    curve.table_entries = 0;
    curve.parametric = *tf;

    if (skcms_AreApproximateInverses(&curve, skcms_sRGB_Inverse_TransferFunction())) {
        fprintf(fp, " (~sRGB)");
    } else if (skcms_AreApproximateInverses(&curve, skcms_Identity_TransferFunction())) {
        fprintf(fp, " (~Identity)");
    }
    fprintf(fp, "\n");
}

static void dump_curve(FILE* fp, const char* name, const skcms_Curve* curve) {
    if (curve->table_entries == 0) {
        dump_transfer_function(fp, name, &curve->parametric, 0);
    } else {
        fprintf(fp, "%4s : %d-bit table with %u entries", name,
                curve->table_8 ? 8 : 16, curve->table_entries);
        if (skcms_AreApproximateInverses(curve, skcms_sRGB_Inverse_TransferFunction())) {
            fprintf(fp, " (~sRGB)");
        }
        fprintf(fp, "\n");
        float max_error;
        skcms_TransferFunction tf;
        if (skcms_ApproximateCurve(curve, &tf, &max_error)) {
            dump_transfer_function(fp, "~=", &tf, max_error);
        }
    }
}

void dump_profile(const skcms_ICCProfile* profile, FILE* fp) {
    fprintf(fp, "%20s : 0x%08X : %u\n", "Size", profile->size, profile->size);
    dump_sig_field(fp, "Data color space", profile->data_color_space);
    dump_sig_field(fp, "PCS", profile->pcs);
    fprintf(fp, "%20s : 0x%08X : %u\n", "Tag count", profile->tag_count, profile->tag_count);

    fprintf(fp, "\n");

    fprintf(fp, " Tag    : Type   : Size   : Offset\n");
    fprintf(fp, " ------ : ------ : ------ : --------\n");
    for (uint32_t i = 0; i < profile->tag_count; ++i) {
        skcms_ICCTag tag;
        skcms_GetTagByIndex(profile, i, &tag);
        char tagSig[5];
        char typeSig[5];
        signature_to_string(tag.signature, tagSig);
        signature_to_string(tag.type, typeSig);
        fprintf(fp, " '%s' : '%s' : %6u : %u\n", tagSig, typeSig, tag.size,
                (uint32_t)(tag.buf - profile->buffer));
    }

    fprintf(fp, "\n");

    if (profile->has_trc) {
        const char* trcNames[3] = { "rTRC", "gTRC", "bTRC" };
        for (int i = 0; i < 3; ++i) {
            dump_curve(fp, trcNames[i], &profile->trc[i]);
        }
        if (skcms_TRCs_AreApproximateInverse(profile, skcms_sRGB_Inverse_TransferFunction())) {
            fprintf(fp, "TRCs ≈ sRGB\n");
        }
    }

    skcms_ICCProfile best_single_curve = *profile;
    if (skcms_MakeUsableAsDestinationWithSingleCurve(&best_single_curve)) {
        dump_transfer_function(fp, "Best", &best_single_curve.trc[0].parametric, 0.0f);

        skcms_TransferFunction inv;
        if (skcms_TransferFunction_invert(&best_single_curve.trc[0].parametric, &inv)) {
            dump_transfer_function(fp, "Inv ", &inv, 0.0f);

            fprintf(fp, "Best Error: | %.6g %.6g %.6g |\n",
                skcms_MaxRoundtripError(&profile->trc[0], &inv),
                skcms_MaxRoundtripError(&profile->trc[1], &inv),
                skcms_MaxRoundtripError(&profile->trc[2], &inv));
        } else {
            fprintf(fp, "*** could not invert Best ***\n");
        }
    }

    if (profile->has_toXYZD50) {
        skcms_Matrix3x3 toXYZ = profile->toXYZD50;

        fprintf(fp, " XYZ : | ");
        print_shortest_float(fp, toXYZ.vals[0][0]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[0][1]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[0][2]); fprintf(fp, " |\n");

        fprintf(fp, "       | ");
        print_shortest_float(fp, toXYZ.vals[1][0]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[1][1]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[1][2]); fprintf(fp, " |\n");

        fprintf(fp, "       | ");
        print_shortest_float(fp, toXYZ.vals[2][0]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[2][1]); fprintf(fp, " ");
        print_shortest_float(fp, toXYZ.vals[2][2]); fprintf(fp, " |\n");

        float white_x = toXYZ.vals[0][0] + toXYZ.vals[0][1] + toXYZ.vals[0][2],
              white_y = toXYZ.vals[1][0] + toXYZ.vals[1][1] + toXYZ.vals[1][2],
              white_z = toXYZ.vals[2][0] + toXYZ.vals[2][1] + toXYZ.vals[2][2];
        if (fabsf_(white_x - 0.964f) > 0.01f ||
            fabsf_(white_y - 1.000f) > 0.01f ||
            fabsf_(white_z - 0.825f) > 0.01f) {
            fprintf(fp, " !!! This does not appear to use a D50 whitepoint, rather [%g %g %g]\n",
                    white_x, white_y, white_z);
        }
    }

    if (profile->has_A2B) {
        const skcms_A2B* a2b = &profile->A2B;
        fprintf(fp, " A2B : %s%s\"B\"\n", a2b-> input_channels ? "\"A\", CLUT, "   : ""
                                        , a2b->matrix_channels ? "\"M\", Matrix, " : "");
        if (a2b->input_channels) {
            fprintf(fp, "%4s : %u inputs\n", "\"A\"", a2b->input_channels);
            const char* curveNames[4] = { "A0", "A1", "A2", "A3" };
            for (uint32_t i = 0; i < a2b->input_channels; ++i) {
                dump_curve(fp, curveNames[i], &a2b->input_curves[i]);
            }
            fprintf(fp, "%4s : ", "CLUT");
            const char* sep = "";
            for (uint32_t i = 0; i < a2b->input_channels; ++i) {
                fprintf(fp, "%s%u", sep, a2b->grid_points[i]);
                sep = " x ";
            }
            fprintf(fp, " (%d bpp)\n", a2b->grid_8 ? 8 : 16);
        }

        if (a2b->matrix_channels) {
            fprintf(fp, "%4s : %u inputs\n", "\"M\"", a2b->matrix_channels);
            const char* curveNames[4] = { "M0", "M1", "M2" };
            for (uint32_t i = 0; i < a2b->matrix_channels; ++i) {
                dump_curve(fp, curveNames[i], &a2b->matrix_curves[i]);
            }
            const skcms_Matrix3x4* m = &a2b->matrix;
            fprintf(fp, "Mtrx : | ");
            print_shortest_float(fp, m->vals[0][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][3]); fprintf(fp, " |\n");
            fprintf(fp, "       | ");
            print_shortest_float(fp, m->vals[1][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][3]); fprintf(fp, " |\n");
            fprintf(fp, "       | ");
            print_shortest_float(fp, m->vals[2][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][3]); fprintf(fp, " |\n");
        }

        {
            fprintf(fp, "%4s : %u outputs\n", "\"B\"", a2b->output_channels);
            const char* curveNames[3] = { "B0", "B1", "B2" };
            for (uint32_t i = 0; i < a2b->output_channels; ++i) {
                dump_curve(fp, curveNames[i], &a2b->output_curves[i]);
            }
        }
    }

    if (profile->has_B2A) {
        const skcms_B2A* b2a = &profile->B2A;
        fprintf(fp, " B2A : \"B\"%s%s\n", b2a->matrix_channels ? ", Matrix, \"M\"" : ""
                                        , b2a->output_channels ? ", CLUT, \"A\""   : "");

        {
            fprintf(fp, "%4s : %u inputs\n", "\"B\"", b2a->input_channels);
            const char* curveNames[3] = { "B0", "B1", "B2" };
            for (uint32_t i = 0; i < b2a->input_channels; ++i) {
                dump_curve(fp, curveNames[i], &b2a->input_curves[i]);
            }
        }

        if (b2a->matrix_channels) {
            const skcms_Matrix3x4* m = &b2a->matrix;
            fprintf(fp, "Mtrx : | ");
            print_shortest_float(fp, m->vals[0][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[0][3]); fprintf(fp, " |\n");
            fprintf(fp, "       | ");
            print_shortest_float(fp, m->vals[1][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[1][3]); fprintf(fp, " |\n");
            fprintf(fp, "       | ");
            print_shortest_float(fp, m->vals[2][0]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][1]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][2]); fprintf(fp, " ");
            print_shortest_float(fp, m->vals[2][3]); fprintf(fp, " |\n");
            fprintf(fp, "%4s : %u inputs\n", "\"M\"", b2a->matrix_channels);
            const char* curveNames[4] = { "M0", "M1", "M2" };
            for (uint32_t i = 0; i < b2a->matrix_channels; ++i) {
                dump_curve(fp, curveNames[i], &b2a->matrix_curves[i]);
            }
        }

        if (b2a->output_channels) {
            fprintf(fp, "%4s : ", "CLUT");
            const char* sep = "";
            for (uint32_t i = 0; i < b2a->input_channels; ++i) {
                fprintf(fp, "%s%u", sep, b2a->grid_points[i]);
                sep = " x ";
            }
            fprintf(fp, " (%d bpp)\n", b2a->grid_8 ? 8 : 16);
            fprintf(fp, "%4s : %u outputs\n", "\"A\"", b2a->output_channels);
            const char* curveNames[4] = { "A0", "A1", "A2", "A3" };
            for (uint32_t i = 0; i < b2a->output_channels; ++i) {
                dump_curve(fp, curveNames[i], &b2a->output_curves[i]);
            }
        }
    }

    skcms_Matrix3x3 chad;
    if (skcms_GetCHAD(profile, &chad)) {
        fprintf(fp, "CHAD : | ");
        print_shortest_float(fp, chad.vals[0][0]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[0][1]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[0][2]); fprintf(fp, " |\n");

        fprintf(fp, "       | ");
        print_shortest_float(fp, chad.vals[1][0]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[1][1]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[1][2]); fprintf(fp, " |\n");

        fprintf(fp, "       | ");
        print_shortest_float(fp, chad.vals[2][0]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[2][1]); fprintf(fp, " ");
        print_shortest_float(fp, chad.vals[2][2]); fprintf(fp, " |\n");
    }

    float wtpt[3];
    if (skcms_GetWTPT(profile, wtpt)) {
        fprintf(fp, "WTPT : | ");
        print_shortest_float(fp, wtpt[0]); fprintf(fp, " ");
        print_shortest_float(fp, wtpt[1]); fprintf(fp, " ");
        print_shortest_float(fp, wtpt[2]); fprintf(fp, " |\n");
    }

    if (profile->has_CICP) {
        fprintf(fp, "CICP : CP: %u TF: %u MC: %u FR: %u\n",
                profile->CICP.color_primaries, profile->CICP.transfer_characteristics,
                profile->CICP.matrix_coefficients, profile->CICP.video_full_range_flag);
    }

    dump_transform_to_XYZD50(fp, profile);
    dump_transform_to_sRGBA (fp, profile);
    if (skcms_ApproximatelyEqualProfiles(profile, skcms_sRGB_profile())) {
        fprintf(fp, "This profile ≈ sRGB.\n");
    }
}

bool load_file_fp(FILE* fp, void** buf, size_t* len) {
    if (fseek(fp, 0L, SEEK_END) != 0) {
        return false;
    }
    long size = ftell(fp);
    if (size <= 0) {
        return false;
    }
    *len = (size_t)size;
    rewind(fp);

    *buf = malloc(*len);
    if (!*buf) {
        return false;
    }

    if (fread(*buf, 1, *len, fp) != *len) {
        free(*buf);
        return false;
    }
    return true;
}

bool load_file(const char* filename, void** buf, size_t* len) {
    FILE* fp = fopen(filename, "rb");
    if (!fp) {
        return false;
    }
    bool result = load_file_fp(fp, buf, len);
    fclose(fp);
    return result;
}

bool write_file(const char* filename, void* buf, size_t len) {
    FILE* fp = fopen(filename, "wb");
    if (!fp) {
        return false;
    }
    bool result = (fwrite(buf, 1, len, fp) == len);
    fclose(fp);
    return result;
}
