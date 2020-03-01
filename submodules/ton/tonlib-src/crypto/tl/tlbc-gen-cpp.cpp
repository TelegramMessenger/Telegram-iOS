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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "tlbc-gen-cpp.h"
#include "td/utils/bits.h"
#include "td/utils/filesystem.h"

namespace tlbc {

/*
 * 
 *   C++ CODE GENERATION
 * 
 */

CppIdentSet global_cpp_ids;

std::vector<std::unique_ptr<CppTypeCode>> cpp_type;

bool add_type_members;

std::set<std::string> forbidden_cpp_idents, local_forbidden_cpp_idents;
std::vector<std::string> const_type_expr_cpp_idents;
std::vector<bool> const_type_expr_simple;

void init_forbidden_cpp_idents() {
  std::set<std::string>& f = forbidden_cpp_idents;
  f.insert("true");
  f.insert("false");
  f.insert("int");
  f.insert("bool");
  f.insert("unsigned");
  f.insert("long");
  f.insert("short");
  f.insert("char");
  f.insert("void");
  f.insert("class");
  f.insert("struct");
  f.insert("enum");
  f.insert("union");
  f.insert("public");
  f.insert("private");
  f.insert("protected");
  f.insert("extern");
  f.insert("static");
  f.insert("final");
  f.insert("if");
  f.insert("else");
  f.insert("while");
  f.insert("do");
  f.insert("for");
  f.insert("break");
  f.insert("continue");
  f.insert("return");
  f.insert("virtual");
  f.insert("explicit");
  f.insert("override");
  f.insert("new");
  f.insert("delete");
  f.insert("operator");
  f.insert("Ref");
  f.insert("Cell");
  f.insert("CellSlice");
  f.insert("Anything");
  f.insert("RefAnything");
  f.insert("Nat");
  f.insert("t_Nat");
  f.insert("t_RefCell");
  f.insert("t_Anything");
  f.insert("TLB");
  f.insert("TLB_Complex");
  f.insert("PrettyPrinter");
  std::set<std::string>& l = local_forbidden_cpp_idents;
  l.insert("cons_len");
  l.insert("cons_len_exact");
  l.insert("cons_tag");
  l.insert("skip");
  l.insert("validate_skip");
  l.insert("get_size");
  l.insert("pack");
  l.insert("unpack");
  l.insert("ops");
  l.insert("cs");
  l.insert("cb");
  l.insert("cell_ref");
  l.insert("type_class");
  l.insert("pp");
  l.insert("weak");
}

std::string CppIdentSet::compute_cpp_ident(std::string orig_ident, int count) {
  std::ostringstream os;
  int a, r = 0, cnt = 0;
  bool prev_skip = false;
  for (int c : orig_ident) {
    bool pp = prev_skip;
    prev_skip = true;
    if (c & 0x80) {
      if ((c & 0xe0) == 0xc0) {
        a = (c & 0x1f);
        r = 1;
        continue;
      } else if ((c & 0xf0) == 0xe0) {
        a = (c & 0x0f);
        r = 2;
        continue;
      }
      if ((c & 0xc0) != 0x80) {
        continue;
      }
      if (!r) {
        continue;
      }
      a = (a << 6) | (c & 0x3f);
      if (--r) {
        continue;
      }
      c = a;
    }
    prev_skip = false;
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_') {
      os << (char)c;
      cnt++;
      continue;
    }
    if (c >= '0' && c <= '9') {
      if (!cnt) {
        os << '_';
        cnt++;
      }
      os << (char)c;
      cnt++;
      continue;
    }
    if (c >= 0x410 && c < 0x450) {
      os << (char)(0xc0 + (c >> 6)) << (char)(0x80 + (c & 0x3f));
      cnt++;
      continue;
    }
    prev_skip = true;
    if (!pp) {
      os << '_';
    }
  }
  if (!cnt) {
    os << '_';
    prev_skip = true;
  }
  if (count) {
    os << count;
  }
  return os.str();
}

bool CppIdentSet::is_good_ident(std::string ident) {
  return !defined(ident) && !forbidden_cpp_idents.count(ident) &&
         !(extra_forbidden_idents && extra_forbidden_idents->count(ident));
}

std::string CppIdentSet::new_ident(std::string orig_ident, int count, std::string suffix) {
  while (true) {
    std::string ident = compute_cpp_ident(orig_ident, count) + suffix;
    if (is_good_ident(ident)) {
      cpp_idents.insert(ident);
      return ident;
    }
    ++count;
  }
}

struct SizeWriter {
  int sz;
  explicit SizeWriter(int _sz) : sz(_sz) {
  }
  void write(std::ostream& os) const;
};

void SizeWriter::write(std::ostream& os) const {
  if (sz < 0x10000) {
    os << sz;
  } else {
    os << "0x" << std::hex << sz << std::dec;
  }
}

std::ostream& operator<<(std::ostream& os, SizeWriter w) {
  w.write(os);
  return os;
}

unsigned long long CppTypeCode::compute_selector_mask() const {
  unsigned long long z = 0, w = 1;
  int c = 0;
  for (int v : cons_tag_map) {
    if (v > c) {
      c = v;
      z |= w;
    }
    w <<= 1;
  }
  return z;
}

struct HexConstWriter {
  unsigned long long mask;
  explicit HexConstWriter(unsigned long long _mask) : mask(_mask){};
  void write(std::ostream& os) const;
};

void HexConstWriter::write(std::ostream& os) const {
  if (mask < 32) {
    os << mask;
  } else {
    os << "0x" << std::hex << mask << std::dec;
  }
  if (mask >= (1ULL << 31)) {
    os << (mask >= (1ULL << 32) ? "ULL" : "U");
  }
}

std::ostream& operator<<(std::ostream& os, HexConstWriter w) {
  w.write(os);
  return os;
}

cpp_val_type detect_cpp_type(const TypeExpr* expr) {
  if (expr->tp == TypeExpr::te_Ref) {
    return ct_cell;
  }
  if (expr->is_nat) {
    return ct_int32;
  }
  MinMaxSize sz = expr->compute_size();
  int l = sz.fixed_bit_size();
  if (expr->is_nat_subtype) {
    return l == 1 ? ct_bool : ct_int32;
  }
  if (expr->tp == TypeExpr::te_CondType) {
    cpp_val_type subtype = detect_cpp_type(expr->args.at(1));
    if (subtype == ct_slice || subtype == ct_cell || subtype == ct_integer || subtype == ct_bitstring ||
        subtype == ct_enum) {
      return subtype;
    }
    if ((subtype == ct_int32 || subtype == ct_int64) && expr->args[1]->is_integer() > 0) {
      return subtype;
    }
    return ct_slice;
  }
  int x = expr->is_integer();
  if (sz.max_size() & 0xff) {
    return ct_slice;
  }
  if (!x) {
    const Type* ta = expr->type_applied;
    if (expr->tp == TypeExpr::te_Apply && ta && ta->is_simple_enum) {
      return ct_enum;
    }
    if (expr->tp == TypeExpr::te_Apply && ta && ta->type_idx < builtin_types_num &&
        (ta == Bits_type || ta->get_name().at(0) == 'b')) {
      return (l >= 0 && l <= 256) ? ct_bits : ct_bitstring;
    }
    if (expr->tp == TypeExpr::te_Tuple && expr->args[1]->tp == TypeExpr::te_Apply &&
        expr->args[1]->type_applied->is_bool) {
      return (l >= 0 && l <= 256) ? ct_bits : ct_bitstring;
    }
    return ct_slice;
  }
  l = (sz.max_size() >> 8);
  if (x > 0 && l == 1) {
    return ct_bool;
  }
  if (l < 32) {
    return ct_int32;
  }
  if (l == 32) {
    return (x < 0 ? ct_int32 : ct_uint32);
  }
  if (l < 64) {
    return ct_int64;
  }
  if (l == 64) {
    return (x < 0 ? ct_int64 : ct_uint64);
  }
  return ct_integer;
}

cpp_val_type detect_field_cpp_type(const Field& field) {
  return field.subrec ? ct_subrecord : detect_cpp_type(field.type);
}

void show_valtype(std::ostream& os, cpp_val_type x, int size = -1, bool pass_value = false) {
  switch (x) {
    case ct_void:
      os << "void";
      break;
    case ct_slice:
      os << "Ref<CellSlice>";
      break;
    case ct_cell:
      os << "Ref<Cell>";
      break;
    case ct_typeptr:
      os << "const TLB*";
      break;
    case ct_typeref:
      os << "const TLB&";
      break;
    case ct_bitstring:
      os << "Ref<td::BitString>";
      break;
    case ct_bits:
      if (pass_value) {
        os << "const ";
      }
      os << "td::BitArray<" << size << ">";
      if (pass_value) {
        os << "&";
      }
      break;
    case ct_integer:
      os << "RefInt256";
      break;
    case ct_bool:
      os << "bool";
      break;
    case ct_enum:
      os << "char";
      break;
    case ct_int32:
      os << "int";
      break;
    case ct_uint32:
      os << "unsigned";
      break;
    case ct_int64:
      os << "long long";
      break;
    case ct_uint64:
      os << "unsigned long long";
      break;
    case ct_subrecord:
      if (pass_value) {
        os << "const ";
      }
      os << "<unknown-cpp-type>::Record";
      if (pass_value) {
        os << "&";
      }
      break;
    default:
      os << "<unknown-cpp-scalar-type>";
  }
}

bool CppValType::needs_move() const {
  return (vt == ct_cell || vt == ct_slice || vt == ct_bitstring || vt == ct_integer);
}

void CppValType::show(std::ostream& os, bool pass_value) const {
  show_valtype(os, vt, size, pass_value);
}

std::ostream& operator<<(std::ostream& os, CppValType cvt) {
  cvt.show(os);
  return os;
}

void CppTypeCode::ConsField::print_type(std::ostream& os, bool pass_value) const {
  if (ctype != ct_subrecord) {
    get_cvt().show(os, pass_value);
  } else {
    assert(subrec);
    if (pass_value) {
      os << "const ";
    }
    subrec->print_full_name(os);
    if (pass_value) {
      os << "&";
    }
  }
}

void CppTypeCode::ConsRecord::print_full_name(std::ostream& os) const {
  os << cpp_type.cpp_type_class_name << "::" << cpp_name;
}

void CppTypeCode::assign_class_name() {
  std::string type_name = type.get_name();
  sym_idx_t name = type.type_name;
  if (!name && type.parent_type_idx >= 0) {
    int i = type.parent_type_idx;
    while (true) {
      name = types.at(i).type_name;
      if (name || types.at(i).parent_type_idx < 0) {
        break;
      }
      i = types.at(i).parent_type_idx;
    }
    if (name) {
      type_name = sym::symbols.get_name(name) + "_aux";
    }
  }
  cpp_type_class_name = global_cpp_ids.new_ident(type_name);
  if (params) {
    cpp_type_template_name = global_cpp_ids.new_ident(cpp_type_class_name + "T");
  } else {
    cpp_type_var_name = global_cpp_ids.new_ident(std::string{"t_"} + cpp_type_class_name);
  }
}

void CppTypeCode::assign_cons_names() {
  cons_enum_name.resize(cons_num);
  for (int i = 0; i < cons_num; i++) {
    sym_idx_t cons = type.constructors.at(i)->constr_name;
    if (cons) {
      cons_enum_name[i] = local_cpp_ids.new_ident(sym::symbols.get_name(cons));
    } else if (type.const_param_idx >= 0) {
      int pv = type.constructors[i]->get_const_param(type.const_param_idx);
      cons_enum_name[i] = local_cpp_ids.new_ident(pv ? "cons" : "cons0", pv);
    } else {
      cons_enum_name[i] = local_cpp_ids.new_ident("cons", i + 1);
    }
  }
}

void CppTypeCode::assign_cons_values() {
  std::vector<std::pair<unsigned long long, int>> a;
  a.reserve(cons_num);
  for (int i = 0; i < cons_num; i++) {
    a.emplace_back(type.constructors[i]->begins_with.min(), i);
  }
  std::sort(a.begin(), a.end());
  cons_enum_value.resize(cons_num);
  cons_idx_by_enum.resize(cons_num);
  int i = 0;
  for (auto z : a) {
    cons_enum_value[z.second] = i;
    cons_idx_by_enum[i++] = z.second;
  }
}

std::vector<std::string> std_field_names = {"x", "y", "z", "t", "u", "v", "w"};

void CppTypeCode::assign_record_cons_names() {
  for (int i = 0; i < cons_num; i++) {
    const Constructor& ctor = *type.constructors.at(i);
    records.emplace_back(*this, ctor, i);
    ConsRecord& record = records.back();
    record.has_trivial_name = (cons_num <= 1 || !ctor.constr_name);
    record.declared = false;
    record.cpp_name = local_cpp_ids.new_ident(cons_num <= 1 ? "Record" : std::string{"Record_"} + cons_enum_name[i]);
    CppIdentSet rec_cpp_ids;
    rec_cpp_ids.insert("type_class");
    rec_cpp_ids.insert(record.cpp_name);
    // maybe : add field identifiers from type class context (?)
    for (int j = 0; j < ctor.fields_num; j++) {
      const Field& field = ctor.fields.at(j);
      if (field.constraint) {
      } else if (!field.implicit) {
        MinMaxSize sz = field.type->compute_size();
        if (!sz.max_size()) {
          continue;
        }
        std::string field_name;
        const ConsRecord* subrec = nullptr;
        if (field.name) {
          field_name = rec_cpp_ids.new_ident(field.get_name());
        } else if (field.subrec) {
          field_name = rec_cpp_ids.new_ident("r", 1);
          subrec = &cpp_type.at(field.type->args.at(0)->type_applied->type_idx)->records.at(0);
        } else if (field.type->tp == TypeExpr::te_Ref) {
          field_name = rec_cpp_ids.new_ident("ref", 1);
        }
        record.cpp_fields.emplace_back(field, field_name, detect_field_cpp_type(field), sz.fixed_bit_size(), j, subrec);
      } else if (field.used && (add_type_members || field.type->is_nat_subtype)) {
        std::string field_name = rec_cpp_ids.new_ident(field.get_name());
        record.cpp_fields.emplace_back(field, field_name, field.type->is_nat_subtype ? ct_int32 : ct_typeptr, -1, j,
                                       nullptr, true);
      }
    }
    auto q = std_field_names.cbegin();
    for (auto& fi : record.cpp_fields) {
      if (fi.name.empty()) {
        bool is_ok = false;
        while (q < std_field_names.cend()) {
          if (!rec_cpp_ids.defined(*q)) {
            fi.name = rec_cpp_ids.new_ident(*q++);
            is_ok = true;
            break;
          }
        }
        if (!is_ok) {
          fi.name = rec_cpp_ids.new_ident("f", 1);
        }
      }
    }
    record.is_trivial = (record.cpp_fields.size() <= 1);
    record.is_small = (record.cpp_fields.size() <= 3);
    record.inline_record = (record.cpp_fields.size() <= 2);
    cpp_val_type t = ct_unknown;
    if (record.is_trivial) {
      t = (record.cpp_fields.size() == 1) ? record.cpp_fields.at(0).ctype : ct_void;
    }
    std::vector<cpp_val_type> tv;
    for (const auto& f : record.cpp_fields) {
      if (f.ctype == ct_subrecord) {
        record.is_trivial = record.is_small = false;
      } else if (!f.implicit) {
        tv.push_back(f.ctype);
      }
    }
    record.equiv_cpp_type = t;
    record.equiv_cpp_types = tv;
    record.triv_conflict = false;
    for (int j = 0; j < i; j++) {
      if (records[j].equiv_cpp_types == tv) {
        record.triv_conflict = records[j].triv_conflict = true;
        break;
      }
    }
  }
}

