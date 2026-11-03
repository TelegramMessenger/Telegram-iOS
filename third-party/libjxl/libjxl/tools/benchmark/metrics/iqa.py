#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

import os
import sys
import pathlib
import torch
from torchvision import transforms
import numpy as np

path = pathlib.Path(__file__).parent.absolute(
) / '..' / '..' / '..' / 'third_party' / 'IQA-optimization'
sys.path.append(str(path))

from IQA_pytorch import SSIM, MS_SSIM, CW_SSIM, GMSD, LPIPSvgg, DISTS, NLPD, FSIM, VSI, VIFs, VIF, MAD


# only really works with the output from JXL, but we don't need more than that.
def read_pfm(fname):
    with open(fname, 'rb') as f:
        header_width_height = []
        while len(header_width_height) < 3:
            header_width_height += f.readline().rstrip().split()
        header, width, height = header_width_height
        assert header == b'PF' or header == b'Pf'
        width, height = int(width), int(height)
        scale = float(f.readline().rstrip())
        fmt = '<f' if scale < 0 else '>f'
        data = np.fromfile(f, fmt)
        if header == b'PF':
            out = np.reshape(data, (height, width, 3))[::-1, :, :]
        else:
            out = np.reshape(data, (height, width))[::-1, :]
        return out.astype(np.float)


D_dict = {
    'cwssim': CW_SSIM,
    'dists': DISTS,
    'fsim': FSIM,
    'gmsd': GMSD,
    'lpips': LPIPSvgg,
    'mad': MAD,
    'msssim': MS_SSIM,
    'nlpd': NLPD,
    'ssim': SSIM,
    'vif': VIF,
    'vsi': VSI,
}

algo = os.path.basename(sys.argv[1]).split('.')[0]
algo, color = algo.split('-')

channels = 3

if color == 'y':
    channels = 1


def Load(path):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    transform = transforms.Compose([
        transforms.ToTensor(),
    ])
    img = read_pfm(path)
    if len(img.shape) == 3 and channels == 1:  # rgb -> Y
        assert img.shape[2] == 3
        tmp = np.zeros((img.shape[0], img.shape[1], 1), dtype=float)
        tmp[:, :, 0] = (0.2126 * img[:, :, 0] + 0.7152 * img[:, :, 1] +
                        0.0722 * img[:, :, 2])
        img = tmp
    if len(img.shape) == 2 and channels == 3:  # Y -> rgb
        gray = img
        img = np.zeros((img.shape[0], img.shape[1], 3), dtype=float)
        img[:, :, 0] = img[:, :, 1] = img[:, :, 2] = gray
    if len(img.shape) == 3:
        img = np.transpose(img, axes=(2, 0, 1)).copy()
    return torch.FloatTensor(img).unsqueeze(0).to(device)


ref_img = Load(sys.argv[2])
enc_img = Load(sys.argv[3])
D = D_dict[algo](channels=channels)
score = D(ref_img, enc_img, as_loss=False)

with open(sys.argv[4], 'w') as f:
    print(score.item(), file=f)
