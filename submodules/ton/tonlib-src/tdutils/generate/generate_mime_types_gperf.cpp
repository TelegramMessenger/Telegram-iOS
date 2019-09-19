/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include <algorithm>
#include <cassert>
#include <cstddef>
#include <fstream>
#include <iostream>
#include <map>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

static std::pair<std::string, std::string> split(std::string s, char delimiter = ' ') {
  auto delimiter_pos = s.find(delimiter);
  if (delimiter_pos == std::string::npos) {
    return {std::move(s), ""};
  } else {
    auto head = s.substr(0, delimiter_pos);
    auto tail = s.substr(delimiter_pos + 1);
    return {head, tail};
  }
}

static bool generate(const char *file_name, const char *from_name, const char *to_name,
                     const std::map<std::string, std::string> &map) {
  // binary mode is needed for MSYS2 gperf
  std::ofstream out(file_name, std::ios_base::trunc | std::ios_base::binary);
  if (!out) {
    std::cerr << "Can't open output file \"" << file_name << std::endl;
    return false;
  }

  out << "%struct-type\n";
  out << "%ignore-case\n";
  out << "%language=ANSI-C\n";
  out << "%readonly-tables\n";
  out << "%includes\n";
  out << "%enum\n";
  out << "%define slot-name " << from_name << "\n";
  out << "%define initializer-suffix ,nullptr\n";
  out << "%define slot-name " << from_name << "\n";
  out << "%define hash-function-name " << from_name << "_hash\n";
  out << "%define lookup-function-name search_" << from_name << "\n";
  //  out << "%define class-name " << from_name << "_to_" << to_name << "\n";
  out << "struct " << from_name << "_and_" << to_name << " {\n";
  out << "  const char *" << from_name << ";\n";
  out << "  const char *" << to_name << ";\n";
  out << "}\n";
  out << "%%\n";

  for (auto &value : map) {
    out << '"' << value.first << "\", \"" << value.second << '"' << "\n";
  }

  out << "%%\n";
  out << "const char *" << from_name << "_to_" << to_name << "(const char *" << from_name << ", size_t " << from_name
      << "_len) {\n";
  out << "  const auto &result = search_" << from_name << "(" << from_name << ", " << from_name << "_len);\n";
  out << "  if (result == nullptr) {\n";
  out << "    return nullptr;\n";
  out << "  }\n";
  out << "\n";
  out << "  return result->" << to_name << ";\n";
  out << "}\n";

  return true;
}

static bool is_private_mime_type(const std::string &mime_type) {
  return mime_type.find("/x-") != std::string::npos;
}

int main(int argc, char *argv[]) {
  if (argc != 4) {
    std::cerr << "Wrong number of arguments supplied. Expected 'generate_mime_types_gperf <mime_types.txt> "
                 "<mime_type_to_extension.cpp> <extension_to_mime_type.cpp>'"
              << std::endl;
    return EXIT_FAILURE;
  }

  std::ifstream mime_types_file(argv[1]);
  if (!mime_types_file) {
    std::cerr << "Can't open input file \"" << argv[1] << std::endl;
    return EXIT_FAILURE;
  }

  std::map<std::string, std::string> mime_type_to_extension;
  std::map<std::string, std::string> extension_to_mime_type;

  std::string line;
  while (std::getline(mime_types_file, line)) {
    while (!line.empty() && (line.back() == '\r' || line.back() == '\n')) {
      line.pop_back();
    }

    std::string mime_type;
    std::string extensions_string;
    std::tie(mime_type, extensions_string) = split(line, '\t');

    if (mime_type.empty()) {
      std::cerr << "Wrong MIME type description \"" << line << "\"" << std::endl;
      continue;
    }

    auto extensions_start_position = extensions_string.find_first_not_of(" \t");
    if (extensions_start_position == std::string::npos) {
      std::cerr << "Wrong MIME type description \"" << line << "\"" << std::endl;
      continue;
    }
    extensions_string = extensions_string.substr(extensions_start_position);

    std::vector<std::string> extensions;
    while (!extensions_string.empty()) {
      extensions.push_back("");
      std::tie(extensions.back(), extensions_string) = split(extensions_string);
    }
    assert(!extensions.empty());

    std::map<std::string, std::string> preffered_extensions{{"image/jpeg", "jpg"},  {"audio/mpeg", "mp3"},
                                                            {"audio/midi", "midi"}, {"text/x-pascal", "pas"},
                                                            {"text/x-asm", "asm"},  {"video/quicktime", "mov"}};
    std::size_t index = 0;
    if (preffered_extensions.count(mime_type) != 0) {
      index = std::find(extensions.begin(), extensions.end(), preffered_extensions[mime_type]) - extensions.begin();
      assert(index < extensions.size());
    }
    if (mime_type_to_extension.emplace_hint(mime_type_to_extension.end(), mime_type, extensions[index])->second !=
        extensions[index]) {
      std::cerr << "MIME type \"" << mime_type << "\" has more than one extensions list" << std::endl;
    }

    for (auto &extension : extensions) {
      if (!extension_to_mime_type.emplace(extension, mime_type).second) {
        if (is_private_mime_type(extension_to_mime_type[extension]) == is_private_mime_type(mime_type)) {
          std::cerr << "Extension \"" << extension << "\" matches more than one type" << std::endl;
        } else {
          if (!is_private_mime_type(mime_type)) {
            extension_to_mime_type[extension] = mime_type;
          }
        }
      }
    }
  }

  if (!generate(argv[2], "mime_type", "extension", mime_type_to_extension)) {
    return EXIT_FAILURE;
  }
  if (!generate(argv[3], "extension", "mime_type", extension_to_mime_type)) {
    return EXIT_FAILURE;
  }
}