bool CppTypeCode::ConsRecord::recover_idents(CppIdentSet& idents) const {
  bool is_ok = idents.insert(cpp_name) && idents.insert("type_class");
  for (const auto& f : cpp_fields) {
    is_ok &= idents.insert(f.name);
  }
  return is_ok;
}

void CppTypeCode::assign_class_field_names() {
  char cn = 'm', ct = 'X';
  int c = 0;
  for (int z : type.args) {
    bool f = z & Type::_IsNat;
    bool neg = (z & Type::_IsNeg);
    type_param_is_nat.push_back(f);
    type_param_is_neg.push_back(neg);
    std::string id;
    if (!neg && !c++) {
      template_args += ", ";
      constructor_args += ", ";
    }
    if (f) {
      id = local_cpp_ids.new_ident(std::string{cn}, 0, "_");
      if (cn != 't') {
        ++cn;
      }
      if (!neg) {
        template_args += "int ";
        constructor_args += "int ";
      } else {
        skip_extra_args += ", int& ";
        skip_extra_args_pass += ", ";
      }
    } else {
      id = local_cpp_ids.new_ident(std::string{ct}, 0, "_");
      if (ct != 'Z') {
        ++ct;
      } else {
        ct = 'T';
      }
      assert(!neg);
      template_args += "typename ";
      constructor_args += "const TLB& ";
    }
    type_param_name.push_back(id);
    if (!neg) {
      template_args += id;
      constructor_args += id;
    } else {
      skip_extra_args += id;
      skip_extra_args_pass += id;
    }
  }
}

bool CppTypeCode::compute_simple_cons_tags() {
  if (!type.is_pfx_determ || type.useful_depth > 8) {
    return false;
  }
  int d = type.useful_depth;
  int n = (1 << d);
  cons_tag_map.resize(n, 0);
  //std::cerr << "compute_simple_cons_tags() for `" << type.get_name() << "` (d=" << d << ")\n";
  for (int i = 0; i < cons_num; i++) {
    int t = cons_enum_value.at(i) + 1;
    for (unsigned long long z : type.constructors[i]->begins_with.pfx) {
      int l = std::min(63 - td::count_trailing_zeroes_non_zero64(z), d);
      assert(l <= d);
      int a = d ? (int)((z & (z - 1)) >> (64 - d)) : 0;
      int b = (1 << (d - l));
      while (b-- > 0) {
        assert(!cons_tag_map.at(a) || cons_tag_map[a] == t);
        cons_tag_map[a++] = t;
      }
    }
  }
  int c = 0;
  for (int v : cons_tag_map) {
    if (v && v != c && v != ++c) {
      return false;
    }
  }
  return true;
}

bool CppTypeCode::check_incremental_cons_tags() const {
  if (!cons_num || common_cons_len < 0) {
    return false;
  }
  int l = common_cons_len;
  if (!l || l > 32) {
    return true;
  }
  for (int i = 0; i < cons_num; i++) {
    unsigned long long tag = (type.constructors.at(i)->tag >> (64 - l));
    if (tag != (unsigned)cons_enum_value.at(i)) {
      return false;
    }
  }
  return true;
}

bool CppTypeCode::init() {
  builtin = type.is_builtin;
  cons_num = type.constr_num;
  params = ret_params = tot_params = 0;
  for (int z : type.args) {
    if ((z & Type::_IsNeg)) {
      ++ret_params;
    } else {
      ++params;
    }
    ++tot_params;
  }
  assign_class_name();
  assign_cons_names();
  assign_class_field_names();
  assign_cons_values();
  assign_record_cons_names();
  simple_get_size = type.has_fixed_size;
  inline_skip = simple_get_size;
  inline_validate_skip = (inline_skip && type.any_bits && !(type.size.min_size() & 0xff));
  inline_get_tag = (type.is_pfx_determ && type.useful_depth <= 6);
  simple_cons_tags = compute_simple_cons_tags();
  common_cons_len = type.cons_common_len();
  incremental_cons_tags = check_incremental_cons_tags();
  return true;
}

void CppTypeCode::generate_cons_enum(std::ostream& os) {
  os << "  enum { ";
  for (int i = 0; i < cons_num; i++) {
    if (i) {
      os << ", ";
    }
    int k = cons_idx_by_enum.at(i);
    os << cons_enum_name.at(k);
    assert(cons_enum_value.at(k) == i);
  }
  os << " };\n";
}

void CppTypeCode::generate_cons_len_array(std::ostream& os, std::string nl, int options) {
  bool f = (options & 2);
  os << nl << (f ? "" : "static ") << ((options & 3) ? "constexpr " : "") << "char ";
  if (f) {
    os << cpp_type_class_name << "::";
  }
  os << "cons_len[" << cons_num << "]";
  if (f) {
    os << ";\n";
    return;
  }
  os << " = { ";
  for (int i = 0; i < cons_num; i++) {
    int k = cons_idx_by_enum.at(i);
    const Constructor& constr = *type.constructors.at(k);
    if (i > 0) {
      os << ", ";
    }
    os << constr.tag_bits;
  }
  os << " };\n";
}

void CppTypeCode::generate_cons_tag_array(std::ostream& os, std::string nl, int options) {
  int m = -1;
  for (int i = 0; i < cons_num; i++) {
    int k = cons_idx_by_enum.at(i);
    const Constructor& constr = *type.constructors.at(k);
    if (constr.tag_bits > m) {
      m = constr.tag_bits;
    }
  }
  bool f = (options & 2);
  os << nl << (f ? "" : "static ") << ((options & 3) ? "constexpr " : "");
  if (m <= 8) {
    os << "unsigned char ";
  } else if (m <= 16) {
    os << "unsigned short ";
  } else if (m <= 32) {
    os << "unsigned ";
  } else {
    os << "unsigned long long ";
  }
  if (f) {
    os << cpp_type_class_name << "::";
  }
  os << "cons_tag[" << cons_num << "]";
  if (f) {
    os << ";\n";
    return;
  }
  os << " = { ";
  for (int i = 0; i < cons_num; i++) {
    int k = cons_idx_by_enum.at(i);
    const Constructor& constr = *type.constructors.at(k);
    if (i > 0) {
      os << ", ";
    }
    os << HexConstWriter{constr.tag_bits ? (constr.tag >> (64 - constr.tag_bits)) : 0};
  }
  os << " };\n";
}

void CppTypeCode::generate_cons_tag_info(std::ostream& os, std::string nl, int options) {
  if (cons_num) {
    if (common_cons_len == -1) {
      generate_cons_len_array(os, nl, options);
    } else if (options & 1) {
      os << "  static constexpr int cons_len_exact = " << common_cons_len << ";\n";
    }
    if (common_cons_len != 0 && !incremental_cons_tags) {
      generate_cons_tag_array(os, nl, options);
    }
  }
}

void CppTypeCode::generate_get_tag_subcase(std::ostream& os, std::string nl, const BinTrie* trie, int depth) const {
  if (!trie || !trie->down_tag) {
    os << nl << "return -1; // ???";
    return;
  }
  if (trie->is_unique()) {
    os << nl << "return " << cons_enum_name.at(trie->unique_value()) << ";";
    return;
  }
  if (!trie->useful_depth) {
    generate_get_tag_param(os, nl, trie->down_tag);
    return;
  }
  assert(trie->left || trie->right);
  if (!trie->right) {
    generate_get_tag_subcase(os, nl, trie->left.get(), depth + 1);
    return;
  }
  if (!trie->left) {
    generate_get_tag_subcase(os, nl, trie->right.get(), depth + 1);
    return;
  }
  if (trie->left->is_unique() && trie->right->is_unique()) {
    os << nl << "return cs.bit_at(" << depth << ") ? ";
    int a = trie->right->unique_value(), b = trie->left->unique_value();
    os << (a >= 0 ? cons_enum_name.at(a) : "-1") << " : ";
    os << (b >= 0 ? cons_enum_name.at(b) : "-1") << ";";
    return;
  }
  os << nl << "if (cs.bit_at(" << depth << ")) {";
  generate_get_tag_subcase(os, nl + "  ", trie->right.get(), depth + 1);
  os << nl << "} else {";
  generate_get_tag_subcase(os, nl + "  ", trie->left.get(), depth + 1);
  os << nl << "}";
}

void CppTypeCode::generate_get_tag_param(std::ostream& os, std::string nl, unsigned long long tag,
                                         unsigned long long tag_params) const {
  if (!tag) {
    os << nl << "return -1; // ???";
    return;
  }
  if (!(tag & (tag - 1))) {
    os << nl << "return " << cons_enum_name.at(td::count_trailing_zeroes64(tag)) << ";";
    return;
  }
  int cnt = td::count_bits64(tag);
  DCHECK(cnt >= 2);
  int mdim = 0, mmdim = 0;
  for (int c = 0; c < 64; c++) {
    if ((tag >> c) & 1) {
      int dim = type.constructors.at(c)->admissible_params.dim;
      if (dim > mdim) {
        mmdim = mdim;
        mdim = dim;
      } else if (dim > mmdim) {
        mmdim = dim;
      }
    }
  }
  assert(mmdim > 0);
  for (int p1 = 0; p1 < mmdim; p1++) {
    char A[4];
    std::memset(A, 0, sizeof(A));
    int c;
    for (c = 0; c < 64; c++) {
      if ((tag >> c) & 1) {
        if (!type.constructors[c]->admissible_params.extract1(A, (char)(c + 1), p1)) {
          break;
        }
      }
    }
    if (c == 64) {
      std::string param_name = get_nat_param_name(p1);
      generate_get_tag_param1(os, nl, A, &param_name);
      return;
    }
  }
  for (int p2 = 0; p2 < mmdim; p2++) {
    for (int p1 = 0; p1 < p2; p1++) {
      char A[4][4];
      std::memset(A, 0, sizeof(A));
      int c;
      for (c = 0; c < 64; c++) {
        if ((tag >> c) & 1) {
          if (!type.constructors[c]->admissible_params.extract2(A, (char)(c + 1), p1, p2)) {
            break;
          }
        }
      }
      if (c == 64) {
        std::string param_names[2];
        param_names[0] = get_nat_param_name(p1);
        param_names[1] = get_nat_param_name(p2);
        generate_get_tag_param2(os, nl, A, param_names);
        return;
      }
    }
  }
  for (int p3 = 0; p3 < mmdim; p3++) {
    for (int p2 = 0; p2 < p3; p2++) {
      for (int p1 = 0; p1 < p2; p1++) {
        char A[4][4][4];
        std::memset(A, 0, sizeof(A));
        int c;
        for (c = 0; c < 64; c++) {
          if ((tag >> c) & 1) {
            if (!type.constructors[c]->admissible_params.extract3(A, (char)(c + 1), p1, p2, p3)) {
              break;
            }
          }
        }
        if (c == 64) {
          std::string param_names[3];
          param_names[0] = get_nat_param_name(p1);
          param_names[1] = get_nat_param_name(p2);
          param_names[2] = get_nat_param_name(p3);
          generate_get_tag_param3(os, nl, A, param_names);
          return;
        }
      }
    }
  }
  os << nl << "// ??? cannot distinguish constructors for this type using up to three parameters\n";
  throw src::Fatal{std::string{"cannot generate `"} + cpp_type_class_name + "::get_tag()` method for type `" +
                   type.get_name() + "`"};
}

bool CppTypeCode::match_param_pattern(std::ostream& os, std::string nl, const char A[4], int mask, std::string pattern,
                                      std::string param_name) const {
  int v = 0, w = 0;
  for (int i = 0; i < 4; i++) {
    if (A[i]) {
      if ((mask >> i) & 1) {
        v = (v && v != A[i] ? -1 : A[i]);
      } else {
        w = (w && w != A[i] ? -1 : A[i]);
      }
    }
  }
  if (v <= 0 || w <= 0) {
    return false;
  }
  os << nl << "return ";
  for (char c : pattern) {
    if (c != '#') {
      os << c;
    } else {
      os << param_name;
    }
  }
  os << " ? " << cons_enum_name.at(v - 1) << " : " << cons_enum_name.at(w - 1) << ";";
  return true;
}

void CppTypeCode::generate_get_tag_param1(std::ostream& os, std::string nl, const char A[4],
                                          const std::string param_names[1]) const {
  os << nl << "// distinguish by parameter `" << param_names[0] << "` using";
  for (int i = 0; i < 4; i++) {
    os << ' ' << (int)A[i];
  }
  if (match_param_pattern(os, nl, A, 14, "#", param_names[0]) ||
      match_param_pattern(os, nl, A, 2, "# == 1", param_names[0]) ||
      match_param_pattern(os, nl, A, 3, "# <= 1", param_names[0]) ||
      match_param_pattern(os, nl, A, 10, "(# & 1)", param_names[0]) ||
      match_param_pattern(os, nl, A, 4, "# && !(# & 1)", param_names[0]) ||
      match_param_pattern(os, nl, A, 8, "# > 1 && (# & 1)", param_names[0])) {
    return;
  }
  os << nl << "// static inline size_t nat_abs(int x) { return (x > 1) * 2 + (x & 1); }";
  os << nl << "static signed char ctab[4] = { ";
  for (int i = 0; i < 4; i++) {
    if (i > 0) {
      os << ", ";
    }
    os << (A[i] ? cons_enum_name.at(A[i] - 1) : "-1");
  }
  os << " };" << nl << "return ctab[nat_abs(" << param_names[0] << ")];";
}

void CppTypeCode::generate_get_tag_param2(std::ostream& os, std::string nl, const char A[4][4],
                                          const std::string param_names[2]) const {
  os << nl << "// distinguish by parameters `" << param_names[0] << "`, `" << param_names[1] << "` using";
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      os << ' ' << (int)A[i][j];
    }
  }
  os << nl << "// static inline size_t nat_abs(int x) { return (x > 1) * 2 + (x & 1); }";
  os << nl << "static signed char ctab[4][4] = { ";
  for (int i = 0; i < 16; i++) {
    if (i > 0) {
      os << ", ";
    }
    int v = A[i >> 2][i & 3];
    os << (v ? cons_enum_name.at(v - 1) : "-1");
  }
  os << " };" << nl << "return ctab[nat_abs(" << param_names[0] << ")][nat_abs(" << param_names[1] << ")];";
}

