#if defined(__SSE2__)

#include "vdrawhelper.h"

#include <emmintrin.h> /* for SSE2 intrinsics */
#include <xmmintrin.h> /* for _mm_shuffle_pi16 and _MM_SHUFFLE */

// Each 32bits components of alphaChannel must be in the form 0x00AA00AA
inline static __m128i v4_byte_mul_sse2(__m128i c, __m128i a)
{
    const __m128i ag_mask = _mm_set1_epi32(0xFF00FF00);
    const __m128i rb_mask = _mm_set1_epi32(0x00FF00FF);

    /* for AG */
    __m128i v_ag = _mm_and_si128(ag_mask, c);
    v_ag = _mm_srli_epi32(v_ag, 8);
    v_ag = _mm_mullo_epi16(a, v_ag);
    v_ag = _mm_and_si128(ag_mask, v_ag);

    /* for RB */
    __m128i v_rb = _mm_and_si128(rb_mask, c);
    v_rb = _mm_mullo_epi16(a, v_rb);
    v_rb = _mm_srli_epi32(v_rb, 8);
    v_rb = _mm_and_si128(rb_mask, v_rb);

    /* combine */
    return _mm_add_epi32(v_ag, v_rb);
}

static inline __m128i v4_ialpha_sse2(__m128i c)
{
    __m128i a = _mm_srli_epi32(c, 24);

    return _mm_sub_epi32(_mm_set1_epi32(0xff), a);
}

static inline __m128i v4_interpolate_color_sse2(__m128i a, __m128i c0,
                                                __m128i c1)
{
    const __m128i rb_mask = _mm_set1_epi32(0xFF00FF00);
    const __m128i zero = _mm_setzero_si128();

    __m128i a_l = a;
    __m128i a_h = a;
    a_l = _mm_unpacklo_epi16(a_l, a_l);
    a_h = _mm_unpackhi_epi16(a_h, a_h);

    __m128i a_t = _mm_slli_epi64(a_l, 32);
    __m128i a_t0 = _mm_slli_epi64(a_h, 32);

    a_l = _mm_add_epi32(a_l, a_t);
    a_h = _mm_add_epi32(a_h, a_t0);

    __m128i c0_l = c0;
    __m128i c0_h = c0;

    c0_l = _mm_unpacklo_epi8(c0_l, zero);
    c0_h = _mm_unpackhi_epi8(c0_h, zero);

    __m128i c1_l = c1;
    __m128i c1_h = c1;

    c1_l = _mm_unpacklo_epi8(c1_l, zero);
    c1_h = _mm_unpackhi_epi8(c1_h, zero);

    __m128i cl_sub = _mm_sub_epi16(c0_l, c1_l);
    __m128i ch_sub = _mm_sub_epi16(c0_h, c1_h);

    cl_sub = _mm_mullo_epi16(cl_sub, a_l);
    ch_sub = _mm_mullo_epi16(ch_sub, a_h);

    __m128i c1ls = _mm_slli_epi16(c1_l, 8);
    __m128i c1hs = _mm_slli_epi16(c1_h, 8);

    cl_sub = _mm_add_epi16(cl_sub, c1ls);
    ch_sub = _mm_add_epi16(ch_sub, c1hs);

    cl_sub = _mm_and_si128(cl_sub, rb_mask);
    ch_sub = _mm_and_si128(ch_sub, rb_mask);

    cl_sub = _mm_srli_epi64(cl_sub, 8);
    ch_sub = _mm_srli_epi64(ch_sub, 8);

    cl_sub = _mm_packus_epi16(cl_sub, cl_sub);
    ch_sub = _mm_packus_epi16(ch_sub, ch_sub);

    return (__m128i)_mm_shuffle_ps((__m128)cl_sub, (__m128)ch_sub, 0x44);
}

// Load src and dest vector
#define V4_FETCH_SRC_DEST                           \
    __m128i v_src = _mm_loadu_si128((__m128i*)src); \
    __m128i v_dest = _mm_load_si128((__m128i*)dest);

#define V4_FETCH_SRC __m128i v_src = _mm_loadu_si128((__m128i*)src);

#define V4_STORE_DEST _mm_store_si128((__m128i*)dest, v_src);

#define V4_SRC_DEST_LEN_INC \
    dest += 4;              \
    src += 4;               \
    length -= 4;

// Multiply src color with const_alpha
#define V4_ALPHA_MULTIPLY v_src = v4_byte_mul_sse2(v_src, v_alpha);

