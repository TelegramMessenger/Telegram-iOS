#!/usr/bin/python
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""Script to update jpegli global scale after a change affecting quality.

start as ./update_jpegli_global_scale.py build <corpus-dir>
"""

import os
import re
import subprocess
import sys

def SourceFileName():
  return "lib/jpegli/quant.cc"

def ScalePattern(scale_type):
  return "constexpr float kGlobalScale" + scale_type + " = ";

def CodecName(scale_type):
  if scale_type == "YCbCr":
    return "jpeg:enc-jpegli:q90"
  elif scale_type == "XYB":
    return "jpeg:enc-jpegli:xyb:q90"
  else:
    raise Exception("Unknown scale type %s" % scale_type)
  
def ReadGlobalScale(scale_type):
  pattern = ScalePattern(scale_type)
  with open(SourceFileName()) as f:
    for line in f.read().splitlines():
      if line.startswith(pattern):
        return float(line[len(pattern):-2])
  raise Exception("Global scale %s not found." % scale_type)
  
    
def UpdateGlobalScale(scale_type, new_val):
  pattern = ScalePattern(scale_type)
  found_pattern = False
  fdata = ""
  with open(SourceFileName()) as f:
    for line in f.read().splitlines():
      if line.startswith(pattern):
        fdata += pattern + "%.8ff;\n" % new_val
        found_pattern = True
      else:
        fdata += line + "\n"
  if not found_pattern:
    raise Exception("Global scale %s not found." % scale_type)
  with open(SourceFileName(), "w") as f:
    f.write(fdata)
    f.close()

def EvalPnorm(build_dir, corpus_dir, codec):
  compile_args = ["ninja", "-C", build_dir, "tools/benchmark_xl"]
  try:
    subprocess.check_output(compile_args)
  except:
    subprocess.check_call(compile_args)
  process = subprocess.Popen(
    (os.path.join(build_dir, "tools/benchmark_xl"),
     "--input", os.path.join(corpus_dir, "*.png"),
     "--codec", codec),
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE)
  (out, err) = process.communicate(input=None)
  for line in out.splitlines():
    if line.startswith(codec):
      return float(line.split()[8])
  raise Exception("Unexpected benchmark output:\n%sstderr:\n%s" % (out, err))


if len(sys.argv) != 3:
  print("usage: ", sys.argv[0], "build-dir corpus-dir")
  exit(1)

build_dir = sys.argv[1]
corpus_dir = sys.argv[2]
    
jpeg_pnorm = EvalPnorm(build_dir, corpus_dir, "jpeg:q90")

print("Libjpeg pnorm: %.8f" % jpeg_pnorm)

for scale_type in ["YCbCr", "XYB"]:
  scale = ReadGlobalScale(scale_type)
  best_scale = scale
  best_rel_error = 100.0
  for i in range(10):
    jpegli_pnorm = EvalPnorm(build_dir, corpus_dir, CodecName(scale_type))
    rel_error = abs(jpegli_pnorm / jpeg_pnorm - 1)
    print("[%-5s] scale: %.8f  pnorm: %.8f  error: %.8f" %
          (scale_type, scale, jpegli_pnorm, rel_error))
    if rel_error < best_rel_error:
      best_rel_error = rel_error
      best_scale = scale
    if rel_error < 0.0001:
      break
    scale = scale * jpeg_pnorm / jpegli_pnorm
    UpdateGlobalScale(scale_type, scale)
  UpdateGlobalScale(scale_type, best_scale)