void CppTypeCode::generate_get_tag_param3(std::ostream& os, std::string nl, const char A[4][4][4],
                                          const std::string param_names[3]) const {
  os << nl << "// distinguish by parameters `" << param_names[0] << "`, `" << param_names[1] << "`, `" << param_names[2]
     << "` using";
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      for (int k = 0; k < 4; k++) {
        os << ' ' << (int)A[i][j][k];
      }
    }
  }
  os << nl << "// static inline size_t nat_abs(int x) { return (x > 1) * 2 + (x & 1); }";
  os << nl << "static signed char ctab[4][4][4] = { ";
  for (int i = 0; i < 64; i++) {
    if (i > 0) {
      os << ", ";
    }
    int v = A[i >> 4][(i >> 2) & 3][i & 3];
    os << (v ? cons_enum_name.at(v - 1) : "-1");
  }
  os << " };" << nl << "return ctab[nat_abs(" << param_names[0] << ")][nat_abs(" << param_names[1] << ")][nat_abs("
     << param_names[2] << ")];";
}

std::string CppTypeCode::get_nat_param_name(int idx) const {
  for (int i = 0; i < tot_params; i++) {
    if (!type_param_is_neg.at(i) && type_param_is_nat.at(i) && !idx--) {
      return type_param_name.at(i);
    }
  }
  return "???";
}

void CppTypeCode::generate_tag_pfx_selector(std::ostream& os, std::string nl, const BinTrie& trie, int d,
                                            int min_size) const {
  assert(d >= 0 && d <= 6);
  int n = (1 << d);
  unsigned long long A[64];
  int c[65];
  unsigned long long mask = trie.build_submap(d, A);
  int l = 1;
  c[0] = -1;
  for (int i = 0; i < n; i++) {
    assert(!(A[i] & (A[i] - 1)));
    if ((mask >> l) & 1) {
      c[l++] = A[i] ? td::count_trailing_zeroes_non_zero64(A[i]) : -1;
    }
  }
  bool simple = (l > n / 2);
  if (simple) {
    l = n + 1;
    for (int i = 0; i < n; i++) {
      c[i + 1] = A[i] ? td::count_trailing_zeroes_non_zero64(A[i]) : -1;
    }
  }
  os << nl << "static signed char ctab[" << l << "] = {";
  for (int i = 0; i < l; i++) {
    if (i > 0) {
      os << ", ";
    }
    if (c[i] < 0) {
      os << c[i];
    } else {
      os << cons_enum_name.at(c[i]);
    }
  }
  os << "};" << nl << "return ctab[1 + ";
  if (simple) {
    os << "(long long)cs.prefetch_ulong(" << d << ")];";
  } else {
    os << "(long long)cs.bselect" << (d >= min_size ? "(" : "_ext(") << d << ", " << HexConstWriter{mask} << ")];";
  }
}

bool CppTypeCode::generate_get_tag_pfx_distinguisher(std::ostream& os, std::string nl,
                                                     const std::vector<int>& constr_list, bool in_block) const {
  if (constr_list.empty()) {
    os << nl << "  return -1;";
    return false;
  }
  if (constr_list.size() == 1) {
    os << nl << "  return " << cons_enum_name.at(constr_list[0]) << ";";
    return false;
  }
  std::unique_ptr<BinTrie> trie;
  for (int i : constr_list) {
    trie = BinTrie::insert_paths(std::move(trie), type.constructors.at(i)->begins_with, 1ULL << i);
  }
  if (!trie) {
    os << nl << "  return -1;";
    return false;
  }
  int d = trie->compute_useful_depth();
  bool is_pfx_determ = !trie->find_conflict_path();
  assert(is_pfx_determ);
  if (!in_block) {
    os << " {";
  }
  generate_tag_pfx_selector(os, nl, *trie, d, (int)(type.size.min_size() >> 8));
  return !in_block;
}

void CppTypeCode::generate_get_tag_body(std::ostream& os, std::string nl) {
  int d = type.useful_depth;
  cons_tag_exact.resize(cons_num, false);
  if (type.is_pfx_determ) {
    if (!cons_num) {
      os << nl << "return -1;";
      return;
    }
    if (!d) {
      assert(simple_cons_tags && cons_num == 1);
      cons_tag_exact[0] = !(type.constructors.at(0)->tag_bits);
      os << nl << "return 0;";
      return;
    }
    int min_size = (int)(type.size.min_size() >> 8);
    bool always_has = (d <= min_size);
    if (d <= 6 && simple_cons_tags) {
      unsigned long long sm = compute_selector_mask();
      if (always_has && sm + 1 == (2ULL << ((1 << d) - 1))) {
        for (int i = 0; i < cons_num; i++) {
          cons_tag_exact[i] = (type.constructors.at(i)->tag_bits <= d);
        }
        os << nl << "return (int)cs.prefetch_ulong(" << d << ");";
        return;
      }
      for (int i = 0; i < cons_num; i++) {
        unsigned long long tag = type.constructors.at(i)->tag;
        int l = 63 - td::count_trailing_zeroes_non_zero64(tag);
        if (l <= d) {
          int a = (int)((tag & (tag - 1)) >> (64 - d));
          int b = a + (1 << (d - l));
          cons_tag_exact[i] = ((sm >> a) & 1) && (b == (1 << d) || ((sm >> b) & 1));
        }
      }
      os << nl << "return cs.bselect" << (always_has ? "(" : "_ext(") << d << ", " << HexConstWriter{sm} << ");";
      return;
    }
    if (d <= 6) {
      generate_tag_pfx_selector(os, nl, *(type.cs_trie), d, min_size);
      return;
    }
  }
  if (type.is_const_param_determ || type.is_const_param_pfx_determ) {
    int p = type.const_param_idx;
    assert(p >= 0);
    std::vector<int> param_values = type.get_all_param_values(p);
    assert(param_values.size() > 1 && param_values.at(0) >= 0);
    os << nl << "switch (" << type_param_name.at(p) << ") {";
    for (int pv : param_values) {
      assert(pv >= 0);
      os << nl << "case " << pv << ":";
      std::vector<int> constr_list = type.get_constr_by_param_value(p, pv);
      assert(!constr_list.empty());
      if (constr_list.size() == 1) {
        os << nl << "  return " << cons_enum_name.at(constr_list[0]) << ";";
        continue;
      }
      bool opbr = generate_get_tag_pfx_distinguisher(os, nl + "  ", constr_list, false);
      if (opbr) {
        os << nl << "}";
      }
    }
    os << nl << "default:" << nl << "  return -1;" << nl << "}";
    return;
  }
  if (d) {
    int d1 = std::min(6, d);
    int n = (1 << d1);
    bool always_has = (d1 <= (int)(type.size.min_size() >> 8));
    unsigned long long A[64], B[64];
    unsigned long long mask = type.cs_trie->build_submap(d1, A);
    int l = td::count_bits64(mask);
    bool simple = (l > n / 2 || n <= 8);
    if (!simple) {
      int j = 0;
      for (int i = 0; i < n; i++) {
        if ((mask >> i) & 1) {
          //std::cerr << i << ',' << std::hex << A[i] << std::dec << std::endl;
          B[j] = (2 * i + 1ULL) << (63 - d1);
          A[j++] = A[i];
        }
      }
      assert(j == l);
    } else {
      for (int i = 0; i < n; i++) {
        B[i] = (2 * i + 1ULL) << (63 - d1);
      }
      l = n;
    }
    os << nl << "switch (";
    if (simple) {
      os << "(int)cs.prefetch_ulong(" << d1;
    } else {
      os << "cs.bselect" << (always_has ? "(" : "_ext(") << d1 << ", " << HexConstWriter{mask};
    }
    os << ")) {";
    for (int i = 0; i < l; i++) {
      if (A[i] != 0) {
        if ((long long)A[i] > 0) {
          int j;
          for (j = 0; j < i; j++) {
            if (A[j] == A[i]) {
              break;
            }
          }
          if (j < i) {
            continue;
          }
        }
        os << nl << "case " << i << ":";
        if ((long long)A[i] > 0) {
          int j;
          for (j = i + 1; j < l; j++) {
            if (A[j] == A[i]) {
              os << "  case " << j << ":";
            }
          }
          if (!(A[i] & (A[i] - 1))) {
            os << nl << "  return " << cons_enum_name.at(td::count_trailing_zeroes_non_zero64(A[i])) << ";";
          }
        } else {
          generate_get_tag_subcase(os, nl + "  ", type.cs_trie->lookup_node_const(B[i]), d1);
        }
      }
    }
    os << nl << "default:" << nl << "  return -1;" << nl << "}";
  } else {
    generate_get_tag_subcase(os, nl, type.cs_trie.get(), 0);
  }
}

void CppTypeCode::generate_type_fields(std::ostream& os, int options) {
  int st = -1;
  for (int i = 0; i < tot_params; i++) {
    if (type_param_is_neg[i]) {
      continue;
    }
    int nst = type_param_is_nat[i];
    if (st != nst) {
      if (st >= 0) {
        os << ";\n";
      }
      os << (nst ? "  int " : "  const TLB ");
      st = nst;
    } else {
      os << ", ";
    }
    if (!nst) {
      os << '&';
    }
    os << type_param_name[i];
  }
  if (st >= 0) {
    os << ";\n";
  }
}

static std::string constr_arg_name(std::string type_field_name) {
  if (type_field_name.size() <= 1 || type_field_name.back() != '_') {
    return std::string{"_"} + type_field_name;
  } else {
    return {type_field_name, 0, type_field_name.size() - 1};
  }
}

void CppTypeCode::generate_type_constructor(std::ostream& os, int options) {
  os << "  " << cpp_type_class_name << "(";
  for (int i = 0, j = 0; i < tot_params; i++) {
    if (type_param_is_neg[i]) {
      continue;
    }
    if (j++ > 0) {
      os << ", ";
    }
    os << (type_param_is_nat[i] ? "int " : "const TLB& ");
    os << constr_arg_name(type_param_name[i]);
  }
  os << ")";
  for (int i = 0, j = 0; i < tot_params; i++) {
    if (type_param_is_neg[i]) {
      continue;
    }
    if (j++ > 0) {
      os << ", ";
    } else {
      os << " : ";
    }
    os << type_param_name[i] << "(" << constr_arg_name(type_param_name[i]) << ")";
  }
  os << " {}\n";
}

void Action::show(std::ostream& os) const {
  if (fixed_size >= 0) {
    if (!fixed_size) {
      os << "true";
    } else if (fixed_size < 0x10000) {
      os << "cs.advance(" << fixed_size << ")";
    } else if (!(fixed_size & 0xffff)) {
      os << "cs.advance_refs(" << (fixed_size >> 16) << ")";
    } else {
      os << "cs.advance_ext(0x" << std::hex << fixed_size << std::dec << ")";
    }
  } else {
    os << action;
  }
}

bool Action::may_combine(const Action& next) const {
  return !fixed_size || !next.fixed_size || (fixed_size >= 0 && next.fixed_size >= 0);
}

bool Action::operator+=(const Action& next) {
  if (!next.fixed_size) {
    return true;
  }
  if (!fixed_size) {
    fixed_size = next.fixed_size;
    action = next.action;
    return true;
  }
  if (fixed_size >= 0 && next.fixed_size >= 0) {
    fixed_size += next.fixed_size;
    return true;
  }
  return false;
}

void operator+=(std::vector<Action>& av, const Action& next) {
  if (av.empty() || !(av.back() += next)) {
    if (next.is_constraint && !av.empty() && av.back().fixed_size >= 0) {
      Action last = av.back();
      av.pop_back();
      av.push_back(next);
      av.push_back(last);
    } else {
      av.push_back(next);
    }
  }
}

void CppTypeCode::clear_context() {
  actions.clear();
  incomplete = 0;
  tmp_ints = 0;
  needs_tmp_cell = false;
  tmp_vars.clear();
  field_vars.clear();
  field_var_set.clear();
  param_var_set.clear();
  param_constraint_used.clear();
  tmp_cpp_ids.clear();
  tmp_cpp_ids.new_ident("cs");
  tmp_cpp_ids.new_ident("cb");
  tmp_cpp_ids.new_ident("cell_ref");
  tmp_cpp_ids.new_ident("t");
}

std::string CppTypeCode::new_tmp_var() {
  char buffer[16];
  while (true) {
    sprintf(buffer, "t%d", ++tmp_ints);
    if (tmp_cpp_ids.is_good_ident(buffer) && local_cpp_ids.is_good_ident(buffer)) {
      break;
    }
  }
  std::string s{buffer};
  s = tmp_cpp_ids.new_ident(s);
  tmp_vars.push_back(s);
  return s;
}

std::string CppTypeCode::new_tmp_var(std::string hint) {
  if (hint.empty() || hint == "_") {
    return new_tmp_var();
  }
  int count = 0;
  while (true) {
    std::string s = local_cpp_ids.compute_cpp_ident(hint, count++);
    if (tmp_cpp_ids.is_good_ident(s) && local_cpp_ids.is_good_ident(s)) {
      s = tmp_cpp_ids.new_ident(s);
      tmp_vars.push_back(s);
      return s;
    }
  }
}

std::string compute_type_class_name(const Type* typ, int& fake_arg) {
  fake_arg = -1;
  int idx = typ->type_idx;
  if (idx >= builtin_types_num) {
    return cpp_type[idx]->cpp_type_class_name;
  } else if (typ->produces_nat) {
    if (typ == Nat_type) {
      return "Nat";
    } else if (typ == NatWidth_type) {
      return "NatWidth";
    } else if (typ == NatLeq_type) {
      return "NatLeq";
    } else if (typ == NatLess_type) {
      return "NatLess";
    }
    // ...
  } else if (typ == Any_type) {
    return "Anything";
  } else if (typ->has_fixed_size) {
    fake_arg = (typ->size.min_size() >> 8);
    int c = typ->get_name()[0];
    return (c == 'b') ? "Bits" : ((c == 'u') ? "UInt" : "Int");
  } else if (typ == Int_type) {
    return "Int";
  } else if (typ == UInt_type) {
    return "UInt";
  } else if (typ == Bits_type) {
    return "Bits";
  }
  return "<Unknown_Builtin_Type>";
}

std::string compute_type_expr_class_name(const TypeExpr* expr, int& fake_arg) {
  switch (expr->tp) {
    case TypeExpr::te_Apply:
      return compute_type_class_name(expr->type_applied, fake_arg);
    case TypeExpr::te_Ref:
      return "RefT";
    case TypeExpr::te_Tuple:
      return "TupleT";
    case TypeExpr::te_CondType:
      return "CondT";
  }
  return "<Unknown-Type-Class>";
}

