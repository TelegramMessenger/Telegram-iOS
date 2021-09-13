#!/bin/pyton3

# Based on https://github.com/chrisballinger/python-localizable

import argparse
import sys
import re
import codecs
import struct

from typing import Dict, List


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
    entries: List[Entry] = []
    pluralized = re.compile(r'^(.*?)_(0|1|2|3_10|many|any)$', re.U)
    processed_entries = set()
    for string in strings:
        key = string['key']
        m = pluralized.match(key)
        if m is not None:
            raw_key = m.group(1)

            positional_arguments = parse_positional_arguments(string['value'])

            if raw_key in processed_entries:
                for i in range(0, len(entries)):
                    if entries[i].name == raw_key:
                        if len(entries[i].positional_arguments) < len(positional_arguments):
                            entries[i].positional_arguments = positional_arguments
                continue
            processed_entries.add(raw_key)

            entries.append(Entry(
                name=raw_key,
                is_pluralized=True,
                positional_arguments=positional_arguments
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

    had_error = False
    for entry in entries:
        if entry.is_pluralized:
            if len(entry.positional_arguments) > 1:
                print('Pluralized key "{}" needs to contain at most 1 positional argument, {} were provided'
                      .format(entry.name, len(entry.positional_arguments)))
                had_error = True

    if had_error:
        sys.exit(1)

    entries.sort(key=lambda x: x.name)
    return entries


def write_string(file, string: str):
    file.write((string + '\n').encode('utf-8'))


def write_bin_uint32(file, value: int):
    file.write(struct.pack('I', value))


def write_bin_uint8(file, value: int):
    file.write(struct.pack('B', value))


def write_bin_string(file, value: str):
    file.write(value.encode('utf-8'))


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


def generate(header_path: str, implementation_path: str, data_path: str, entries: [Entry]):
    print('Generating strings into:\n{}\n{}'.format(header_path, implementation_path))
    with open(header_path, 'wb') as header_file, open(implementation_path, 'wb') as source_file,\
            open(data_path, 'wb') as data_file:

        formatted_accessors = ''
        max_format_argument_count = 0
        for entry in entries:
            num_arguments = len(entry.positional_arguments)
            if num_arguments > max_format_argument_count:
                max_format_argument_count = num_arguments
        if max_format_argument_count != 0:
            for num_arguments in range(1, max_format_argument_count + 1):
                arguments_string = ''
                arguments_array = ''
                for i in range(0, num_arguments):
                    arguments_string += ', id _Nonnull arg{}'.format(i)
                    if i != 0:
                        arguments_array += ', '
                    arguments_array += '[[NSString alloc] initWithFormat:@"%@", arg{}]'.format(i)
                formatted_accessors += '''
static _FormattedString * _Nonnull getFormatted{num_arguments}(_PresentationStrings * _Nonnull strings,
    uint32_t keyId{arguments_string}) {{
    NSString *formatString = getSingle(strings, strings->_idToKey[@(keyId)], nil);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[{arguments_array}]);
}}
'''.format(num_arguments=num_arguments, arguments_string=arguments_string, arguments_array=arguments_array)

        write_string(header_file, '''// Automatically-generated file, do not edit

#import <Foundation/Foundation.h>

@interface _FormattedStringRange : NSObject

@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) NSRange range;

- (instancetype _Nonnull)initWithIndex:(NSInteger)index range:(NSRange)range;

@end


@interface _FormattedString : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull string;
@property (nonatomic, strong, readonly) NSArray<_FormattedStringRange *> * _Nonnull ranges;

- (instancetype _Nonnull)initWithString:(NSString * _Nonnull)string
    ranges:(NSArray<_FormattedStringRange *> * _Nonnull)ranges;

@end


@interface _PresentationStringsComponent : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull languageCode;
@property (nonatomic, strong, readonly) NSString * _Nonnull localizedName;
@property (nonatomic, strong, readonly) NSString * _Nullable pluralizationRulesCode;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, NSString *> * _Nonnull dict;

- (instancetype _Nonnull)initWithLanguageCode:(NSString * _Nonnull)languageCode
    localizedName:(NSString * _Nonnull)localizedName
    pluralizationRulesCode:(NSString * _Nullable)pluralizationRulesCode
    dict:(NSDictionary<NSString *, NSString *> * _Nonnull)dict;

@end

@interface _PresentationStrings : NSObject

@property (nonatomic, readonly) uint32_t lc;
@property (nonatomic, strong, readonly) _PresentationStringsComponent * _Nonnull primaryComponent;
@property (nonatomic, strong, readonly) _PresentationStringsComponent * _Nullable secondaryComponent;
@property (nonatomic, strong, readonly) NSString * _Nonnull baseLanguageCode;
@property (nonatomic, strong, readonly) NSString * _Nonnull groupingSeparator;

- (instancetype _Nonnull)initWithPrimaryComponent:(_PresentationStringsComponent * _Nonnull)primaryComponent
    secondaryComponent:(_PresentationStringsComponent * _Nullable)secondaryComponent
    groupingSeparator:(NSString * _Nullable)groupingSeparator;

@end

''')

        write_string(source_file, '''// Automatically-generated file, do not edit

#import <PresentationStrings/PresentationStrings.h>
#import <NumberPluralizationForm/NumberPluralizationForm.h>
#import <AppBundle/AppBundle.h>

@implementation _FormattedStringRange

- (instancetype _Nonnull)initWithIndex:(NSInteger)index range:(NSRange)range {
    self = [super init];
    if (self != nil) {
        _index = index;
        _range = range;
    }
    return self;
}

@end


@implementation _FormattedString

- (instancetype _Nonnull)initWithString:(NSString * _Nonnull)string
    ranges:(NSArray<_FormattedStringRange *> * _Nonnull)ranges {
    self = [super init];
    if (self != nil) {
        _string = string;
        _ranges = ranges;
    }
    return self;
}

@end

@implementation _PresentationStringsComponent

- (instancetype _Nonnull)initWithLanguageCode:(NSString * _Nonnull)languageCode
    localizedName:(NSString * _Nonnull)localizedName
    pluralizationRulesCode:(NSString * _Nullable)pluralizationRulesCode
    dict:(NSDictionary<NSString *, NSString *> * _Nonnull)dict {
    self = [super init];
    if (self != nil) {
        _languageCode = languageCode;
        _localizedName = localizedName;
        _pluralizationRulesCode = pluralizationRulesCode;
        _dict = dict;
    }
    return self;
}

@end

@interface _PresentationStrings () {
    @public
    NSDictionary<NSNumber *, NSString *> *_idToKey;
}

@end

static NSArray<_FormattedStringRange *> * _Nonnull extractArgumentRanges(NSString * _Nonnull string) {
    static NSRegularExpression *argumentRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        argumentRegex = [NSRegularExpression regularExpressionWithPattern:@"%(((\\\\d+)\\\\$)?)([@df])"
            options:0 error:nil];
    });
    
    NSMutableArray<_FormattedStringRange *> *result = [[NSMutableArray alloc] init];
    NSArray<NSTextCheckingResult *> *matches = [argumentRegex matchesInString:string
        options:0 range:NSMakeRange(0, string.length)];
    int index = 0;
    for (NSTextCheckingResult *match in matches) {
        int currentIndex = index;
        NSRange matchRange = [match rangeAtIndex:3]; 
        if (matchRange.location != NSNotFound) {
            currentIndex = [[string substringWithRange:matchRange] intValue] - 1;
        }
        [result addObject:[[_FormattedStringRange alloc] initWithIndex:currentIndex range:[match rangeAtIndex:0]]];
        index += 1;
    }
    
    return result;
}

static _FormattedString * _Nonnull formatWithArgumentRanges(
    NSString * _Nonnull string,
    NSArray<_FormattedStringRange *> * _Nonnull ranges,
    NSArray<NSString *> * _Nonnull arguments
) {
    NSMutableArray<_FormattedStringRange *> *resultingRanges = [[NSMutableArray alloc] init];
    NSMutableString *result = [[NSMutableString alloc] init];
    NSUInteger currentLocation = 0;
    
    for (_FormattedStringRange *range in ranges) {
        if (currentLocation < range.range.location) {
            [result appendString:[string substringWithRange:
                NSMakeRange(currentLocation, range.range.location - currentLocation)]];
        }
        NSString *argument = nil;
        if (range.index >= 0 && range.index < arguments.count) {
            argument = arguments[range.index];
        } else {
            argument = @"?";
        }
        [resultingRanges addObject:[[_FormattedStringRange alloc] initWithIndex:range.index
            range:NSMakeRange(result.length, argument.length)]];
        [result appendString:argument];
        currentLocation = range.range.location + range.range.length;
    }
    
    if (currentLocation != string.length) {
        [result appendString:[string substringWithRange:NSMakeRange(currentLocation, string.length - currentLocation)]];
    }
    
    return [[_FormattedString alloc] initWithString:result ranges:resultingRanges];
}

static NSString * _Nonnull getPluralizationSuffix(uint32_t lc, int32_t value) {
    NumberPluralizationForm pluralizationForm = numberPluralizationForm(lc, value);
    switch (pluralizationForm) {
        case NumberPluralizationFormZero: {
            return @"_0";
        }
        case NumberPluralizationFormOne: {
            return @"_1";
        }
        case NumberPluralizationFormTwo: {
            return @"_2";
        }
        case NumberPluralizationFormFew: {
            return @"_3_10";
        }
        case NumberPluralizationFormMany: {
            return @"_many";
        }
        default: {
            return @"_any";
        }
    }
}

static NSString * _Nonnull getSingle(_PresentationStrings * _Nullable strings, NSString * _Nonnull key,
    bool * _Nullable isFound) {
    NSString *result = nil;
    if (strings) {
        result = strings.primaryComponent.dict[key];
        if (!result) {
            result = strings.secondaryComponent.dict[key];
        }
    }
    if (!result) {
        static NSDictionary<NSString *, NSString *> *fallbackDict = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *lprojPath = [getAppBundle() pathForResource:@"en" ofType:@"lproj"];
            if (!lprojPath) {
                return;
            }
            NSBundle *bundle = [NSBundle bundleWithPath:lprojPath];
            if (!bundle) {
                return;
            }
            NSString *stringsPath = [bundle pathForResource:@"Localizable" ofType:@"strings"];
            if (!stringsPath) {
                return;
            }
            fallbackDict = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:stringsPath]];
        });
        result = fallbackDict[key]; 
    }
    if (!result) {
        result = key;
        if (isFound) {
            *isFound = false;
        }
    } else {
        if (isFound) {
            *isFound = true;
        }
    }
    return result;
}

static NSString * _Nonnull getSingleIndirect(_PresentationStrings * _Nonnull strings, uint32_t keyId) {
    return getSingle(strings, strings->_idToKey[@(keyId)], nil);
}

static NSString * _Nonnull getPluralized(_PresentationStrings * _Nonnull strings, NSString * _Nonnull key,
    int32_t value) {
    NSString *parsedKey = [[NSString alloc] initWithFormat:@"%@%@", key, getPluralizationSuffix(strings.lc, value)];
    bool isFound = false;
    NSString *formatString = getSingle(strings, parsedKey, &isFound);
    if (!isFound) {
        // fall back to English
        parsedKey = [[NSString alloc] initWithFormat:@"%@%@", key, getPluralizationSuffix(0x656e, value)];
        formatString = getSingle(nil, parsedKey, nil);
    }
    NSString *stringValue = formatNumberWithGroupingSeparator(strings.groupingSeparator, value);
    NSArray<_FormattedStringRange *> *argumentRanges = extractArgumentRanges(formatString);
    return formatWithArgumentRanges(formatString, argumentRanges, @[stringValue]).string;
}

static NSString * _Nonnull getPluralizedIndirect(_PresentationStrings * _Nonnull strings, uint32_t keyId,
    int32_t value) {
    return getPluralized(strings, strings->_idToKey[@(keyId)], value);
}''' + formatted_accessors + '''
@implementation _PresentationStrings

- (instancetype _Nonnull)initWithPrimaryComponent:(_PresentationStringsComponent * _Nonnull)primaryComponent
    secondaryComponent:(_PresentationStringsComponent * _Nullable)secondaryComponent
    groupingSeparator:(NSString * _Nullable)groupingSeparator {
    self = [super init];
    if (self != nil) {
        static NSDictionary<NSNumber *, NSString *> *idToKey = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *dataPath = [getAppBundle() pathForResource:@"PresentationStrings" ofType:@"data"];
            if (!dataPath) {
                assert(false);
                return;
            }
            NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:dataPath]];
            if (!data) {
                assert(false);
                return;
            }
            if (data.length < 4) {
                assert(false);
                return;
            }
            
            NSMutableDictionary<NSNumber *, NSString *> *result = [[NSMutableDictionary alloc] init]; 
            
            uint32_t entryCount = 0;
            [data getBytes:&entryCount range:NSMakeRange(0, 4)];
            
            NSInteger offset = 4;
            for (uint32_t i = 0; i < entryCount; i++) {
                uint8_t stringLength = 0;
                [data getBytes:&stringLength range:NSMakeRange(offset, 1)];
                offset += 1;
                
                NSData *stringData = [data subdataWithRange:NSMakeRange(offset, stringLength)];
                offset += stringLength;
                
                result[@(i)] = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
            }
            idToKey = result;
        });
        _idToKey = idToKey;
    
        _primaryComponent = primaryComponent;
        _secondaryComponent = secondaryComponent;
        _groupingSeparator = groupingSeparator;
        
        if (secondaryComponent) {
            _baseLanguageCode = secondaryComponent.languageCode;
        } else {
            _baseLanguageCode = primaryComponent.languageCode;
        }
        
        NSString *languageCode = nil;
        if (primaryComponent.pluralizationRulesCode) {
            languageCode = primaryComponent.pluralizationRulesCode;
        } else {
            languageCode = primaryComponent.languageCode;
        }
        
        NSString *rawCode = languageCode;
        
        NSRange range = [languageCode rangeOfString:@"_"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringWithRange:NSMakeRange(0, range.location)];
        }
        range = [languageCode rangeOfString:@"-"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringWithRange:NSMakeRange(0, range.location)];
        }
        
        rawCode = [rawCode lowercaseString];
        
        uint32_t lc = 0;
        for (NSInteger i = 0; i < rawCode.length; i++) {
            lc = (lc << 8) + (uint32_t)[rawCode characterAtIndex:i];
        }
        _lc = lc;
    }
    return self;
}

@end

''')

        counter = IndexCounter()

        entry_keys = []

        for entry in entries:
            entry_id = '_L' + counter.get_next_valid_id()

            entry_key_id = len(entry_keys)
            entry_keys.append(entry.name)

            write_string(source_file, '// {}'.format(entry.name))

            function_arguments = ''
            format_arguments_array = ''
            if entry.is_pluralized:
                function_return_spec = 'NSString * _Nonnull'
                swift_spec = '_PresentationStrings.{}(self:_:)'.format(sanitize_entry_identifer(entry.name))
                function_arguments = ', int32_t value'
            elif len(entry.positional_arguments) != 0:
                function_return_spec = '_FormattedString * _Nonnull'
                positional_arguments_spec = ''
                argument_index = -1
                for argument in entry.positional_arguments:
                    argument_index += 1
                    format_arguments_array += ', '
                    if argument.kind == 'd':
                        function_arguments += ', NSInteger _{}'.format(argument_index)
                        format_arguments_array += '@(_{})'.format(argument_index)
                    elif argument.kind == '@':
                        function_arguments += ', NSString * _Nonnull _{}'.format(argument_index)
                        format_arguments_array += '_{}'.format(argument_index)
                    else:
                        raise Exception('Unsupported argument type {}'.format(argument.kind))
                    positional_arguments_spec += '_:'
                swift_spec = '_PresentationStrings.{}(self:{})'.format(
                    sanitize_entry_identifer(entry.name), positional_arguments_spec)
            else:
                function_return_spec = 'NSString * _Nonnull'
                swift_spec = 'getter:_PresentationStrings.{}(self:)'.format(sanitize_entry_identifer(entry.name))

            function_spec = '{} {}'.format(function_return_spec, entry_id)
            function_spec += '(_PresentationStrings * _Nonnull _self{})'.format(function_arguments)

            write_string(header_file, '{function_spec} __attribute__((__swift_name__("{swift_spec}")));'.format(
                function_spec=function_spec, swift_spec=swift_spec))

            if entry.is_pluralized:
                argument_format_type = ''
                if entry.positional_arguments[0].kind == 'd':
                    argument_format_type = '0'
                elif entry.positional_arguments[0].kind == '@':
                    argument_format_type = '1'
                else:
                    raise Exception('Unsupported argument type {}'.format(argument.kind))
                write_string(source_file, function_spec + ''' {{
    return getPluralizedIndirect(_self, {entry_key_id}, value);
}}'''.format(key=entry.name, entry_key_id=entry_key_id))
            elif len(entry.positional_arguments) != 0:
                write_string(source_file, function_spec + ''' {{
    return getFormatted{argument_count}(_self, {key_id}{arguments_array});
}}'''.format(key_id=entry_key_id, argument_count=len(entry.positional_arguments), arguments_array=format_arguments_array))
            else:
                write_string(source_file, function_spec + ''' {{
    return getSingleIndirect(_self, {entry_key_id});
}}'''.format(key=entry.name,  entry_key_id=entry_key_id))

        write_bin_uint32(data_file, len(entry_keys))
        for entry_key in entry_keys:
            write_bin_uint8(data_file, len(entry_key))
            write_bin_string(data_file, entry_key)


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
    parser.add_argument(
        '--outData',
        required=True,
        help='Path to PresentationStrings.data',
        metavar='path'
    )

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    parsed_strings = parse_strings(args.source)
    all_entries = parse_entries(parsed_strings)
    generate(header_path=args.outHeader, implementation_path=args.outImplementation, data_path=args.outData,
             entries=all_entries)
