% Copyright (c) the JPEG XL Project Authors. All rights reserved.
%
% Use of this source code is governed by a BSD-style
% license that can be found in the LICENSE file.

pkg load image;

args = argv();

original_filename = args{1};
decoded_filename = args{2};

original = pfs_read_luminance(original_filename);
decoded = pfs_read_luminance(decoded_filename);

res = hdrvdp(decoded, original, 'luminance', 30, {});
printf("%f\n", res.Q);