void CppTypeCode::output_cpp_expr(std::ostream& os, const TypeExpr* expr, int prio, bool allow_type_neg) const {
  if (expr->negated) {
    if (!allow_type_neg || expr->tp != TypeExpr::te_Apply) {
      throw src::Fatal{static_cast<std::ostringstream&&>(std::ostringstream{} << "cannot convert negated expression `"
                                                                              << expr << "` into C++ code")
                           .str()};
    }
  }
  int pos_args = 0;
  for (const TypeExpr* arg : expr->args) {
    pos_args += !arg->negated;
  }
  switch (expr->tp) {
    case TypeExpr::te_Param: {
      int i = expr->value;
      assert(field_var_set.at(i));
      std::string fv = field_vars.at(i);
      assert(!fv.empty());
      os << fv;
      return;
    }
    case TypeExpr::te_Apply:
      if (!pos_args && expr->type_applied->type_idx >= builtin_types_num) {
        int type_idx = expr->type_applied->type_idx;
        const CppTypeCode& cc = *cpp_type.at(type_idx);
        assert(!cc.cpp_type_var_name.empty());
        os << cc.cpp_type_var_name;
        return;
      }
      // fall through
    case TypeExpr::te_Ref:
    case TypeExpr::te_CondType:
    case TypeExpr::te_Tuple:
      if (expr->is_constexpr > 0) {
        os << const_type_expr_cpp_idents.at(expr->is_constexpr);
        return;
      } else {
        int fake_arg = -1;
        os << compute_type_expr_class_name(expr, fake_arg);
        os << "{";
        int c = 0;
        if (fake_arg >= 0) {
          os << fake_arg;
          c = 1;
        }
        for (const TypeExpr* arg : expr->args) {
          if (!arg->negated) {
            os << (c++ ? ", " : "");
            output_cpp_expr(os, arg);
          }
        }
        os << '}';
        return;
      }
    case TypeExpr::te_Add:
      if (prio > 10) {
        os << "(";
      }
      output_cpp_expr(os, expr->args[0], 10);
      os << " + ";
      output_cpp_expr(os, expr->args[1], 10);
      if (prio > 10) {
        os << ")";
      }
      return;
    case TypeExpr::te_MulConst:
      if (prio > 20) {
        os << "(";
      }
      os << expr->value;
      os << " * ";
      output_cpp_expr(os, expr->args[0], 20);
      if (prio > 20) {
        os << ")";
      }
      return;
    case TypeExpr::te_GetBit:
      if (prio > 0) {
        os << "(";
      }
      output_cpp_expr(os, expr->args[0], 5);
      os << " & ";
      if (expr->args[1]->tp == TypeExpr::te_IntConst && (unsigned)expr->args[1]->value <= 31) {
        int v = expr->args[1]->value;
        if (v > 1024) {
          os << "0x" << std::hex << (1 << v) << std::dec;
        } else {
          os << (1 << v);
        }
      } else {
        os << "(1 << ";
        output_cpp_expr(os, expr->args[1], 5);
        os << ")";
      }
      if (prio > 0) {
        os << ")";
      }
      return;
    case TypeExpr::te_IntConst:
      os << expr->value;
      return;
  }
  os << "<unknown-expression>";
}

bool CppTypeCode::can_compute_sizeof(const TypeExpr* expr) const {
  if (expr->negated || expr->is_nat) {
    return false;
  }
  MinMaxSize sz = expr->compute_size();
  if (sz.is_fixed()) {
    return !(sz.min_size() & 0xff);
  }
  if (expr->tp == TypeExpr::te_Apply && (expr->type_applied == Int_type || expr->type_applied == UInt_type ||
                                         expr->type_applied == NatWidth_type || expr->type_applied == Bits_type)) {
    return true;
  }
  if (expr->tp != TypeExpr::te_CondType && expr->tp != TypeExpr::te_Tuple) {
    return false;
  }
  return can_compute_sizeof(expr->args[1]);
}

void CppTypeCode::output_cpp_sizeof_expr(std::ostream& os, const TypeExpr* expr, int prio) const {
  if (expr->negated) {
    throw src::Fatal{static_cast<std::ostringstream&&>(std::ostringstream{}
                                                       << "cannot compute size of negated type expression `" << expr
                                                       << "` in C++ code")
                         .str()};
  }
  if (expr->is_nat) {
    throw src::Fatal{static_cast<std::ostringstream&&>(std::ostringstream{}
                                                       << "cannot compute size of non-type expression `" << expr
                                                       << "` in C++ code")
                         .str()};
  }
  MinMaxSize sz = expr->compute_size();
  if (sz.is_fixed()) {
    os << SizeWriter{(int)sz.convert_min_size()};
    return;
  }
  switch (expr->tp) {
    case TypeExpr::te_CondType:
      if (prio > 5) {
        os << '(';
      }
      output_cpp_expr(os, expr->args[0], 5);
      os << " ? ";
      output_cpp_sizeof_expr(os, expr->args[1], 6);
      os << " : 0";
      if (prio > 5) {
        os << ')';
      }
      return;
    case TypeExpr::te_Tuple:
      if (expr->args[0]->tp == TypeExpr::te_IntConst && expr->args[0]->value == 1) {
        output_cpp_sizeof_expr(os, expr->args[1], prio);
        return;
      }
      sz = expr->args[1]->compute_size();
      if (sz.is_fixed() && sz.convert_min_size() == 1) {
        output_cpp_expr(os, expr->args[0], prio);
        return;
      }
      if (prio > 20) {
        os << '(';
      }
      output_cpp_expr(os, expr->args[0], 20);
      os << " * ";
      output_cpp_sizeof_expr(os, expr->args[1], 20);
      if (prio > 20) {
        os << ')';
      }
      return;
    case TypeExpr::te_Apply:
      if (expr->type_applied == Int_type || expr->type_applied == UInt_type || expr->type_applied == NatWidth_type ||
          expr->type_applied == Bits_type) {
        output_cpp_expr(os, expr->args[0], prio);
        return;
      }
      // no break
  }
  os << "<unknown-expression>";
}

bool CppTypeCode::can_compute(const TypeExpr* expr) const {
  if (expr->negated) {
    return false;
  }
  if (expr->tp == TypeExpr::te_Param) {
    return field_var_set.at(expr->value);
  }
  for (const TypeExpr* arg : expr->args) {
    if (!can_compute(arg)) {
      return false;
    }
  }
  return true;
}

bool CppTypeCode::can_use_to_compute(const TypeExpr* expr, int i) const {
  if (!expr->negated || !expr->is_nat) {
    return false;
  }
  if (expr->tp == TypeExpr::te_Param) {
    return expr->value == i;
  }
  for (const TypeExpr* arg : expr->args) {
    if (!(arg->negated ? can_use_to_compute(arg, i) : can_compute(arg))) {
      return false;
    }
  }
  return true;
}

void CppTypeCode::add_compute_actions(const TypeExpr* expr, int i, std::string bind_to) {
  assert(expr->negated && expr->is_nat);
  switch (expr->tp) {
    case TypeExpr::te_MulConst: {
      assert(expr->args.size() == 1 && expr->value > 0);
      const TypeExpr* x = expr->args[0];
      assert(x->negated);
      std::string tmp;
      if (x->tp != TypeExpr::te_Param || (x->value != i && i >= 0)) {
        tmp = new_tmp_var();
      } else {
        i = x->value;
        tmp = field_vars.at(i);
        assert(!tmp.empty());
        assert(!field_var_set[i]);
        field_var_set[i] = true;
        x = nullptr;
      }
      std::ostringstream ss;
      ss << "mul_r1(" << tmp << ", " << expr->value << ", " << bind_to << ")";
      actions += Action{std::move(ss), true};
      if (x) {
        add_compute_actions(x, i, tmp);
      }
      return;
    }
    case TypeExpr::te_Add: {
      assert(expr->args.size() == 2);
      const TypeExpr *x = expr->args[0], *y = expr->args[1];
      assert(x->negated ^ y->negated);
      if (!x->negated) {
        std::swap(x, y);
      }
      std::string tmp;
      if (x->tp != TypeExpr::te_Param || (x->value != i && i >= 0)) {
        tmp = new_tmp_var();
      } else {
        i = x->value;
        tmp = field_vars.at(i);
        assert(!tmp.empty());
        assert(!field_var_set[i]);
        field_var_set[i] = true;
        x = nullptr;
      }
      std::ostringstream ss;
      ss << "add_r1(" << tmp << ", ";
      output_cpp_expr(ss, y);
      ss << ", " << bind_to << ")";
      actions += Action{std::move(ss), true};
      if (x) {
        add_compute_actions(x, i, tmp);
      }
      return;
    }
    case TypeExpr::te_Param:
      assert(expr->value == i || i < 0);
      i = expr->value;
      assert(!field_vars.at(i).empty());
      if (!field_var_set.at(i)) {
        actions += Action{std::string{"("} + field_vars.at(i) + " = " + bind_to + ") >= 0"};
        field_var_set[i] = true;
      } else {
        actions += Action{field_vars.at(i) + " == " + bind_to};
      }
      return;
  }
  throw src::Fatal{static_cast<std::ostringstream&&>(std::ostringstream{} << "cannot use expression `" << expr << "` = "
                                                                          << bind_to << " to set field variable "
                                                                          << (i >= 0 ? field_vars.at(i) : "<unknown>"))
                       .str()};
}

bool CppTypeCode::is_self(const TypeExpr* expr, const Constructor& constr) const {
  if (expr->tp != TypeExpr::te_Apply || expr->type_applied != &type || (int)expr->args.size() != tot_params) {
    return false;
  }
  assert(constr.params.size() == expr->args.size());
  for (int i = 0; i < tot_params; i++) {
    assert(type_param_is_neg[i] == expr->args[i]->negated);
    assert(type_param_is_neg[i] == constr.param_negated[i]);
    if (!type_param_is_neg[i] && !expr->args[i]->equal(*constr.params[i])) {
      return false;
    }
  }
  return true;
}

void CppTypeCode::init_cons_context(const Constructor& constr) {
  clear_context();
  field_vars.resize(constr.fields.size());
  field_var_set.resize(constr.fields.size(), false);
  param_var_set.resize(params + ret_params, false);
  param_constraint_used.resize(params + ret_params, false);
}

void CppTypeCode::identify_cons_params(const Constructor& constr, int options) {
  int j = 0;
  for (const TypeExpr* pexpr : constr.params) {
    if (pexpr->tp == TypeExpr::te_Param) {
      if (!type_param_is_neg.at(j)) {
        int i = pexpr->value;
        if (field_var_set.at(i)) {
          // field i and parameter j must be equal
          actions += Action{type_param_name.at(j) + " == " + field_vars.at(i)};
          param_constraint_used[j] = true;
        } else if (field_vars.at(i).empty()) {
          // identify field i with parameter j
          field_vars[i] = type_param_name.at(j);
          field_var_set[i] = true;
          param_constraint_used[j] = true;
        }
      } else if (!(options & 2)) {
        tmp_vars.push_back(type_param_name.at(j));
      }
    }
    j++;
  }
}

void CppTypeCode::identify_cons_neg_params(const Constructor& constr, int options) {
  int j = 0;
  for (const TypeExpr* pexpr : constr.params) {
    if (pexpr->tp == TypeExpr::te_Param && type_param_is_neg.at(j)) {
      int i = pexpr->value;
      if (!field_var_set.at(i) && field_vars.at(i).empty()) {
        // identify field i with parameter j
        field_vars[i] = type_param_name.at(j);
        param_constraint_used[j] = true;
      }
    }
    j++;
  }
}

void CppTypeCode::add_cons_tag_check(const Constructor& constr, int cidx, int options) {
  if (constr.tag_bits) {
    if ((options & 1) && ((options & 8) || cons_num == 1 || !cons_tag_exact.at(cidx))) {
      std::ostringstream ss;
      int l = constr.tag_bits;
      unsigned long long tag = (constr.tag >> (64 - l));
      if (l < 64) {
        ss << "cs.fetch_ulong(" << l << ") == " << HexConstWriter{tag};
      } else {
        ss << "cs.begins_with_skip(" << l << ", " << HexConstWriter{tag} << ")";
      }
      actions.emplace_back(std::move(ss));
    } else {
      actions.emplace_back(constr.tag_bits);
    }
  }
}

void CppTypeCode::add_cons_tag_store(const Constructor& constr, int cidx) {
  if (constr.tag_bits) {
    std::ostringstream ss;
    int l = constr.tag_bits;
    unsigned long long tag = (constr.tag >> (64 - l));
    ss << "cb.store_long_bool(" << HexConstWriter{tag} << ", " << l << ")";
    actions.emplace_back(std::move(ss));
  }
}

void CppTypeCode::add_remaining_param_constraints_check(const Constructor& constr, int options) {
  int j = 0;
  for (const TypeExpr* pexpr : constr.params) {
    if (!param_constraint_used.at(j)) {
      std::ostringstream ss;
      if (!type_param_is_neg.at(j)) {
        ss << type_param_name.at(j) << " == ";
        output_cpp_expr(ss, pexpr);
        actions += Action{std::move(ss)};
      } else if (options & 2) {
        ss << "(" << type_param_name.at(j) << " = ";
        output_cpp_expr(ss, pexpr);
        ss << ") >= 0";
        actions += Action{std::move(ss), true};
      }
    }
    ++j;
  }
}

void CppTypeCode::output_actions(std::ostream& os, std::string nl, int options) {
  bool opbr = false;
  if (tmp_vars.size() || needs_tmp_cell) {
    if (!(options & 4)) {
      opbr = true;
      os << " {";
    }
    if (tmp_vars.size()) {
      os << nl << "int";
      int c = 0;
      for (auto t : tmp_vars) {
        if (c++) {
          os << ",";
        }
        os << " " << t;
      }
      os << ";";
    }
    if (needs_tmp_cell) {
      os << nl << "Ref<vm::Cell> tmp_cell;";
    }
  }
  if (!actions.size()) {
    os << nl << "return true;";
  } else {
    for (std::size_t i = 0; i < actions.size(); i++) {
      os << nl << (i ? "    && " : "return ");
      actions[i].show(os);
    }
    os << ";";
  }
  if (incomplete) {
    os << nl << "// ???";
  }
  if (opbr) {
    os << nl << "}";
  }
}

void CppTypeCode::compute_implicit_field(const Constructor& constr, const Field& field, int options) {
  int i = field.field_idx;
  if (field_vars.at(i).empty()) {
    assert(!field_var_set.at(i));
    assert(field.type->is_nat_subtype);
    std::string id = new_tmp_var(field.get_name());
    field_vars[i] = id;
  }
  int j = -1;
  for (const TypeExpr* pexpr : constr.params) {
    ++j;
    if (!param_constraint_used.at(j) && !type_param_is_neg.at(j)) {
      // std::cerr << "can_use_to_compute(" << pexpr << ", " << i << ") = " << can_use_to_compute(pexpr, i) << std::endl;
      if (!field_var_set.at(i) && pexpr->tp == TypeExpr::te_Param && pexpr->value == i) {
        std::ostringstream ss;
        if (field.type->is_nat_subtype) {
          ss << "(" << field_vars[i] << " = " << type_param_name.at(j) << ") >= 0";
        } else {
          ss << "(" << field_vars[i] << " = &" << type_param_name.at(j) << ")";
        }
        actions += Action{std::move(ss)};
        field_vars[i] = type_param_name[j];
        field_var_set[i] = true;
        param_constraint_used[j] = true;
      } else if (can_compute(pexpr)) {
        std::ostringstream ss;
        ss << type_param_name.at(j) << " == ";
        output_cpp_expr(ss, pexpr);
        actions += Action{std::move(ss), true};
        param_constraint_used[j] = true;
      } else if (!field_var_set.at(i) && can_use_to_compute(pexpr, i)) {
        add_compute_actions(pexpr, i, type_param_name.at(j));
        param_constraint_used[j] = true;
      }
    }
  }
}

