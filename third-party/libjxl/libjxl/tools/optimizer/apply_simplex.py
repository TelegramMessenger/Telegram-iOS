#!/usr/bin/python
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""apply_simplex.py: Updates constants based on results of simplex search.

To use this tool, the simplex search parameters must we wrapped in a bias(n)
function call that returns the value of the VARn environment variable. The
tool reads a text file containing the simplex definition that simplex_fork.py
has written, and updates the target source files by substituting the bias(n)
function calls with the (n+1)th coordinate of the simplex vector, and also
simplifies these expressions by evaluating them to a sinlge floating point
literal.

The tool recognizes and evaluates the following expressions:
  <constant> + bias(n),
  <constant> * bias(n),
  <constant> + <coeff> * bias(n).

The --keep_bias command-line flag can be used to continue an aborted simplex
search. This will keep the same bias(n) terms in the code, but would update the
surronding constants.

The --index_min and --index_max flags can be used to update only a subset of the
bias(n) parameters.
"""

import argparse
import re
import sys

def ParseSimplex(fn):
    """Returns the simplex definition written by simplex_fork.py"""

    with open(fn, "r") as f:
        line = f.readline()
        vec = eval(line)
    return vec


def PythonExpr(c_expr):
    """Removes the f at the end of float literals"""

    def repl(m):
        return m.group(1)

    return re.sub("(\d+)f", repl, c_expr)


def UpdateSourceFile(fn, vec, keep_bias, id_min, id_max, minval):
    """Updates expressions containing a bias(N) term."""

    with open(fn, "r") as f:
        lines_in = f.readlines()
        lines_out = []
        rbias = "(bias\((\d+)\))"
        r = " -?\d+\.\d+f?( (\+|-|\*) (\d+\.\d+f? \* )?" + rbias + ")"
        for line in lines_in:
            line_out = line
            x = re.search(r, line)
            if x:
                id = int(x.group(5))
                if id >= id_min and id <= id_max:
                    expr = re.sub(rbias, str(vec[id + 1]), x.group(0))
                    val = eval(PythonExpr(expr))
                    if minval and val < minval:
                        val = minval
                    expr_out = " " + str(val) + "f"
                    if keep_bias:
                        expr_out += x.group(1)
                    line_out = re.sub(r, expr_out, line)
            lines_out.append(line_out)

    with open(fn, "w") as f:
        f.writelines(lines_out)
        f.close()


def ApplySimplex(args):
  """Main entry point of the program after parsing parameters."""

  vec = ParseSimplex(args.simplex)
  for fn in args.target:
      UpdateSourceFile(fn, vec, args.keep_bias, args.index_min, args.index_max,
                       args.minval)
  return 0


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('target', type=str, nargs='+',
                      help='source file(s) to update')
  parser.add_argument('--simplex', default='best_simplex.txt',
                      help='simplex to apply to the code')
  parser.add_argument('--keep_bias', default=False, action='store_true',
                      help='keep the bias term in the code, can be used to ' +
                      'continue simplex search')
  parser.add_argument('--index_min', type=int, default=0,
                      help='start index of the simplex to apply')
  parser.add_argument('--index_max', type=int, default=9999,
                      help='last index of the simplex to apply')
  parser.add_argument('--minval', type=float, default=None,
                      help='apply a minimum to expression results')
  args = parser.parse_args()
  sys.exit(ApplySimplex(args))


if __name__ == '__main__':
  main()