// dest = src + dest * sia
#define V4_COMP_OP_SRC_OVER                                  \
    __m128i v_sia = v4_ialpha_sse2(v_src);                   \
    v_sia = _mm_add_epi32(v_sia, _mm_slli_epi32(v_sia, 16)); \
    v_dest = v4_byte_mul_sse2(v_dest, v_sia);                \
    v_src = _mm_add_epi32(v_src, v_dest);

// dest = src + dest * sia
#define V4_COMP_OP_SRC \
    v_src = v4_interpolate_color_sse2(v_alpha, v_src, v_dest);

void memfill32(uint32_t* dest, uint32_t value, int length)
{
    __m128i vector_data = _mm_set_epi32(value, value, value, value);

    // run till memory alligned to 16byte memory
    while (length && ((uintptr_t)dest & 0xf)) {
        *dest++ = value;
        length--;
    }

    while (length >= 32) {
        _mm_store_si128((__m128i*)(dest), vector_data);
        _mm_store_si128((__m128i*)(dest + 4), vector_data);
        _mm_store_si128((__m128i*)(dest + 8), vector_data);
        _mm_store_si128((__m128i*)(dest + 12), vector_data);
        _mm_store_si128((__m128i*)(dest + 16), vector_data);
        _mm_store_si128((__m128i*)(dest + 20), vector_data);
        _mm_store_si128((__m128i*)(dest + 24), vector_data);
        _mm_store_si128((__m128i*)(dest + 28), vector_data);

        dest += 32;
        length -= 32;
    }

    if (length >= 16) {
        _mm_store_si128((__m128i*)(dest), vector_data);
        _mm_store_si128((__m128i*)(dest + 4), vector_data);
        _mm_store_si128((__m128i*)(dest + 8), vector_data);
        _mm_store_si128((__m128i*)(dest + 12), vector_data);

        dest += 16;
        length -= 16;
    }

    if (length >= 8) {
        _mm_store_si128((__m128i*)(dest), vector_data);
        _mm_store_si128((__m128i*)(dest + 4), vector_data);

        dest += 8;
        length -= 8;
    }

    if (length >= 4) {
        _mm_store_si128((__m128i*)(dest), vector_data);

        dest += 4;
        length -= 4;
    }

    while (length) {
        *dest++ = value;
        length--;
    }
}

// dest = color + (dest * alpha)
inline static void comp_func_helper_sse2(uint32_t* dest, int length,
                                         uint32_t color, uint32_t alpha)
{
    const __m128i v_color = _mm_set1_epi32(color);
    const __m128i v_a = _mm_set1_epi16(alpha);

    LOOP_ALIGNED_U1_A4(dest, length,
                       { /* UOP */
                         *dest = color + BYTE_MUL(*dest, alpha);
                         dest++;
                         length--;
                       },
                       { /* A4OP */
                         __m128i v_dest = _mm_load_si128((__m128i*)dest);

                         v_dest = v4_byte_mul_sse2(v_dest, v_a);
                         v_dest = _mm_add_epi32(v_dest, v_color);

                         _mm_store_si128((__m128i*)dest, v_dest);

                         dest += 4;
                         length -= 4;
                       })
}

void Vcomp_func_solid_Source_sse2(uint32_t* dest, int length, uint32_t color,
                                 uint32_t const_alpha)
{
    if (const_alpha == 255) {
        memfill32(dest, color, length);
    } else {
        int ialpha;

        ialpha = 255 - const_alpha;
        color = BYTE_MUL(color, const_alpha);
        comp_func_helper_sse2(dest, length, color, ialpha);
    }
}

void Vcomp_func_solid_SourceOver_sse2(uint32_t* dest, int length,
                                      uint32_t color,
                                     uint32_t const_alpha)
{
    int ialpha;

    if (const_alpha != 255) color = BYTE_MUL(color, const_alpha);
    ialpha = 255 - vAlpha(color);
    comp_func_helper_sse2(dest, length, color, ialpha);
}

void Vcomp_func_Source_sse2(uint32_t* dest, const uint32_t* src, int length,
                           uint32_t const_alpha)
{
    int ialpha;
    if (const_alpha == 255) {
        memcpy(dest, src, length * sizeof(uint32_t));
    } else {
        ialpha = 255 - const_alpha;
        __m128i v_alpha = _mm_set1_epi32(const_alpha);

        LOOP_ALIGNED_U1_A4(dest, length,
                           { /* UOP */
                             *dest = INTERPOLATE_PIXEL_255(*src, const_alpha,
                                                           *dest, ialpha);
                             dest++;
                             src++;
                             length--;
                           },
                           {/* A4OP */
                            V4_FETCH_SRC_DEST V4_COMP_OP_SRC V4_STORE_DEST
                                                             V4_SRC_DEST_LEN_INC})
    }
}

