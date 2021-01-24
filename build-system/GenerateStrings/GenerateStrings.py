#!/bin/pyton3

# Based on https://github.com/chrisballinger/python-localizable

import argparse
import sys
import os
import re
import codecs


def _unescape_key(s):
    return s.replace('\\\n', '')


def _unescape(s):
    s = s.replace('\\\n', '')
    return s.replace('\\"', '"').replace(r'\n', '\n').replace(r'\r', '\r')


def _get_content(filename: str):
    if filename is None:
        return None
    return _get_content_from_file(filename, 'utf-8')


def _get_content_from_file(filename: str, encoding: str):
    f = open(filename, 'rb')
    try:
        f = codecs.open(filename, 'r', encoding=encoding)
        return f.read()
    except IOError as e:
        print("Error opening file %s with encoding %s: %s" % (filename, encoding, e.message))
    except Exception as e:
        print("Unhandled exception: %s" % e.message)
    finally:
        f.close()


def parse_strings(filename: str):
    content = _get_content(filename=filename)

    stringset = []
    f = content
    if f.startswith(u'\ufeff'):
        f = f.lstrip(u'\ufeff')
    # regex for finding all comments in a file
    cp = r'(?:/\*(?P<comment>(?:[^*]|(?:\*+[^*/]))*\**)\*/)'
    p = re.compile(r'(?:%s[ \t]*[\n]|[\r\n]|[\r]){0,1}(?P<line>(("(?P<key>[^"\\]*(?:\\.[^"\\]*)*)")|('
                   r'?P<property>\w+))\s*=\s*"(?P<value>[^"\\]*(?:\\.[^"\\]*)*)"\s*;)' % cp, re.DOTALL | re.U)
    c = re.compile(r'//[^\n]*\n|/\*(?:.|[\r\n])*?\*/', re.U)
    ws = re.compile(r'\s+', re.U)
    end = 0
    for i in p.finditer(f):
        start = i.start('line')
        end_ = i.end()
        key = i.group('key')
        if not key:
            key = i.group('property')
        value = i.group('value')
        while end < start:
            m = c.match(f, end, start) or ws.match(f, end, start)
            if not m or m.start() != end:
                print("Invalid syntax: %s" % f[end:start])
            end = m.end()
        end = end_
        key = _unescape_key(key)
        stringset.append({'key': key, 'value': _unescape(value)})
    return stringset


class Entry:
    def __init__(self, is_pluralized: bool, positional_arguments: [str]):
        self.is_pluralized = is_pluralized
        self.positional_arguments = positional_arguments


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='GenerateStrings')

    parser.add_argument(
        '--source',
        required=True,
        help='Path to Localizable.strings',
        metavar='path'
    )
    parser.add_argument(
        '--outImplementation',
        required=True,
        help='Path to PresentationStrings.m',
        metavar='path'
    )
    parser.add_argument(
        '--outHeader',
        required=True,
        help='Path to PresentationStrings.h',
        metavar='path'
    )

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    parsed_strings = parse_strings(args.source)
    print(parsed_strings)