bool CppTypeCode::add_constraint_check(const Constructor& constr, const Field& field, int options) {
  const TypeExpr* expr = field.type;
  if (expr->tp == TypeExpr::te_Apply &&
      (expr->type_applied == Eq_type || expr->type_applied == Less_type || expr->type_applied == Leq_type)) {
    assert(expr->args.size() == 2);
    const TypeExpr *x = expr->args[0], *y = expr->args[1];
    if (x->negated || y->negated) {
      assert(expr->type_applied == Eq_type);
      assert(x->negated ^ y->negated);
      if (!x->negated) {
        std::swap(x, y);
      }
      std::ostringstream ss;
      output_cpp_expr(ss, y);
      add_compute_actions(x, -1, ss.str());
    } else {
      std::ostringstream ss;
      output_cpp_expr(ss, x);
      ss << (expr->type_applied == Eq_type ? " == " : (expr->type_applied == Less_type ? " < " : " <= "));
      output_cpp_expr(ss, y);
      actions += Action{std::move(ss), true};
    }
    return true;
  } else {
    // ...
    ++incomplete;
    actions += Action{"check_constraint_incomplete"};
    return false;
  }
}

void CppTypeCode::output_negative_type_arguments(std::ostream& os, const TypeExpr* expr) {
  assert(expr->tp == TypeExpr::te_Apply);
  for (const TypeExpr* arg : expr->args) {
    if (arg->negated) {
      int j = arg->value;
      if (arg->tp == TypeExpr::te_Param && !field_var_set.at(j)) {
        assert(!field_vars.at(j).empty());
        os << ", " << field_vars.at(j);
        field_var_set[j] = true;
      } else {
        std::string tmp = new_tmp_var();
        os << ", " << tmp;
        postponed_equate.emplace_back(tmp, arg);
      }
    }
  }
}

void CppTypeCode::add_postponed_equate_actions() {
  for (const auto& p : postponed_equate) {
    add_compute_actions(p.second, -1, p.first);
  }
  postponed_equate.clear();
}

std::string CppTypeCode::add_fetch_nat_field(const Constructor& constr, const Field& field, int options) {
  const TypeExpr* expr = field.type;
  int i = field.field_idx;
  std::string id = field_vars.at(i);
  if (id.empty()) {
    field_vars[i] = id = new_tmp_var(field.get_name());
  }
  const Type* ta = expr->type_applied;
  assert(expr->tp == TypeExpr::te_Apply &&
         (ta == Nat_type || ta == NatWidth_type || ta == NatLeq_type || ta == NatLess_type));
  std::ostringstream ss;
  ss << "cs.";
  if (ta == Nat_type) {
    ss << "fetch_uint_to(32, " << id << ")";
  } else if (ta == NatWidth_type && expr->args.at(0)->tp == TypeExpr::te_IntConst && expr->args[0]->value == 1) {
    ss << "fetch_bool_to(" << id << ")";
  } else {
    if (ta == NatWidth_type) {
      ss << "fetch_uint_to(";
    } else if (ta == NatLeq_type) {
      ss << "fetch_uint_leq(";
    } else if (ta == NatLess_type) {
      ss << "fetch_uint_less(";
    }
    output_cpp_expr(ss, expr->args[0]);
    ss << ", " << id << ")";
  }
  actions += Action{std::move(ss)};
  field_var_set[i] = true;
  return id;
}

void CppTypeCode::add_store_nat_field(const Constructor& constr, const Field& field, int options) {
  const TypeExpr* expr = field.type;
  int i = field.field_idx;
  std::string id = field_vars.at(i);
  assert(!id.empty());
  const Type* ta = expr->type_applied;
  assert(expr->tp == TypeExpr::te_Apply &&
         (ta == Nat_type || ta == NatWidth_type || ta == NatLeq_type || ta == NatLess_type));
  std::ostringstream ss;
  ss << "cb.";
  if (ta == Nat_type) {
    ss << "store_ulong_rchk_bool(" << id << ", 32)";
  } else if (ta == NatWidth_type) {
    if (expr->args.at(0)->tp == TypeExpr::te_IntConst && expr->args[0]->value == 1) {
      ss << "store_ulong_rchk_bool(" << id << ", 1)";
    } else {
      ss << "store_ulong_rchk_bool(" << id << ", ";
      output_cpp_expr(ss, expr->args[0]);
      ss << ")";
    }
  } else if (ta == NatLeq_type) {
    ss << "store_uint_leq(";
    output_cpp_expr(ss, expr->args[0]);
    ss << ", " << id << ")";
  } else if (ta == NatLess_type) {
    ss << "store_uint_less(";
    output_cpp_expr(ss, expr->args[0]);
    ss << ", " << id << ")";
  } else {
    ss << "<store-unknown-nat-subtype>(" << id << ")";
  }
  actions += Action{std::move(ss)};
  field_var_set[i] = true;
}

void CppTypeCode::generate_skip_field(const Constructor& constr, const Field& field, int options) {
  const TypeExpr* expr = field.type;
  MinMaxSize sz = expr->compute_size();
  bool any_bits = expr->compute_any_bits();
  bool validating = (options & 1);
  // std::cerr << "field `" << field.get_name() << "` size is " << sz << "; fixed=" << sz.is_fixed() << "; any=" << any_bits << std::endl;
  if (field.used || (validating && expr->is_nat_subtype && !any_bits)) {
    // an explicit field of type # or ## which is used later or its value is not arbitrary
    // (must load the value into an integer variable and check)
    assert(expr->is_nat_subtype && "cannot use fields of non-`#` type");
    add_fetch_nat_field(constr, field, options);
    return;
  }
  if (sz.is_fixed() && (!validating || (!(sz.min_size() & 0xff) && any_bits))) {
    // field has fixed size, and either its bits can have arbitrary values (and it has no references)
    // ... or we are not validating
    // simply skip the necessary amount of bits
    // NB: if the field is a reference, and we are not validating, we arrive here
    actions += Action{(int)sz.convert_min_size()};
    return;
  }
  if (expr->negated) {
    // the field type has some "negative" parameters, which will be computed while checking this field
    // must invoke the correct validate_skip or skip method for the type in question
    std::ostringstream ss;
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100, true);
      ss << '.';
    }
    ss << (validating ? "validate_skip(ops, cs, weak" : "skip(cs");
    output_negative_type_arguments(ss, expr);
    ss << ")";
    actions += Action{std::move(ss)};
    add_postponed_equate_actions();
    return;
  }
  // at this point, if the field type is a reference, we must be validating
  if (expr->tp == TypeExpr::te_Ref && expr->args[0]->tp == TypeExpr::te_Apply &&
      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type)) {
    // field type is a reference to a cell with arbitrary contents
    actions += Action{0x10000};
    return;
  }
  // remaining case: general positive type expression
  std::ostringstream ss;
  std::string tail;
  while (expr->tp == TypeExpr::te_CondType) {
    // optimization for (chains of) conditional types ( x?type )
    assert(expr->args.size() == 2);
    ss << "(!";
    output_cpp_expr(ss, expr->args[0], 30);
    ss << " || ";
    expr = expr->args[1];
    tail = std::string{")"} + tail;
  }
  if ((!validating || any_bits) && can_compute_sizeof(expr)) {
    // field size can be computed at run-time, and either the contents is arbitrary, or we are not validating
    ss << "cs.advance(";
    output_cpp_sizeof_expr(ss, expr, 0);
    ss << ")" << tail;
    actions += Action{std::move(ss)};
    return;
  }
  if (expr->tp != TypeExpr::te_Ref) {
    // field type is not a reference, generate a type expression and invoke skip/validate_skip method
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100);
      ss << '.';
    }
    ss << (validating ? "validate_skip(ops, cs, weak)" : "skip(cs)") << tail;
    actions += Action{std::move(ss)};
    return;
  }
  // the (remaining) field type is a reference
  if (!validating || (expr->args[0]->tp == TypeExpr::te_Apply &&
                      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type))) {
    // the subcase when the field type is either a reference to a cell with arbitrary contents
    // or it is a reference, and we are not validating, so we simply skip the reference
    ss << "cs.advance_refs(1)" << tail;
    actions += Action{std::move(ss)};
    return;
  }
  // general reference type, invoke validate_skip_ref()
  // (notice that we are necessarily validating at this point)
  expr = expr->args[0];
  if (!is_self(expr, constr)) {
    output_cpp_expr(ss, expr, 100);
    ss << '.';
  }
  ss << "validate_skip_ref(ops, cs, weak)" << tail;
  actions += Action{ss.str()};
}

void CppTypeCode::generate_skip_cons_method(std::ostream& os, std::string nl, int cidx, int options) {
  const Constructor& constr = *(type.constructors.at(cidx));
  init_cons_context(constr);
  identify_cons_params(constr, options);
  identify_cons_neg_params(constr, options);
  add_cons_tag_check(constr, cidx, options);
  for (const Field& field : constr.fields) {
    if (!field.implicit) {
      generate_skip_field(constr, field, options);
    } else if (!field.constraint) {
      compute_implicit_field(constr, field, options);
    } else {
      add_constraint_check(constr, field, options);
    }
  }
  add_remaining_param_constraints_check(constr, options);
  output_actions(os, nl, options);
  clear_context();
}

void CppTypeCode::generate_skip_method(std::ostream& os, int options) {
  bool validate = options & 1;
  bool ret_ext = options & 2;
  os << "\nbool " << cpp_type_class_name
     << "::" << (validate ? "validate_skip(int* ops, vm::CellSlice& cs, bool weak" : "skip(vm::CellSlice& cs");
  if (ret_ext) {
    os << skip_extra_args;
  }
  os << ") const {";
  if (cons_num > 1) {
    os << "\n  switch (get_tag(cs)) {\n";
    for (int i = 0; i < cons_num; i++) {
      os << "  case " << cons_enum_name[i] << ":";
      generate_skip_cons_method(os, "\n    ", i, options & ~4);
      os << "\n";
    }
    os << "  }\n  return false;\n";
  } else if (cons_num == 1) {
    generate_skip_cons_method(os, "\n  ", 0, options | 4);
    os << "\n";
  } else {
    os << "\n  return false;\n";
  }
  os << "}\n";
}

void CppTypeCode::generate_cons_tag_check(std::ostream& os, std::string nl, int cidx, bool force) {
  const Constructor& constr = *(type.constructors.at(cidx));
  if (!constr.tag_bits) {
    os << nl << "return " << cons_enum_name[cidx] << ";";
  } else if (force || cons_num == 1 || !cons_tag_exact.at(cidx)) {
    os << nl << "return ";
    int l = constr.tag_bits;
    unsigned long long tag = (constr.tag >> (64 - l));
    if (l < 64 || tag != ~0ULL) {
      os << "cs.prefetch_ulong(" << l << ") == " << HexConstWriter{tag};
    } else {
      os << "cs.begins_with(" << l << ", " << HexConstWriter{tag} << ")";
    }
    os << " ? " << cons_enum_name[cidx] << " : -1;";
  } else {
    os << nl << "return cs.have(" << constr.tag_bits << ") ? " << cons_enum_name[cidx] << " : -1;";
  }
}

void CppTypeCode::generate_check_tag_method(std::ostream& os) {
  os << "\nint " << cpp_type_class_name << "::check_tag(const vm::CellSlice& cs) const {";
  if (cons_num > 1) {
    os << "\n  switch (get_tag(cs)) {\n";
    for (int i = 0; i < cons_num; i++) {
      os << "  case " << cons_enum_name[i] << ":";
      generate_cons_tag_check(os, "\n    ", i);
      os << "\n";
    }
    os << "  }\n  return -1;\n";
  } else if (cons_num == 1) {
    generate_cons_tag_check(os, "\n  ", 0);
    os << "\n";
  } else {
    os << "\n  return -1;\n";
  }
  os << "}\n";
}

bool CppTypeCode::output_print_simple_field(std::ostream& os, const Field& field, std::string field_name,
                                            const TypeExpr* expr) {
  cpp_val_type cvt = detect_cpp_type(expr);
  MinMaxSize sz = expr->compute_size();
  int i = expr->is_integer();
  int l = (sz.is_fixed() ? sz.convert_min_size() : -1);
  switch (cvt) {
    case ct_bitstring:
    case ct_bits:
      assert(!(sz.max_size() & 0xff));
      os << "pp.fetch_bits_field(cs, ";
      output_cpp_sizeof_expr(os, expr, 0);
      if (!field_name.empty()) {
        os << ", \"" << field_name << '"';
      }
      os << ")";
      return true;
    case ct_bool:
    case ct_int32:
    case ct_uint32:
    case ct_int64:
    case ct_uint64:
      assert(i && l <= 64);
      os << "pp.fetch_" << (i > 0 ? "u" : "") << "int_field(cs, ";
      output_cpp_sizeof_expr(os, expr, 0);
      if (!field_name.empty()) {
        os << ", \"" << field_name << '"';
      }
      os << ")";
      return true;
    case ct_integer:
      assert(i);
      os << "pp.fetch_" << (i > 0 ? "u" : "") << "int256_field(cs, ";
      output_cpp_sizeof_expr(os, expr, 0);
      if (!field_name.empty()) {
        os << ", \"" << field_name << '"';
      }
      os << ")";
      return true;
    default:
      break;
  }
  return false;
}

void CppTypeCode::generate_print_field(const Constructor& constr, const Field& field, int options) {
  const TypeExpr* expr = field.type;
  MinMaxSize sz = expr->compute_size();
  cpp_val_type cvt = detect_cpp_type(expr);
  bool any_bits = expr->compute_any_bits();
  bool is_simple = (cvt >= ct_bits && cvt <= ct_uint64 && cvt != ct_enum);
  // std::cerr << "field `" << field.get_name() << "` size is " << sz << "; fixed=" << sz.is_fixed() << "; any=" << any_bits << std::endl;
  std::string field_name = field.name ? field.get_name() : "";
  if (field.used || expr->is_nat_subtype) {
    // an explicit field of type # or ##
    assert(expr->is_nat_subtype && "cannot use fields of non-`#` type");
    std::ostringstream ss;
    ss << "pp.field_int(" << add_fetch_nat_field(constr, field, options);
    if (field.name) {
      ss << ", \"" << field_name << '"';
    }
    ss << ')';
    actions += Action{std::move(ss)};
    return;
  }
  if (sz.is_fixed() && !(sz.min_size() & 0xff) && any_bits) {
    // field has fixed size, and either its bits can have arbitrary values (and it has no references)
    std::ostringstream ss;
    if (output_print_simple_field(ss, field, field_name, expr)) {
      actions += Action{std::move(ss)};
      return;
    }
  }
  bool cond_chain = (expr->tp == TypeExpr::te_CondType);
  if (!cond_chain && !is_simple) {
    if (field.name) {
      actions += Action{std::string{"pp.field(\""} + field_name + "\")"};
    } else {
      actions += Action{"pp.field()"};
    }
  }
  if (expr->negated) {
    // the field type has some "negative" parameters, which will be computed while checking this field
    // must invoke the correct validate_skip or skip method for the type in question
    assert(!cond_chain);
    std::ostringstream ss;
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100, true);
      ss << '.';
    }
    ss << "print_skip(pp, cs";
    output_negative_type_arguments(ss, expr);
    ss << ")";
    actions += Action{std::move(ss)};
    add_postponed_equate_actions();
    return;
  }
  // remaining case: general positive type expression
  std::ostringstream ss;
  std::string tail;
  while (expr->tp == TypeExpr::te_CondType) {
    // optimization for (chains of) conditional types ( x?type )
    assert(expr->args.size() == 2);
    ss << "(!";
    output_cpp_expr(ss, expr->args[0], 30);
    ss << " || ";
    expr = expr->args[1];
    tail += ')';
  }
  if (output_print_simple_field(ss, field, field_name, expr)) {
    ss << tail;
    actions += Action{std::move(ss)};
    return;
  }
  if (cond_chain) {
    if (field.name) {
      ss << "(pp.field(\"" + field_name + "\") && ";
    } else {
      ss << "(pp.field() && ";
    }
    tail += ')';
  }
  if (expr->tp != TypeExpr::te_Ref) {
    // field type is not a reference, generate a type expression and invoke skip/validate_skip method
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100);
      ss << '.';
    }
    ss << "print_skip(pp, cs)" << tail;
    actions += Action{std::move(ss)};
    return;
  }
  // general reference type, invoke print_ref()
  expr = expr->args[0];
  if (!is_self(expr, constr)) {
    output_cpp_expr(ss, expr, 100);
    ss << '.';
  }
  ss << "print_ref(pp, cs.fetch_ref())" << tail;
  actions += Action{ss.str()};
}