void comp_func_SourceOver_sse2_1(uint32_t* dest, const uint32_t* src,
                                 int length, uint32_t const_alpha)
{
    uint32_t s, sia;

    if (const_alpha == 255) {
        LOOP_ALIGNED_U1_A4(dest, length,
                           { /* UOP */
                             s = *src;
                             sia = vAlpha(~s);
                             *dest = s + BYTE_MUL(*dest, sia);
                             dest++;
                             src++;
                             length--;
                           },
                           {/* A4OP */
                            V4_FETCH_SRC_DEST V4_COMP_OP_SRC_OVER V4_STORE_DEST
                                                                  V4_SRC_DEST_LEN_INC})
    } else {
        __m128i v_alpha = _mm_set1_epi32(const_alpha);
        LOOP_ALIGNED_U1_A4(
            dest, length,
            { /* UOP */
              s = BYTE_MUL(*src, const_alpha);
              sia = vAlpha(~s);
              *dest = s + BYTE_MUL(*dest, sia);
              dest++;
              src++;
              length--;
            },
            {/* A4OP */
             V4_FETCH_SRC_DEST V4_ALPHA_MULTIPLY V4_COMP_OP_SRC_OVER
                 V4_STORE_DEST V4_SRC_DEST_LEN_INC})
    }
}

// Pixman implementation
#define force_inline inline

static force_inline __m128i unpack_32_1x128(uint32_t data)
{
    return _mm_unpacklo_epi8(_mm_cvtsi32_si128(data), _mm_setzero_si128());
}

static force_inline void unpack_128_2x128(__m128i data, __m128i* data_lo,
                                          __m128i* data_hi)
{
    *data_lo = _mm_unpacklo_epi8(data, _mm_setzero_si128());
    *data_hi = _mm_unpackhi_epi8(data, _mm_setzero_si128());
}

static force_inline uint32_t pack_1x128_32(__m128i data)
{
    return _mm_cvtsi128_si32(_mm_packus_epi16(data, _mm_setzero_si128()));
}

static force_inline __m128i pack_2x128_128(__m128i lo, __m128i hi)
{
    return _mm_packus_epi16(lo, hi);
}

/* load 4 pixels from a 16-byte boundary aligned address */
static force_inline __m128i load_128_aligned(__m128i* src)
{
    return _mm_load_si128(src);
}

/* load 4 pixels from a unaligned address */
static force_inline __m128i load_128_unaligned(const __m128i* src)
{
    return _mm_loadu_si128(src);
}

/* save 4 pixels on a 16-byte boundary aligned address */
static force_inline void save_128_aligned(__m128i* dst, __m128i data)
{
    _mm_store_si128(dst, data);
}

static force_inline int is_opaque(__m128i x)
{
    __m128i ffs = _mm_cmpeq_epi8(x, x);

    return (_mm_movemask_epi8(_mm_cmpeq_epi8(x, ffs)) & 0x8888) == 0x8888;
}

static force_inline int is_zero(__m128i x)
{
    return _mm_movemask_epi8(_mm_cmpeq_epi8(x, _mm_setzero_si128())) == 0xffff;
}

static force_inline __m128i expand_alpha_1x128(__m128i data)
{
    return _mm_shufflehi_epi16(
        _mm_shufflelo_epi16(data, _MM_SHUFFLE(3, 3, 3, 3)),
        _MM_SHUFFLE(3, 3, 3, 3));
}

static force_inline __m128i create_mask_16_128(uint16_t mask)
{
    return _mm_set1_epi16(mask);
}

static __m128i mask_0080 = create_mask_16_128(0x0080);
static __m128i mask_00ff = create_mask_16_128(0x00ff);
static __m128i mask_0101 = create_mask_16_128(0x0101);

static force_inline __m128i negate_1x128(__m128i data)
{
    return _mm_xor_si128(data, mask_00ff);
}

static force_inline void negate_2x128(__m128i data_lo, __m128i data_hi,
                                      __m128i* neg_lo, __m128i* neg_hi)
{
    *neg_lo = _mm_xor_si128(data_lo, mask_00ff);
    *neg_hi = _mm_xor_si128(data_hi, mask_00ff);
}

static force_inline __m128i pix_multiply_1x128(__m128i data, __m128i alpha)
{
    return _mm_mulhi_epu16(
        _mm_adds_epu16(_mm_mullo_epi16(data, alpha), mask_0080), mask_0101);
}

