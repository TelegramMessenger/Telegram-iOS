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
#pragma once
#include <iostream>
#include <map>
#include "vm/cellslice.h"

namespace tlb {

using td::Ref;
using vm::CellSlice;

struct PrettyPrinter;

class TLB {
 public:
  enum { default_validate_max_cells = 1024 };
  virtual ~TLB() = default;
  virtual int get_size(const vm::CellSlice& cs) const {
    return -1;
  }
  virtual bool skip(vm::CellSlice& cs) const {
    return cs.skip_ext(get_size(cs));
  }
  virtual bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    return cs.have_ext(get_size(cs));
  }
  virtual bool validate_exact(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    return (int)cs.size_ext() == get_size(cs);
  }
  bool validate_upto(int ops, const vm::CellSlice& cs, bool weak = false) const {
    return validate(&ops, cs, weak);
  }
  bool validate_exact_upto(int ops, const vm::CellSlice& cs, bool weak = false) const {
    return validate_exact(&ops, cs, weak);
  }
  bool validate_csr(int* ops, Ref<vm::CellSlice> cs_ref, bool weak = false) const {
    return cs_ref.not_null() && validate_skip_exact(ops, cs_ref.write(), weak);
  }
  bool validate_csr(int ops, Ref<vm::CellSlice> cs_ref, bool weak = false) const {
    return validate_csr(&ops, std::move(cs_ref), weak);
  }
  bool validate_csr(Ref<vm::CellSlice> cs_ref, bool weak = false) const {
    return validate_csr(default_validate_max_cells, std::move(cs_ref), weak);
  }
  Ref<vm::CellSlice> fetch(vm::CellSlice& cs) const {
    return cs.fetch_subslice_ext(get_size(cs));
  }
  Ref<vm::CellSlice> prefetch(const vm::CellSlice& cs) const {
    return cs.prefetch_subslice_ext(get_size(cs));
  }
  virtual Ref<vm::CellSlice> validate_fetch(int* ops, vm::CellSlice& cs, bool weak = false) const {
    return validate(ops, cs, weak) ? cs.fetch_subslice_ext(get_size(cs)) : Ref<vm::CellSlice>{};
  }
  virtual Ref<vm::CellSlice> validate_prefetch(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    return validate(ops, cs, weak) ? cs.prefetch_subslice_ext(get_size(cs)) : Ref<vm::CellSlice>{};
  }
  bool fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res) const {
    return (res = fetch(cs)).not_null();
  }
  bool validate_fetch_to(int* ops, vm::CellSlice& cs, Ref<vm::CellSlice>& res, bool weak = false) const {
    return (res = validate_fetch(ops, cs, weak)).not_null();
  }
  bool store_from(vm::CellBuilder& cb, Ref<vm::CellSlice> field) const {
    return field.not_null() && get_size(*field) == (int)field->size_ext() && cb.append_cellslice_bool(std::move(field));
  }
  bool validate_store_from(int* ops, vm::CellBuilder& cb, Ref<vm::CellSlice> field, bool weak = false) const {
    if (field.is_null()) {
      return false;
    }
    vm::CellSlice cs{*field};
    return validate_skip(ops, cs, weak) && cs.empty_ext() && cb.append_cellslice_bool(std::move(field));
  }
  virtual bool extract(vm::CellSlice& cs) const {
    return cs.only_ext(get_size(cs));
  }
  virtual bool validate_extract(int* ops, vm::CellSlice& cs, bool weak = false) const {
    return validate(ops, cs, weak) && extract(cs);
  }
  int get_size_by_skip(const vm::CellSlice& cs) const {
    vm::CellSlice copy{cs};
    return skip(copy) ? copy.subtract_base_ext(cs) : -1;
  }
  virtual bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const {
    return validate(ops, cs, weak) && skip(cs);
  }
  bool validate_skip_upto(int ops, vm::CellSlice& cs, bool weak = false) const {
    return validate_skip(&ops, cs, weak);
  }
  bool validate_skip_exact(int* ops, vm::CellSlice& cs, bool weak = false) const {
    return validate_skip(ops, cs, weak) && cs.empty_ext();
  }
  bool validate_by_skip(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    vm::CellSlice copy{cs};
    return validate_skip(ops, copy, weak);
  }
  bool validate_by_skip_exact(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    vm::CellSlice copy{cs};
    return validate_skip_exact(ops, copy, weak);
  }
  bool extract_by_skip(vm::CellSlice& cs) const {
    vm::CellSlice copy{cs};
    return skip(copy) && cs.cut_tail(copy);
  }
  bool validate_extract_by_skip(int* ops, vm::CellSlice& cs, bool weak = false) const {
    vm::CellSlice copy{cs};
    return validate_skip(ops, copy, weak) && cs.cut_tail(copy);
  }
  Ref<vm::CellSlice> validate_fetch_by_skip(int* ops, vm::CellSlice& cs, bool weak = false) const {
    Ref<vm::CellSlice> copy{true, cs};
    return validate_skip(ops, cs, weak) && copy.unique_write().cut_tail(cs) ? copy : Ref<vm::CellSlice>{};
  }
  Ref<vm::CellSlice> validate_prefetch_by_skip(int* ops, const vm::CellSlice& cs, bool weak = false) const {
    vm::CellSlice copy{cs};
    return validate_skip(ops, copy, false) ? cs.prefetch_subslice_ext(copy.subtract_base_ext(cs))
                                           : Ref<vm::CellSlice>{};
  }
  virtual bool skip_copy(vm::CellBuilder& cb, vm::CellSlice& cs) const {
    return cb.append_cellslice_bool(fetch(cs));
  }
  virtual bool copy(vm::CellBuilder& cb, const vm::CellSlice& cs) const {
    return cb.append_cellslice_bool(prefetch(cs));
  }
  virtual bool always_special() const {
    return false;
  }
  virtual int get_tag(const vm::CellSlice& cs) const {
    return -1;
  }
  virtual int check_tag(const vm::CellSlice& cs) const {
    return get_tag(cs);
  }
  bool has_valid_tag(const vm::CellSlice& cs) const {
    return check_tag(cs) >= 0;
  }
  virtual long long as_int(const vm::CellSlice& cs) const {
    return -1;
  }
  virtual unsigned long long as_uint(const vm::CellSlice& cs) const {
    return static_cast<unsigned long long>(-1);
  }
  virtual td::RefInt256 as_integer(const vm::CellSlice& cs) const {
    return {};
  }
  virtual td::RefInt256 as_integer_skip(vm::CellSlice& cs) const {
    return {};
  }
  virtual td::RefInt256 as_integer(Ref<vm::CellSlice> cs) const {
    return as_integer(*cs);
  }
  bool as_integer_skip_to(vm::CellSlice& cs, td::RefInt256& res) const {
    return (res = as_integer_skip(cs)).not_null();
  }
  bool as_integer_to(const vm::CellSlice& cs, td::RefInt256& res) const {
    return (res = as_integer(cs)).not_null();
  }
  bool as_integer_to(Ref<vm::CellSlice> cs_ref, td::RefInt256& res) const {
    return (res = as_integer(std::move(cs_ref))).not_null();
  }
  bool validate_ref(int* ops, Ref<vm::Cell> cell_ref, bool weak = false) const {
    return cell_ref.not_null() && validate_ref_internal(ops, std::move(cell_ref), weak);
  }
  bool validate_ref(int ops, Ref<vm::Cell> cell_ref, bool weak = false) const {
    return validate_ref(&ops, std::move(cell_ref), weak);
  }
  bool validate_ref(Ref<vm::Cell> cell_ref, bool weak = false) const {
    return validate_ref(default_validate_max_cells, std::move(cell_ref), weak);
  }
  bool force_validate_ref(int* ops, Ref<vm::Cell> cell_ref) const {
    return cell_ref.not_null() && validate_ref_internal(ops, std::move(cell_ref), false);
  }
  bool force_validate_ref(int ops, Ref<vm::Cell> cell_ref) const {
    return force_validate_ref(&ops, std::move(cell_ref));
  }
  bool force_validate_ref(Ref<vm::Cell> cell_ref) const {
    return force_validate_ref(default_validate_max_cells, std::move(cell_ref));
  }
  bool validate_skip_ref(int* ops, vm::CellSlice& cs, bool weak = false) const {
    return validate_ref(ops, cs.fetch_ref(), weak);
  }
  bool validate_skip_ref(int ops, vm::CellSlice& cs, bool weak = false) const {
    return validate_skip_ref(&ops, cs, weak);
  }
  virtual bool null_value(vm::CellBuilder& cb) const {
    return false;
  }
  virtual bool store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
    return false;
  }
  virtual bool store_long(vm::CellBuilder& cb, long long value) const {
    return store_integer_value(cb, td::BigInt256{value});
  }
  virtual bool store_integer_ref(vm::CellBuilder& cb, td::RefInt256 value) const {
    return value.not_null() && store_integer_value(cb, *value);
  }
  bool pack_integer(Ref<vm::CellSlice>& csr, td::RefInt256 value) const {
    vm::CellBuilder cb;
    return store_integer_ref(cb, value) && (csr = vm::load_cell_slice_ref(cb.finalize())).not_null();
  }
  virtual bool add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
    td::RefInt256 x = as_integer_skip(cs1), y = as_integer_skip(cs2);
    return x.not_null() && y.not_null() && store_integer_ref(cb, x += std::move(y));
  }
  // result: -1 = error, 0 = ok (zero), 1 = ok
  virtual int sub_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
    td::RefInt256 x = as_integer_skip(cs1), y = as_integer_skip(cs2);
    return x.not_null() && y.not_null() && store_integer_ref(cb, x -= std::move(y)) ? (td::sgn(x) ? 1 : 0) : -1;
  }
  template <typename... Args>
  bool unpack(Ref<vm::CellSlice> cs_ref, Args&... args) const {
    return cs_ref.not_null() && unpack(cs_ref.write(), args...) && cs_ref->empty_ext();
  }
  virtual std::ostream& print_type(std::ostream& os) const {
    return os << "<unknown-TLB-type>";
  }
  std::string get_type_name() const;
  virtual bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const;
  virtual bool print(PrettyPrinter& pp, const vm::CellSlice& cs) const {
    vm::CellSlice cs_copy{cs};
    return print_skip(pp, cs_copy);
  }
  bool print_special(PrettyPrinter& pp, vm::CellSlice& cs) const;
  bool print_ref(PrettyPrinter& pp, Ref<vm::Cell> cell_ref) const;
  bool print(PrettyPrinter& pp, Ref<vm::CellSlice> cs_ref) const {
    return print(pp, *cs_ref);
  }
  bool print_skip(std::ostream& os, vm::CellSlice& cs, int indent = 0, int rec_limit = 0) const;
  bool print(std::ostream& os, const vm::CellSlice& cs, int indent = 0, int rec_limit = 0) const;
  bool print(std::ostream& os, Ref<vm::CellSlice> cs_ref, int indent = 0, int rec_limit = 0) const {
    return print(os, *cs_ref, indent, rec_limit);
  }
  bool print_ref(std::ostream& os, Ref<vm::Cell> cell_ref, int indent = 0, int rec_limit = 0) const;
  bool print_ref(int rec_limit, std::ostream& os, Ref<vm::Cell> cell_ref, int indent = 0) const {
    return print_ref(os, std::move(cell_ref), indent, rec_limit);
  }
  std::string as_string_skip(vm::CellSlice& cs, int indent = 0) const;
  std::string as_string(const vm::CellSlice& cs, int indent = 0) const;
  std::string as_string(Ref<vm::CellSlice> cs_ref, int indent = 0) const {
    return cs_ref.not_null() ? as_string(*cs_ref, indent) : "<null>";
  }
  std::string as_string_ref(Ref<vm::Cell> cell_ref, int indent = 0) const;
  static inline size_t nat_abs(int x) {
    return (x > 1) * 2 + (x & 1);
  }

 protected:
  bool validate_ref_internal(int* ops, Ref<vm::Cell> cell_ref, bool weak = false) const;
};

