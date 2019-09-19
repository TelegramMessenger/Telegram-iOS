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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

namespace tlbc {

extern std::set<std::string> forbidden_cpp_idents, local_forbidden_cpp_idents;

struct CppIdentSet {
  std::set<std::string> cpp_idents;
  const std::set<std::string>* extra_forbidden_idents;
  CppIdentSet(const std::set<std::string>* forbid = nullptr) : extra_forbidden_idents(forbid) {
  }
  static std::string compute_cpp_ident(std::string orig_ident, int count = 0);
  std::string new_ident(std::string orig_ident, int count = 0, std::string suffix = "");
  bool insert(std::string ident) {
    return cpp_idents.insert(ident).second;
  }
  bool defined(std::string ident) {
    return cpp_idents.count(ident);
  }
  bool is_good_ident(std::string ident);
  void clear() {
    cpp_idents.clear();
  }
};

extern CppIdentSet global_cpp_ids;

struct Action {
  int fixed_size;
  bool is_pure;
  bool is_constraint;
  std::string action;
  Action(int _size) : fixed_size(_size), is_pure(false), is_constraint(false) {
  }
  Action(std::string _action, bool _cst = false)
      : fixed_size(-1), is_pure(false), is_constraint(_cst), action(_action) {
  }
  Action(const std::ostringstream& ss, bool _cst = false)
      : fixed_size(-1), is_pure(false), is_constraint(_cst), action(ss.str()) {
  }
  Action(std::ostringstream&& ss, bool _cst = false)
      : fixed_size(-1), is_pure(false), is_constraint(_cst), action(std::move(ss).str()) {
  }
  void show(std::ostream& os) const;
  bool may_combine(const Action& next) const;
  bool operator+=(const Action& next);
};

enum cpp_val_type {
  ct_unknown,
  ct_void = 1,
  ct_slice = 2,
  ct_cell = 3,
  ct_typeref = 4,
  ct_typeptr = 5,
  ct_bits = 6,
  ct_bitstring = 7,
  ct_integer = 8,
  ct_bool = 10,
  ct_enum = 11,
  ct_int32 = 12,
  ct_uint32 = 13,
  ct_int64 = 14,
  ct_uint64 = 15,
  ct_subrecord = 16
};

struct CppValType {
  cpp_val_type vt;
  int size;
  CppValType(cpp_val_type _vt = ct_unknown, int _size = -1) : vt(_vt), size(_size) {
  }
  cpp_val_type get() const {
    return vt;
  }
  void show(std::ostream& os, bool pass_value = false) const;
  bool needs_move() const;
};

extern std::ostream& operator<<(std::ostream& os, CppValType cvt);

class CppTypeCode {
  Type& type;
  bool ok;
  bool builtin;
  bool inline_get_tag;
  bool inline_skip;
  bool inline_validate_skip;
  bool simple_get_size;
  bool simple_cons_tags;
  bool incremental_cons_tags;

 public:
  int params;
  int tot_params;
  int ret_params;
  int cons_num;
  int common_cons_len;
  std::vector<std::string> cons_enum_name;
  std::vector<int> cons_enum_value;
  std::vector<int> cons_tag_map;
  std::vector<bool> cons_tag_exact;
  std::vector<int> cons_idx_by_enum;
  std::string cpp_type_var_name;
  std::string cpp_type_class_name;
  std::string cpp_type_template_name;

  struct ConsRecord;

  struct ConsField {
    const Field& field;
    const ConsRecord* subrec;
    std::string name;
    cpp_val_type ctype;
    int size;
    int orig_idx;
    bool implicit;
    ConsField(const Field& _field, std::string _name, cpp_val_type _ctype, int _size, int _idx,
              const ConsRecord* _subrec = nullptr, bool _implicit = false)
        : field(_field), subrec(_subrec), name(_name), ctype(_ctype), size(_size), orig_idx(_idx), implicit(_implicit) {
      assert(ctype != ct_subrecord || subrec);
    }
    CppValType get_cvt() const {
      return {ctype, size};
    }
    void print_type(std::ostream& os, bool pass_value = false) const;
  };