void CppTypeCode::generate_print_cons_method(std::ostream& os, std::string nl, int cidx, int options) {
  const Constructor& constr = *(type.constructors.at(cidx));
  init_cons_context(constr);
  identify_cons_params(constr, options);
  identify_cons_neg_params(constr, options);
  add_cons_tag_check(constr, cidx, options);
  bool do_open = !constr.is_enum;
  if (do_open) {
    if (constr.constr_name) {
      actions += Action{std::string{"pp.open(\""} + constr.get_name() + "\")"};
    } else {
      actions += Action{"pp.open()"};
    }
  } else {
    actions += Action{std::string{"pp.cons(\""} + constr.get_name() + "\")"};
  }
  for (const Field& field : constr.fields) {
    if (!field.implicit) {
      generate_print_field(constr, field, options);
    } else if (!field.constraint) {
      compute_implicit_field(constr, field, options);
    } else {
      add_constraint_check(constr, field, options);
    }
  }
  add_remaining_param_constraints_check(constr, options);
  if (do_open) {
    actions += Action{"pp.close()"};
  }
  output_actions(os, nl, options);
  clear_context();
}

void CppTypeCode::generate_print_method(std::ostream& os, int options) {
  bool ret_ext = options & 2;
  os << "\nbool " << cpp_type_class_name << "::print_skip(PrettyPrinter& pp, vm::CellSlice& cs";
  if (ret_ext) {
    os << skip_extra_args;
  }
  os << ") const {";
  if (cons_num > 1) {
    os << "\n  switch (get_tag(cs)) {\n";
    for (int i = 0; i < cons_num; i++) {
      os << "  case " << cons_enum_name[i] << ":";
      generate_print_cons_method(os, "\n    ", i, options & ~4);
      os << "\n";
    }
    os << "  }\n  return pp.fail(\"unknown constructor for " << type.get_name() << "\");\n";
  } else if (cons_num == 1) {
    generate_print_cons_method(os, "\n  ", 0, options | 4);
    os << "\n";
  } else {
    os << "\n  return pp.fail(\"no constructors for " << type.get_name() << "\");\n";
  }
  os << "}\n";
}

void CppTypeCode::bind_record_fields(const CppTypeCode::ConsRecord& rec, int options) {
  bool direct = options & 8;
  bool read_only = options & 32;
  for (const ConsField& fi : rec.cpp_fields) {
    int i = fi.orig_idx;
    assert(field_vars.at(i).empty() && !field_var_set.at(i));
    if (!read_only || !rec.constr.fields.at(i).implicit) {
      field_vars[i] = direct ? fi.name : std::string{"data."} + fi.name;
      field_var_set[i] = read_only;
    }
  }
}

void CppTypeCode::output_fetch_field(std::ostream& os, std::string field_var, const TypeExpr* expr, cpp_val_type cvt) {
  int i = expr->is_integer();
  MinMaxSize sz = expr->compute_size();
  int l = (sz.is_fixed() ? sz.convert_min_size() : -1);
  switch (cvt) {
    case ct_slice:
      os << "cs.fetch_subslice_" << (sz.max_size() & 0xff ? "ext_" : "") << "to(";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ", " << field_var << ")";
      return;
    case ct_bitstring:
      assert(!(sz.max_size() & 0xff));
      os << "cs.fetch_bitstring_to(";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ", " << field_var << ")";
      return;
    case ct_bits:
      assert(l >= 0 && l < 0x10000);
      os << "cs.fetch_bits_to(" << field_var << ".bits(), " << l << ")";
      return;
    case ct_cell:
      assert(l == 0x10000);
      os << "cs.fetch_ref_to(" << field_var << ")";
      return;
    case ct_bool:
      assert(i > 0 && l == 1);
      os << "cs.fetch_bool_to(" << field_var << ")";
      return;
    case ct_int32:
    case ct_uint32:
    case ct_int64:
    case ct_uint64:
      assert(i && l <= 64);
      os << "cs.fetch_" << (i > 0 ? "u" : "") << "int_to(";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ", " << field_var << ")";
      return;
    case ct_integer:
      assert(i);
      os << "cs.fetch_" << (i > 0 ? "u" : "") << "int256_to(";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ", " << field_var << ")";
      return;
    default:
      break;
  }
  throw src::Fatal{"cannot fetch a field of unknown scalar type"};
}

void CppTypeCode::output_fetch_subrecord(std::ostream& os, std::string field_name, const ConsRecord* subrec) {
  assert(subrec);
  os << subrec->cpp_type.cpp_type_var_name << ".cell_unpack(cs.fetch_ref(), " << field_name << ")";
}

void CppTypeCode::generate_unpack_field(const CppTypeCode::ConsField& fi, const Constructor& constr, const Field& field,
                                        int options) {
  int i = field.field_idx;
  const TypeExpr* expr = field.type;
  MinMaxSize sz = expr->compute_size();
  bool any_bits = expr->compute_any_bits();
  bool validating = (options & 1);
  cpp_val_type cvt = fi.ctype;
  // std::cerr << "field `" << field.get_name() << "` size is " << sz << "; fixed=" << sz.is_fixed() << "; any=" << any_bits << std::endl;
  if (field.used || expr->is_nat_subtype) {
    assert(expr->is_nat_subtype && "cannot use fields of non-`#` type");
    assert(cvt == ct_int32 || cvt == ct_bool);
    add_fetch_nat_field(constr, field, options);
    return;
  }
  if (sz.is_fixed() && cvt != ct_enum && (!validating || (!(sz.min_size() & 0xff) && any_bits))) {
    // field has fixed size, and either its bits can have arbitrary values (and it has no references)
    // ... or we are not validating
    // simply skip the necessary amount of bits
    // NB: if the field is a reference, and we are not validating, we arrive here
    if (cvt == ct_cell) {
      assert(sz.min_size() == 1);
    }
    std::ostringstream ss;
    if (cvt == ct_subrecord && field.subrec) {
      output_fetch_subrecord(ss, field_vars.at(i), fi.subrec);
    } else {
      output_fetch_field(ss, field_vars.at(i), expr, cvt);
    }
    actions += Action{std::move(ss)};
    field_var_set[i] = true;
    return;
  }
  if (expr->negated) {
    // the field type has some "negative" parameters, which will be computed while checking this field
    // must invoke the correct validate_skip or skip method for the type in question
    std::ostringstream ss;
    assert(cvt == ct_slice);
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100, true);
      ss << '.';
    }
    ss << (validating ? "validate_fetch_to(ops, cs, weak, " : "fetch_to(cs, ") << field_vars.at(i);
    output_negative_type_arguments(ss, expr);
    ss << ")";
    actions += Action{std::move(ss)};
    add_postponed_equate_actions();
    field_var_set[i] = true;
    return;
  }
  // at this point, if the field type is a reference, we must be validating
  if (expr->tp == TypeExpr::te_Ref && expr->args[0]->tp == TypeExpr::te_Apply &&
      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type)) {
    // field type is a reference to a cell with arbitrary contents
    assert(cvt == ct_cell);
    actions += Action{"cs.fetch_ref_to(" + field_vars.at(i) + ")"};
    field_var_set[i] = true;
    return;
  }
  // remaining case: general positive type expression
  std::ostringstream ss;
  std::string tail;
  while (expr->tp == TypeExpr::te_CondType) {
    // optimization for (chains of) conditional types ( x?type )
    assert(expr->args.size() == 2);
    ss << "(!";
    output_cpp_expr(ss, expr->args[0], 30);
    ss << " || ";
    expr = expr->args[1];
    tail = std::string{")"} + tail;
  }
  if ((!validating || any_bits) && can_compute_sizeof(expr) && cvt != ct_enum) {
    // field size can be computed at run-time, and either the contents is arbitrary, or we are not validating
    output_fetch_field(ss, field_vars.at(i), expr, cvt);
    field_var_set[i] = true;
    ss << tail;
    actions += Action{std::move(ss)};
    return;
  }
  if (expr->tp != TypeExpr::te_Ref) {
    // field type is not a reference, generate a type expression and invoke skip/validate_skip method
    assert(cvt == ct_slice || cvt == ct_enum);
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100);
      ss << '.';
    }
    ss << (validating ? "validate_" : "") << "fetch_" << (cvt == ct_enum ? "enum_" : "")
       << (validating ? "to(ops, cs, weak, " : "to(cs, ") << field_vars.at(i) << ")" << tail;
    field_var_set[i] = true;
    actions += Action{std::move(ss)};
    return;
  }
  // the (remaining) field type is a reference
  if (!validating || (expr->args[0]->tp == TypeExpr::te_Apply &&
                      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type))) {
    // the subcase when the field type is either a reference to a cell with arbitrary contents
    // or it is a reference, and we are not validating, so we simply skip the reference
    assert(cvt == ct_cell);
    ss << "cs.fetch_ref_to(" << field_vars.at(i) << ")" << tail;
    field_var_set[i] = true;
    actions += Action{std::move(ss)};
    return;
  }
  // general reference type, invoke validate_skip_ref()
  // (notice that we are necessarily validating at this point)
  expr = expr->args[0];
  assert(cvt == ct_cell);
  ss << "(cs.fetch_ref_to(" << field_vars.at(i) << ") && ";
  if (!is_self(expr, constr)) {
    output_cpp_expr(ss, expr, 100);
    ss << '.';
  }
  ss << "validate_ref(ops, " << field_vars.at(i) << "))" << tail;
  actions += Action{ss.str()};
}

void CppTypeCode::generate_unpack_method(std::ostream& os, CppTypeCode::ConsRecord& rec, int options) {
  std::ostringstream tmp;
  if (!rec.declare_record_unpack(tmp, "", options)) {
    return;
  }
  tmp.clear();
  os << "\n";
  bool res = rec.declare_record_unpack(os, "", options | 3072);
  DCHECK(res);
  if (options & 16) {
    // cell unpack version
    os << "\n  if (cell_ref.is_null()) { return false; }"
       << "\n  auto cs = load_cell_slice(std::move(cell_ref));"
       << "\n  return " << (options & 1 ? "validate_" : "") << "unpack";
    if (!(options & 8)) {
      os << "(";
      if (options & 1) {
        os << "ops, ";
      }
      os << "cs, data";
    } else {
      os << "_" << cons_enum_name.at(rec.cons_idx) << "(cs";
      for (const auto& f : rec.cpp_fields) {
        os << ", " << f.name;
      }
    }
    if (options & 2) {
      os << skip_extra_args_pass;
    }
    os << ") && cs.empty_ext();\n}\n";
    return;
  }
  init_cons_context(rec.constr);
  bind_record_fields(rec, options);
  identify_cons_params(rec.constr, options);
  identify_cons_neg_params(rec.constr, options);
  add_cons_tag_check(rec.constr, rec.cons_idx, 9 /* (options & 1) | 8 */);
  auto it = rec.cpp_fields.cbegin(), end = rec.cpp_fields.cend();
  for (const Field& field : rec.constr.fields) {
    if (field.constraint) {
      add_constraint_check(rec.constr, field, options);
      continue;
    }
    if (!field.implicit) {
      assert(it < end && it->orig_idx == field.field_idx);
      generate_unpack_field(*it++, rec.constr, field, options);
    } else {
      if (it < end && it->orig_idx == field.field_idx) {
        ++it;
      }
      compute_implicit_field(rec.constr, field, options);
    }
  }
  assert(it == end);
  add_remaining_param_constraints_check(rec.constr, options);
  output_actions(os, "\n  ", options | 4);
  clear_context();
  os << "\n}\n";
}

void CppTypeCode::output_store_field(std::ostream& os, std::string field_var, const TypeExpr* expr, cpp_val_type cvt) {
  int i = expr->is_integer();
  MinMaxSize sz = expr->compute_size();
  int l = (sz.is_fixed() ? sz.convert_min_size() : -1);
  switch (cvt) {
    case ct_slice:
      os << "cb.append_cellslice_chk(" << field_var << ", ";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ")";
      return;
    case ct_bitstring:
      assert(!(sz.max_size() & 0xff));
      os << "cb.append_bitstring_chk(" << field_var << ", ";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ")";
      return;
    case ct_bits:
      assert(l >= 0 && l < 0x10000);
      os << "cb.store_bits_bool(" << field_var << ".cbits(), " << l << ")";
      return;
    case ct_cell:
      assert(l == 0x10000);
      os << "cb.store_ref_bool(" << field_var << ")";
      return;
    case ct_bool:
      assert(i > 0 && l == 1);
      // os << "cb.store_bool(" << field_var << ")";
      // return;
      // fall through
    case ct_int32:
    case ct_uint32:
    case ct_int64:
    case ct_uint64:
      assert(i && l <= 64);
      os << "cb.store_" << (i > 0 ? "u" : "") << "long_rchk_bool(" << field_var << ", ";
      output_cpp_sizeof_expr(os, expr, 0);
      os << ")";
      return;
    case ct_integer:
      assert(i);
      os << "cb.store_int256_bool(" << field_var << ", ";
      output_cpp_sizeof_expr(os, expr, 0);
      os << (i > 0 ? ", false)" : ")");
      return;
    default:
      break;
  }
  throw src::Fatal{"cannot store a field of unknown scalar type"};
}

void CppTypeCode::add_store_subrecord(std::string field_name, const ConsRecord* subrec) {
  assert(subrec);
  needs_tmp_cell = true;
  std::ostringstream ss;
  ss << subrec->cpp_type.cpp_type_var_name << ".cell_pack(tmp_cell, " << field_name << ")";
  actions += Action{std::move(ss)};
  actions += Action{"cb.store_ref_bool(std::move(tmp_cell))"};
}

