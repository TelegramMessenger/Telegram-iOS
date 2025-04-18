#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.


"""build_stats.py: Gather statistics about sizes of dependencies.

This tools computes a realistic estimate of the size contribution to a binary
from a statically linked library. Statically linked libraries compiled with
-ffunction-sections and linked -gc-sections mean that we could drop part of the
library at the final binary linking time. This tool takes that into account the
symbols that end up in the final binary and not just all the symbols of the
components.
"""

import argparse
import collections
import itertools
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

# Ignore functions with stack size smaller than this value.
MIN_STACK_SIZE = 32


Symbol = collections.namedtuple('Symbol', ['address', 'size', 'typ', 'name'])

# Represents the stack size information of a function (defined by its address).
SymbolStack = collections.namedtuple('SymbolStack',
                                     ['address', 'stack_size'])

ObjectStats = collections.namedtuple('ObjectStats',
                                     ['name', 'in_partition', 'size_map'])

# An object target file in the build system.
Target = collections.namedtuple('Target',
                                ['name', 'deps', 'filename'])

# Sections that end up in the binary file.
# t - text (code), d - global non-const data, n/r - read-only data,
# w - weak symbols (likely inline code not inlined),
# v - weak symbols (vtable / typeinfo)
# u - unique symbols
BIN_SIZE = 'tdnrwvu'

# Sections that end up in static RAM.
RAM_SIZE = 'dbs'

# u - symbols imported from some other library
# a - absolute address symbols
IGNORE_SYMBOLS = 'ua'

SIMD_NAMESPACES = [
    'N_SCALAR', 'N_WASM', 'N_NEON', 'N_PPC8', 'N_SSE4', 'N_AVX2', 'N_AVX3']


def LoadSymbols(filename):
  ret = []
  nmout = subprocess.check_output(['nm', '--format=posix', filename])
  for line in nmout.decode('utf-8').splitlines():
    if line.rstrip().endswith(':'):
      # Ignore object names.
      continue
    # symbol_name, symbol_type, (optional) address, (optional) size
    symlist = line.rstrip().split(' ')
    assert 2 <= len(symlist) <= 4
    ret.append(Symbol(
        int(symlist[2], 16) if len(symlist) > 2 else None,
        int(symlist[3], 16) if len(symlist) > 3 else None,
        symlist[1],
        symlist[0]))
  return ret

def LoadTargetCommand(target, build_dir):
  stdout = subprocess.check_output(
      ['ninja', '-C', build_dir, '-t', 'commands', target])
  # The last command is always the command to build (link) the requested
  # target.
  command = stdout.splitlines()[-1]
  return command.decode('utf-8')


def LoadTarget(target, build_dir):
  """Loads a build system target and its dependencies into a Target object"""
  if target.endswith('.o'):
    # Speed up this case.
    return Target(target, [], target)

  link_params = LoadTargetCommand(target, build_dir).split()
  if 'cmake_symlink_library' in link_params:
    # The target is a library symlinked, use the target of the symlink
    # instead.
    target = link_params[link_params.index('cmake_symlink_library') + 1]
    link_params = LoadTargetCommand(target, build_dir).split()

  # The target name is not always the same as the filename of the output, for
  # example, "djxl" target generates "tools/djxl" file.
  if '-o' in link_params:
    target_filename = link_params[link_params.index('-o') + 1]
  elif target.endswith('.a'):
    # Command is '/path/to/ar', 'qc', 'target.a', ...
    target_filename = link_params[link_params.index('qc') + 1]
  else:
    raise Exception('Unknown "%s" output filename in command: %r' %
                    (target, link_params))

  tgt_libs = []
  for entry in link_params:
    if not entry or not (entry.endswith('.o') or entry.endswith('.a')):
      continue
    if entry == target_filename:
      continue
    fn = os.path.join(build_dir, entry)
    if not os.path.exists(fn):
      continue
    if entry in tgt_libs:
      continue
    tgt_libs.append(entry)

  return Target(target, tgt_libs, target_filename)


def TargetTransitiveDeps(all_tgts, target):
  """Returns the list of all transitive dependencies of target"""
  ret = all_tgts[target].deps
  # There can't be loop dependencies in the targets.
  i = 0
  while i < len(ret):
    ret.extend(all_tgts[ret[i]].deps)
    i += 1
  return ret