  struct ConsRecord {
    const CppTypeCode& cpp_type;
    const Constructor& constr;
    int cons_idx;
    bool is_trivial;
    bool is_small;
    bool triv_conflict;
    bool has_trivial_name;
    bool inline_record;
    bool declared;
    cpp_val_type equiv_cpp_type;
    std::vector<cpp_val_type> equiv_cpp_types;
    std::string cpp_name;
    std::vector<ConsField> cpp_fields;
    ConsRecord(const CppTypeCode& _cpp_type, const Constructor& _constr, int idx, bool _triv = false)
        : cpp_type(_cpp_type), constr(_constr), cons_idx(idx), is_trivial(_triv), declared(false) {
    }
    bool recover_idents(CppIdentSet& idents) const;
    void declare_record(std::ostream& os, std::string nl, int options);
    bool declare_record_unpack(std::ostream& os, std::string nl, int options);
    bool declare_record_pack(std::ostream& os, std::string nl, int options);
    void print_full_name(std::ostream& os) const;
  };
  std::vector<ConsRecord> records;

 private:
  std::vector<std::string> type_param_name;
  std::vector<bool> type_param_is_nat;
  std::vector<bool> type_param_is_neg;
  std::string template_args;
  std::string constructor_args;
  std::string skip_extra_args;
  std::string skip_extra_args_pass;
  CppIdentSet local_cpp_ids;
  bool init();

 public:
  CppTypeCode(Type& _type) : type(_type), local_cpp_ids(&local_forbidden_cpp_idents) {
    ok = init();
  }
  bool is_ok() const {
    return ok;
  }
  void generate(std::ostream& os, int options = 0);

 private:
  bool compute_simple_cons_tags();
  bool check_incremental_cons_tags() const;
  unsigned long long compute_selector_mask() const;
  void assign_class_name();
  void assign_cons_names();
  void assign_class_field_names();
  void assign_cons_values();
  void assign_record_cons_names();
  void generate_cons_enum(std::ostream& os);
  void generate_type_constructor(std::ostream& os, int options);
  void generate_type_fields(std::ostream& os, int options);
  void generate_header(std::ostream& os, int options = 0);
  void generate_body(std::ostream& os, int options = 0);
  void generate_cons_len_array(std::ostream& os, std::string nl, int options = 0);
  void generate_cons_tag_array(std::ostream& os, std::string nl, int options = 0);
  void generate_cons_tag_info(std::ostream& os, std::string nl, int options = 0);
  void generate_skip_method(std::ostream& os, int options = 0);
  void generate_skip_cons_method(std::ostream& os, std::string nl, int cidx, int options);
  void generate_cons_tag_check(std::ostream& os, std::string nl, int cidx, bool force = false);
  void generate_check_tag_method(std::ostream& os);
  void generate_unpack_method(std::ostream& os, ConsRecord& rec, int options);
  void generate_pack_method(std::ostream& os, ConsRecord& rec, int options);
  void generate_ext_fetch_to(std::ostream& os, int options);
  void generate_fetch_enum_method(std::ostream& os, int options);
  void generate_store_enum_method(std::ostream& os, int options);
  void generate_print_type_body(std::ostream& os, std::string nl);
  void generate_print_method(std::ostream& os, int options = 0);
  void generate_print_cons_method(std::ostream& os, std::string nl, int cidx, int options);
  void generate_get_tag_body(std::ostream& os, std::string nl);
  void generate_get_tag_subcase(std::ostream& os, std::string nl, const BinTrie* trie, int depth) const;
  void generate_get_tag_param(std::ostream& os, std::string nl, unsigned long long tag,
                              unsigned long long params = std::numeric_limits<td::uint64>::max()) const;
  void generate_get_tag_param1(std::ostream& os, std::string nl, const char A[4],
                               const std::string param_names[1]) const;
  void generate_get_tag_param2(std::ostream& os, std::string nl, const char A[4][4],
                               const std::string param_names[2]) const;
  void generate_get_tag_param3(std::ostream& os, std::string nl, const char A[4][4][4],
                               const std::string param_names[3]) const;
  bool match_param_pattern(std::ostream& os, std::string nl, const char A[4], int mask, std::string pattern,
                           std::string param_name) const;
  std::string get_nat_param_name(int idx) const;
  void generate_tag_pfx_selector(std::ostream& os, std::string nl, const BinTrie& trie, int d, int min_size) const;
  bool generate_get_tag_pfx_distinguisher(std::ostream& os, std::string nl, const std::vector<int>& constr_list,
                                          bool in_block) const;

