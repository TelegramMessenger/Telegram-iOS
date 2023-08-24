#!/usr/bin/python
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""Implementation of simplex search for an external process.

The external process gets the input vector through environment variables.
Input of vector as setenv("VAR%dimension", val)
Getting the optimized function with regexp match from stdout
of the forked process.

https://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method

start as ./simplex_fork.py binary dimensions amount
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from six.moves import range
import copy
import os
import random
import re
import subprocess
import sys

def Midpoint(simplex):
  """Nelder-Mead-like simplex midpoint calculation."""
  simplex.sort()
  dim = len(simplex) - 1
  retval = [None] + [0.0] * dim
  for i in range(1, dim + 1):
    for k in range(dim):
      retval[i] += simplex[k][i]
    retval[i] /= dim
  return retval


def Subtract(a, b):
  """Vector arithmetic, with [0] being ignored."""
  return [None if k == 0 else a[k] - b[k] for k in range(len(a))]

def Add(a, b):
  """Vector arithmetic, with [0] being ignored."""
  return [None if k == 0 else a[k] + b[k] for k in range(len(a))]

def Average(a, b):
  """Vector arithmetic, with [0] being ignored."""
  return [None if k == 0 else 0.5 * (a[k] + b[k]) for k in range(len(a))]


eval_hash = {}
g_best_val = None

def EvalCacheForget():
  global eval_hash
  eval_hash = {}

def RandomizedJxlCodecs():
  retval = []
  minval = 0.5
  maxval = 8.3
  rangeval = maxval/minval
  steps = 17
  for i in range(steps):
    mul = minval * rangeval**(float(i)/(steps - 1))
    mul *= 0.99 + 0.05 * random.random()
    retval.append("jxl:d%.4f" % mul)
  for i in range(steps - 1):
    mul = minval * rangeval**(float(i+0.5)/(steps - 1))
    mul *= 0.99 + 0.05 * random.random()
    retval.append("jxl:d%.4f" % mul)
  return ",".join(retval)

g_codecs = RandomizedJxlCodecs()

def Eval(vec, binary_name, cached=True):
  """Evaluates the objective function by forking a process.

  Args:
    vec: [0] will be set to the objective function, [1:] will
      contain the vector position for the objective function.
    binary_name: the name of the binary that evaluates the value.
  """
  global eval_hash
  global g_codecs
  global g_best_val
  key = ""
  # os.environ["BUTTERAUGLI_OPTIMIZE"] = "1"
  for i in range(300):
    os.environ["VAR%d" % i] = "0"
  for i in range(len(vec) - 1):
    os.environ["VAR%d" % i] = str(vec[i + 1])
    key += str(vec[i + 1]) + ":"
  if cached and (key in eval_hash):
    vec[0] = eval_hash[key]
    return

  process = subprocess.Popen(
      (binary_name,
       '--input',
       '/usr/local/google/home/jyrki/newcorpus/split/*.png',
       '--error_pnorm=4',
       '--more_columns',
       '--codec', g_codecs),
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      env=dict(os.environ))

  # process.wait()
  found_score = False
  vec[0] = 1.0
  dct2 = 0.0
  dct4 = 0.0
  dct16 = 0.0
  dct32 = 0.0
  n = 0
  for line in process.communicate(input=None)[0].splitlines():
    print("BE", line)
    sys.stdout.flush()
    if line[0:3] == b'jxl':
      bpp = line.split()[3]
      dist_pnorm = line.split()[9]
      dist_max = line.split()[6]
      vec[0] *= float(dist_pnorm) * float(bpp) / 16.0
      #vec[0] *= (float(dist_max) * float(bpp) / 16.0) ** 0.01
      n += 1
      found_score = True
      distance = float(line.split()[0].split(b'd')[-1])
      #faultybpp = 1.0 + 0.43 * ((float(bpp) * distance ** 0.69) - 1.595) ** 2
      #vec[0] *= faultybpp

  print("eval: ", vec)
  if (vec[0] <= 0.0):
    vec[0] = 1e30
  if found_score:
    eval_hash[key] = vec[0]
    if not g_best_val or vec[0] < g_best_val:
      g_best_val = vec[0]
      print("\nSaving best simplex\n")
      with open("best_simplex.txt", "w") as f:
        print(vec, file=f)
    return
  vec[0] = 1e33
  return
  # sys.exit("awful things happened")

