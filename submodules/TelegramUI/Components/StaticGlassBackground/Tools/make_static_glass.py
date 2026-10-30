#!/usr/bin/env python3
"""Makes the static glass assets from captures of the real iOS glass.

Usage: make_static_glass.py <captures dir> <output dir> [shape ...]

With shapes named, only those are written (so assets made from earlier captures stay as they are).

The captures come from Tests/GlassCapture (the real GlassBackgroundView over a plain page, screenshotted on an iOS 27
simulator at 3x; its README.md and capture.sh): `light-panel-{FFFFFF,E0E0E0,F0F0F0}` and
`dark-panel-{000000,202020,101010}`, each a .png and its .json manifest of shape frames. Each asset written is checked
against all three captured pages of its mode, and the errors printed.

Glass over a uniform page composes as C = F + (1 - a) * B per channel (B the page): the alpha comes from two pages, and
the premultiplied colour F is taken from the anchor page (white for light, black for dark), so an asset reproduces the
capture exactly there. Dark glass lightens the page (F above a * 255): the bytes are premultiplied and are drawn as they
are, not clamped.

Each asset is a 9-slice: the shape's two ends with 12pt of its straight run beyond them (the rim highlight dips there)
and a 1pt slice from the middle of the run, plus the margins the glass draws outside the shape (the light shadow). A
rounded rectangle (`rect-*`) is cut so along both axes and stretches both ways.

The `tint-*` modes are fixed tints captured over the same pages as the panel (`light-tint-000000a100-*`, …), for tints
the model in StaticGlassBackground does not reproduce (black ink, white at 0.8).

The `media` mode is the dark glass the chat puts over media (tinted black at 0.3), captured as
`dark-tint-000000a30-{000000,141415,808080,FFFFFF}`. That glass adapts to what is behind it (it compresses bright
backgrounds: 22, 35, 92, 127 inside over those pages), which no image can, so its alpha and colour are a least-squares
fit over all four pages: within about 6 levels over black and white and 12 darker over mid-gray, which keeps the white
text on it readable over bright media.

.bin format: b"SGL1", UInt16 width, height (px), UInt8 scale, UInt16 shape frame x, y, w, h (px), UInt16 cap insets
left, top, right, bottom (px), then a raw DEFLATE stream (Foundation's `.zlib`) of width * height * 4 premultiplied
RGBA bytes. Little-endian.
"""
import json
import os
import struct
import sys
import zlib

import numpy as np
from PIL import Image

SHAPES = ['capsule-r15', 'capsule-r21', 'circle-r15', 'vcapsule-r15', 'capsule-r10', 'circle-r24', 'rect-r12']
MODES = {
    'light': {'prefix': 'light-panel', 'anchor': 'FFFFFF', 'second': 'E0E0E0', 'checks': ['F0F0F0']},
    'dark': {'prefix': 'dark-panel', 'anchor': '000000', 'second': '202020', 'checks': ['101010']},
    'media': {'prefix': 'dark-tint-000000a30', 'anchor': '000000', 'second': 'FFFFFF', 'checks': ['808080', '141415'], 'shapes': ['capsule-r10', 'circle-r24', 'rect-r12'], 'fit': True},
    # Fixed tints the chat uses, captured rather than modelled: the monochrome look's ink (black in light, white in
    # dark) on chosen reactions and file controls, and the light button of the unsupported-content banner.
    'tint-000000a100-light': {'prefix': 'light-tint-000000a100', 'anchor': 'FFFFFF', 'second': 'E0E0E0', 'checks': ['F0F0F0', 'F9F9FB'], 'shapes': ['capsule-r10', 'capsule-r15', 'circle-r15', 'circle-r24']},
    'tint-FFFFFFa100-dark': {'prefix': 'dark-tint-FFFFFFa100', 'anchor': '000000', 'second': '202020', 'checks': ['101010', '141415'], 'shapes': ['capsule-r10', 'capsule-r15', 'circle-r15', 'circle-r24']},
    'tint-FFFFFFa80-light': {'prefix': 'light-tint-FFFFFFa80', 'anchor': 'FFFFFF', 'second': 'E0E0E0', 'checks': ['F0F0F0', 'F9F9FB'], 'shapes': ['capsule-r10', 'capsule-r15', 'circle-r15']},
}
END_RUN = 12  # points of straight run kept with each end
SEARCH_MARGIN = 24  # points searched around a shape for what the glass draws outside it


def page_value(hex_string):
    v = int(hex_string, 16)
    return np.array([(v >> 16) & 255, (v >> 8) & 255, v & 255], dtype=np.float64)