def LoadStackSizes(filename, binutils=''):
  """Loads the stack size used by functions from the ELF.

  This function loads the stack size the compiler stored in the .stack_sizes
  section, which can be done by compiling with -fstack-size-section in clang.
  """
  with tempfile.NamedTemporaryFile() as stack_sizes_sec:
    subprocess.check_call(
        [binutils + 'objcopy', '-O', 'binary', '--only-section=.stack_sizes',
         '--set-section-flags', '.stack_sizes=alloc', filename,
         stack_sizes_sec.name])
    stack_sizes = stack_sizes_sec.read()
  # From the documentation:
  #  The section will contain an array of pairs of function symbol values
  #  (pointer size) and stack sizes (unsigned LEB128). The stack size values
  #  only include the space allocated in the function prologue. Functions with
  #  dynamic stack allocations are not included.

  # Get the pointer format based on the ELF file.
  output = subprocess.check_output(
      [binutils + 'objdump', '-a', filename]).decode('utf-8')
  elf_format = re.search('file format (.*)$', output, re.MULTILINE).group(1)
  if elf_format.startswith('elf64-little') or elf_format == 'elf64-x86-64':
    pointer_fmt = '<Q'
  elif elf_format.startswith('elf32-little') or elf_format == 'elf32-i386':
    pointer_fmt = '<I'
  else:
    raise Exception('Unknown ELF format: %s' % elf_format)
  pointer_size = struct.calcsize(pointer_fmt)

  ret = []
  i = 0
  while i < len(stack_sizes):
    assert len(stack_sizes) >= i + pointer_size
    addr, = struct.unpack_from(pointer_fmt, stack_sizes, i)
    i += pointer_size
    # Parse LEB128
    size = 0
    for j in range(10):
      b = stack_sizes[i]
      i += 1
      size += (b & 0x7f) << (7 * j)
      if (b & 0x80) == 0:
        break
    if size >= MIN_STACK_SIZE:
      ret.append(SymbolStack(addr, size))
  return ret


def TargetSize(symbols, symbol_filter=None):
  ret = {}
  for sym in symbols:
    if not sym.size or (symbol_filter is not None and
                        sym.name not in symbol_filter):
      continue
    t = sym.typ.lower()
    # We can remove symbols if they appear in multiple objects since they will
    # be merged by the linker.
    if symbol_filter is not None and (t == sym.typ or t in 'wv'):
      symbol_filter.remove(sym.name)
    ret.setdefault(t, 0)
    ret[t] += sym.size
  return ret


def PrintStats(stats):
  """Print a table with the size stats for a target"""
  table = []
  sum_bin_size = 0
  sum_ram_size = 0

  for objstat in stats:
    bin_size = 0
    ram_size = 0
    for typ, size in objstat.size_map.items():
      if typ in BIN_SIZE:
        bin_size += size
      if typ in RAM_SIZE:
        ram_size += size
      if typ not in BIN_SIZE + RAM_SIZE:
        raise Exception('Unknown type "%s"' % typ)
    if objstat.in_partition:
      sum_bin_size += bin_size
      sum_ram_size += ram_size

    table.append((objstat.name, bin_size, ram_size))
  mx_bin_size = max(row[1] for row in table)
  mx_ram_size = max(row[2] for row in table)

  table.append(('-- unknown --', mx_bin_size - sum_bin_size,
                mx_ram_size - sum_ram_size))

  # Print the table
  print('%-32s %17s %17s' % ('Object name', 'Binary size', 'Static RAM size'))
  for name, bin_size, ram_size in table:
    print('%-32s %8d (%5.1f%%) %8d (%5.1f%%)' % (
        name, bin_size, 100. * bin_size / mx_bin_size,
        ram_size, (100. * ram_size / mx_ram_size) if mx_ram_size else 0))
  print()


def PrintStackStats(tgt_stack_sizes, top_entries=20):
  if not tgt_stack_sizes:
    return
  print(' Stack   Symbol name')
  for i, (name, size) in zip(itertools.count(), tgt_stack_sizes.items()):
    if top_entries > 0 and i >= top_entries:
      break
    print('%8d %s' % (size, name))
  print()


def PrintTopSymbols(tgt_top_symbols):
  if not tgt_top_symbols:
    return
  print(' Size     T Symbol name')
  for size, typ, name in tgt_top_symbols:
    print('%9d %s %s' % (size, typ, name))
  print()


