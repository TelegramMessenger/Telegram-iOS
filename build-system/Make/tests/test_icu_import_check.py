"""Tests for ICUImportCheck.

Run: python3 -m unittest discover -s build-system/Make/tests -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import ICUImportCheck  # noqa: E402


class DeclaredFunctionsTests(unittest.TestCase):
    def test_a_declaration_on_one_line_or_two(self):
        header = (
            'U_CAPI UCharDirection U_EXPORT2\n'
            'u_charDirection(UChar32 c);\n'
            'U_CAPI const char * U_EXPORT2 u_errorName(UErrorCode code);\n'
        )
        self.assertEqual(ICUImportCheck.declared_functions([header]), {'u_charDirection', 'u_errorName'})

    def test_comments_declare_nothing(self):
        header = (
            '/* U_CAPI void U_EXPORT2 ubidi_open(void); */\n'
            '// U_CAPI void U_EXPORT2 ucol_open(const char* loc);\n'
            'U_CAPI int32_t U_EXPORT2 u_strToUpper(UChar *dest);\n'
        )
        self.assertEqual(ICUImportCheck.declared_functions([header]), {'u_strToUpper'})


class ImportsTests(unittest.TestCase):
    def test_only_libicucore_bindings_count(self):
        output = (
            '/path/TelegramUIFramework [arm64]:\n'
            '    -imports:\n'
            '      0x0001  _u_charDirection (from libicucore)\n'
            '      0x01D2  _ucol_getAttribute [weak-import] (from libicucore)\n'
            '      0x0003  _objc_msgSend (from libobjc)\n'
            '      0x0004  _uidna_openUTS46 (from libicucore)\n'
        )
        self.assertEqual(ICUImportCheck.icu_imports(output), {'u_charDirection', 'ucol_getAttribute', 'uidna_openUTS46'})

    def test_the_bundles_binaries(self):
        names = [
            'Payload/Telegram.app/Telegram',
            'Payload/Telegram.app/Info.plist',
            'Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework',
            'Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/Info.plist',
            'Payload/Telegram.app/PlugIns/Share.appex/Share',
            'Payload/Telegram.app/PlugIns/Share.appex/Assets.car',
        ]
        matched = [name for name in names if any(pattern.match(name) for pattern in ICUImportCheck.BINARY_PATTERNS)]
        self.assertEqual(matched, [names[0], names[2], names[4]])


if __name__ == '__main__':
    unittest.main()