static inline std::ostream& operator<<(std::ostream& os, const TLB& type) {
  return type.print_type(os);
}

struct TLB_Complex : TLB {
  bool skip(vm::CellSlice& cs) const override {
    return validate_skip(nullptr, cs);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override = 0;
  int get_size(const vm::CellSlice& cs) const override {
    return get_size_by_skip(cs);
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return validate_by_skip(ops, cs, weak);
  }
  bool validate_exact(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return validate_by_skip_exact(ops, cs, weak);
  }
  bool extract(vm::CellSlice& cs) const override {
    return extract_by_skip(cs);
  }
  bool validate_extract(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return validate_extract_by_skip(ops, cs, weak);
  }
  Ref<vm::CellSlice> validate_fetch(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return validate_fetch_by_skip(ops, cs, weak);
  }
  Ref<vm::CellSlice> validate_prefetch(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return validate_prefetch_by_skip(ops, cs, weak);
  }
  td::RefInt256 as_integer(const vm::CellSlice& cs) const override {
    vm::CellSlice copy{cs};
    auto res = as_integer_skip(copy);
    return res.not_null() && copy.empty_ext() ? std::move(res) : td::RefInt256{};
  }
  td::RefInt256 as_integer(Ref<vm::CellSlice> cs) const override {
    auto res = as_integer_skip(cs.write());
    return res.not_null() && cs->empty_ext() ? std::move(res) : td::RefInt256{};
  }
};

class TlbTypeHolder : public td::CntObject {
  const TLB* type{nullptr};
  char* data{nullptr};