void CppTypeCode::generate_pack_field(const CppTypeCode::ConsField& fi, const Constructor& constr, const Field& field,
                                      int options) {
  int i = field.field_idx;
  const TypeExpr* expr = field.type;
  MinMaxSize sz = expr->compute_size();
  bool any_bits = expr->compute_any_bits();
  bool validating = (options & 1);
  cpp_val_type cvt = fi.ctype;
  // std::cerr << "field `" << field.get_name() << "` size is " << sz << "; fixed=" << sz.is_fixed() << "; any=" << any_bits << std::endl;
  if (field.used || expr->is_nat_subtype) {
    assert(expr->is_nat_subtype && "cannot use fields of non-`#` type");
    assert(cvt == ct_int32 || cvt == ct_bool);
    add_store_nat_field(constr, field, options);
    return;
  }
  if (sz.is_fixed() && cvt != ct_enum && (!validating || (!(sz.min_size() & 0xff) && any_bits))) {
    // field has fixed size, and either its bits can have arbitrary values (and it has no references)
    // ... or we are not validating
    // simply skip the necessary amount of bits
    // NB: if the field is a reference, and we are not validating, we arrive here
    if (cvt == ct_cell) {
      assert(sz.min_size() == 1);
    }
    if (cvt == ct_subrecord && field.subrec) {
      add_store_subrecord(field_vars.at(i), fi.subrec);
    } else {
      std::ostringstream ss;
      output_store_field(ss, field_vars.at(i), expr, cvt);
      actions += Action{std::move(ss)};
    }
    field_var_set[i] = true;
    return;
  }
  if (expr->negated) {
    // the field type has some "negative" parameters, which will be computed while checking this field
    // must invoke the correct validate_skip or skip method for the type in question
    std::ostringstream ss;
    assert(cvt == ct_slice);
    ss << "tlb::" << (validating ? "validate_" : "") << "store_from(cb, ";
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 5, true);
    } else {
      ss << "*this";
    }
    ss << ", " << field_vars.at(i);
    output_negative_type_arguments(ss, expr);
    ss << ")";
    actions += Action{std::move(ss)};
    add_postponed_equate_actions();
    field_var_set[i] = true;
    return;
  }
  // at this point, if the field type is a reference, we must be validating
  if (expr->tp == TypeExpr::te_Ref && expr->args[0]->tp == TypeExpr::te_Apply &&
      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type)) {
    // field type is a reference to a cell with arbitrary contents
    assert(cvt == ct_cell);
    actions += Action{"cb.store_ref_bool(" + field_vars.at(i) + ")"};
    field_var_set[i] = true;
    return;
  }
  // remaining case: general positive type expression
  std::ostringstream ss;
  std::string tail;
  while (expr->tp == TypeExpr::te_CondType) {
    // optimization for (chains of) conditional types ( x?type )
    assert(expr->args.size() == 2);
    ss << "(!";
    output_cpp_expr(ss, expr->args[0], 30);
    ss << " || ";
    expr = expr->args[1];
    tail = std::string{")"} + tail;
  }
  if ((!validating || any_bits) && can_compute_sizeof(expr) && cvt != ct_enum) {
    // field size can be computed at run-time, and either the contents is arbitrary, or we are not validating
    output_store_field(ss, field_vars.at(i), expr, cvt);
    field_var_set[i] = true;
    ss << tail;
    actions += Action{std::move(ss)};
    return;
  }
  if (expr->tp != TypeExpr::te_Ref) {
    // field type is not a reference, generate a type expression and invoke skip/validate_skip method
    assert(cvt == ct_slice || cvt == ct_enum);
    if (!is_self(expr, constr)) {
      output_cpp_expr(ss, expr, 100);
      ss << '.';
    }
    ss << (validating ? "validate_" : "") << "store_" << (cvt == ct_enum ? "enum_" : "") << "from(cb, "
       << field_vars.at(i) << ")" << tail;
    field_var_set[i] = true;
    actions += Action{std::move(ss)};
    return;
  }
  // the (remaining) field type is a reference
  if (!validating || (expr->args[0]->tp == TypeExpr::te_Apply &&
                      (expr->args[0]->type_applied == Cell_type || expr->args[0]->type_applied == Any_type))) {
    // the subcase when the field type is either a reference to a cell with arbitrary contents
    // or it is a reference, and we are not validating, so we simply skip the reference
    assert(cvt == ct_cell);
    ss << "cb.store_ref_bool(" << field_vars.at(i) << ")" << tail;
    field_var_set[i] = true;
    actions += Action{std::move(ss)};
    return;
  }
  // general reference type, invoke validate_skip_ref()
  // (notice that we are necessarily validating at this point)
  expr = expr->args[0];
  assert(cvt == ct_cell);
  ss << "(cb.store_ref_bool(" << field_vars.at(i) << ") && ";
  if (!is_self(expr, constr)) {
    output_cpp_expr(ss, expr, 100);
    ss << '.';
  }
  ss << "validate_ref(ops, " << field_vars.at(i) << "))" << tail;
  actions += Action{ss.str()};
}

void CppTypeCode::generate_pack_method(std::ostream& os, CppTypeCode::ConsRecord& rec, int options) {
  std::ostringstream tmp;
  if (!rec.declare_record_pack(tmp, "", options)) {
    return;
  }
  tmp.clear();
  os << "\n";
  bool res = rec.declare_record_pack(os, "", options | 3072);
  DCHECK(res);
  if (options & 16) {
    // cell pack version
    os << "\n  vm::CellBuilder cb;"
       << "\n  return " << (options & 1 ? "validate_" : "") << "pack";
    if (!(options & 8)) {
      os << "(cb, data";
    } else {
      os << "_" << cons_enum_name.at(rec.cons_idx) << "(cb";
      for (const auto& f : rec.cpp_fields) {
        // skip SOME implicit fields ???
        if (f.implicit) {
        } else if (f.get_cvt().needs_move()) {
          os << ", std::move(" << f.name << ")";
        } else {
          os << ", " << f.name;
        }
      }
    }
    if (options & 2) {
      os << skip_extra_args_pass;
    }
    os << ") && std::move(cb).finalize_to(cell_ref);\n}\n";
    return;
  }
  init_cons_context(rec.constr);
  bind_record_fields(rec, options | 32);
  identify_cons_params(rec.constr, options);
  identify_cons_neg_params(rec.constr, options);
  add_cons_tag_store(rec.constr, rec.cons_idx);
  auto it = rec.cpp_fields.cbegin(), end = rec.cpp_fields.cend();
  for (const Field& field : rec.constr.fields) {
    if (field.constraint) {
      add_constraint_check(rec.constr, field, options);
      continue;
    }
    if (!field.implicit) {
      assert(it < end && it->orig_idx == field.field_idx);
      generate_pack_field(*it++, rec.constr, field, options);
    } else {
      if (it < end && it->orig_idx == field.field_idx) {
        ++it;
      }
      compute_implicit_field(rec.constr, field, options);
    }
  }
  assert(it == end);
  add_remaining_param_constraints_check(rec.constr, options);
  output_actions(os, "\n  ", options | 4);
  clear_context();
  os << "\n}\n";
}

void CppTypeCode::generate_ext_fetch_to(std::ostream& os, int options) {
  std::string validate = (options & 1) ? "validate_" : "";
  os << "\nbool " << cpp_type_class_name << "::" << validate << "fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res"
     << skip_extra_args << ") const {\n"
     << "  res = Ref<vm::CellSlice>{true, cs};\n"
     << "  return " << validate << "skip(cs" << skip_extra_args_pass << ") && res.unique_write().cut_tail(cs);\n"
     << "}\n";
}

void CppTypeCode::ConsRecord::declare_record(std::ostream& os, std::string nl, int options) {
  bool force = options & 1024;
  if (declared) {
    return;
  }
  if (!force) {
    os << nl << "struct " << cpp_name;
    if (!inline_record) {
      os << ";\n";
      return;
    }
  } else {
    os << "\n" << nl << "struct " << cpp_type.cpp_type_class_name << "::" << cpp_name;
  }
  os << " {\n";
  os << nl << "  typedef " << cpp_type.cpp_type_class_name << " type_class;\n";
  CppIdentSet rec_cpp_ids;
  recover_idents(rec_cpp_ids);
  std::size_t n = cpp_fields.size();
  for (const ConsField& fi : cpp_fields) {
    os << nl << "  ";
    fi.print_type(os);
    os << " " << fi.name << ";  \t// ";
    if (fi.field.name) {
      os << fi.field.get_name() << " : ";
    }
    fi.field.type->show(os, &constr);
    os << std::endl;
  }
  if (n) {
    os << nl << "  " << cpp_name << "() = default;\n";
    std::vector<std::string> ctor_args;
    os << nl << "  " << cpp_name << "(";
    int i = 0, j = 0;
    for (const ConsField& fi : cpp_fields) {
      if (!fi.implicit) {
        std::string arg = rec_cpp_ids.new_ident(std::string{"_"} + fi.name);
        ctor_args.push_back(arg);
        if (i++) {
          os << ", ";
        }
        fi.print_type(os, true);
        os << " " << arg;
      }
    }
    os << ") : ";
    i = 0;
    for (const ConsField& fi : cpp_fields) {
      if (i++) {
        os << ", ";
      }
      os << fi.name << "(";
      if (fi.implicit) {
        os << (fi.ctype == ct_int32 ? "-1" : "nullptr");
      } else if (fi.get_cvt().needs_move()) {
        os << "std::move(" << ctor_args.at(j++) << ")";
      } else {
        os << ctor_args.at(j++);
      }
      os << ")";
    }
    os << " {}\n";
  }
  os << nl << "};\n";
  declared = true;
}

bool CppTypeCode::ConsRecord::declare_record_unpack(std::ostream& os, std::string nl, int options) {
  bool is_ok = false;
  bool cell = options & 16;
  std::string slice_arg = cell ? "Ref<vm::Cell> cell_ref" : "vm::CellSlice& cs";
  std::string fun_name = (options & 1) ? "validate_unpack" : "unpack";
  if (cell) {
    fun_name = std::string{"cell_"} + fun_name;
  }
  std::string class_name;
  if (options & 2048) {
    class_name = cpp_type.cpp_type_class_name + "::";
  }
  if (!(options & 8)) {
    os << nl << "bool " << class_name << fun_name << "(" << slice_arg << ", " << class_name << cpp_name << "& data";
    is_ok = true;
  } else if (is_small) {
    os << nl << "bool " << class_name << fun_name << "_" << cpp_type.cons_enum_name.at(cons_idx) << "(" << slice_arg;
    for (const auto& f : cpp_fields) {
      os << ", " << f.get_cvt() << "& " << f.name;
    }
    is_ok = true;
  }
  if (is_ok) {
    if (options & 2) {
      os << cpp_type.skip_extra_args;
    }
    os << ") const" << (options & 1024 ? " {" : ";\n");
  }
  return is_ok;
}

bool CppTypeCode::ConsRecord::declare_record_pack(std::ostream& os, std::string nl, int options) {
  bool is_ok = false;
  bool cell = options & 16;
  std::string builder_arg = cell ? "Ref<vm::Cell>& cell_ref" : "vm::CellBuilder& cb";
  std::string fun_name = (options & 1) ? "validate_pack" : "pack";
  if (cell) {
    fun_name = std::string{"cell_"} + fun_name;
  }
  std::string class_name;
  if (options & 2048) {
    class_name = cpp_type.cpp_type_class_name + "::";
  }
  if (!(options & 8)) {
    os << nl << "bool " << class_name << fun_name << "(" << builder_arg << ", const " << class_name << cpp_name
       << "& data";
    is_ok = true;
  } else if (is_small) {
    os << nl << "bool " << class_name << fun_name << "_" << cpp_type.cons_enum_name.at(cons_idx) << "(" << builder_arg;
    for (const auto& f : cpp_fields) {
      // skip SOME implicit fields ???
      if (!f.implicit) {
        os << ", " << f.get_cvt() << " " << f.name;
      }
    }
    is_ok = true;
  }
  if (is_ok) {
    if (options & 2) {
      os << cpp_type.skip_extra_args;
    }
    os << ") const" << (options & 1024 ? " {" : ";\n");
  }
  return is_ok;
}

void CppTypeCode::generate_fetch_enum_method(std::ostream& os, int options) {
  int minl = type.size.convert_min_size(), maxl = type.size.convert_max_size();
  bool exact = type.cons_all_exact();
  std::string ctag = incremental_cons_tags ? "(unsigned)t" : "cons_tag[t]";
  os << "\nbool " << cpp_type_class_name << "::fetch_enum_to(vm::CellSlice& cs, char& value) const {\n";
  if (!cons_num) {
    os << "  value = -1;\n"
          "  return false;\n";
  } else if (!maxl) {
    os << "  value = 0;\n"
          "  return true;\n";
  } else if (cons_num == 1) {
    const Constructor& constr = *type.constructors.at(0);
    os << "  value = (cs.fetch_ulong(" << minl << ") == " << HexConstWriter{constr.tag >> (64 - constr.tag_bits)}
       << ") ? 0 : -1;\n";
    os << "  return !value;\n";
  } else if (minl == maxl) {
    if (exact) {
      os << "  value = (char)cs.fetch_ulong(" << minl << ");\n";
      os << "  return value >= 0;\n";
    } else {
      os << "  int t = get_tag(cs);\n";
      os << "  value = (char)t;\n";
      os << "  return t >= 0 && cs.fetch_ulong(" << minl << ") == " << ctag << ";\n";
    }
  } else if (exact) {
    os << "  int t = get_tag(cs);\n";
    os << "  value = (char)t;\n";
    os << "  return t >= 0 && cs.advance(cons_len[t]);\n";
  } else {
    os << "  int t = get_tag(cs);\n";
    os << "  value = (char)t;\n";
    os << "  return t >= 0 && cs.fetch_ulong(cons_len[t]) == " << ctag << ";\n";
  }
  os << "}\n";
}

void CppTypeCode::generate_store_enum_method(std::ostream& os, int options) {
  int minl = type.size.convert_min_size(), maxl = type.size.convert_max_size();
  bool exact = type.cons_all_exact();
  std::string ctag = incremental_cons_tags ? "value" : "cons_tag[value]";
  os << "\nbool " << cpp_type_class_name << "::store_enum_from(vm::CellBuilder& cb, int value) const {\n";
  if (!cons_num) {
    os << "  return false;\n";
  } else if (!maxl) {
    os << "  return !value;\n";
  } else if (cons_num == 1) {
    const Constructor& constr = *type.constructors.at(0);
    os << "  return !value && cb.store_long_bool(" << HexConstWriter{constr.tag >> (64 - constr.tag_bits)} << ", "
       << minl << ");\n";
  } else if (minl == maxl) {
    if (exact) {
      os << "  return cb.store_long_rchk_bool(value, " << minl << ");\n";
    } else if (incremental_cons_tags && cons_num > (1 << (minl - 1))) {
      os << "  return cb.store_uint_less(" << cons_num << ", value);\n";
    } else {
      os << "  return (unsigned)value < " << cons_num << " && cb.store_long_bool(" << ctag << ", " << minl << ");\n";
    }
  } else {
    os << "  return (unsigned)value < " << cons_num << " && cb.store_long_bool(" << ctag << ", cons_len[value]);\n";
  }
  os << "}\n";
}