def load(captures, mode, page):
    label = f"{MODES[mode]['prefix']}-{page}"
    image = np.asarray(Image.open(os.path.join(captures, label + '.png')).convert('RGB')).astype(np.float64)
    manifest = json.load(open(os.path.join(captures, label + '.json')))
    return image, manifest


def matte(anchor, second, b_anchor, b_second):
    """Alpha and premultiplied colour, exact over the anchor page."""
    one_minus_alpha = np.clip(((second - anchor) / (b_second - b_anchor)).mean(axis=2, keepdims=True), 0.0, 1.0)
    # One level of capture noise over a page difference of 32 moves the alpha by 0.03; where that would make F
    # negative over the anchor page (a shadow is F = 0), the anchor decides.
    if b_anchor.max() > 0.0:
        one_minus_alpha = np.minimum(one_minus_alpha, (anchor / b_anchor).min(axis=2, keepdims=True))
    f = np.clip(anchor - one_minus_alpha * b_anchor, 0.0, 255.0)
    return 1.0 - one_minus_alpha, f


def fit(images, pages):
    """Alpha and premultiplied colour fitted over several pages by least squares (C = F + k * B, k = 1 - alpha)."""
    b = np.array([page_value(p).mean() for p in pages])
    c = np.stack([image.mean(axis=2) for image in images], axis=0)
    b_mean, c_mean = b.mean(), c.mean(axis=0)
    k = (((b - b_mean)[:, None, None]) * (c - c_mean)).sum(axis=0) / ((b - b_mean) ** 2).sum()
    k = np.clip(k, 0.0, 1.0)[..., None]
    f = np.clip(np.stack(images, axis=0).mean(axis=0) - k * b_mean, 0.0, 255.0)
    return 1.0 - k, f