def Reflect(simplex, binary):
  """Main iteration step of Nelder-Mead optimization. Modifies `simplex`."""
  simplex.sort()
  last = simplex[-1]
  mid = Midpoint(simplex)
  diff = Subtract(mid, last)
  mirrored = Add(mid, diff)
  Eval(mirrored, binary)
  if mirrored[0] > simplex[-2][0]:
    print("\nStill worst\n\n")
    # Still the worst, shrink towards the best.
    shrinking = Average(simplex[-1], simplex[0])
    Eval(shrinking, binary)
    print("\nshrinking...\n\n")
    simplex[-1] = shrinking
    return
  if mirrored[0] < simplex[0][0]:
    # new best
    print("\nNew Best\n\n")
    even_further = Add(mirrored, diff)
    Eval(even_further, binary)
    if even_further[0] < mirrored[0]:
      print("\nEven Further\n\n")
      mirrored = even_further
    simplex[-1] = mirrored
    # try to extend
    return
  else:
    # not a best, not a worst point
    simplex[-1] = mirrored


def OneDimensionalSearch(simplex, shrink, index):
  # last appended was better than the best so far, try to replace it
  last_attempt = simplex[-1][:]
  best = simplex[0]
  if last_attempt[0] < best[0]:
    # try expansion of the amount
    diff = simplex[-1][index] - simplex[0][index]
    simplex[-1][index] = simplex[0][index] + shrink * diff
    Eval(simplex[-1], g_binary)
    if simplex[-1][0] < last_attempt[0]:
      # it got better
      return True
  elif last_attempt[0] >= 0:
    diff = simplex[-1][index] - simplex[0][index]
    simplex[-1][index] = simplex[0][index] - diff
    Eval(simplex[-1], g_binary)
    if simplex[-1][0] < last_attempt[0]:
      # it got better
      return True
  simplex[-1] = last_attempt
  return False

def InitialSimplex(vec, dim, amount):
  """Initialize the simplex at origin."""
  EvalCacheForget()
  best = vec[:]
  Eval(best, g_binary)
  retval = [best]
  comp_order = list(range(1, dim + 1))
  random.shuffle(comp_order)

  for i in range(dim):
    index = comp_order[i]
    best = retval[0][:]
    best[index] += amount
    Eval(best, g_binary)
    retval.append(best)
    do_shrink = True
    while OneDimensionalSearch(retval, 2.0, index):
      print("OneDimensionalSearch-Grow")
    while OneDimensionalSearch(retval, 1.1, index):
      print("OneDimensionalSearch-SlowGrow")
      do_shrink = False
    if do_shrink:
      while OneDimensionalSearch(retval, 0.9, index):
        print("OneDimensionalSearch-SlowShrinking")
    retval.sort()
  return retval


if len(sys.argv) != 4:
  print("usage: ", sys.argv[0], "binary-name number-of-dimensions simplex-size")
  exit(1)

g_dim = int(sys.argv[2])
g_amount = float(sys.argv[3])
g_binary = sys.argv[1]
g_simplex = InitialSimplex([None] + [0.0] * g_dim,
                           g_dim, 7.0 * g_amount)
best = g_simplex[0][:]
g_codecs = RandomizedJxlCodecs()
g_simplex = InitialSimplex(best, g_dim, g_amount * 2.47)
best = g_simplex[0][:]
g_simplex = InitialSimplex(best, g_dim, g_amount)
best = g_simplex[0][:]
g_simplex = InitialSimplex(best, g_dim, g_amount * 0.33)
best = g_simplex[0][:]

for restarts in range(99999):
  for ii in range(g_dim * 5):
    g_simplex.sort()
    print("reflect", ii, g_simplex[0])
    Reflect(g_simplex, g_binary)

  mulli = 0.1 + 15 * random.random()**2.0
  g_codecs = RandomizedJxlCodecs()
  print("\n\n\nRestart", restarts, "mulli", mulli)
  g_simplex.sort()
  best = g_simplex[0][:]
  g_simplex = InitialSimplex(best, g_dim, g_amount * mulli)