 public:
  TlbTypeHolder() = default;
  TlbTypeHolder(const TLB* _type) : type(_type), data(nullptr) {
  }
  TlbTypeHolder(const TLB* _type, char* _data) : type(_type), data(_data) {
  }
  ~TlbTypeHolder() override {
    free(data);
  }
  const TLB* get() const {
    return type;
  }
  const TLB& operator*() const {
    return *type;
  }
  const TLB* operator->() const {
    return type;
  }
};

static inline bool add_chk(int x, int y, int z) {
  return x + y == z && z >= 0;
}

static inline bool add_r1(int& x, int y, int z) {
  return z >= y && (x = z - y) >= 0;
}

static inline bool add_r3(int& x, int y, int& z) {
  return (z = (x + y)) >= 0;
}

static inline bool mul_chk(int x, int y, int z) {
  return (long long)x * y == z;
}

static inline bool mul_r1(int& x, int y, int z) {
  return y && !(z % y) && (x = z / y) >= 0;
}

static inline bool mul_r3(int x, int y, int& z) {
  unsigned long long t = (unsigned long long)x * y;
  if (t <= 0x7fffffff) {
    z = (int)t;
    return true;
  } else {
    return false;
  }
}

static inline int mul_bound(int x, int y) {
  unsigned long long t = (unsigned long long)x * y;
  return t <= 0x7fffffff ? (int)t : 0x7fffffff;
}

// templatized unpack functions
template <typename R, typename... Args>
bool unpack(vm::CellSlice& cs, R& rec, Args&... args) {
  return (typename R::type_class{}).unpack(cs, rec, args...);
}

template <typename R, typename... Args>
bool unpack_exact(vm::CellSlice& cs, R& rec, Args&... args) {
  return (typename R::type_class{}).unpack(cs, rec, args...) && cs.empty_ext();
}

template <typename T, typename R, typename... Args>
bool type_unpack(vm::CellSlice& cs, const T& type, R& rec, Args&... args) {
  return type.unpack(cs, rec, args...);
}

template <typename T, typename R, typename... Args>
bool type_unpack_exact(vm::CellSlice& cs, const T& type, R& rec, Args&... args) {
  return type.unpack(cs, rec, args...) && cs.empty_ext();
}

template <typename R, typename... Args>
bool csr_unpack(Ref<vm::CellSlice> csr, R& rec, Args&... args) {
  return (typename R::type_class{}).unpack(csr.write(), rec, args...) && csr->empty_ext();
}

template <typename R, typename... Args>
bool csr_unpack_safe(Ref<vm::CellSlice> csr, R& rec, Args&... args) {
  return csr.not_null() && (typename R::type_class{}).unpack(csr.write(), rec, args...) && csr->empty_ext();
}

template <typename R, typename... Args>
bool unpack_cell(Ref<vm::Cell> cell, R& rec, Args&... args) {
  vm::CellSlice cs = vm::load_cell_slice(std::move(cell));
  return cs.is_valid() && (typename R::type_class{}).unpack(cs, rec, args...) && cs.empty_ext();
}

template <typename R, typename... Args>
bool unpack_cell_inexact(Ref<vm::Cell> cell, R& rec, Args&... args) {
  vm::CellSlice cs = vm::load_cell_slice(std::move(cell));
  return cs.is_valid() && (typename R::type_class{}).unpack(cs, rec, args...);
}

template <typename T, typename R, typename... Args>
bool type_unpack_cell(Ref<vm::Cell> cell, const T& type, R& rec, Args&... args) {
  vm::CellSlice cs = vm::load_cell_slice(std::move(cell));
  return cs.is_valid() && type.unpack(cs, rec, args...) && cs.empty_ext();
}

template <typename T, typename R, typename... Args>
bool csr_type_unpack(Ref<vm::CellSlice> csr, const T& type, R& rec, Args&... args) {
  return type.unpack(csr.write(), rec, args...) && csr->empty_ext();
}

template <typename R, typename... Args>
bool csr_unpack_inexact(Ref<vm::CellSlice> csr, R& rec, Args&... args) {
  return (typename R::type_class{}).unpack(csr.write(), rec, args...);
}

template <typename T, typename R, typename... Args>
bool csr_type_unpack_inexact(Ref<vm::CellSlice> csr, const T& type, R& rec, Args&... args) {
  return type.unpack(csr.write(), rec, args...);
}

template <typename R, typename... Args>
bool csr_unpack_skip(Ref<vm::CellSlice>& csr, R& rec, Args&... args) {
  return (typename R::type_class{}).unpack(csr.write(), rec, args...);
}

template <typename T, typename R, typename... Args>
bool csr_type_unpack_skip(Ref<vm::CellSlice>& csr, const T& type, R& rec, Args&... args) {
  return type.unpack(csr.write(), rec, args...);
}

// templatized pack functions
template <typename R, typename... Args>
bool pack(vm::CellBuilder& cb, const R& rec, Args&... args) {
  return (typename R::type_class{}).pack(cb, rec, args...);
}

template <typename T, typename R, typename... Args>
bool type_pack(vm::CellBuilder& cb, const T& type, const R& rec, Args&... args) {
  return type.pack(cb, rec, args...);
}

template <typename R, typename... Args>
bool pack_cell(Ref<vm::Cell>& cell, const R& rec, Args&... args) {
  vm::CellBuilder cb;
  return pack(cb, rec, args...) && cb.finalize_to(cell);
}

template <typename T, typename R, typename... Args>
bool type_pack_cell(Ref<vm::Cell>& cell, const T& type, const R& rec, Args&... args) {
  vm::CellBuilder cb;
  return type.pack(cb, rec, args...) && cb.finalize_to(cell);
}

template <typename R, typename... Args>
bool csr_pack(Ref<vm::CellSlice>& csr, const R& rec, Args&... args) {
  vm::CellBuilder cb;
  Ref<vm::Cell> cell;
  return pack(cb, rec, args...) && cb.finalize_to(cell) && (csr = vm::load_cell_slice_ref(std::move(cell))).not_null();
}

template <typename T, typename R, typename... Args>
bool csr_type_pack(Ref<vm::CellSlice>& csr, const T& type, const R& rec, Args&... args) {
  vm::CellBuilder cb;
  Ref<vm::Cell> cell;
  return type.pack(cb, rec, args...) && cb.finalize_to(cell) &&
         (csr = vm::load_cell_slice_ref(std::move(cell))).not_null();
}

// templatized store_from function

template <typename T, typename... Args>
bool store_from(vm::CellBuilder& cb, const T& tlb_type, Ref<vm::CellSlice> field, Args&... args) {
  if (field.is_null()) {
    return false;
  }
  vm::CellSlice cs{*field};
  return tlb_type.skip(cs, args...) && cs.empty_ext() && cb.append_cellslice_bool(std::move(field));
}

}  // namespace tlb

