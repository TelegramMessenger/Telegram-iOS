# JPEG XL Format Overview

This document gives an overview of the JPEG XL file format and codestream,
its features, and the underlying design rationale.
The aim of this document is to provide general insight into the
format capabilities and design, thus helping developers
better understand how to use the `libjxl` API.

## Codestream and File Format

The JPEG XL format is defined in ISO/IEC 18181. This standard consists of
four parts:

*   18181-1: Core codestream
*   18181-2: File format
*   18181-3: Conformance testing
*   18181-4: Reference implementation

### Core codestream

The core codestream contains all the data necessary to decode and display
still image or animation data. This includes basic metadata like image dimensions,
the pixel data itself, colorspace information, orientation, upsampling, etc.

### File format

The JPEG XL file format can take two forms:

*   A 'naked' codestream. In this case, only the image/animation data itself is
stored, and no additional metadata can be included. Such a file starts with the
bytes `0xFF0A` (the JPEG marker for "start of JPEG XL codestream").
*   An ISOBMFF-based container. This is a box-based container that includes a
JPEG XL codestream box (`jxlc`), and can optionally include other boxes with
additional information, such as Exif metadata. In this case, the file starts with
the bytes `0x0000000C 4A584C20 0D0A870A`.

### Conformance testing

This part of the standard defines precision bounds and test cases for conforming
decoders, to verify that they implement all coding tools correctly and accurately.

### Reference implementation

The `libjxl` software is the reference implementation of JPEG XL.


## Metadata versus Image Data

JPEG XL makes a clear separation between metadata and image data.
Everything that is needed to correctly display an image is
considered to be image data, and is part of the core codestream. This includes
elements that have traditionally been considered 'metadata', such as ICC profiles
and Exif orientation. The goal is to reduce the ambiguity and potential for
incorrect implementations that can be caused by having a 'black box' codestream
that only contains numerical pixel data, requiring applications to figure out how
to correctly interpret the data (i.e. apply color transforms, upsampling,
orientation, blending, cropping, etc.). By including this functionality in the
codestream itself, the decoder can provide output in a normalized way
(e.g. in RGBA, orientation already applied, frames blended and coalesced),
simplifying things and making it less error-prone for applications.

The remaining metadata, e.g. Exif or XMP, can be stored in the container format,
but it does not influence image rendering. In the case of Exif orientation,
this field has to be ignored by applications, since the orientation in the
codestream always takes precedence (and will already have been applied
transparently by the decoder). This means that stripping metadata can be done
without affecting the displayed image.


## Codestream Features

### Color Management

In JPEG XL, images always have a fully defined colorspace, i.e. it is always
unambiguous how to interpret the pixel values. There are two options:

*   Pixel data is in a specified (non-XYB) colorspace, and the decoder will produce
a pixel buffer in this colorspace plus an ICC profile that describes that
colorspace. Mathematically lossless encoding can only use this option.
*   Pixel data is in the XYB colorspace, which is an absolute colorspace.
In this case, the decoder can produce a pixel buffer directly in a desired
display space like sRGB, Display-P3 or Rec.2100 PQ.

The image header always contains a colorspace; however, its meaning depends on
which of the above two options were used:

*   In the first case (non-XYB), the signaled colorspace defines the
interpretation of the pixel data.
*   In the second case (XYB), the signaled colorspace is merely a _suggestion_
of a target colorspace to represent the image in, i.e. it is the colorspace
the original image was in, that has a sufficiently wide gamut and a
suitable transfer curve to represent the image data with high fidelity
using a limited bit depth representation.

Colorspaces can be signaled in two ways in JPEG XL:

*    CICP-style Enum values: This is a very compact representation that
covers most or all of the common colorspaces. The decoder can convert
XYB to any of these colorspaces without requiring an external color management
library.
*    ICC profiles: Arbitrary ICC profiles can also be used, including
CMYK ones. The ICC profile data gets compressed. In this case, external
color management software (e.g. lcms2 or skcms) has to be used for color
conversions.

