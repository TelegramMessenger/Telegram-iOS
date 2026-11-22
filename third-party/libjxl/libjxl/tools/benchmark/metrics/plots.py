#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

import csv
import sys
import math
import plotly.graph_objects as go

_, results, output_dir, *rest = sys.argv
OUTPUT = rest[0] if rest else 'svg'
# valid values: html, svg, png, webp, jpeg, pdf

with open(results, 'r') as f:
    reader = csv.DictReader(f)
    all_results = list(reader)

nonmetric_columns = set([
    "method", "image", "error", "size", "pixels", "enc_speed", "dec_speed",
    "bpp", "bppp", "qabpp"
])

metrics = set(all_results[0].keys()) - nonmetric_columns


def codec(method):
    sm = method.split(':')
    ssm = set(sm)
    speeds = set([
        'kitten', 'falcon', 'wombat', 'cheetah', 'tortoise', 'squirrel',
        'hare', 'fast'
    ])
    s = speeds.intersection(ssm)
    if sm[0] == 'custom':
        return sm[1]
    if sm[0] == 'jxl' and s:
        return 'jxl-' + list(s)[0]
    return sm[0]


data = {(m, img): {c: []
                   for c in {codec(x['method'])
                             for x in all_results}}
        for m in metrics for img in {x['image']
                                     for x in all_results}}

for r in all_results:
    c = codec(r['method'])
    img = r['image']
    bpp = r['bpp']
    for m in metrics:
        data[(m, img)][c].append((float(bpp), float(r[m])))


def pos(codec):
    if 'jxl-dis' in codec:
        return 6, codec
    elif 'jxl' in codec:
        return 7, codec
    elif 'avif' in codec:
        return 5, codec
    elif 'kdu' in codec:
        return 4, codec
    elif 'heif' in codec:
        return 3, codec
    elif 'fuif' in codec or 'pik' in codec:
        return 2, codec
    elif 'jpg' in codec or 'jpeg' in codec or 'web' in codec:
        return 1, codec
    else:
        return 0, codec


def style(codec):
    configs = {
        'jxl-cheetah': {
            'color': '#e41a1c',
            'dash': '1px, 1px',
            'width': 2
        },
        'jxl-wombat': {
            'color': '#e41a1c',
            'dash': '2px, 2px',
            'width': 2
        },
        'jxl-squirrel': {
            'color': '#e41a1c',
            'dash': '5px, 5px',
            'width': 2
        },
        'jxl-kitten': {
            'color': '#e41a1c',
            'width': 2
        },
        'jxl-dis-cheetah': {
            'color': '#377eb8',
            'dash': '1px, 1px',
            'width': 2
        },
        'jxl-dis-wombat': {
            'color': '#377eb8',
            'dash': '2px, 2px',
            'width': 2
        },
        'jxl-dis-squirrel': {
            'color': '#377eb8',
            'dash': '5px, 5px',
            'width': 2
        },
        'jxl-dis-kitten': {
            'color': '#377eb8',
            'width': 2
        },
        'rav1e.avif': {
            'color': '#4daf4a',
            'dash': '3px, 3px',
            'width': 2
        },
        '420.rav1e.avif': {
            'color': '#4daf4a',
            'dash': '1px, 1px',
            'width': 2
        },
        '444.rav1e.avif': {
            'color': '#4daf4a',
            'dash': '3px, 3px',
            'width': 2
        },
        'psnr.420.aom.avif': {
            'color': '#4daf4a',
            'dash': '5px, 5px',
            'width': 2
        },
        'psnr.444.aom.avif': {
            'color': '#4daf4a',
            'dash': '7px, 7px',
            'width': 2
        },
        'ssim.420.aom.avif': {
            'color': '#4daf4a',
            'dash': '9px, 9px',
            'width': 2
        },
        'ssim.444.aom.avif': {
            'color': '#4daf4a',
            'width': 2
        },
        'heif': {
            'color': '#984ea3',
            'width': 2
        },
        'fuif': {
            'color': '#ff7f00',
            'dash': '2px, 2px',
            'width': 2
        },
        'pik-cfp': {
            'color': '#ff7f00',
            'width': 2
        },
        'pik-cfp-fast': {
            'color': '#ff7f00',
            'dash': '4px, 4px',
            'width': 2
        },
        'webp': {
            'color': '#000000',
            'width': 2
        },
        'jpeg': {
            'color': '#a65628',
            'width': 2
        },
        'xt.jpg': {
            'color': '#a65628',
            'width': 2
        },
        'perc1.kdu.j2k': {
            'color': '#f781bf',
            'dash': '1px, 1px',
            'width': 2
        },
        'perc2.kdu.j2k': {
            'color': '#f781bf',
            'dash': '3px, 3px',
            'width': 2
        },
        'perc3.kdu.j2k': {
            'color': '#f781bf',
            'dash': '5px, 5px',
            'width': 2
        },
        'perc4.kdu.j2k': {
            'color': '#f781bf',
            'dash': '7px, 7px',
            'width': 2
        },
        'default.kdu.j2k': {
            'color': '#f781bf',
            'width': 2
        },
    }
    return configs.get(codec, dict())


visible_by_default = set([
    'jxl-kitten', 'ssim.444.aom.avif', 'heif', 'webp', 'jpeg', 'xt.jpg',
    'default.kdu.j2k'
])

column_remap = {
    'p': '6-Butteraugli',
    'dist': 'Max-Butteraugli',
    'psnr': "PSNR-YUV 6/8 Y",
    'MS-SSIM-Y': '-log10(1 - MS-SSIM-Y)',
    'puSSIM': '-log10(1 - puSSIM)',
    'FSIM-Y': '-log10(1 - FSIM-Y)',
    'FSIM-RGB': '-log10(1 - FSIM-RGB)',
    'VMAF': '-log10(1 - VMAF / 100)',
}


def remap(metric):
    funs = {
        'MS-SSIM-Y': lambda x: -math.log10(1 - x),
        'puSSIM': lambda x: -math.log10(1 - x),
        'FSIM-Y': lambda x: -math.log10(1 - x),
        'FSIM-RGB': lambda x: -math.log10(1 - x),
        'VMAF': lambda x: -math.log10(1 + 1e-8 - x / 100),
    }
    return funs.get(metric, lambda x: x)


for (m, img) in data:
    fname = "%s/%s_%s" % (output_dir, m, img)
    fig = go.Figure()
    for method in sorted(data[(m, img)].keys(), key=pos):
        vals = data[(m, img)][method]
        zvals = list(zip(*sorted(vals)))
        if not zvals:
            continue
        fig.add_trace(
            go.Scatter(x=zvals[0],
                       y=[remap(m)(x) for x in zvals[1]],
                       mode='lines',
                       name=method,
                       line=style(method),
                       visible=True
                       if method in visible_by_default else 'legendonly'))
    fig.update_layout(title=img,
                      xaxis_title='bpp',
                      yaxis_title=column_remap.get(m, m))
    fig.update_xaxes(type='log')
    if OUTPUT == 'html':
        fig.write_html(fname + '.html', include_plotlyjs='directory')
    else:
        fig.write_image(fname + '.' + OUTPUT, scale=4)