static force_inline void pix_multiply_2x128(__m128i* data_lo, __m128i* data_hi,
                                            __m128i* alpha_lo,
                                            __m128i* alpha_hi, __m128i* ret_lo,
                                            __m128i* ret_hi)
{
    __m128i lo, hi;

    lo = _mm_mullo_epi16(*data_lo, *alpha_lo);
    hi = _mm_mullo_epi16(*data_hi, *alpha_hi);
    lo = _mm_adds_epu16(lo, mask_0080);
    hi = _mm_adds_epu16(hi, mask_0080);
    *ret_lo = _mm_mulhi_epu16(lo, mask_0101);
    *ret_hi = _mm_mulhi_epu16(hi, mask_0101);
}

static force_inline __m128i over_1x128(__m128i src, __m128i alpha, __m128i dst)
{
    return _mm_adds_epu8(src, pix_multiply_1x128(dst, negate_1x128(alpha)));
}

static force_inline void expand_alpha_2x128(__m128i data_lo, __m128i data_hi,
                                            __m128i* alpha_lo,
                                            __m128i* alpha_hi)
{
    __m128i lo, hi;

    lo = _mm_shufflelo_epi16(data_lo, _MM_SHUFFLE(3, 3, 3, 3));
    hi = _mm_shufflelo_epi16(data_hi, _MM_SHUFFLE(3, 3, 3, 3));

    *alpha_lo = _mm_shufflehi_epi16(lo, _MM_SHUFFLE(3, 3, 3, 3));
    *alpha_hi = _mm_shufflehi_epi16(hi, _MM_SHUFFLE(3, 3, 3, 3));
}

static force_inline void over_2x128(__m128i* src_lo, __m128i* src_hi,
                                    __m128i* alpha_lo, __m128i* alpha_hi,
                                    __m128i* dst_lo, __m128i* dst_hi)
{
    __m128i t1, t2;

    negate_2x128(*alpha_lo, *alpha_hi, &t1, &t2);

    pix_multiply_2x128(dst_lo, dst_hi, &t1, &t2, dst_lo, dst_hi);

    *dst_lo = _mm_adds_epu8(*src_lo, *dst_lo);
    *dst_hi = _mm_adds_epu8(*src_hi, *dst_hi);
}

static force_inline uint32_t core_combine_over_u_pixel_sse2(uint32_t src,
                                                            uint32_t dst)
{
    uint8_t a;
    __m128i xmms;

    a = src >> 24;

    if (a == 0xff) {
        return src;
    } else if (src) {
        xmms = unpack_32_1x128(src);
        return pack_1x128_32(
            over_1x128(xmms, expand_alpha_1x128(xmms), unpack_32_1x128(dst)));
    }

    return dst;
}

// static force_inline void
// core_combine_over_u_sse2_no_mask (uint32_t *	  pd,
//                  const uint32_t*    ps,
//                  int                w)
void Vcomp_func_SourceOver_sse2(uint32_t* pd, const uint32_t* ps, int w,
                               uint32_t)
{
    uint32_t s, d;

    /* Align dst on a 16-byte boundary */
    while (w && ((uintptr_t)pd & 15)) {
        d = *pd;
        s = *ps;

        if (s) *pd = core_combine_over_u_pixel_sse2(s, d);
        pd++;
        ps++;
        w--;
    }

    while (w >= 4) {
        __m128i src;
        __m128i src_hi, src_lo, dst_hi, dst_lo;
        __m128i alpha_hi, alpha_lo;

        src = load_128_unaligned((__m128i*)ps);

        if (!is_zero(src)) {
            if (is_opaque(src)) {
                save_128_aligned((__m128i*)pd, src);
            } else {
                __m128i dst = load_128_aligned((__m128i*)pd);

                unpack_128_2x128(src, &src_lo, &src_hi);
                unpack_128_2x128(dst, &dst_lo, &dst_hi);

                expand_alpha_2x128(src_lo, src_hi, &alpha_lo, &alpha_hi);
                over_2x128(&src_lo, &src_hi, &alpha_lo, &alpha_hi, &dst_lo,
                           &dst_hi);

                save_128_aligned((__m128i*)pd, pack_2x128_128(dst_lo, dst_hi));
            }
        }

        ps += 4;
        pd += 4;
        w -= 4;
    }
    while (w) {
        d = *pd;
        s = *ps;

        if (s) *pd = core_combine_over_u_pixel_sse2(s, d);
        pd++;
        ps++;

        w--;
    }
}

#endif