void CppTypeCode::generate_print_type_body(std::ostream& os, std::string nl) {
  std::string name = type.type_name ? type.get_name() : cpp_type_class_name;
  if (!tot_params) {
    os << nl << "return os << \"" << name << "\";";
    return;
  }
  os << nl << "return os << \"(" << name;
  for (int i = 0; i < tot_params; i++) {
    if (type_param_is_neg[i]) {
      os << " ~" << type_param_name[i];
    } else {
      os << " \" << " << type_param_name[i] << " << \"";
    }
  }
  os << ")\";";
}

void CppTypeCode::generate_header(std::ostream& os, int options) {
  os << "\nstruct " << cpp_type_class_name << " final : TLB_Complex {\n";
  generate_cons_enum(os);
  generate_cons_tag_info(os, "  ", 1);
  if (params) {
    generate_type_fields(os, options);
    generate_type_constructor(os, options);
  }
  for (int i = 0; i < cons_num; i++) {
    records.at(i).declare_record(os, "  ", options);
  }
  if (type.is_special) {
    os << "  bool always_special() const override {\n";
    os << "    return true;\n  }\n";
  }
  int sz = type.size.min_size();
  sz = ((sz & 0xff) << 16) | (sz >> 8);
  if (simple_get_size) {
    os << "  int get_size(const vm::CellSlice& cs) const override {\n";
    os << "    return " << SizeWriter{sz} << ";\n  }\n";
  }
  os << "  bool skip(vm::CellSlice& cs) const override";
  if (!inline_skip) {
    os << ";\n";
  } else if (sz) {
    os << " {\n    return cs.advance" << (sz < 0x10000 ? "(" : "_ext(") << SizeWriter{sz} << ");\n  }\n";
  } else {
    os << " {\n    return true;\n  }\n";
  }
  if (ret_params) {
    os << "  bool skip(vm::CellSlice& cs" << skip_extra_args << ") const;\n";
  }
  os << "  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override";
  if (!inline_validate_skip) {
    os << ";\n";
  } else if (sz) {
    os << " {\n    return cs.advance(" << SizeWriter{sz} << ");\n  }\n";
  } else {
    os << " {\n    return true;\n  }\n";
  }
  if (ret_params) {
    os << "  bool validate_skip(int *ops, vm::CellSlice& cs, bool weak" << skip_extra_args << ") const;\n";
    os << "  bool fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res" << skip_extra_args << ") const;\n";
  }
  if (type.is_simple_enum) {
    os << "  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;\n";
    os << "  bool store_enum_from(vm::CellBuilder& cb, int value) const;\n";
  }
  for (int i = 0; i < cons_num; i++) {
    records[i].declare_record_unpack(os, "  ", 2);
    records[i].declare_record_unpack(os, "  ", 10);
    records[i].declare_record_unpack(os, "  ", 18);
    records[i].declare_record_unpack(os, "  ", 26);
    records[i].declare_record_pack(os, "  ", 2);
    records[i].declare_record_pack(os, "  ", 10);
    records[i].declare_record_pack(os, "  ", 18);
    records[i].declare_record_pack(os, "  ", 26);
  }
  os << "  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;\n";
  if (ret_params) {
    os << "  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs" << skip_extra_args << ") const;\n";
  }
  os << "  std::ostream& print_type(std::ostream& os) const override {";
  generate_print_type_body(os, "\n    ");
  os << "\n  }\n";
  os << "  int check_tag(const vm::CellSlice& cs) const override;\n";
  os << "  int get_tag(const vm::CellSlice& cs) const override";
  if (inline_get_tag) {
    os << " {";
    generate_get_tag_body(os, "\n    ");
    os << "\n  }\n";
  } else {
    os << ";\n";
  }
  os << "};\n";
  for (int i = 0; i < cons_num; i++) {
    records.at(i).declare_record(os, "", options | 1024);
  }
  if (!cpp_type_var_name.empty()) {
    os << "\nextern const " << cpp_type_class_name << " " << cpp_type_var_name << ";\n";
  }
}

void CppTypeCode::generate_body(std::ostream& os, int options) {
  generate_cons_tag_info(os, "", 2);
  if (!inline_get_tag) {
    os << "\nint " << cpp_type_class_name << "::get_tag(const vm::CellSlice& cs) const {";
    generate_get_tag_body(os, "\n  ");
    os << "\n}\n";
  }
  generate_check_tag_method(os);
  options &= -4;
  if (!inline_skip) {
    generate_skip_method(os, options);
  }
  if (ret_params) {
    generate_skip_method(os, options + 2);
  }
  if (!inline_validate_skip) {
    generate_skip_method(os, options + 1);
  }
  if (ret_params) {
    generate_skip_method(os, options + 3);
    generate_ext_fetch_to(os, options);
  }
  if (type.is_simple_enum) {
    generate_fetch_enum_method(os, options);
    generate_store_enum_method(os, options);
  }
  for (int i = 0; i < cons_num; i++) {
    ConsRecord& rec = records.at(i);
    generate_unpack_method(os, rec, 2);
    generate_unpack_method(os, rec, 10);
    generate_unpack_method(os, rec, 18);
    generate_unpack_method(os, rec, 26);
  }
  for (int i = 0; i < cons_num; i++) {
    ConsRecord& rec = records.at(i);
    generate_pack_method(os, rec, 2);
    generate_pack_method(os, rec, 10);
    generate_pack_method(os, rec, 18);
    generate_pack_method(os, rec, 26);
  }
  generate_print_method(os, options + 1);
  if (ret_params) {
    generate_print_method(os, options + 3);
  }
  if (!cpp_type_var_name.empty()) {
    os << "\nconst " << cpp_type_class_name << " " << cpp_type_var_name << ";";
  }
  os << std::endl;
}

void CppTypeCode::generate(std::ostream& os, int options) {
  std::string type_name = type.get_name();
  if (!type.type_name && type.is_auto) {
    type_name = cpp_type_class_name;
  }
  if (options & 1) {
    os << "\n//\n// headers for " << (type.is_auto ? "auxiliary " : "") << "type `" << type_name << "`\n//\n";
    generate_header(os, options);
  } else if (options & 2) {
    std::ostringstream tmp;
    generate_header(tmp, options | 1);
  }
  if (options & 2) {
    os << "\n//\n// code for " << (type.is_auto ? "auxiliary " : "") << "type `" << type_name << "`\n//\n";
    generate_body(os, options);
  }
}

void generate_type_constant(std::ostream& os, int i, TypeExpr* expr, std::string cpp_name, int mode) {
  if (!mode) {
    os << "// " << expr << std::endl;
    os << "extern ";
  }
  std::string cls_name = "TLB";
  int fake_arg = -1;
  cls_name = compute_type_expr_class_name(expr, fake_arg);
  os << "const " << cls_name << ' ' << cpp_name;
  if (!mode) {
    os << ";\n";
    return;
  }
  int c = 0;
  if (fake_arg >= 0) {
    os << '{' << fake_arg;
    c++;
  }
  for (const TypeExpr* arg : expr->args) {
    if (!arg->negated) {
      assert(arg->is_constexpr);
      os << (c++ ? ", " : "{");
      if (arg->is_nat) {
        os << arg->value;
      } else {
        os << const_type_expr_cpp_idents.at(arg->is_constexpr);
      }
    }
  }
  if (c) {
    os << '}';
  }
  os << ";\n";
}

void generate_type_constants(std::ostream& os, int mode) {
  os << "\n// " << (mode ? "definitions" : "declarations") << " of constant types used\n\n";
  for (int i = 1; i <= const_type_expr_num; i++) {
    TypeExpr* expr = const_type_expr[i];
    if (!expr->is_nat && !const_type_expr_simple[i]) {
      generate_type_constant(os, i, expr, const_type_expr_cpp_idents[i], mode);
    }
  }
}

void generate_register_function(std::ostream& os, int mode) {
  os << "\n// " << (mode ? "definition" : "declaration") << " of type name registration function\n";
  if (!mode) {
    os << "extern bool register_simple_types(std::function<bool(const char*, const TLB*)> func);\n";
    return;
  }
  os << "bool register_simple_types(std::function<bool(const char*, const TLB*)> func) {\n";
  os << "  return ";
  int k = 0;
  for (int i = builtin_types_num; i < types_num; i++) {
    Type& type = types[i];
    CppTypeCode& cc = *cpp_type[i];
    if (!cc.cpp_type_var_name.empty() && type.type_name) {
      if (k++) {
        os << "\n      && ";
      }
      os << "func(\"" << type.get_name() << "\", &" << cc.cpp_type_var_name << ")";
    }
  }
  if (!k) {
    os << "true";
  }
  os << ";\n}\n\n";
}

void assign_const_type_cpp_idents() {
  const_type_expr_cpp_idents.resize(const_type_expr_num + 1, "");
  const_type_expr_simple.resize(const_type_expr_num + 1, false);
  for (int i = 1; i <= const_type_expr_num; i++) {
    const TypeExpr* expr = const_type_expr[i];
    if (!expr->is_nat) {
      if (expr->tp == TypeExpr::te_Ref && expr->args[0]->tp == TypeExpr::te_Apply &&
          (expr->args[0]->type_applied == Any_type || expr->args[0]->type_applied == Cell_type)) {
        const_type_expr_cpp_idents[i] = "t_RefCell";
        const_type_expr_simple[i] = true;
        continue;
      }
      if (expr->tp == TypeExpr::te_Apply) {
        const Type* typ = expr->type_applied;
        int idx = typ->type_idx;
        if (typ == Any_type || typ == Cell_type || typ == Nat_type) {
          const_type_expr_cpp_idents[i] = (typ == Nat_type ? "t_Nat" : "t_Anything");
          const_type_expr_simple[i] = true;
          continue;
        }
        if (idx >= builtin_types_num && idx < types_num && !cpp_type[idx]->params) {
          const_type_expr_cpp_idents[i] = cpp_type[idx]->cpp_type_var_name;
          const_type_expr_simple[i] = true;
          continue;
        }
      }
      std::ostringstream ss;
      ss << "t";
      expr->const_type_name(ss);
      const_type_expr_cpp_idents[i] = global_cpp_ids.new_ident(ss.str());
    }
  }
}

std::string cpp_namespace = "tlb";
std::vector<std::string> cpp_namespace_list;
std::string tlb_library_header_name = "tl/tlblib.hpp";

void split_namespace_id() {
  auto prev_it = cpp_namespace.cbegin();
  for (auto it = cpp_namespace.cbegin(); it != cpp_namespace.cend(); ++it) {
    if (it[0] == ':' && it + 2 != cpp_namespace.cend() && it[1] == ':') {
      if (prev_it != it) {
        cpp_namespace_list.emplace_back(prev_it, it);
      }
      ++it;
      prev_it = it + 1;
    }
  }
  if (prev_it != cpp_namespace.cend()) {
    cpp_namespace_list.emplace_back(prev_it, cpp_namespace.cend());
  }
}

std::vector<int> type_gen_order;

void prepare_generate_cpp(int options = 0) {
  std::vector<std::pair<int, int>> pairs;
  pairs.reserve(types_num - builtin_types_num);
  for (int i = builtin_types_num; i < types_num; i++) {
    pairs.emplace_back(types.at(i).last_declared, i);
  }
  std::sort(pairs.begin(), pairs.end());
  type_gen_order.reserve(pairs.size());
  for (auto z : pairs) {
    type_gen_order.push_back(z.second);
  }
  cpp_type.resize(types_num);
  for (int i : type_gen_order) {
    Type& type = types[i];
    cpp_type[i] = std::make_unique<CppTypeCode>(type);
    CppTypeCode& cc = *cpp_type[i];
    if (!cpp_type[i] || !cc.is_ok()) {
      throw src::Fatal{std::string{"cannot generate c++ code for type `"} + type.get_name() + "`"};
    }
  }
  split_namespace_id();
  assign_const_type_cpp_idents();
}

bool generate_prepared;
bool gen_cpp;
bool gen_hpp;
bool append_suffix;

void generate_cpp_output_to(std::ostream& os, int options = 0, std::vector<std::string> include_files = {}) {
  if (!generate_prepared) {
    prepare_generate_cpp(options);
    generate_prepared = true;
  }
  if (options & 1) {
    os << "#pragma once\n";
  }
  for (auto s : include_files) {
    if (s.size() >= 10 && s.substr(s.size() - 10) == "tlblib.hpp") {
      os << "#include <" << s << ">\n";
    } else {
      os << "#include \"" << s << "\"\n";
    }
  }
  os << "/*\n *\n *  AUTO-GENERATED FROM";
  for (auto s : source_list) {
    if (s.empty()) {
      os << " stdin";
    } else {
      os << " `" << s << "`";
    }
  }
  os << "\n *\n */\n";
  for (int i = 0; i < builtin_types_num; i++) {
    Type& type = types[i];
    if (type.used) {
      os << "// uses built-in type `" << type.get_name() << "`\n";
    }
  }
  for (auto cpp_nsp : cpp_namespace_list) {
    os << "\nnamespace " << cpp_nsp << " {" << std::endl;
  };
  if (cpp_namespace != "tlb") {
    os << "using namespace ::tlb;\n";
  }
  os << "using td::Ref;\n"
     << "using vm::CellSlice;\n"
     << "using vm::Cell;\n"
     << "using td::RefInt256;\n";
  for (int pass = 1; pass <= 2; pass++) {
    if (options & pass) {
      for (int i : type_gen_order) {
        CppTypeCode& cc = *cpp_type[i];
        cc.generate(os, (options & -4) | pass);
      }
      generate_type_constants(os, pass - 1);
      generate_register_function(os, pass - 1);
    }
  }
  for (auto it = cpp_namespace_list.rbegin(); it != cpp_namespace_list.rend(); ++it) {
    os << "\n} // namespace " << *it << std::endl;
  }
}

void generate_cpp_output_to(std::string filename, int options = 0, std::vector<std::string> include_files = {}) {
  std::stringstream ss;
  generate_cpp_output_to(ss, options, std::move(include_files));
  auto new_content = ss.str();
  auto r_old_content = td::read_file_str(filename);
  if (r_old_content.is_ok() && r_old_content.ok() == new_content) {
    return;
  }
  std::ofstream os{filename};
  if (!os) {
    throw src::Fatal{std::string{"cannot create output file `"} + filename + "`"};
  }
  os << new_content;
}

void generate_cpp_output(std::string filename = "", int options = 0) {
  if (!gen_cpp && !gen_hpp) {
    gen_cpp = gen_hpp = true;
  }
  options &= ~3;
  options |= (gen_hpp ? 1 : 0) | (gen_cpp << 1);
  if (filename.empty()) {
    generate_cpp_output_to(std::cout, options, {tlb_library_header_name});
  } else if (!append_suffix) {
    generate_cpp_output_to(filename, options, {tlb_library_header_name});
  } else {
    if (gen_hpp) {
      generate_cpp_output_to(filename + ".h", options & ~2, {tlb_library_header_name});
    }
    if (gen_cpp) {
      generate_cpp_output_to(filename + ".cpp", options & ~1, {filename + ".h"});
    }
  }
}

}  // namespace tlbc