namespace tlb {

struct PrettyPrinter {
  enum { default_print_limit = 4096 };
  std::ostream& os;
  int indent;
  int level;
  bool failed;
  bool nl_used;
  int mode;
  int limit{default_print_limit};
  PrettyPrinter(std::ostream& _os, int _indent = 0, int _mode = 1)
      : os(_os), indent(_indent), level(0), failed(false), nl_used(false), mode(_mode) {
  }
  PrettyPrinter(int _limit, std::ostream& _os, int _indent = 0, int _mode = 1)
      : os(_os), indent(_indent), level(0), failed(false), nl_used(false), mode(_mode), limit(_limit) {
  }
  ~PrettyPrinter();
  bool ok() const {
    return !failed && !level;
  }
  bool fail_unless(bool res) {
    if (!res) {
      failed = true;
    }
    return res;
  }
  bool fail(std::string msg);
  bool nl(int delta = 0);
  bool raw_nl(int delta = 0);
  bool mkindent(int delta = 0);
  bool mode_nl();
  bool open(std::string msg = "");
  bool close();
  bool close(std::string msg);
  bool field(std::string name);
  bool field();
  bool field_int(long long value);
  bool field_int(long long value, std::string name);
  bool field_uint(unsigned long long value);
  bool field_uint(unsigned long long value, std::string name);
  bool register_recursive_call() {
    return limit--;
  }
  void set_limit(int new_limit) {
    if (new_limit > 0) {
      limit = new_limit;
    }
  }
  bool out(std::string str) {
    os << str;
    return true;
  }
  bool out_int(long long value) {
    os << value;
    return true;
  }
  bool out_uint(unsigned long long value) {
    os << value;
    return true;
  }
  bool out_integer(td::RefInt256 value) {
    if (value.not_null()) {
      os << std::move(value);
      return true;
    } else {
      return false;
    }
  }
  bool cons(std::string str) {
    return out(str);
  }
  bool fetch_bits_field(vm::CellSlice& cs, int n);
  bool fetch_bits_field(vm::CellSlice& cs, int n, std::string name);
  bool fetch_int_field(vm::CellSlice& cs, int n);
  bool fetch_int_field(vm::CellSlice& cs, int n, std::string name);
  bool fetch_uint_field(vm::CellSlice& cs, int n);
  bool fetch_uint_field(vm::CellSlice& cs, int n, std::string name);
  bool fetch_int256_field(vm::CellSlice& cs, int n);
  bool fetch_int256_field(vm::CellSlice& cs, int n, std::string name);
  bool fetch_uint256_field(vm::CellSlice& cs, int n);
  bool fetch_uint256_field(vm::CellSlice& cs, int n, std::string name);
  template <typename T>
  PrettyPrinter& operator<<(const T& value) {
    os << value;
    return *this;
  }
};

}  // namespace tlb

