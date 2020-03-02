/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2019-2020 Telegram Systems LLP
*/
#include "utils.h"

namespace vm {

td::Result<vm::StackEntry> convert_stack_entry(td::Slice word);
td::Result<std::vector<vm::StackEntry>> parse_stack_entries_in(td::Slice& str, bool prefix_only = false);
td::Result<vm::StackEntry> parse_stack_entry_in(td::Slice& str, bool prefix_only = false);

namespace {

td::Slice& skip_spaces(td::Slice& str, const char* delims) {
  while (str.size() > 0 && strchr(delims, str[0])) {
    str.remove_prefix(1);
  }
  return str;
}

td::Slice get_word(td::Slice& str, const char* delims, const char* specials) {
  skip_spaces(str, delims);

  size_t p = 0;
  while (p < str.size() && !strchr(delims, str[p])) {
    if (specials && strchr(specials, str[p])) {
      if (!p) {
        p++;
      }
      break;
    }
    p++;
  }

  td::Slice ret = str.copy().truncate(p);
  str.remove_prefix(p);
  return ret;
}

}  // namespace

td::Result<vm::StackEntry> parse_stack_entry_in(td::Slice& str, bool prefix_only) {
  auto word = get_word(str, " \t", "[()]");
  if (word.empty()) {
    return td::Status::Error("stack value expected instead of end-of-line");
  }
  if (word.size() == 1 && (word[0] == '[' || word[0] == '(')) {
    int expected = (word[0] == '(' ? ')' : ']');
    TRY_RESULT(values, parse_stack_entries_in(str, true));
    word = get_word(str, " \t", "[()]");
    if (word.size() != 1 || word[0] != expected) {
      return td::Status::Error("closing bracket expected");
    }
    vm::StackEntry value;
    if (expected == ']') {
      value = vm::StackEntry{std::move(values)};
    } else {
      value = vm::StackEntry::make_list(std::move(values));
    }
    if (prefix_only || (skip_spaces(str, " \t").size() == 0)) {
      return value;
    } else {
      return td::Status::Error("extra data at the end");
    }
  } else {
    return convert_stack_entry(word);
  }
}

td::Result<vm::StackEntry> convert_stack_entry(td::Slice str) {
  if (str.empty() || str.size() > 65535) {
    return td::Status::Error("too long string");
  }
  int l = (int)str.size();
  if (str[0] == '"') {
    vm::CellBuilder cb;
    if (l == 1 || str.back() != '"' || l >= 127 + 2 || !cb.store_bytes_bool(str.data() + 1, l - 2)) {
      return td::Status::Error("incomplete (or too long) string");
    }
    return vm::StackEntry{vm::load_cell_slice_ref(cb.finalize())};
  }
  if (l >= 3 && (str[0] == 'x' || str[0] == 'b') && str[1] == '{' && str.back() == '}') {
    unsigned char buff[128];
    int bits =
        (str[0] == 'x')
            ? (int)td::bitstring::parse_bitstring_hex_literal(buff, sizeof(buff), str.begin() + 2, str.end() - 1)
            : (int)td::bitstring::parse_bitstring_binary_literal(buff, sizeof(buff), str.begin() + 2, str.end() - 1);
    if (bits < 0) {
      return td::Status::Error("failed to parse raw b{...}/x{...} number");
    }
    return vm::StackEntry{
        Ref<vm::CellSlice>{true, vm::CellBuilder().store_bits(td::ConstBitPtr{buff}, bits).finalize()}};
  }
  auto num = td::make_refint();
  auto& x = num.unique_write();
  if (l >= 3 && str[0] == '0' && str[1] == 'x') {
    if (x.parse_hex(str.data() + 2, l - 2) != l - 2) {
      return td::Status::Error("failed to parse 0x... hex number");
    }
  } else if (l >= 4 && str[0] == '-' && str[1] == '0' && str[2] == 'x') {
    if (x.parse_hex(str.data() + 3, l - 3) != l - 3) {
      return td::Status::Error("failed to parse -0x... hex number");
    }
    x.negate().normalize();
  } else if (!l || x.parse_dec(str.data(), l) != l) {
    return td::Status::Error("failed to parse dec number");
  }
  return vm::StackEntry{std::move(num)};
}

td::Result<std::vector<vm::StackEntry>> parse_stack_entries_in(td::Slice& str, bool prefix_only) {
  std::vector<vm::StackEntry> ret;
  while (!skip_spaces(str, " \t").empty()) {
    auto c = str.copy();
    auto word = get_word(c, " \t", "[()]");
    if (word == "]" || word == ")") {
      if (prefix_only) {
        return ret;
      } else {
        return td::Status::Error("not paired closing bracket");
      }
    }
    TRY_RESULT(value, parse_stack_entry_in(str, true));
    ret.push_back(std::move(value));
  }
  return ret;
}

td::Result<std::vector<vm::StackEntry>> parse_stack_entries(td::Slice str, bool prefix_only) {
  return parse_stack_entries_in(str, prefix_only);
}

td::Result<vm::StackEntry> parse_stack_entry(td::Slice str, bool prefix_only) {
  return parse_stack_entry_in(str, prefix_only);
}

}  // namespace vm
