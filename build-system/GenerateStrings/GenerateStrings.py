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
        print("Unhandled exception: %s" % e)
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
    p = re.compile(r'(?:%s[ \t]*[\n]|[\r\n]|[\r])?(?P<line>(("(?P<key>[^"\\]*(?:\\.[^"\\]*)*)")|('
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


class PositionalArgument:
    def __init__(self, index: int, kind: str):
        self.index = index
        self.kind = kind


class Entry:
    def __init__(self, name: str, is_pluralized: bool, positional_arguments: [PositionalArgument]):
        self.name = name
        self.is_pluralized = is_pluralized
        self.positional_arguments = positional_arguments


def parse_positional_arguments(string: str) -> [PositionalArgument]:
    result = list()

    implicit_index = 0
    argument = re.compile(r'%((\d)\$)?([@d])', re.U)
    start_position = 0
    while True:
        m = argument.search(string, start_position)
        if m is None:
            break
        index = m.group(2)
        if index is None:
            index = implicit_index
            implicit_index += 1
        else:
            index = int(index)
        kind = m.group(3)
        result.append(PositionalArgument(index=index, kind=kind))
        start_position = m.end(0)

    return result


def parse_entries(strings: [dict]) -> [Entry]:
    entries = []
    pluralized = re.compile(r'^(.*?)_(0|1|2|3_10|many|any)$', re.U)
    processed_entries = set()
    for string in strings:
        key = string['key']
        m = pluralized.match(key)
        if m is not None:
            raw_key = m.group(1)

            if raw_key in processed_entries:
                continue
            processed_entries.add(raw_key)

            entries.append(Entry(
                name=raw_key,
                is_pluralized=True,
                positional_arguments=[]
            ))
        else:
            if key in processed_entries:
                continue
            processed_entries.add(key)

            entries.append(Entry(
                name=key,
                is_pluralized=False,
                positional_arguments=parse_positional_arguments(string['value'])
            ))
    entries.sort(key=lambda x: x.name)
    return entries


def write_string(file, string: str):
    file.write((string + '\n').encode('utf-8'))


class IndexCounter:
    def __init__(self):
        self.dictionary = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        self.filter_ids = {
            'NO',
            'YES',
        }
        self.max_index = len(self.dictionary) - 1
        self.value = []
        self.increment()

    def increment(self):
        index = 0
        while True:
            if len(self.value) == index:
                for i in range(len(self.value)):
                    self.value[i] = 0
                self.value.append(0)
                break
            if self.value[index] + 1 <= self.max_index:
                if index != 0:
                    for i in range(index):
                        self.value[i] = 0
                self.value[index] += 1
                break
            else:
                index += 1

    def get(self):
        result = ''
        for index in reversed(self.value):
            result += self.dictionary[index]
        return result

    def get_next_valid_id(self) -> str:
        while True:
            result = self.get()
            self.increment()
            if result not in self.filter_ids:
                return result


def sanitize_entry_identifer(string: str) -> str:
    return string.replace('.', '_')


def generate(header_path: str, implementation_path: str, entries: [Entry]):
    test_path = '/Users/ali/build/telegram/telegram-ios/submodules/PresentationStrings/main.m'
    print('Generating strings into:\n{}\n{}'.format(header_path, implementation_path))
    with open(header_path, 'wb') as header_file, open(implementation_path, 'wb') as source_file, open(test_path, 'wb') as test_file:
        write_string(test_file, '#import <Foundation/Foundation.h>')
        write_string(test_file, '#import <PresentationStrings/PresentationStrings.h>')
        write_string(test_file, '')
        write_string(test_file, 'int main(int argc, const char **argv) {')
        write_string(test_file, 'PresentationStrings *strings = [[PresentationStrings alloc] init];')

        write_string(header_file, '#import <Foundation/Foundation.h>')
        write_string(header_file, '')
        write_string(header_file, '@interface PresentationStrings : NSObject')
        write_string(header_file, '')
        write_string(header_file, '@end')

        write_string(source_file, '#import <PresentationStrings/PresentationStrings.h>')
        write_string(source_file, '')
        write_string(source_file, '@implementation PresentationStrings')
        write_string(source_file, '@end')
        write_string(source_file, '')

        counter = IndexCounter()
        for entry in entries:
            entry_id = '_L' + counter.get_next_valid_id()
            write_string(header_file, '// {}'.format(entry.name))
            write_string(source_file, '// {}'.format(entry.name))

            function_arguments = ''
            if entry.is_pluralized:
                swift_spec = 'PresentationStrings.{}(self:_:)'.format(sanitize_entry_identifer(entry.name))
                function_arguments = ', int32_t value'
            elif len(entry.positional_arguments) != 0:
                positional_arguments_spec = ''
                argument_index = -1
                for argument in entry.positional_arguments:
                    argument_index += 1
                    if argument.kind == 'd':
                        function_arguments += ', int32_t _{}'.format(argument_index)
                    elif argument.kind == '@':
                        function_arguments += ', NSString * _Nonnull _{}'.format(argument_index)
                    else:
                        raise Exception('Unsupported argument type {}'.format(argument.kind))
                    positional_arguments_spec += '_:'
                swift_spec = 'PresentationStrings.{}(self:{})'.format(
                    sanitize_entry_identifer(entry.name), positional_arguments_spec)
            else:
                swift_spec = 'getter:PresentationStrings.{}(self:)'.format(sanitize_entry_identifer(entry.name))
            # write_string(header_file, '__attribute__((swift_name("{}")))'
            #              .format(swift_spec))
            write_string(header_file, 'NSString * _Nonnull {}(PresentationStrings * _Nonnull _self);'.format(
                entry_id, function_arguments))

            write_string(test_file, '{}(strings);'.format(entry_id))
            write_string(test_file, '{}(strings);'.format(entry_id))
            write_string(test_file, '{}(strings);'.format(entry_id))

            write_string(source_file, 'NSString * _Nonnull {}(PresentationStrings * _Nonnull _self) {{'.format(
                entry_id, function_arguments))
            write_string(source_file, '    return @"";'.format(entry_id))
            write_string(source_file, '}')
            write_string(source_file, ''.format(entry_id))
        write_string(test_file, '    return 0;')
        write_string(test_file, '}')
        write_string(test_file, '')


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
    all_entries = parse_entries(parsed_strings)
    generate(header_path=args.outHeader, implementation_path=args.outImplementation, entries=all_entries)
