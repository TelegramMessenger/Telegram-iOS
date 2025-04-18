#!/usr/bin/env python3

# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""Produces demos for how progressive-saliency encoding would look like.

As long as we do not have a progressive decoder that allows showing images
generated from partially-available data, we can resort to building
animated gifs that show how progressive loading would look like.

Method:

1. JPEG-XL encode the image, but stop at the pre-final (2nd) step.
2. Use separate tool to compute a heatmap which shows where differences between
   the pre-final and final image are expected to be perceptually worst.
3. Use this heatmap to JPEG-XL encode the image with the final step split into
   'salient parts only' and 'non-salient parts'. Generate a sequence of images
   that stop decoding after the 1st, 2nd, 3rd, 4th step. JPEG-XL decode these
   truncated images back to PNG.
4. Measure byte sizes of the truncated-encoded images.
5. Build an animated GIF with variable delays by calling ImageMagick's
   `convert` command.

"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from six.moves import zip
import ast  # For ast.literal_eval() only.
import os
import re
import shlex
import subprocess
import sys

_BLOCKSIZE = 8

_CONF_PARSERS = dict(
    keep_tempfiles=lambda s: bool(ast.literal_eval(s)),
    heatmap_command=shlex.split,
    simulated_progressive_loading_time_sec=float,
    simulated_progressive_loading_delay_until_looparound_sec=float,
    jpegxl_encoder=shlex.split,
    jpegxl_decoder=shlex.split,
    blurring=lambda s: s.split(),
)


def parse_config(config_filename):
  """Parses the configuration file."""
  conf = {}
  re_comment = re.compile(r'^\s*(?:#.*)?$')
  re_param = re.compile(r'^(?P<option>\w+)\s*:\s*(?P<value>.*?)\s*$')
  try:
    with open(config_filename) as h:
      for line in h:
        if re_comment.match(line):
          continue
        m = re_param.match(line)
        if not m:
          raise ValueError('Syntax error')
        conf[m.group('option')] = (
            _CONF_PARSERS[m.group('option')](m.group('value')))
  except Exception as exn:
    raise ValueError('Bad Configuration line ({}): {}'.format(exn, line))
  missing_options = set(_CONF_PARSERS) - set(conf)
  if missing_options:
    raise ValueError('Missing configuration options: ' + ', '.join(
        sorted(missing_options)))
  return conf


def generate_demo_image(config, input_filename, output_filename):
  tempfiles = []
  #
  def encode_img(input_filename, output_filename, num_steps,
                 heatmap_filename=None):
    replacements = {
        '${INPUT}': input_filename,
        '${OUTPUT}': output_filename,
        '${STEPS}': str(num_steps),
        # Heatmap argument will be provided in --param=value form.
        '${HEATMAP_ARG}': ('--saliency_map_filename=' + heatmap_filename
                           if heatmap_filename is not None else '')
        }
    # Remove empty args. This removes the heatmap-argument if no heatmap
    # is provided..
    cmd = [
        _f for _f in
        [replacements.get(arg, arg) for arg in config['jpegxl_encoder']] if _f
    ]
    tempfiles.append(output_filename)
    subprocess.call(cmd)
  #
  def decode_img(input_filename, output_filename):
    replacements = {'${INPUT}': input_filename, '${OUTPUT}': output_filename}
    cmd = [replacements.get(arg, arg) for arg in config['jpegxl_decoder']]
    tempfiles.append(output_filename)
    subprocess.call(cmd)
  #
  def generate_heatmap(orig_image_filename, coarse_grained_filename,
                       heatmap_filename):
    cmd = config['heatmap_command'] + [
        str(_BLOCKSIZE), orig_image_filename, coarse_grained_filename,
        heatmap_filename]
    tempfiles.append(heatmap_filename)
    subprocess.call(cmd)
  #
  try:
    encode_img(input_filename, output_filename + '._step1.pik', 1)
    decode_img(output_filename + '._step1.pik', output_filename + '._step1.png')
    encode_img(input_filename, output_filename + '._step2.pik', 2)
    decode_img(output_filename + '._step2.pik', output_filename + '._step2.png')
    generate_heatmap(input_filename, output_filename + '._step2.png',
                     output_filename + '._heatmap.png')
    encode_img(input_filename,
               output_filename + '._step3.pik', 3,
               output_filename + '._heatmap.png')
    encode_img(input_filename,
               output_filename + '._step4.pik', 4,
               output_filename + '._heatmap.png')
    decode_img(output_filename + '._step3.pik', output_filename + '._step3.png')
    decode_img(output_filename + '._step4.pik', output_filename + '._step4.png')
    data_sizes = [
        os.stat('{}._step{}.pik'.format(output_filename, num_step)).st_size
        for num_step in (1, 2, 3, 4)]
    time_offsets = [0] + [
        # Imagemagick's `convert` accepts delays in units of 1/100 sec.
        round(100 * config['simulated_progressive_loading_time_sec'] * size /
              data_sizes[-1]) for size in data_sizes]
    time_delays = [t_next - t_prev
                   for t_next, t_prev in zip(time_offsets[1:], time_offsets)]
    # Add a fake white initial image. As long as no usable image data is
    # available, the user will see a white background.
    subprocess.call(['convert',
                     output_filename + '._step1.png',
                     '-fill', 'white', '-colorize', '100%',
                     output_filename + '._step0.png'])
    tempfiles.append(output_filename + '._step0.png')
    subprocess.call(
        ['convert', '-loop', '0', output_filename + '._step0.png'] +
        [arg for args in [
            ['-delay', str(time_delays[n - 1]),
             '-blur', config['blurring'][n - 1],
             '{}._step{}.png'.format(output_filename, n)]
            for n in (1, 2, 3, 4)] for arg in args] +
        ['-delay', str(round(100 * config[
            'simulated_progressive_loading_delay_until_looparound_sec'])),
         output_filename + '._step4.png',
         output_filename])
  finally:
    if not config['keep_tempfiles']:
      for filename in tempfiles:
        try:
          os.unlink(filename)
        except OSError:
          pass  # May already have been deleted otherwise.


def main():
  if sys.version.startswith('2.'):
    sys.exit('This is a python3-only script.')
  if (len(sys.argv) != 4 or not sys.argv[-1].endswith('.gif')
      or not sys.argv[-2].endswith('.png')):
    sys.exit(
        'Usage: {} [config_options_file] [input.png] [output.gif]'.format(
            sys.argv[0]))
  try:
    _, config_filename, input_filename, output_filename = sys.argv
    config = parse_config(config_filename)
    generate_demo_image(config, input_filename, output_filename)
  except ValueError as exn:
    sys.exit(exn)



if __name__ == '__main__':
  main()
