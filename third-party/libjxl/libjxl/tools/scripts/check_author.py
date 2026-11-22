#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.


"""check_author.py: Check that a given author is listed in the AUTHORS file."""

import argparse
import fnmatch
import os
import re
import sys


def IsAuthorInFile(email, name, filename):
  """Return whether we find the name/email in the authors filename"""
  # Organization emails have emails listed as <*@domain.com>. This matches those
  # patterns.
  email_pattern_regex = re.compile(r'.*<([^>]+)>')

  with open(filename, 'r') as f:
    for line in f:
      line = line.strip()
      if line.startswith('#') or not line:
        continue
      # Exact match for a line without an email is OK.
      if line == name:
        return True
      # Exact email address match is OK, even if the name is different.
      if fnmatch.fnmatch(line, '* <%s>' % email):
        print(
            "User %s <%s> matched with different name %s" % (name, email, line),
            file=sys.stderr)
        return True
      # Organizations often have *@domain.com email patterns which don't match
      # the name.
      if '*' in line:
        m = email_pattern_regex.match(line)
        if m and fnmatch.fnmatch(email, m.group(1)):
          print("User %s <%s> matched pattern %s" % (name, email, line),
                file=sys.stderr)
          return True
  return False

def IndividualsInAlphabeticOrder(filename):
  """Checks if the names are in alphabetic order"""
  with open(filename, 'r') as f:
    lines = f.readlines()
    individual_header = '# Individuals:\n'
    if individual_header in lines:
      individual_authors = lines[lines.index(individual_header) + 1:]
      sorted_authors = sorted(individual_authors, key=str.casefold)
      if sorted_authors == individual_authors:
        print("Individual authors are sorted alphabetically.")
        return True
      else:
        print("Individual authors are not sorted alphabetically."
              " The expected order is:")
        print(''.join(sorted_authors))
        return False
    else:
      print("Cannot find line '# Individuals:' in file.")
  return False


def CheckAuthor(args):
  authors_path = os.path.join(args.source_dir, 'AUTHORS')
  author_in_file = IsAuthorInFile(
      args.email, args.name, authors_path)
  if not author_in_file:
    print("User %s <%s> not found, please add yourself to the AUTHORS file" % (
              args.name, args.email),
          file=sys.stderr)

  sorted_alphabetically = IndividualsInAlphabeticOrder(authors_path)
  if not sorted_alphabetically:
    print("Authors not in alphabetical order, please sort them.", file=sys.stderr)
  if not author_in_file or not sorted_alphabetically:
    if not args.dry_run:
      sys.exit(1)


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('email', type=str,
                      help='email of the commit author to check')
  parser.add_argument('name', type=str,
                      help='name of the commit author to check')
  parser.add_argument(
      '--source-dir',
      default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
      help='path to the source directory where the AUTHORS file is located')
  parser.add_argument('--dry-run', default=False, action='store_true',
                      help='Don\'t return an exit code in case of failure')
  args = parser.parse_args()
  CheckAuthor(args)


if __name__ == '__main__':
  main()