namespace tlb {

class TypenameLookup {
  std::map<std::string, const TLB*> types;

 public:
  typedef std::function<bool(const char*, const TLB*)> simple_register_func_t;
  typedef std::function<bool(simple_register_func_t)> register_func_t;
  TypenameLookup() = default;
  TypenameLookup(register_func_t func) {
    register_types(func);
  }
  bool register_type(const char* name, const TLB* tp);
  bool register_types(register_func_t func);
  const TLB* lookup(std::string str) const;
};

}  // namespace tlb

namespace tlb {

struct False final : TLB {
  int get_size(const vm::CellSlice& cs) const override {
    return -1;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "False";
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return false;
  }
};

extern const False t_False;

struct True final : TLB {
  int get_size(const vm::CellSlice& cs) const override {
    return 0;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "True";
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return pp.out("true");
  }
};

extern const True t_True;

struct Unit final : TLB {
  int get_size(const vm::CellSlice& cs) const override {
    return 0;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Unit";
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return pp.out("()");
  }
};

struct FwdT final : TLB {
  const TLB& X;
  FwdT(const TLB& _X) : X(_X) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return X.get_size(cs);
  }
  bool skip(vm::CellSlice& cs) const override {
    return X.skip(cs);
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return X.validate(ops, cs, weak);
  }
  Ref<vm::CellSlice> validate_fetch(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_fetch(ops, cs, weak);
  }
  Ref<vm::CellSlice> validate_prefetch(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_prefetch(ops, cs, weak);
  }
  bool extract(vm::CellSlice& cs) const override {
    return X.extract(cs);
  }
  bool validate_extract(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_extract(ops, cs, weak);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_skip(ops, cs, weak);
  }
  bool skip_copy(vm::CellBuilder& cb, vm::CellSlice& cs) const override {
    return X.skip_copy(cb, cs);
  }
  bool copy(vm::CellBuilder& cb, const vm::CellSlice& cs) const override {
    return X.copy(cb, cs);
  }
  int get_tag(const vm::CellSlice& cs) const override {
    return X.get_tag(cs);
  }
  long long as_int(const vm::CellSlice& cs) const override {
    return X.as_int(cs);
  }
  unsigned long long as_uint(const vm::CellSlice& cs) const override {
    return X.as_uint(cs);
  }
  td::RefInt256 as_integer(const vm::CellSlice& cs) const override {
    return X.as_integer(cs);
  }
  td::RefInt256 as_integer_skip(vm::CellSlice& cs) const override {
    return X.as_integer_skip(cs);
  }
  td::RefInt256 as_integer(Ref<vm::CellSlice> cs) const override {
    return X.as_integer(std::move(cs));
  }
  bool null_value(vm::CellBuilder& cb) const override {
    return X.null_value(cb);
  }
  bool store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const override {
    return X.store_integer_value(cb, value);
  }
  bool store_integer_ref(vm::CellBuilder& cb, td::RefInt256 value) const override {
    return X.store_integer_ref(cb, std::move(value));
  }
  bool add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const override {
    return X.add_values(cb, cs1, cs2);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return X.print_type(os);
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return X.print_skip(pp, cs);
  }
};

