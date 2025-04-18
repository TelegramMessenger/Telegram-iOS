% Copyright (c) the JPEG XL Project Authors. All rights reserved.
%
% Use of this source code is governed by a BSD-style
% license that can be found in the LICENSE file.

pkg load image;

args = argv();

metric = args{1};
original_filename = args{2};
decoded_filename = args{3};

original = pfs_read_luminance(original_filename);
decoded = pfs_read_luminance(decoded_filename);

switch (metric)
  case "psnr"
    res = qm_pu2_psnr(original, decoded);
  case "ssim"
    res = qm_pu2_ssim(original, decoded);
  otherwise
    error(sprintf("unrecognized metric %s", metric));
end

printf("%f\n", res);