def build(captures, mode, shape_name):
    pages = MODES[mode]
    anchor, manifest = load(captures, mode, pages['anchor'])
    second, _ = load(captures, mode, pages['second'])
    scale = int(manifest['scale'])
    shape = [s for s in manifest['shapes'] if s['name'] == shape_name][0]
    x, y, w, h = [int(round(v)) for v in shape['frame']]
    r = int(round(shape['radius']))
    m = SEARCH_MARGIN
    x0, y0, x1, y1 = (x - m) * scale, (y - m) * scale, (x + w + m) * scale, (y + h + m) * scale
    if pages.get('fit'):
        names = [pages['anchor'], pages['second']] + pages['checks']
        alpha, f = fit([load(captures, mode, n)[0][y0:y1, x0:x1] for n in names], names)
    else:
        alpha, f = matte(anchor[y0:y1, x0:x1], second[y0:y1, x0:x1], page_value(pages['anchor']), page_value(pages['second']))

    # What the glass draws outside the shape, in whole points.
    visible = (alpha[..., 0] * 255.0 > 0.75) | (f.max(axis=2) > 0.75)
    ys, xs = np.nonzero(visible)
    left = max(0, m - (xs.min() // scale))
    right = max(0, (xs.max() // scale + 1) - (m + w))
    top = max(0, m - (ys.min() // scale))
    bottom = max(0, (ys.max() // scale + 1) - (m + h))
    cx0, cy0 = (m - left) * scale, (m - top) * scale
    cx1, cy1 = (m + w + right) * scale, (m + h + bottom) * scale
    alpha, f = alpha[cy0:cy1, cx0:cx1], f[cy0:cy1, cx0:cx1]
    frame = (left * scale, top * scale, w * scale, h * scale)

    horizontal = w > h
    vertical = h > w
    if shape_name.startswith('rect-'):
        fx0, fx1, fxm = (left + r + END_RUN) * scale, (left + w - r - END_RUN) * scale, (left + w // 2) * scale
        fy0, fy1, fym = (top + r + END_RUN) * scale, (top + h - r - END_RUN) * scale, (top + h // 2) * scale
        assert fx0 < fxm < fx1 and fy0 < fym < fy1, shape_name
        def cut2(a):
            a = np.concatenate([a[:, :fx0], a[:, fxm:fxm + scale], a[:, fx1:]], axis=1)
            return np.concatenate([a[:fy0], a[fym:fym + scale], a[fy1:]], axis=0)
        width_before, height_before = a_width(alpha), a_height(alpha)
        alpha, f = cut2(alpha), cut2(f)
        caps = (fx0, fy0, width_before - fx1, height_before - fy1)
        frame = (frame[0], frame[1], frame[2] - (fx1 - fx0) + scale, frame[3] - (fy1 - fy0) + scale)
    elif horizontal or vertical:
        if horizontal:
            first = (left + r + END_RUN) * scale
            last = (left + w - r - END_RUN) * scale
            middle = (left + w // 2) * scale
            assert first < middle < last, shape_name
            def cut(a):
                return np.concatenate([a[:, :first], a[:, middle:middle + scale], a[:, last:]], axis=1)
            caps = (first, 0, a_width(alpha) - last, 0)
            frame = (frame[0], frame[1], frame[2] - (last - first) + scale, frame[3])
        else:
            first = (top + r + END_RUN) * scale
            last = (top + h - r - END_RUN) * scale
            middle = (top + h // 2) * scale
            assert first < middle < last, shape_name
            def cut(a):
                return np.concatenate([a[:first], a[middle:middle + scale], a[last:]], axis=0)
            caps = (0, first, 0, a_height(alpha) - last)
            frame = (frame[0], frame[1], frame[2], frame[3] - (last - first) + scale)
        alpha, f = cut(alpha), cut(f)
    else:
        caps = (0, 0, 0, 0)
    return {'alpha': alpha, 'f': f, 'scale': scale, 'frame': frame, 'caps': caps, 'shape': (x, y, w, h), 'radius': r}


def a_width(a):
    return a.shape[1]


def a_height(a):
    return a.shape[0]


def stretch_to(asset, w_px, h_px):
    """The asset drawn at a shape size (px), as UIKit stretches a resizable image."""
    alpha, f = asset['alpha'], asset['f']
    left, top, right, bottom = asset['caps']
    fx, fy, fw, fh = asset['frame']
    if left or right:
        extra = w_px - fw
        mid = alpha.shape[1] - left - right
        reps = mid + extra
        idx = np.concatenate([np.arange(left), left + (np.arange(reps) * mid // reps), np.arange(alpha.shape[1] - right, alpha.shape[1])])
        alpha, f = alpha[:, idx], f[:, idx]
    if top or bottom:
        extra = h_px - fh
        mid = alpha.shape[0] - top - bottom
        reps = mid + extra
        idx = np.concatenate([np.arange(top), top + (np.arange(reps) * mid // reps), np.arange(alpha.shape[0] - bottom, alpha.shape[0])])
        alpha, f = alpha[idx], f[idx]
    return alpha, f


def check(captures, mode, shape_name, asset):
    """Composite the asset (premultiplied, quantised as stored) over each captured page at the captured size."""
    x, y, w, h = asset['shape']
    s = asset['scale']
    a8 = np.round(asset['alpha'] * 255.0) / 255.0
    f8 = np.round(asset['f'])
    stored = dict(asset, alpha=a8, f=f8)
    alpha, f = stretch_to(stored, w * s, h * s)
    fx, fy, _, _ = asset['frame']
    out = []
    for page in [MODES[mode]['anchor'], MODES[mode]['second']] + MODES[mode]['checks']:
        image, _ = load(captures, mode, page)
        x0, y0 = x * s - fx, y * s - fy
        captured = image[y0:y0 + alpha.shape[0], x0:x0 + alpha.shape[1]]
        composed = f + (1.0 - alpha) * page_value(page)
        err = np.abs(composed - captured)
        out.append(f'{page} max {err.max():.1f} p99 {np.percentile(err, 99):.1f}')
    return ', '.join(out)


def write(asset, path):
    alpha, f = asset['alpha'], asset['f']
    height, width = alpha.shape[0], alpha.shape[1]
    rgba = np.concatenate([np.round(f), np.round(alpha * 255.0)], axis=2).clip(0, 255).astype(np.uint8)
    header = b'SGL1' + struct.pack('<HHB', width, height, asset['scale'])
    header += struct.pack('<HHHH', *[int(v) for v in asset['frame']])
    header += struct.pack('<HHHH', *[int(v) for v in asset['caps']])
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    body = compressor.compress(rgba.tobytes()) + compressor.flush()
    with open(path, 'wb') as file:
        file.write(header + body)
    return len(header) + len(body)


def main():
    captures, output = sys.argv[1], sys.argv[2]
    only = sys.argv[3:]
    os.makedirs(output, exist_ok=True)
    for mode in MODES:
        for shape_name in MODES[mode].get('shapes', SHAPES):
            if only and shape_name not in only:
                continue
            asset = build(captures, mode, shape_name)
            name = f'static-glass-{shape_name}-{mode}.bin'
            size = write(asset, os.path.join(output, name))
            h, w = asset['alpha'].shape[:2]
            print(f'{name}: {w}x{h}px, frame {asset["frame"]}, caps {asset["caps"]}, {size} bytes | {check(captures, mode, shape_name, asset)}')


if __name__ == '__main__':
    main()