### Frames

A JPEG XL codestream contains one or more frames. In the case of animation,
these frames have a duration and can be looped (infinitely or a number of times).
Zero-duration frames are possible and represent different layers of the image.

Frames can have a blendmode (Replace, Add, Alpha-blend, Multiply, etc.) and
they can use any previous frame as a base.
They can be smaller than the image canvas, in which case the pixels outside the
crop are copied from the base frame. They can be positioned at an arbitrary
offset from the image canvas; this offset can also be negative and frames can
also be larger than the image canvas, in which case parts of the frame will
be invisible and only the intersection with the image canvas will be shown.

By default, the decoder will blend and coalesce frames, producing only a single
output frame when there are subsequent zero-duration frames, and all output frames
are of the same size (the size of the image canvas) and have either no duration
(in case of a still image) or a non-zero duration (in case of animation).

### Pixel Data

Every frame contains pixel data encoded in one of two modes:

*   VarDCT mode: In this mode, variable-sized DCT transforms are applied
and the image data is encoded in the form of DCT coefficients. This mode is
always lossy, but it can also be used to losslessly represent an existing
(already lossy) JPEG image, in which case only the DCT8x8 is used.
*   Modular mode: In this mode, only integer arithmetic is used, which
enables lossless compression. However, this mode can also be used for lossy
compression. Multiple transformations can be used to improve compression or to
obtain other desirable effects: reversible color transforms (RCTs),
(delta) palette transforms, and a modified non-linear Haar transform
called Squeeze, which facilitates (but does not require) lossy compression
and enables progressive decoding.

Internally, the VarDCT mode uses Modular sub-bitstreams to encode
various auxiliary images, such as the "LF image" (a 1:8 downscaled version
of the image that contains the DC coefficients of DCT8x8 and low-frequency
coefficients of the larger DCT transforms), extra channels besides the
three color channels (e.g. alpha), and weights for adaptive quantization.

In addition, both modes can separately encode additional 'image features' that
are rendered on top of the decoded image:

*   Patches: rectangles from a previously decoded frame (which can be a
'hidden' frame that is not displayed but only stored to be referenced later)
can be blended using one of the blendmodes on top of the current frame.
This allows the encoder to identify repeating patterns (such as letters of
text) and encode them only once, using patches to insert the pattern in
multiple spots. These patterns are encoded in a previous frame, making
it possible to add Modular-encoded pixels to a VarDCT-encoded frame or
vice versa.
*   Splines: centripetal Catmull-Rom splines can be encoded, with a color
and a thickness that can vary along the arclength of the curve.
Although the current encoder does not use this bitstream feature yet, we
anticipate that it can be useful to complement DCT-encoded data, since
thin lines are hard to represent faithfully using the DCT.
*   Noise: luma-modulated synthetic noise can be added to an image, e.g.
to emulate photon noise, in a way that avoids poor compression due to
high frequency DCT coefficients.

Finally, both modes can also optionally apply two filtering methods to
the decoded image, which both have the goal of reducing block artifacts
and ringing:

*   Gabor-like transform ('Gaborish'): a small (3x3) blur that gets
applied across block and group boundaries, reducing blockiness. The
encoder applies the inverse sharpening transform before encoding,
effectively getting the benefits of lapped transforms without the
disadvantages.
*   Edge-preserving filter ('EPF'): similar to a bilateral filter,
this smoothing filter avoids blurring edges while reducing ringing.
The strength of this filter is signaled and can locally be adapted.

### Groups

In both modes (Modular and VarDCT), the frame data is signaled as
a sequence of groups. These groups can be decoded independently,
and the frame header contains a table of contents (TOC) with bitstream
offsets for the start of each group. This enables parallel decoding,
and also partial decoding of a region of interest or a progressive preview.