 private:
  std::vector<Action> actions;
  int incomplete;
  int tmp_ints;
  bool needs_tmp_cell;
  std::vector<std::string> tmp_vars;
  std::vector<std::string> field_vars;
  std::vector<bool> field_var_set;
  std::vector<bool> param_var_set;
  std::vector<bool> param_constraint_used;
  std::vector<std::pair<std::string, const TypeExpr*>> postponed_equate;
  CppIdentSet tmp_cpp_ids;
  void clear_context();
  void init_cons_context(const Constructor& constr);
  std::string new_tmp_var(std::string hint);
  std::string new_tmp_var();
  void add_action(const Action& act);
  void output_actions(std::ostream& os, std::string nl, int options);
  void output_cpp_expr(std::ostream& os, const TypeExpr* expr, int prio = 0, bool allow_type_neg = false) const;
  void output_cpp_sizeof_expr(std::ostream& os, const TypeExpr* expr, int prio) const;
  void output_negative_type_arguments(std::ostream& os, const TypeExpr* expr);
  bool can_compute(const TypeExpr* expr) const;
  bool can_use_to_compute(const TypeExpr* expr, int i) const;
  bool can_compute_sizeof(const TypeExpr* expr) const;
  bool is_self(const TypeExpr* expr, const Constructor& constr) const;
  void add_compute_actions(const TypeExpr* expr, int i, std::string bind_to);
  void identify_cons_params(const Constructor& constr, int options);
  void identify_cons_neg_params(const Constructor& constr, int options);
  void bind_record_fields(const ConsRecord& rec, int options);
  void add_cons_tag_check(const Constructor& constr, int cidx, int options);
  void add_cons_tag_store(const Constructor& constr, int cidx);
  std::string add_fetch_nat_field(const Constructor& constr, const Field& field, int options);
  void add_store_nat_field(const Constructor& constr, const Field& field, int options);
  void add_remaining_param_constraints_check(const Constructor& constr, int options);
  void compute_implicit_field(const Constructor& constr, const Field& field, int options);
  bool add_constraint_check(const Constructor& constr, const Field& field, int options);
  void add_postponed_equate_actions();
  void output_fetch_field(std::ostream& os, std::string field_name, const TypeExpr* expr, cpp_val_type cvt);
  void output_fetch_subrecord(std::ostream& os, std::string field_name, const ConsRecord* subrec);
  void output_store_field(std::ostream& os, std::string field_name, const TypeExpr* expr, cpp_val_type cvt);
  void add_store_subrecord(std::string field_name, const ConsRecord* subrec);
  void generate_skip_field(const Constructor& constr, const Field& field, int options);
  void generate_print_field(const Constructor& constr, const Field& field, int options);
  bool output_print_simple_field(std::ostream& os, const Field& field, std::string field_name, const TypeExpr* expr);
  void generate_unpack_field(const ConsField& fi, const Constructor& constr, const Field& field, int options);
  void generate_pack_field(const ConsField& fi, const Constructor& constr, const Field& field, int options);
};

extern std::vector<std::unique_ptr<CppTypeCode>> cpp_type;

extern bool add_type_members;

}  // namespace tlbc