def SizeStats(args):
  """Main entry point of the program after parsing parameters.

  Computes the size statistics of the given targets and their components."""
  # The dictionary with the stats that we store on disk as a json. This includes
  # one entry per passed args.target.
  stats = {}

  # Cache of Target object of a target.
  tgts = {}

  # Load all the targets.
  pending = set(args.target)
  while pending:
    target = pending.pop()
    tgt = LoadTarget(target, args.build_dir)
    tgts[target] = tgt
    if args.recursive:
      for dep in tgt.deps:
        if dep not in tgts:
          pending.add(dep)

  # Cache of symbols of a target.
  syms = {}
  # Load the symbols from the all targets and its deps.
  all_deps = set(tgts.keys()).union(*[set(tgt.deps) for tgt in tgts.values()])
  for entry in all_deps:
    fn = os.path.join(args.build_dir,
                      tgts[entry].filename if entry in tgts else entry)
    syms[entry] = LoadSymbols(fn)

  for target in args.target:
    tgt_stats = []
    tgt = tgts[target]

    tgt_syms = syms[target]
    used_syms = set()
    for sym in tgt_syms:
      if sym.typ.lower() in BIN_SIZE + RAM_SIZE:
        used_syms.add(sym.name)
      elif sym.typ.lower() in IGNORE_SYMBOLS:
        continue
      else:
        print('Unknown: %s %s' % (sym.typ, sym.name))

    target_path = os.path.join(args.build_dir, tgt.filename)
    sym_stacks = []
    if not target_path.endswith('.a'):
      sym_stacks = LoadStackSizes(target_path, args.binutils)
    symbols_by_addr = {sym.address: sym for sym in tgt_syms
                          if sym.typ.lower() in 'tw'}
    tgt_stack_sizes = collections.OrderedDict()
    for sym_stack in sorted(sym_stacks, key=lambda s: -s.stack_size):
      tgt_stack_sizes[
          symbols_by_addr[sym_stack.address].name] = sym_stack.stack_size

    tgt_top_symbols = []
    if args.top_symbols:
      tgt_top_symbols = [(sym.size, sym.typ, sym.name) for sym in tgt_syms
                         if sym.name in used_syms and sym.size]
      tgt_top_symbols.sort(key=lambda t: (-t[0], t[2]))
      tgt_top_symbols = tgt_top_symbols[:args.top_symbols]

    tgt_size = TargetSize(tgt_syms)
    tgt_stats.append(ObjectStats(target, False, tgt_size))

    # Split out by SIMD.
    for namespace in SIMD_NAMESPACES:
      mangled = str(len(namespace)) + namespace
      if not any(mangled in sym.name for sym in tgt_syms):
        continue
      ret = {}
      for sym in tgt_syms:
        if not sym.size or mangled not in sym.name:
          continue
        t = sym.typ.lower()
        ret.setdefault(t, 0)
        ret[t] += sym.size
      # SIMD namespaces are not part of the partition, they are already included
      # in the jpegxl-static normally.
      if not ret:
        continue
      tgt_stats.append(ObjectStats('\\--> ' + namespace, False, ret))

    for obj in tgt.deps:
      dep_used_syms = used_syms.copy()
      obj_size = TargetSize(syms[obj], used_syms)
      if not obj_size:
        continue
      tgt_stats.append(ObjectStats(os.path.basename(obj), True, obj_size))
      if args.recursive:
        # Not really recursive, but it shows all the remaining deps at a second
        # level.
        for obj_dep in sorted(TargetTransitiveDeps(tgts, obj),
                              key=os.path.basename):
          obj_dep_size = TargetSize(syms[obj_dep], dep_used_syms)
          if not obj_dep_size:
            continue
          tgt_stats.append(ObjectStats(
              '   '+ os.path.basename(obj_dep), False, obj_dep_size))

    PrintStats(tgt_stats)
    PrintStackStats(tgt_stack_sizes)
    PrintTopSymbols(tgt_top_symbols)
    stats[target] = {
        'build': tgt_stats,
        'stack': tgt_stack_sizes,
        'top': tgt_top_symbols,
    }

  if args.save:
    with open(args.save, 'w') as f:
      json.dump(stats, f)

  # Check the maximum stack size.
  exit_code = 0
  if args.max_stack:
    for name, size in tgt_stack_sizes.items():
      if size > args.max_stack:
        print('Error: %s exceeds stack limit: %d vs %d' % (
                  name, size, args.max_stack),
              file=sys.stderr)
        exit_code = 1

  return exit_code

def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('target', type=str, nargs='+',
                      help='target(s) to analyze')
  parser.add_argument('--build-dir', default='build',
                      help='path to the build directory')
  parser.add_argument('--save', default=None,
                      help='path to save the stats as JSON file')
  parser.add_argument('-r', '--recursive', default=False, action='store_true',
                      help='Print recursive entries.')
  parser.add_argument('--top-symbols', default=0, type=int,
                      help='Number of largest symbols to print')
  parser.add_argument('--binutils', default='',
                      help='prefix path to binutils tools, such as '
                           'aarch64-linux-gnu-')
  parser.add_argument('--max-stack', default=None, type=int,
                      help=('Maximum static stack size of a function. If a '
                            'static stack is larger it will exit with an error '
                            'code.'))
  args = parser.parse_args()
  sys.exit(SizeStats(args))


if __name__ == '__main__':
  main()