In VarDCT mode, all groups have dimensions 256x256 (or smaller at the
right and bottom borders). First the LF image is encoded, also in
256x256 groups (corresponding to 2048x2048 pixels, since this data
corresponds to the 1:8 image). This means there is always a basic
progressive preview available in VarDCT mode.
Optionally, the LF image can be encoded separately in a (hidden)
LF frame, which can itself recursively be encoded in VarDCT mode
and have its own LF frame. This makes it possible to represent huge
images while still having an overall preview that can be efficiently
decoded.
Then the HF groups are encoded, corresponding to the remaining AC
coefficients. The HF groups can be encoded in multiple passes for
more progressive refinement steps; the coefficients of all passes
are added. Unlike JPEG progressive scan scripts, JPEG XL allows
signaling any amount of detail in any part of the image in any pass.

In Modular mode, groups can have dimensions 128x128, 256x256, 512x512
or 1024x1024. If the Squeeze transform was used, the data will
be split in three parts: the Global groups (the top of the Laplacian
pyramid that fits in a single group), the LF groups (the middle part
of the Laplacian pyramid that corresponds to the data needed to
reconstruct the 1:8 image) and the HF groups (the base of the Laplacian
pyramid), where the HF groups are again possibly encoded in multiple
passes (up to three: one for the 1:4 image, one for the 1:2 image,
and one for the 1:1 image).

In case of a VarDCT image with extra channels (e.g. alpha), the
VarDCT groups and the Modular groups are interleaved in order to
allow progressive previews of all the channels.

The default group order is to encode the LF and HF groups in
scanline order (top to bottom, left to right), but this order
can be permuted arbitrarily. This allows, for example, a center-first
ordering or a saliency-based ordering, causing the bitstream
to prioritize progressive refinements in a different way.


## File Format Features

Besides the image data itself (stored in the `jxlc` codestream box),
the optional container format allows storing additional information.

## Metadata

Three types of metadata can be included in a JPEG XL container:

*   Exif (`Exif`)
*   XMP (`xml `)
*   JUMBF (`jumb`)

This metadata can contain information about the image, such as copyright
notices, GPS coordinates, camera settings, etc.
If it contains rendering-impacting information (such as Exif orientation),
the information in the codestream takes precedence.

## Compressed Metadata

The container allows the above metadata to be stored either uncompressed
(e.g. plaintext XML in the case of XMP) or by Brotli-compression.
In the latter case, the box type is `brob` (Brotli-compressed Box) and
the first four bytes of the box contents define the actual box type
(e.g. `xml `) it represents.

## JPEG Bitstream Reconstruction Data

JPEG XL can losslessly recompress existing JPEG files.
The general design philosophy still applies in this case:
all the image data is stored in the codestream box, including the DCT
coefficients of the original JPEG image and possibly an ICC profile or
Exif orientation.

In order to allow bit-identical reconstruction of the original JPEG file
(not just the image but the actual file), additional information is needed,
since the same image data can be encoded in multiple ways as a JPEG file.
The `jbrd` box (JPEG Bitstream Reconstruction Data) contains this information.
Typically it is relatively small. Using the image data from the codestream,
the JPEG bitstream reconstruction data, and possibly other metadata boxes
that were present in the JPEG file (Exif/XMP/JUMBF), the exact original
JPEG file can be reconstructed.

This box is not needed to display a recompressed JPEG image; it is only
needed to reconstruct the original JPEG file.

## Frame Index

The container can optionally store a `jxli` box, which contains an index
of offsets to keyframes of a JPEG XL animation. It is not needed to display
the animation, but it does facilitate efficient seeking.

## Partial Codestream

The codestream can optionally be split into multiple `jxlp` boxes;
conceptually, this is equivalent to a single `jxlc` box that contains the
concatenation of all partial codestream boxes.
This makes it possible to create a file that starts with
the data needed for a progressive preview of the image, followed by
metadata, followed by the remaining image data.