extern const Unit t_Unit;

struct Bool final : TLB {
  enum { bool_false = 0, bool_true = 1 };
  int get_size(const vm::CellSlice& cs) const override {
    return 1;
  }
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Bool";
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

extern const Bool t_Bool;

struct NatWidth final : TLB {
  int n;
  NatWidth(int _n) : n(_n) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n <= 32 ? n : -1;
  }
  td::RefInt256 as_integer(const vm::CellSlice& cs) const override {
    return cs.prefetch_int256(n, false);
  }
  td::RefInt256 as_integer_skip(vm::CellSlice& cs) const override {
    return cs.fetch_int256(n, false);
  }
  unsigned long long as_uint(const vm::CellSlice& cs) const override {
    return n <= 32 ? cs.prefetch_ulong(n) : -1;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(## " << n << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

extern const NatWidth t_Nat;

struct NatLess final : TLB {
  int n, w;
  NatLess(int _n) : n(_n - 1), w(32 - td::count_leading_zeroes32(_n - 1)) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n >= 0 ? w : -1;
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return n >= 0 && (unsigned)cs.prefetch_ulong(w) <= (unsigned)n;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return n >= 0 && (unsigned)cs.fetch_ulong(w) <= (unsigned)n;
  }
  unsigned long long as_uint(const vm::CellSlice& cs) const override {
    unsigned long long r = cs.prefetch_ulong(w);
    return n >= 0 && (unsigned)r <= (unsigned)n ? r : std::numeric_limits<td::uint64>::max();
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(#< " << n << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

struct NatLeq final : TLB {
  int n, w;
  NatLeq(int _n) : n(_n), w(32 - td::count_leading_zeroes32(_n)) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n >= 0 ? w : -1;
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return n >= 0 && (unsigned)cs.prefetch_ulong(w) <= (unsigned)n;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return n >= 0 && (unsigned)cs.fetch_ulong(w) <= (unsigned)n;
  }
  unsigned long long as_uint(const vm::CellSlice& cs) const override {
    unsigned long long r = cs.prefetch_ulong(w);
    return n >= 0 && (unsigned)r <= (unsigned)n ? r : std::numeric_limits<td::uint64>::max();
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(#<= " << n << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

struct TupleT final : TLB_Complex {
  int n;
  const TLB& X;
  TupleT(int _n, const TLB& _X) : n(_n), X(_X) {
  }
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

struct CondT final : TLB_Complex {
  int n;
  const TLB& X;
  CondT(int _n, const TLB& _X) : n(_n), X(_X) {
  }
  bool skip(vm::CellSlice& cs) const override {
    return !n || X.skip(cs);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return !n || (n > 0 && X.validate_skip(ops, cs, weak));
  }
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(CondT " << n << ' ' << X << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

template <typename T>
struct Cond final : TLB_Complex {
  int n;
  T field_type;
  template <typename... Args>
  Cond(int _n, Args... args) : n(_n), field_type(args...) {
  }
  bool skip(vm::CellSlice& cs) const override {
    return !n || field_type.skip(cs);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return !n || (n > 0 && field_type.validate_skip(ops, cs, weak));
  }
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Cond " << n << ' ' << field_type << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return (n > 0 ? field_type.print_skip(pp, cs) : (!n && pp.out("()")));
  }
};

struct Int final : TLB {
  int n;
  Int(int _n) : n(_n) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n;
  }
  td::RefInt256 as_integer(const vm::CellSlice& cs) const override {
    return cs.prefetch_int256(n, true);
  }
  td::RefInt256 as_integer_skip(vm::CellSlice& cs) const override {
    return cs.fetch_int256(n, true);
  }
  long long as_int(const vm::CellSlice& cs) const override {
    return n <= 64 ? cs.prefetch_long(n) : (1ULL << 63);
  }
  bool null_value(vm::CellBuilder& cb) const override {
    return cb.store_zeroes_bool(n);
  }
  bool store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const override {
    return cb.store_int256_bool(value, n, true);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "int" << n;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

extern const Int t_int8, t_int16, t_int24, t_int32, t_int64, t_int128, t_int256, t_int257;

struct UInt final : TLB {
  int n;
  UInt(int _n) : n(_n) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n;
  }
  td::RefInt256 as_integer(const vm::CellSlice& cs) const override {
    return cs.prefetch_int256(n, false);
  }
  td::RefInt256 as_integer_skip(vm::CellSlice& cs) const override {
    return cs.fetch_int256(n, false);
  }
  unsigned long long as_uint(const vm::CellSlice& cs) const override {
    return n <= 64 ? cs.prefetch_ulong(n) : -1;
  }
  bool null_value(vm::CellBuilder& cb) const override {
    return cb.store_zeroes_bool(n);
  }
  bool store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const override {
    return cb.store_int256_bool(value, n, false);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "uint" << n;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

extern const UInt t_uint8, t_uint16, t_uint24, t_uint32, t_uint64, t_uint128, t_uint256;

struct Bits final : TLB {
  int n;
  Bits(int _n) : n(_n) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return n;
  }
  bool null_value(vm::CellBuilder& cb) const override {
    return cb.store_zeroes_bool(n);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "bits" << n;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

template <class T>
struct Maybe : TLB_Complex {
  T field_type;
  template <typename... Args>
  Maybe(Args... args) : field_type(args...) {
  }
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.have(1) ? (int)cs.prefetch_ulong(1) : -1;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Maybe " << field_type << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

template <class T>
bool Maybe<T>::skip(vm::CellSlice& cs) const {
  int t = get_tag(cs);
  if (t > 0) {
    return cs.advance(1) && field_type.skip(cs);
  } else if (!t) {
    return cs.advance(1);
  } else {
    return false;
  }
}

template <class T>
bool Maybe<T>::validate_skip(int* ops, vm::CellSlice& cs, bool weak) const {
  int t = get_tag(cs);
  if (t > 0) {
    return cs.advance(1) && field_type.validate_skip(ops, cs, weak);
  } else if (!t) {
    return cs.advance(1);
  } else {
    return false;
  }
}

template <class T>
bool Maybe<T>::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  if (!get_tag(cs)) {
    return cs.advance(1) && pp.out("nothing");
  } else {
    return cs.advance(1) && pp.open("just ") && field_type.print_skip(pp, cs) && pp.close();
  }
}

struct RefAnything final : TLB {
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10000;
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "^Cell";
  }
};

extern const RefAnything t_RefCell;

struct Anything final : TLB {
  int get_size(const vm::CellSlice& cs) const override {
    return cs.size_ext();
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Any";
  }
};

extern const Anything t_Anything;

template <class T>
struct RefTo final : TLB {
  T ref_type;
  template <typename... Args>
  RefTo(Args... args) : ref_type(args...) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10000;
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return cs.size_refs() ? ref_type.validate_ref(ops, cs.prefetch_ref(), weak) : false;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return ref_type.validate_skip_ref(ops, cs, weak);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << '^' << ref_type;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return pp.out("^") && ref_type.print_ref(pp, cs.fetch_ref());
  }
};

struct RefT final : TLB {
  const TLB& X;
  RefT(const TLB& _X) : X(_X) {
  }
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10000;
  }
  bool validate(int* ops, const vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_ref(ops, cs.prefetch_ref(), weak);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return X.validate_skip_ref(ops, cs, weak);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << '^' << X;
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override {
    return pp.out("^") && X.print_ref(pp, cs.fetch_ref());
  }
};

template <class T1, class T2>
struct Either final : TLB_Complex {
  T1 left_type;
  T2 right_type;
  bool skip(vm::CellSlice& cs) const override {
    return cs.have(1) ? (cs.fetch_ulong(1) ? right_type.skip(cs) : left_type.skip(cs)) : false;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.have(1)
               ? (cs.fetch_ulong(1) ? right_type.validate_skip(ops, cs, weak) : left_type.validate_skip(ops, cs, weak))
               : false;
  }
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Either " << left_type << ' ' << right_type << ')';
  }
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
};

template <class T1, class T2>
bool Either<T1, T2>::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  if (!get_tag(cs)) {
    return cs.advance(1) && pp.open("left ") && left_type.print_skip(pp, cs) && pp.close();
  } else {
    return cs.advance(1) && pp.open("right ") && right_type.print_skip(pp, cs) && pp.close();
  }
}

}  // namespace tlb
