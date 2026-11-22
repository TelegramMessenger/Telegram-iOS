# HDR tools

This directory contains a small set of command-line tools for HDR conversions,
including to SDR.

## Tone mapping

`tools/tone_map` implements tone mapping as described in annex 5 of
[Report ITU-R BT.2408-4](https://www.itu.int/pub/R-REP-BT.2408-4-2021), more
specifically the YRGB variant. Since the result may contain out-of-gamut colors,
it additionally does very basic gamut mapping. The balance between preserving
saturation and preserving luminance can be controlled by passing a number
between 0 and 1 using `--preserve_saturation`. The default is 0.1. Hue is never
sacrificed.

### Examples

```shell
# Tone maps a PQ image for a 300 cd/m² display, and writes the result as an SDR
# (but still wide-gamut) image to be shown on such a display.
$ tools/tone_map -t 300 ClassE_507.png ClassE_507_tone_mapped_300.png

# The result can also be written as a PQ image itself:
$ tools/tone_map -t 300 --pq ClassE_507.png ClassE_507_tone_mapped_300_pq.png

# It is possible to specify the maximum luminance found in the image using
# `--max_nits`. For OpenEXR input, it will override the `whiteLuminance` tag
# which indicates the luminance of (1, 1, 1). For PQ, it will not affect the
# luminance calculated from the signal, but it will tell the tone mapping how
# much headroom to leave for highlights.
$ tools/tone_map -m 4000 -t 300 ClassE_507.png ClassE_507_tone_mapped_300.png
```

## PQ to HLG conversion

`tools/pq_to_hlg` performs conversion of a PQ image to HLG as described in
section 6 of the aforementioned BT.2408-4. That is, the PQ image is first
limited to 1000 cd/m² using the tone mapping mentioned above, and the result is
treated as if it were the output of a reference 1000 cd/m² HLG display: such a
display  would have a system gamma of 1.2, and therefore, we can apply the
HLG inverse OOTF with a gamma of 1.2 to get “back” to the linear scene-referred
signal that would have produced that output on that reference display (and then
encode it using the OETF).

As with the tone mapping tool, the `--max_nits` and `--preserve_saturation`
options can be used to guide the 1000 cd/m² limiting.

### Example

```shell
$ tools/pq_to_hlg ClassE_507.png ClassE_507_hlg.png
```

## HLG rendering

HLG is designed to look acceptable without specific processing on displays that
expect a “traditional” SDR signal. Nevertheless, it is possible to optimize the
appearance for specific viewing conditions by applying the HLG inverse OETF and
then the OOTF with an appropriate system gamma. Here, the system gamma is
computed using  the extended model mentioned at the bottom of page 29 of
[Report ITU-R BT.2390-9](https://www.itu.int/pub/R-REP-BT.2390-9-2021). That
formula should work well over a wide range of display peak luminances.

It is possible to specify not just the peak luminance of the target display
(using `--target_nits`) but also the ambient luminance of the viewing
environment using `--surround_nits`.

As with the tone mapping tool, the result can be written as a PQ image. In that
case, it would make sense, in further usage of `tools/tone_map` or
`tools/pq_to_hlg`, to set `--max_nits` to the value that was passed as
`--target_nits` to this tool. This also applies to the tone mapping tool.

### Examples

```shell
# Renders an HLG image for a 300 cd/m² display in a 10 cd/m² room.
$ tools/render_hlg -t 300 -s 10 ClassE_507_hlg.png ClassE_507_hlg_300.png

# Renders it for a reference 1000 cd/m² display and writes the result as a PQ
# image.
$ tools/render_hlg -t 1000 --pq ClassE_507_hlg.png ClassE_507_hlg_pq.png

# Informing pq_to_hlg about that maximum luminance then ensures proper
# roundtripping as it will not needlessly tone map the highlights.
$ tools/pq_to_hlg -m 1000 ClassE_507_hlg_pq.png ClassE_507_hlg_pq_hlg.png
```

## Display light to HLG

By applying the inverse OOTF to a display-referred image, it is possible to
compute the scene light, and from there the HLG signal, that would have
produced that output on that display:

```shell
$ tools/display_to_hlg -m 600 -s 5 srgb_input.png hlg_output.png
```

This is the mathematical inverse of `tools/render_hlg`. Furthermore,
`tools/pq_to_hlg` is equivalent to `tools/tone_map -t 1000` followed by
`tools/display_to_hlg -m 1000`.

## OpenEXR to PQ

`tools/exr_to_pq` converts an OpenEXR image into a Rec. 2020 + PQ image, which
can be saved as a PNG or PPM file. Luminance information is taken from the
`whiteLuminance` tag if the input has it, and otherwise defaults to treating
(1, 1, 1) as 100 cd/m². It is also possible to override this using the
`--luminance` (`-l`) flag, in two different ways:

```shell
# Specifies that the brightest pixel in the image happens to be 1500 cd/m².
$ tools/exr_to_pq --luminance='max=1500' input.exr output.png

# Specifies that (1, 1, 1) in the input file is 203 cd/m².
$ tools/exr_to_pq --luminance='white=203' input.exr output.png
```

# LUT generation

There are additionally two tools that can be used to generate look-up tables
for use with e.g. FFmpeg, ReShade, or DaVinci Resolve.

The first of the two tools gives a starting point:

```shell
$ tools/generate_lut_template --lut_size=64 identity.ppm
```

From there, one can apply a chain of per-pixel transforms (including other
LUTs) that the final LUT is intended to represent:

```shell
$ tools/pq_to_hlg identity.ppm pq_to_hlg.ppm
$ tools/render_hlg -t 400 pq_to_hlg.ppm pq_to_400nit_rec2020.png
$ convert pq_to_400nit_rec2020.png -profile /usr/share/color/icc/colord/Rec709.icc pq_to_400nit_rec709.png
```

From there, the PNG image can be used as-is with ReShade’s “LUT” shader
(provided that the correct LUT size is set), or it can be converted to a
[Cube](https://wwwimages2.adobe.com/content/dam/acom/en/products/speedgrade/cc/pdfs/cube-lut-specification-1.0.pdf)
file for use in other software such as FFmpeg’s [lut3d](https://ffmpeg.org/ffmpeg-filters.html#lut3d-1)
filter:

```shell
$ tools/texture_to_cube pq_to_400nit_rec709.png pq_to_400nit_rec709.cube
$ ffmpeg -i pq_video.mkv -vf lut3d=pq_to_400nit_rec709.cube -colorspace bt709 -color_primaries bt709 -color_trc bt709 400nit_rec709_video.mkv
```

Note: instead of converting to a standard color space such as Rec. 709, it is
also possible to convert to the color space of the specific display on which
the content is to be shown, in which case the transformed content does not need
any specific tagging and should be displayed directly without color management
(for example using `ffplay`).
