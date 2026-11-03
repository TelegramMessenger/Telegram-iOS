# Color Management

[TOC]

<!--*
# Document freshness: For more information, see go/fresh-source.
freshness: { owner: 'sboukortt' reviewed: '2022-09-27' }
*-->

## Why

The vast majority of web images are still sRGB. However, wide-gamut material is
increasingly being produced (photography, cinema, 4K). Screens covering most of
the Adobe RGB gamut are readily available and some also cover most of DCI P3
(iPhone, Pixel2) or even BT.2020.

Currently, after a camera records a very saturated red pixel, most raw
processors would clip it to the rather small sRGB gamut before saving as JPEG.
In keeping with our high-quality goal, we prevent such loss by allowing wider
input color spaces.

## Which color space

Even wide gamuts could be expressed relative to the sRGB primaries, but the
resulting coordinates may be outside the valid 0..1 range. Surprisingly, such
'unbounded' coordinates can be passed through color transforms provided the
transfer functions are expressed as parametric functions (not lookup tables).
However, most image file formats (including PNG and PNM) lack min/max metadata
and thus do not support unbounded coordinates.

Instead, we need a larger working gamut to ensure most pixel coordinates are
within bounds and thus not clipped. However, larger gamuts result in lower
precision/resolution when using <= 16 bit encodings (as opposed to 32-bit float
in PFM). BT.2100 or P3 DCI appear to be good compromises.

## CMS library

Transforms with unbounded pixels are desirable because they reduce round-trip
error in tests. This requires parametric curves, which are only supported for
the common sRGB case in ICC v4 profiles. ArgyllCMS does not support v4. The
other popular open-source CMS is LittleCMS. It is also used by color-managed
editors (Krita/darktable), which increases the chances of interoperability.
However, LCMS has race conditions and overflow issues that prevent fuzzing. We
will later switch to the newer skcms. Note that this library does not intend to
support multiProcessElements, so HDR transfer functions cannot be represented
accurately. Thus in the long term, we will probably migrate away from ICC
profiles entirely.

## Which viewer

On Linux, Krita and darktable support loading our PNG output images and their
ICC profile.

## How to compress/decompress

### Embedded ICC profile

-   Create an 8-bit or 16-bit PNG with an iCCP chunk, e.g. using darktable.
-   Pass it to `cjxl`, then `djxl` with no special arguments. The decoded output
    will have the same bit depth (can override with `--output_bit_depth`) and
    color space.

### Images without metadata (e.g. HDR)

-   Create a PGM/PPM/PFM file in a known color space.
-   Invoke `cjxl` with `-x color_space=RGB_D65_202_Rel_Lin` (linear 2020). For
    details/possible values, see color_encoding.cc `Description`.
-   Invoke `djxl` as above with no special arguments.
