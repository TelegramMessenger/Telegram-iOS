#pragma once
#include <tl/tlblib.hpp>
/*
 *
 *  AUTO-GENERATED FROM `block.tlb`
 *
 */
// uses built-in type `#`
// uses built-in type `##`
// uses built-in type `#<`
// uses built-in type `#<=`
// uses built-in type `Any`
// uses built-in type `Cell`
// uses built-in type `int`
// uses built-in type `uint`
// uses built-in type `bits`
// uses built-in type `int8`
// uses built-in type `uint8`
// uses built-in type `uint13`
// uses built-in type `uint15`
// uses built-in type `int16`
// uses built-in type `uint16`
// uses built-in type `int32`
// uses built-in type `uint32`
// uses built-in type `uint63`
// uses built-in type `int64`
// uses built-in type `uint64`
// uses built-in type `uint256`
// uses built-in type `int257`
// uses built-in type `bits256`
// uses built-in type `bits512`

namespace block {

namespace gen {
using namespace ::tlb;
using td::Ref;
using vm::CellSlice;
using vm::Cell;
using td::RefInt256;

//
// headers for type `Unit`
//

struct Unit final : TLB_Complex {
  enum { unit };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Unit type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0;
  }
  bool skip(vm::CellSlice& cs) const override {
    return true;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return true;
  }
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_unit(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_unit(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_unit(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_unit(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Unit";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Unit t_Unit;

//
// headers for type `True`
//

struct True final : TLB_Complex {
  enum { true1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef True type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0;
  }
  bool skip(vm::CellSlice& cs) const override {
    return true;
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return true;
  }
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_true1(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_true1(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_true1(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_true1(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "True";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const True t_True;

//
// headers for type `Bool`
//

struct Bool final : TLB_Complex {
  enum { bool_false, bool_true };
  static constexpr int cons_len_exact = 1;
  struct Record_bool_false {
    typedef Bool type_class;
  };
  struct Record_bool_true {
    typedef Bool type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 1;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(1);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(1);
  }
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record_bool_false& data) const;
  bool unpack_bool_false(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bool_false& data) const;
  bool cell_unpack_bool_false(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_bool_false& data) const;
  bool pack_bool_false(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bool_false& data) const;
  bool cell_pack_bool_false(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_bool_true& data) const;
  bool unpack_bool_true(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bool_true& data) const;
  bool cell_unpack_bool_true(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_bool_true& data) const;
  bool pack_bool_true(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bool_true& data) const;
  bool cell_pack_bool_true(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Bool";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const Bool t_Bool;

//
// headers for type `BoolFalse`
//

struct BoolFalse final : TLB_Complex {
  enum { bool_false };
  static constexpr int cons_len_exact = 1;
  struct Record {
    typedef BoolFalse type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 1;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(1);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_bool_false(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_bool_false(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_bool_false(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_bool_false(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BoolFalse";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const BoolFalse t_BoolFalse;

//
// headers for type `BoolTrue`
//

struct BoolTrue final : TLB_Complex {
  enum { bool_true };
  static constexpr int cons_len_exact = 1;
  static constexpr unsigned char cons_tag[1] = { 1 };
  struct Record {
    typedef BoolTrue type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 1;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(1);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_bool_true(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_bool_true(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_bool_true(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_bool_true(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BoolTrue";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const BoolTrue t_BoolTrue;

//
// headers for type `Maybe`
//

struct Maybe final : TLB_Complex {
  enum { nothing, just };
  static constexpr int cons_len_exact = 1;
  const TLB &X_;
  Maybe(const TLB& X) : X_(X) {}
  struct Record_nothing {
    typedef Maybe type_class;
  };
  struct Record_just {
    typedef Maybe type_class;
    Ref<CellSlice> value;  	// value : X
    Record_just() = default;
    Record_just(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_nothing& data) const;
  bool unpack_nothing(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_nothing& data) const;
  bool cell_unpack_nothing(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_nothing& data) const;
  bool pack_nothing(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_nothing& data) const;
  bool cell_pack_nothing(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_just& data) const;
  bool unpack_just(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_just& data) const;
  bool cell_unpack_just(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_just& data) const;
  bool pack_just(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_just& data) const;
  bool cell_pack_just(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Maybe " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `Either`
//

struct Either final : TLB_Complex {
  enum { left, right };
  static constexpr int cons_len_exact = 1;
  const TLB &X_, &Y_;
  Either(const TLB& X, const TLB& Y) : X_(X), Y_(Y) {}
  struct Record_left {
    typedef Either type_class;
    Ref<CellSlice> value;  	// value : X
    Record_left() = default;
    Record_left(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  struct Record_right {
    typedef Either type_class;
    Ref<CellSlice> value;  	// value : Y
    Record_right() = default;
    Record_right(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_left& data) const;
  bool unpack_left(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_left& data) const;
  bool cell_unpack_left(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_left& data) const;
  bool pack_left(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_left& data) const;
  bool cell_pack_left(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool unpack(vm::CellSlice& cs, Record_right& data) const;
  bool unpack_right(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_right& data) const;
  bool cell_unpack_right(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_right& data) const;
  bool pack_right(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_right& data) const;
  bool cell_pack_right(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Either " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `Both`
//

struct Both final : TLB_Complex {
  enum { pair };
  static constexpr int cons_len_exact = 0;
  const TLB &X_, &Y_;
  Both(const TLB& X, const TLB& Y) : X_(X), Y_(Y) {}
  struct Record {
    typedef Both type_class;
    Ref<CellSlice> first;  	// first : X
    Ref<CellSlice> second;  	// second : Y
    Record() = default;
    Record(Ref<CellSlice> _first, Ref<CellSlice> _second) : first(std::move(_first)), second(std::move(_second)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_pair(vm::CellSlice& cs, Ref<CellSlice>& first, Ref<CellSlice>& second) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_pair(Ref<vm::Cell> cell_ref, Ref<CellSlice>& first, Ref<CellSlice>& second) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_pair(vm::CellBuilder& cb, Ref<CellSlice> first, Ref<CellSlice> second) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_pair(Ref<vm::Cell>& cell_ref, Ref<CellSlice> first, Ref<CellSlice> second) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Both " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

//
// headers for type `Bit`
//

struct Bit final : TLB_Complex {
  enum { bit };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Bit type_class;
    bool x;  	// ## 1
    Record() = default;
    Record(bool _x) : x(_x) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 1;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(1);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(1);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_bit(vm::CellSlice& cs, bool& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_bit(Ref<vm::Cell> cell_ref, bool& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_bit(vm::CellBuilder& cb, bool x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_bit(Ref<vm::Cell>& cell_ref, bool x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Bit";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Bit t_Bit;

//
// headers for type `Hashmap`
//

struct Hashmap final : TLB_Complex {
  enum { hm_edge };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_;
  Hashmap(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Hashmap " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Hashmap::Record {
  typedef Hashmap type_class;
  int n;  	// n : #
  int l;  	// l : #
  int m;  	// m : #
  Ref<CellSlice> label;  	// label : HmLabel ~l n
  Ref<CellSlice> node;  	// node : HashmapNode m X
  Record() = default;
  Record(Ref<CellSlice> _label, Ref<CellSlice> _node) : n(-1), l(-1), m(-1), label(std::move(_label)), node(std::move(_node)) {}
};

//
// headers for type `HashmapNode`
//

struct HashmapNode final : TLB_Complex {
  enum { hmn_leaf, hmn_fork };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_;
  HashmapNode(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_hmn_leaf {
    typedef HashmapNode type_class;
    Ref<CellSlice> value;  	// value : X
    Record_hmn_leaf() = default;
    Record_hmn_leaf(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  struct Record_hmn_fork;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_hmn_leaf& data) const;
  bool unpack_hmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hmn_leaf& data) const;
  bool cell_unpack_hmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_hmn_leaf& data) const;
  bool pack_hmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hmn_leaf& data) const;
  bool cell_pack_hmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool unpack(vm::CellSlice& cs, Record_hmn_fork& data) const;
  bool unpack_hmn_fork(vm::CellSlice& cs, int& n, Ref<Cell>& left, Ref<Cell>& right) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hmn_fork& data) const;
  bool cell_unpack_hmn_fork(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& left, Ref<Cell>& right) const;
  bool pack(vm::CellBuilder& cb, const Record_hmn_fork& data) const;
  bool pack_hmn_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hmn_fork& data) const;
  bool cell_pack_hmn_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HashmapNode " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct HashmapNode::Record_hmn_fork {
  typedef HashmapNode type_class;
  int n;  	// n : #
  Ref<Cell> left;  	// left : ^(Hashmap n X)
  Ref<Cell> right;  	// right : ^(Hashmap n X)
  Record_hmn_fork() = default;
  Record_hmn_fork(Ref<Cell> _left, Ref<Cell> _right) : n(-1), left(std::move(_left)), right(std::move(_right)) {}
};

//
// headers for type `HmLabel`
//

struct HmLabel final : TLB_Complex {
  enum { hml_short, hml_long, hml_same };
  static constexpr char cons_len[3] = { 1, 2, 2 };
  static constexpr unsigned char cons_tag[3] = { 0, 2, 3 };
  int n_;
  HmLabel(int n) : n_(n) {}
  struct Record_hml_short;
  struct Record_hml_long;
  struct Record_hml_same;
  bool skip(vm::CellSlice& cs) const override;
  bool skip(vm::CellSlice& cs, int& m_) const;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool validate_skip(int *ops, vm::CellSlice& cs, bool weak, int& m_) const;
  bool fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res, int& m_) const;
  bool unpack(vm::CellSlice& cs, Record_hml_short& data, int& m_) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hml_short& data, int& m_) const;
  bool pack(vm::CellBuilder& cb, const Record_hml_short& data, int& m_) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hml_short& data, int& m_) const;
  bool unpack(vm::CellSlice& cs, Record_hml_long& data, int& m_) const;
  bool unpack_hml_long(vm::CellSlice& cs, int& m, int& n, Ref<td::BitString>& s, int& m_) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hml_long& data, int& m_) const;
  bool cell_unpack_hml_long(Ref<vm::Cell> cell_ref, int& m, int& n, Ref<td::BitString>& s, int& m_) const;
  bool pack(vm::CellBuilder& cb, const Record_hml_long& data, int& m_) const;
  bool pack_hml_long(vm::CellBuilder& cb, int n, Ref<td::BitString> s, int& m_) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hml_long& data, int& m_) const;
  bool cell_pack_hml_long(Ref<vm::Cell>& cell_ref, int n, Ref<td::BitString> s, int& m_) const;
  bool unpack(vm::CellSlice& cs, Record_hml_same& data, int& m_) const;
  bool unpack_hml_same(vm::CellSlice& cs, int& m, bool& v, int& n, int& m_) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hml_same& data, int& m_) const;
  bool cell_unpack_hml_same(Ref<vm::Cell> cell_ref, int& m, bool& v, int& n, int& m_) const;
  bool pack(vm::CellBuilder& cb, const Record_hml_same& data, int& m_) const;
  bool pack_hml_same(vm::CellBuilder& cb, bool v, int n, int& m_) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hml_same& data, int& m_) const;
  bool cell_pack_hml_same(Ref<vm::Cell>& cell_ref, bool v, int n, int& m_) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs, int& m_) const;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HmLabel ~m_ " << n_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 13);
  }
};

struct HmLabel::Record_hml_short {
  typedef HmLabel type_class;
  int m;  	// m : #
  int n;  	// n : #
  Ref<CellSlice> len;  	// len : Unary ~n
  Ref<td::BitString> s;  	// s : n * Bit
  Record_hml_short() = default;
  Record_hml_short(Ref<CellSlice> _len, Ref<td::BitString> _s) : m(-1), n(-1), len(std::move(_len)), s(std::move(_s)) {}
};

struct HmLabel::Record_hml_long {
  typedef HmLabel type_class;
  int m;  	// m : #
  int n;  	// n : #<= m
  Ref<td::BitString> s;  	// s : n * Bit
  Record_hml_long() = default;
  Record_hml_long(int _n, Ref<td::BitString> _s) : m(-1), n(_n), s(std::move(_s)) {}
};

struct HmLabel::Record_hml_same {
  typedef HmLabel type_class;
  int m;  	// m : #
  bool v;  	// v : Bit
  int n;  	// n : #<= m
  Record_hml_same() = default;
  Record_hml_same(bool _v, int _n) : m(-1), v(_v), n(_n) {}
};

//
// headers for type `Unary`
//

struct Unary final : TLB_Complex {
  enum { unary_zero, unary_succ };
  static constexpr int cons_len_exact = 1;
  struct Record_unary_zero {
    typedef Unary type_class;
  };
  struct Record_unary_succ {
    typedef Unary type_class;
    int n;  	// n : #
    Ref<CellSlice> x;  	// x : Unary ~n
    Record_unary_succ() = default;
    Record_unary_succ(Ref<CellSlice> _x) : n(-1), x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool skip(vm::CellSlice& cs, int& m_) const;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool validate_skip(int *ops, vm::CellSlice& cs, bool weak, int& m_) const;
  bool fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res, int& m_) const;
  bool unpack(vm::CellSlice& cs, Record_unary_zero& data, int& m_) const;
  bool unpack_unary_zero(vm::CellSlice& cs, int& m_) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_unary_zero& data, int& m_) const;
  bool cell_unpack_unary_zero(Ref<vm::Cell> cell_ref, int& m_) const;
  bool pack(vm::CellBuilder& cb, const Record_unary_zero& data, int& m_) const;
  bool pack_unary_zero(vm::CellBuilder& cb, int& m_) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_unary_zero& data, int& m_) const;
  bool cell_pack_unary_zero(Ref<vm::Cell>& cell_ref, int& m_) const;
  bool unpack(vm::CellSlice& cs, Record_unary_succ& data, int& m_) const;
  bool unpack_unary_succ(vm::CellSlice& cs, int& n, Ref<CellSlice>& x, int& m_) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_unary_succ& data, int& m_) const;
  bool cell_unpack_unary_succ(Ref<vm::Cell> cell_ref, int& n, Ref<CellSlice>& x, int& m_) const;
  bool pack(vm::CellBuilder& cb, const Record_unary_succ& data, int& m_) const;
  bool pack_unary_succ(vm::CellBuilder& cb, Ref<CellSlice> x, int& m_) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_unary_succ& data, int& m_) const;
  bool cell_pack_unary_succ(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x, int& m_) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs, int& m_) const;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Unary ~m_)";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const Unary t_Unary;

//
// headers for type `HashmapE`
//

struct HashmapE final : TLB_Complex {
  enum { hme_empty, hme_root };
  static constexpr int cons_len_exact = 1;
  int m_;
  const TLB &X_;
  HashmapE(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_hme_empty {
    typedef HashmapE type_class;
  };
  struct Record_hme_root {
    typedef HashmapE type_class;
    int n;  	// n : #
    Ref<Cell> root;  	// root : ^(Hashmap n X)
    Record_hme_root() = default;
    Record_hme_root(Ref<Cell> _root) : n(-1), root(std::move(_root)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_hme_empty& data) const;
  bool unpack_hme_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hme_empty& data) const;
  bool cell_unpack_hme_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_hme_empty& data) const;
  bool pack_hme_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hme_empty& data) const;
  bool cell_pack_hme_empty(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_hme_root& data) const;
  bool unpack_hme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_hme_root& data) const;
  bool cell_unpack_hme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const;
  bool pack(vm::CellBuilder& cb, const Record_hme_root& data) const;
  bool pack_hme_root(vm::CellBuilder& cb, Ref<Cell> root) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_hme_root& data) const;
  bool cell_pack_hme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HashmapE " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `BitstringSet`
//

struct BitstringSet final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  int m_;
  BitstringSet(int m) : m_(m) {}
  struct Record {
    typedef BitstringSet type_class;
    int n;  	// n : #
    Ref<CellSlice> x;  	// Hashmap n True
    Record() = default;
    Record(Ref<CellSlice> _x) : n(-1), x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, int& n, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, int& n, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(BitstringSet " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

//
// headers for type `HashmapAug`
//

struct HashmapAug final : TLB_Complex {
  enum { ahm_edge };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_, &Y_;
  HashmapAug(int m, const TLB& X, const TLB& Y) : m_(m), X_(X), Y_(Y) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HashmapAug " << m_ << " " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct HashmapAug::Record {
  typedef HashmapAug type_class;
  int n;  	// n : #
  int l;  	// l : #
  int m;  	// m : #
  Ref<CellSlice> label;  	// label : HmLabel ~l n
  Ref<CellSlice> node;  	// node : HashmapAugNode m X Y
  Record() = default;
  Record(Ref<CellSlice> _label, Ref<CellSlice> _node) : n(-1), l(-1), m(-1), label(std::move(_label)), node(std::move(_node)) {}
};

//
// headers for type `HashmapAugNode`
//

struct HashmapAugNode final : TLB_Complex {
  enum { ahmn_leaf, ahmn_fork };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_, &Y_;
  HashmapAugNode(int m, const TLB& X, const TLB& Y) : m_(m), X_(X), Y_(Y) {}
  struct Record_ahmn_leaf {
    typedef HashmapAugNode type_class;
    Ref<CellSlice> extra;  	// extra : Y
    Ref<CellSlice> value;  	// value : X
    Record_ahmn_leaf() = default;
    Record_ahmn_leaf(Ref<CellSlice> _extra, Ref<CellSlice> _value) : extra(std::move(_extra)), value(std::move(_value)) {}
  };
  struct Record_ahmn_fork;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_ahmn_leaf& data) const;
  bool unpack_ahmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& extra, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ahmn_leaf& data) const;
  bool cell_unpack_ahmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_ahmn_leaf& data) const;
  bool pack_ahmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> extra, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ahmn_leaf& data) const;
  bool cell_pack_ahmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra, Ref<CellSlice> value) const;
  bool unpack(vm::CellSlice& cs, Record_ahmn_fork& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ahmn_fork& data) const;
  bool pack(vm::CellBuilder& cb, const Record_ahmn_fork& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ahmn_fork& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HashmapAugNode " << m_ << " " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct HashmapAugNode::Record_ahmn_fork {
  typedef HashmapAugNode type_class;
  int n;  	// n : #
  Ref<Cell> left;  	// left : ^(HashmapAug n X Y)
  Ref<Cell> right;  	// right : ^(HashmapAug n X Y)
  Ref<CellSlice> extra;  	// extra : Y
  Record_ahmn_fork() = default;
  Record_ahmn_fork(Ref<Cell> _left, Ref<Cell> _right, Ref<CellSlice> _extra) : n(-1), left(std::move(_left)), right(std::move(_right)), extra(std::move(_extra)) {}
};

//
// headers for type `HashmapAugE`
//

struct HashmapAugE final : TLB_Complex {
  enum { ahme_empty, ahme_root };
  static constexpr int cons_len_exact = 1;
  int m_;
  const TLB &X_, &Y_;
  HashmapAugE(int m, const TLB& X, const TLB& Y) : m_(m), X_(X), Y_(Y) {}
  struct Record_ahme_empty {
    typedef HashmapAugE type_class;
    Ref<CellSlice> extra;  	// extra : Y
    Record_ahme_empty() = default;
    Record_ahme_empty(Ref<CellSlice> _extra) : extra(std::move(_extra)) {}
  };
  struct Record_ahme_root;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_ahme_empty& data) const;
  bool unpack_ahme_empty(vm::CellSlice& cs, Ref<CellSlice>& extra) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ahme_empty& data) const;
  bool cell_unpack_ahme_empty(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra) const;
  bool pack(vm::CellBuilder& cb, const Record_ahme_empty& data) const;
  bool pack_ahme_empty(vm::CellBuilder& cb, Ref<CellSlice> extra) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ahme_empty& data) const;
  bool cell_pack_ahme_empty(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra) const;
  bool unpack(vm::CellSlice& cs, Record_ahme_root& data) const;
  bool unpack_ahme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root, Ref<CellSlice>& extra) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ahme_root& data) const;
  bool cell_unpack_ahme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root, Ref<CellSlice>& extra) const;
  bool pack(vm::CellBuilder& cb, const Record_ahme_root& data) const;
  bool pack_ahme_root(vm::CellBuilder& cb, Ref<Cell> root, Ref<CellSlice> extra) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ahme_root& data) const;
  bool cell_pack_ahme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root, Ref<CellSlice> extra) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HashmapAugE " << m_ << " " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct HashmapAugE::Record_ahme_root {
  typedef HashmapAugE type_class;
  int n;  	// n : #
  Ref<Cell> root;  	// root : ^(HashmapAug n X Y)
  Ref<CellSlice> extra;  	// extra : Y
  Record_ahme_root() = default;
  Record_ahme_root(Ref<Cell> _root, Ref<CellSlice> _extra) : n(-1), root(std::move(_root)), extra(std::move(_extra)) {}
};

//
// headers for type `VarHashmap`
//

struct VarHashmap final : TLB_Complex {
  enum { vhm_edge };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_;
  VarHashmap(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VarHashmap " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VarHashmap::Record {
  typedef VarHashmap type_class;
  int n;  	// n : #
  int l;  	// l : #
  int m;  	// m : #
  Ref<CellSlice> label;  	// label : HmLabel ~l n
  Ref<CellSlice> node;  	// node : VarHashmapNode m X
  Record() = default;
  Record(Ref<CellSlice> _label, Ref<CellSlice> _node) : n(-1), l(-1), m(-1), label(std::move(_label)), node(std::move(_node)) {}
};

//
// headers for type `VarHashmapNode`
//

struct VarHashmapNode final : TLB_Complex {
  enum { vhmn_leaf, vhmn_fork, vhmn_cont };
  static constexpr char cons_len[3] = { 2, 2, 1 };
  static constexpr unsigned char cons_tag[3] = { 0, 1, 1 };
  int m_;
  const TLB &X_;
  VarHashmapNode(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_vhmn_leaf {
    typedef VarHashmapNode type_class;
    Ref<CellSlice> value;  	// value : X
    Record_vhmn_leaf() = default;
    Record_vhmn_leaf(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  struct Record_vhmn_fork;
  struct Record_vhmn_cont;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vhmn_leaf& data) const;
  bool unpack_vhmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vhmn_leaf& data) const;
  bool cell_unpack_vhmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_vhmn_leaf& data) const;
  bool pack_vhmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vhmn_leaf& data) const;
  bool cell_pack_vhmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool unpack(vm::CellSlice& cs, Record_vhmn_fork& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vhmn_fork& data) const;
  bool pack(vm::CellBuilder& cb, const Record_vhmn_fork& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vhmn_fork& data) const;
  bool unpack(vm::CellSlice& cs, Record_vhmn_cont& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vhmn_cont& data) const;
  bool pack(vm::CellBuilder& cb, const Record_vhmn_cont& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vhmn_cont& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VarHashmapNode " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 7);
  }
};

struct VarHashmapNode::Record_vhmn_fork {
  typedef VarHashmapNode type_class;
  int n;  	// n : #
  Ref<Cell> left;  	// left : ^(VarHashmap n X)
  Ref<Cell> right;  	// right : ^(VarHashmap n X)
  Ref<CellSlice> value;  	// value : Maybe X
  Record_vhmn_fork() = default;
  Record_vhmn_fork(Ref<Cell> _left, Ref<Cell> _right, Ref<CellSlice> _value) : n(-1), left(std::move(_left)), right(std::move(_right)), value(std::move(_value)) {}
};

struct VarHashmapNode::Record_vhmn_cont {
  typedef VarHashmapNode type_class;
  int n;  	// n : #
  bool branch;  	// branch : Bit
  Ref<Cell> child;  	// child : ^(VarHashmap n X)
  Ref<CellSlice> value;  	// value : X
  Record_vhmn_cont() = default;
  Record_vhmn_cont(bool _branch, Ref<Cell> _child, Ref<CellSlice> _value) : n(-1), branch(_branch), child(std::move(_child)), value(std::move(_value)) {}
};

//
// headers for type `VarHashmapE`
//

struct VarHashmapE final : TLB_Complex {
  enum { vhme_empty, vhme_root };
  static constexpr int cons_len_exact = 1;
  int m_;
  const TLB &X_;
  VarHashmapE(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_vhme_empty {
    typedef VarHashmapE type_class;
  };
  struct Record_vhme_root {
    typedef VarHashmapE type_class;
    int n;  	// n : #
    Ref<Cell> root;  	// root : ^(VarHashmap n X)
    Record_vhme_root() = default;
    Record_vhme_root(Ref<Cell> _root) : n(-1), root(std::move(_root)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vhme_empty& data) const;
  bool unpack_vhme_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vhme_empty& data) const;
  bool cell_unpack_vhme_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vhme_empty& data) const;
  bool pack_vhme_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vhme_empty& data) const;
  bool cell_pack_vhme_empty(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vhme_root& data) const;
  bool unpack_vhme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vhme_root& data) const;
  bool cell_unpack_vhme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const;
  bool pack(vm::CellBuilder& cb, const Record_vhme_root& data) const;
  bool pack_vhme_root(vm::CellBuilder& cb, Ref<Cell> root) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vhme_root& data) const;
  bool cell_pack_vhme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VarHashmapE " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `PfxHashmap`
//

struct PfxHashmap final : TLB_Complex {
  enum { phm_edge };
  static constexpr int cons_len_exact = 0;
  int m_;
  const TLB &X_;
  PfxHashmap(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(PfxHashmap " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct PfxHashmap::Record {
  typedef PfxHashmap type_class;
  int n;  	// n : #
  int l;  	// l : #
  int m;  	// m : #
  Ref<CellSlice> label;  	// label : HmLabel ~l n
  Ref<CellSlice> node;  	// node : PfxHashmapNode m X
  Record() = default;
  Record(Ref<CellSlice> _label, Ref<CellSlice> _node) : n(-1), l(-1), m(-1), label(std::move(_label)), node(std::move(_node)) {}
};

//
// headers for type `PfxHashmapNode`
//

struct PfxHashmapNode final : TLB_Complex {
  enum { phmn_leaf, phmn_fork };
  static constexpr int cons_len_exact = 1;
  int m_;
  const TLB &X_;
  PfxHashmapNode(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_phmn_leaf {
    typedef PfxHashmapNode type_class;
    Ref<CellSlice> value;  	// value : X
    Record_phmn_leaf() = default;
    Record_phmn_leaf(Ref<CellSlice> _value) : value(std::move(_value)) {}
  };
  struct Record_phmn_fork;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_phmn_leaf& data) const;
  bool unpack_phmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_phmn_leaf& data) const;
  bool cell_unpack_phmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const;
  bool pack(vm::CellBuilder& cb, const Record_phmn_leaf& data) const;
  bool pack_phmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_phmn_leaf& data) const;
  bool cell_pack_phmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const;
  bool unpack(vm::CellSlice& cs, Record_phmn_fork& data) const;
  bool unpack_phmn_fork(vm::CellSlice& cs, int& n, Ref<Cell>& left, Ref<Cell>& right) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_phmn_fork& data) const;
  bool cell_unpack_phmn_fork(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& left, Ref<Cell>& right) const;
  bool pack(vm::CellBuilder& cb, const Record_phmn_fork& data) const;
  bool pack_phmn_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_phmn_fork& data) const;
  bool cell_pack_phmn_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(PfxHashmapNode " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct PfxHashmapNode::Record_phmn_fork {
  typedef PfxHashmapNode type_class;
  int n;  	// n : #
  Ref<Cell> left;  	// left : ^(PfxHashmap n X)
  Ref<Cell> right;  	// right : ^(PfxHashmap n X)
  Record_phmn_fork() = default;
  Record_phmn_fork(Ref<Cell> _left, Ref<Cell> _right) : n(-1), left(std::move(_left)), right(std::move(_right)) {}
};

//
// headers for type `PfxHashmapE`
//

struct PfxHashmapE final : TLB_Complex {
  enum { phme_empty, phme_root };
  static constexpr int cons_len_exact = 1;
  int m_;
  const TLB &X_;
  PfxHashmapE(int m, const TLB& X) : m_(m), X_(X) {}
  struct Record_phme_empty {
    typedef PfxHashmapE type_class;
  };
  struct Record_phme_root {
    typedef PfxHashmapE type_class;
    int n;  	// n : #
    Ref<Cell> root;  	// root : ^(PfxHashmap n X)
    Record_phme_root() = default;
    Record_phme_root(Ref<Cell> _root) : n(-1), root(std::move(_root)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_phme_empty& data) const;
  bool unpack_phme_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_phme_empty& data) const;
  bool cell_unpack_phme_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_phme_empty& data) const;
  bool pack_phme_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_phme_empty& data) const;
  bool cell_pack_phme_empty(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_phme_root& data) const;
  bool unpack_phme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_phme_root& data) const;
  bool cell_unpack_phme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const;
  bool pack(vm::CellBuilder& cb, const Record_phme_root& data) const;
  bool pack_phme_root(vm::CellBuilder& cb, Ref<Cell> root) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_phme_root& data) const;
  bool cell_pack_phme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(PfxHashmapE " << m_ << " " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `MsgAddressExt`
//

struct MsgAddressExt final : TLB_Complex {
  enum { addr_none, addr_extern };
  static constexpr int cons_len_exact = 2;
  struct Record_addr_none {
    typedef MsgAddressExt type_class;
  };
  struct Record_addr_extern {
    typedef MsgAddressExt type_class;
    int len;  	// len : ## 9
    Ref<td::BitString> external_address;  	// external_address : bits len
    Record_addr_extern() = default;
    Record_addr_extern(int _len, Ref<td::BitString> _external_address) : len(_len), external_address(std::move(_external_address)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_addr_none& data) const;
  bool unpack_addr_none(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_addr_none& data) const;
  bool cell_unpack_addr_none(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_addr_none& data) const;
  bool pack_addr_none(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_addr_none& data) const;
  bool cell_pack_addr_none(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_addr_extern& data) const;
  bool unpack_addr_extern(vm::CellSlice& cs, int& len, Ref<td::BitString>& external_address) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_addr_extern& data) const;
  bool cell_unpack_addr_extern(Ref<vm::Cell> cell_ref, int& len, Ref<td::BitString>& external_address) const;
  bool pack(vm::CellBuilder& cb, const Record_addr_extern& data) const;
  bool pack_addr_extern(vm::CellBuilder& cb, int len, Ref<td::BitString> external_address) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_addr_extern& data) const;
  bool cell_pack_addr_extern(Ref<vm::Cell>& cell_ref, int len, Ref<td::BitString> external_address) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MsgAddressExt";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 3);
  }
};

extern const MsgAddressExt t_MsgAddressExt;

//
// headers for type `Anycast`
//

struct Anycast final : TLB_Complex {
  enum { anycast_info };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Anycast type_class;
    int depth;  	// depth : #<= 30
    Ref<td::BitString> rewrite_pfx;  	// rewrite_pfx : bits depth
    Record() = default;
    Record(int _depth, Ref<td::BitString> _rewrite_pfx) : depth(_depth), rewrite_pfx(std::move(_rewrite_pfx)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_anycast_info(vm::CellSlice& cs, int& depth, Ref<td::BitString>& rewrite_pfx) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_anycast_info(Ref<vm::Cell> cell_ref, int& depth, Ref<td::BitString>& rewrite_pfx) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_anycast_info(vm::CellBuilder& cb, int depth, Ref<td::BitString> rewrite_pfx) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_anycast_info(Ref<vm::Cell>& cell_ref, int depth, Ref<td::BitString> rewrite_pfx) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Anycast";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Anycast t_Anycast;

//
// headers for type `MsgAddressInt`
//

struct MsgAddressInt final : TLB_Complex {
  enum { addr_std, addr_var };
  static constexpr int cons_len_exact = 2;
  static constexpr unsigned char cons_tag[2] = { 2, 3 };
  struct Record_addr_std;
  struct Record_addr_var;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_addr_std& data) const;
  bool unpack_addr_std(vm::CellSlice& cs, Ref<CellSlice>& anycast, int& workchain_id, td::BitArray<256>& address) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_addr_std& data) const;
  bool cell_unpack_addr_std(Ref<vm::Cell> cell_ref, Ref<CellSlice>& anycast, int& workchain_id, td::BitArray<256>& address) const;
  bool pack(vm::CellBuilder& cb, const Record_addr_std& data) const;
  bool pack_addr_std(vm::CellBuilder& cb, Ref<CellSlice> anycast, int workchain_id, td::BitArray<256> address) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_addr_std& data) const;
  bool cell_pack_addr_std(Ref<vm::Cell>& cell_ref, Ref<CellSlice> anycast, int workchain_id, td::BitArray<256> address) const;
  bool unpack(vm::CellSlice& cs, Record_addr_var& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_addr_var& data) const;
  bool pack(vm::CellBuilder& cb, const Record_addr_var& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_addr_var& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MsgAddressInt";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 12);
  }
};

struct MsgAddressInt::Record_addr_std {
  typedef MsgAddressInt type_class;
  Ref<CellSlice> anycast;  	// anycast : Maybe Anycast
  int workchain_id;  	// workchain_id : int8
  td::BitArray<256> address;  	// address : bits256
  Record_addr_std() = default;
  Record_addr_std(Ref<CellSlice> _anycast, int _workchain_id, const td::BitArray<256>& _address) : anycast(std::move(_anycast)), workchain_id(_workchain_id), address(_address) {}
};

struct MsgAddressInt::Record_addr_var {
  typedef MsgAddressInt type_class;
  Ref<CellSlice> anycast;  	// anycast : Maybe Anycast
  int addr_len;  	// addr_len : ## 9
  int workchain_id;  	// workchain_id : int32
  Ref<td::BitString> address;  	// address : bits addr_len
  Record_addr_var() = default;
  Record_addr_var(Ref<CellSlice> _anycast, int _addr_len, int _workchain_id, Ref<td::BitString> _address) : anycast(std::move(_anycast)), addr_len(_addr_len), workchain_id(_workchain_id), address(std::move(_address)) {}
};

extern const MsgAddressInt t_MsgAddressInt;

//
// headers for type `MsgAddress`
//

struct MsgAddress final : TLB_Complex {
  enum { cons2, cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record_cons1 {
    typedef MsgAddress type_class;
    Ref<CellSlice> x;  	// MsgAddressInt
    Record_cons1() = default;
    Record_cons1(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons2 {
    typedef MsgAddress type_class;
    Ref<CellSlice> x;  	// MsgAddressExt
    Record_cons2() = default;
    Record_cons2(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cons1& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons1& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons1& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons1& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons2& data) const;
  bool unpack_cons2(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons2& data) const;
  bool cell_unpack_cons2(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons2& data) const;
  bool pack_cons2(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons2& data) const;
  bool cell_pack_cons2(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MsgAddress";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const MsgAddress t_MsgAddress;

//
// headers for type `VarUInteger`
//

struct VarUInteger final : TLB_Complex {
  enum { var_uint };
  static constexpr int cons_len_exact = 0;
  int m_;
  VarUInteger(int m) : m_(m) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_var_uint(vm::CellSlice& cs, int& n, int& len, RefInt256& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_var_uint(Ref<vm::Cell> cell_ref, int& n, int& len, RefInt256& value) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_var_uint(vm::CellBuilder& cb, int len, RefInt256 value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_var_uint(Ref<vm::Cell>& cell_ref, int len, RefInt256 value) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VarUInteger " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VarUInteger::Record {
  typedef VarUInteger type_class;
  int n;  	// n : #
  int len;  	// len : #< n
  RefInt256 value;  	// value : uint (8 * len)
  Record() = default;
  Record(int _len, RefInt256 _value) : n(-1), len(_len), value(std::move(_value)) {}
};

//
// headers for type `VarInteger`
//

struct VarInteger final : TLB_Complex {
  enum { var_int };
  static constexpr int cons_len_exact = 0;
  int m_;
  VarInteger(int m) : m_(m) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_var_int(vm::CellSlice& cs, int& n, int& len, RefInt256& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_var_int(Ref<vm::Cell> cell_ref, int& n, int& len, RefInt256& value) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_var_int(vm::CellBuilder& cb, int len, RefInt256 value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_var_int(Ref<vm::Cell>& cell_ref, int len, RefInt256 value) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VarInteger " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VarInteger::Record {
  typedef VarInteger type_class;
  int n;  	// n : #
  int len;  	// len : #< n
  RefInt256 value;  	// value : int (8 * len)
  Record() = default;
  Record(int _len, RefInt256 _value) : n(-1), len(_len), value(std::move(_value)) {}
};

//
// headers for type `Grams`
//

struct Grams final : TLB_Complex {
  enum { nanograms };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Grams type_class;
    Ref<CellSlice> amount;  	// amount : VarUInteger 16
    Record() = default;
    Record(Ref<CellSlice> _amount) : amount(std::move(_amount)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_nanograms(vm::CellSlice& cs, Ref<CellSlice>& amount) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_nanograms(Ref<vm::Cell> cell_ref, Ref<CellSlice>& amount) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_nanograms(vm::CellBuilder& cb, Ref<CellSlice> amount) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_nanograms(Ref<vm::Cell>& cell_ref, Ref<CellSlice> amount) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Grams";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Grams t_Grams;

//
// headers for type `ExtraCurrencyCollection`
//

struct ExtraCurrencyCollection final : TLB_Complex {
  enum { extra_currencies };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ExtraCurrencyCollection type_class;
    Ref<CellSlice> dict;  	// dict : HashmapE 32 (VarUInteger 32)
    Record() = default;
    Record(Ref<CellSlice> _dict) : dict(std::move(_dict)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_extra_currencies(vm::CellSlice& cs, Ref<CellSlice>& dict) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_extra_currencies(Ref<vm::Cell> cell_ref, Ref<CellSlice>& dict) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_extra_currencies(vm::CellBuilder& cb, Ref<CellSlice> dict) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_extra_currencies(Ref<vm::Cell>& cell_ref, Ref<CellSlice> dict) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ExtraCurrencyCollection";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ExtraCurrencyCollection t_ExtraCurrencyCollection;

//
// headers for type `CurrencyCollection`
//

struct CurrencyCollection final : TLB_Complex {
  enum { currencies };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef CurrencyCollection type_class;
    Ref<CellSlice> grams;  	// grams : Grams
    Ref<CellSlice> other;  	// other : ExtraCurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _grams, Ref<CellSlice> _other) : grams(std::move(_grams)), other(std::move(_other)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_currencies(vm::CellSlice& cs, Ref<CellSlice>& grams, Ref<CellSlice>& other) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_currencies(Ref<vm::Cell> cell_ref, Ref<CellSlice>& grams, Ref<CellSlice>& other) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_currencies(vm::CellBuilder& cb, Ref<CellSlice> grams, Ref<CellSlice> other) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_currencies(Ref<vm::Cell>& cell_ref, Ref<CellSlice> grams, Ref<CellSlice> other) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CurrencyCollection";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const CurrencyCollection t_CurrencyCollection;

//
// headers for type `CommonMsgInfo`
//

struct CommonMsgInfo final : TLB_Complex {
  enum { int_msg_info, ext_in_msg_info, ext_out_msg_info };
  static constexpr char cons_len[3] = { 1, 2, 2 };
  static constexpr unsigned char cons_tag[3] = { 0, 2, 3 };
  struct Record_int_msg_info;
  struct Record_ext_in_msg_info;
  struct Record_ext_out_msg_info;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_int_msg_info& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_int_msg_info& data) const;
  bool pack(vm::CellBuilder& cb, const Record_int_msg_info& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_int_msg_info& data) const;
  bool unpack(vm::CellSlice& cs, Record_ext_in_msg_info& data) const;
  bool unpack_ext_in_msg_info(vm::CellSlice& cs, Ref<CellSlice>& src, Ref<CellSlice>& dest, Ref<CellSlice>& import_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ext_in_msg_info& data) const;
  bool cell_unpack_ext_in_msg_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& src, Ref<CellSlice>& dest, Ref<CellSlice>& import_fee) const;
  bool pack(vm::CellBuilder& cb, const Record_ext_in_msg_info& data) const;
  bool pack_ext_in_msg_info(vm::CellBuilder& cb, Ref<CellSlice> src, Ref<CellSlice> dest, Ref<CellSlice> import_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ext_in_msg_info& data) const;
  bool cell_pack_ext_in_msg_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> src, Ref<CellSlice> dest, Ref<CellSlice> import_fee) const;
  bool unpack(vm::CellSlice& cs, Record_ext_out_msg_info& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ext_out_msg_info& data) const;
  bool pack(vm::CellBuilder& cb, const Record_ext_out_msg_info& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ext_out_msg_info& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CommonMsgInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 13);
  }
};

struct CommonMsgInfo::Record_int_msg_info {
  typedef CommonMsgInfo type_class;
  bool ihr_disabled;  	// ihr_disabled : Bool
  bool bounce;  	// bounce : Bool
  bool bounced;  	// bounced : Bool
  Ref<CellSlice> src;  	// src : MsgAddressInt
  Ref<CellSlice> dest;  	// dest : MsgAddressInt
  Ref<CellSlice> value;  	// value : CurrencyCollection
  Ref<CellSlice> ihr_fee;  	// ihr_fee : Grams
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  unsigned long long created_lt;  	// created_lt : uint64
  unsigned created_at;  	// created_at : uint32
  Record_int_msg_info() = default;
  Record_int_msg_info(bool _ihr_disabled, bool _bounce, bool _bounced, Ref<CellSlice> _src, Ref<CellSlice> _dest, Ref<CellSlice> _value, Ref<CellSlice> _ihr_fee, Ref<CellSlice> _fwd_fee, unsigned long long _created_lt, unsigned _created_at) : ihr_disabled(_ihr_disabled), bounce(_bounce), bounced(_bounced), src(std::move(_src)), dest(std::move(_dest)), value(std::move(_value)), ihr_fee(std::move(_ihr_fee)), fwd_fee(std::move(_fwd_fee)), created_lt(_created_lt), created_at(_created_at) {}
};

struct CommonMsgInfo::Record_ext_in_msg_info {
  typedef CommonMsgInfo type_class;
  Ref<CellSlice> src;  	// src : MsgAddressExt
  Ref<CellSlice> dest;  	// dest : MsgAddressInt
  Ref<CellSlice> import_fee;  	// import_fee : Grams
  Record_ext_in_msg_info() = default;
  Record_ext_in_msg_info(Ref<CellSlice> _src, Ref<CellSlice> _dest, Ref<CellSlice> _import_fee) : src(std::move(_src)), dest(std::move(_dest)), import_fee(std::move(_import_fee)) {}
};

struct CommonMsgInfo::Record_ext_out_msg_info {
  typedef CommonMsgInfo type_class;
  Ref<CellSlice> src;  	// src : MsgAddressInt
  Ref<CellSlice> dest;  	// dest : MsgAddressExt
  unsigned long long created_lt;  	// created_lt : uint64
  unsigned created_at;  	// created_at : uint32
  Record_ext_out_msg_info() = default;
  Record_ext_out_msg_info(Ref<CellSlice> _src, Ref<CellSlice> _dest, unsigned long long _created_lt, unsigned _created_at) : src(std::move(_src)), dest(std::move(_dest)), created_lt(_created_lt), created_at(_created_at) {}
};

extern const CommonMsgInfo t_CommonMsgInfo;

//
// headers for type `CommonMsgInfoRelaxed`
//

struct CommonMsgInfoRelaxed final : TLB_Complex {
  enum { int_msg_info, ext_out_msg_info };
  static constexpr char cons_len[2] = { 1, 2 };
  static constexpr unsigned char cons_tag[2] = { 0, 3 };
  struct Record_int_msg_info;
  struct Record_ext_out_msg_info;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_int_msg_info& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_int_msg_info& data) const;
  bool pack(vm::CellBuilder& cb, const Record_int_msg_info& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_int_msg_info& data) const;
  bool unpack(vm::CellSlice& cs, Record_ext_out_msg_info& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_ext_out_msg_info& data) const;
  bool pack(vm::CellBuilder& cb, const Record_ext_out_msg_info& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_ext_out_msg_info& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CommonMsgInfoRelaxed";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct CommonMsgInfoRelaxed::Record_int_msg_info {
  typedef CommonMsgInfoRelaxed type_class;
  bool ihr_disabled;  	// ihr_disabled : Bool
  bool bounce;  	// bounce : Bool
  bool bounced;  	// bounced : Bool
  Ref<CellSlice> src;  	// src : MsgAddress
  Ref<CellSlice> dest;  	// dest : MsgAddressInt
  Ref<CellSlice> value;  	// value : CurrencyCollection
  Ref<CellSlice> ihr_fee;  	// ihr_fee : Grams
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  unsigned long long created_lt;  	// created_lt : uint64
  unsigned created_at;  	// created_at : uint32
  Record_int_msg_info() = default;
  Record_int_msg_info(bool _ihr_disabled, bool _bounce, bool _bounced, Ref<CellSlice> _src, Ref<CellSlice> _dest, Ref<CellSlice> _value, Ref<CellSlice> _ihr_fee, Ref<CellSlice> _fwd_fee, unsigned long long _created_lt, unsigned _created_at) : ihr_disabled(_ihr_disabled), bounce(_bounce), bounced(_bounced), src(std::move(_src)), dest(std::move(_dest)), value(std::move(_value)), ihr_fee(std::move(_ihr_fee)), fwd_fee(std::move(_fwd_fee)), created_lt(_created_lt), created_at(_created_at) {}
};

struct CommonMsgInfoRelaxed::Record_ext_out_msg_info {
  typedef CommonMsgInfoRelaxed type_class;
  Ref<CellSlice> src;  	// src : MsgAddress
  Ref<CellSlice> dest;  	// dest : MsgAddressExt
  unsigned long long created_lt;  	// created_lt : uint64
  unsigned created_at;  	// created_at : uint32
  Record_ext_out_msg_info() = default;
  Record_ext_out_msg_info(Ref<CellSlice> _src, Ref<CellSlice> _dest, unsigned long long _created_lt, unsigned _created_at) : src(std::move(_src)), dest(std::move(_dest)), created_lt(_created_lt), created_at(_created_at) {}
};

extern const CommonMsgInfoRelaxed t_CommonMsgInfoRelaxed;

//
// headers for type `TickTock`
//

struct TickTock final : TLB_Complex {
  enum { tick_tock };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef TickTock type_class;
    bool tick;  	// tick : Bool
    bool tock;  	// tock : Bool
    Record() = default;
    Record(bool _tick, bool _tock) : tick(_tick), tock(_tock) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 2;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(2);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(2);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_tick_tock(vm::CellSlice& cs, bool& tick, bool& tock) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_tick_tock(Ref<vm::Cell> cell_ref, bool& tick, bool& tock) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_tick_tock(vm::CellBuilder& cb, bool tick, bool tock) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_tick_tock(Ref<vm::Cell>& cell_ref, bool tick, bool tock) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TickTock";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const TickTock t_TickTock;

//
// headers for type `StateInit`
//

struct StateInit final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "StateInit";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct StateInit::Record {
  typedef StateInit type_class;
  Ref<CellSlice> split_depth;  	// split_depth : Maybe (## 5)
  Ref<CellSlice> special;  	// special : Maybe TickTock
  Ref<CellSlice> code;  	// code : Maybe ^Cell
  Ref<CellSlice> data;  	// data : Maybe ^Cell
  Ref<CellSlice> library;  	// library : HashmapE 256 SimpleLib
  Record() = default;
  Record(Ref<CellSlice> _split_depth, Ref<CellSlice> _special, Ref<CellSlice> _code, Ref<CellSlice> _data, Ref<CellSlice> _library) : split_depth(std::move(_split_depth)), special(std::move(_special)), code(std::move(_code)), data(std::move(_data)), library(std::move(_library)) {}
};

extern const StateInit t_StateInit;

//
// headers for type `SimpleLib`
//

struct SimpleLib final : TLB_Complex {
  enum { simple_lib };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef SimpleLib type_class;
    bool public1;  	// public : Bool
    Ref<Cell> root;  	// root : ^Cell
    Record() = default;
    Record(bool _public1, Ref<Cell> _root) : public1(_public1), root(std::move(_root)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10001;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10001);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_simple_lib(vm::CellSlice& cs, bool& public1, Ref<Cell>& root) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_simple_lib(Ref<vm::Cell> cell_ref, bool& public1, Ref<Cell>& root) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_simple_lib(vm::CellBuilder& cb, bool public1, Ref<Cell> root) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_simple_lib(Ref<vm::Cell>& cell_ref, bool public1, Ref<Cell> root) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SimpleLib";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const SimpleLib t_SimpleLib;

//
// headers for type `Message`
//

struct Message final : TLB_Complex {
  enum { message };
  static constexpr int cons_len_exact = 0;
  const TLB &X_;
  Message(const TLB& X) : X_(X) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_message(vm::CellSlice& cs, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_message(Ref<vm::Cell> cell_ref, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_message(vm::CellBuilder& cb, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_message(Ref<vm::Cell>& cell_ref, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(Message " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Message::Record {
  typedef Message type_class;
  Ref<CellSlice> info;  	// info : CommonMsgInfo
  Ref<CellSlice> init;  	// init : Maybe (Either StateInit ^StateInit)
  Ref<CellSlice> body;  	// body : Either X ^X
  Record() = default;
  Record(Ref<CellSlice> _info, Ref<CellSlice> _init, Ref<CellSlice> _body) : info(std::move(_info)), init(std::move(_init)), body(std::move(_body)) {}
};

//
// headers for type `MessageRelaxed`
//

struct MessageRelaxed final : TLB_Complex {
  enum { message };
  static constexpr int cons_len_exact = 0;
  const TLB &X_;
  MessageRelaxed(const TLB& X) : X_(X) {}
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_message(vm::CellSlice& cs, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_message(Ref<vm::Cell> cell_ref, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_message(vm::CellBuilder& cb, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_message(Ref<vm::Cell>& cell_ref, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(MessageRelaxed " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct MessageRelaxed::Record {
  typedef MessageRelaxed type_class;
  Ref<CellSlice> info;  	// info : CommonMsgInfoRelaxed
  Ref<CellSlice> init;  	// init : Maybe (Either StateInit ^StateInit)
  Ref<CellSlice> body;  	// body : Either X ^X
  Record() = default;
  Record(Ref<CellSlice> _info, Ref<CellSlice> _init, Ref<CellSlice> _body) : info(std::move(_info)), init(std::move(_init)), body(std::move(_body)) {}
};

//
// headers for type `MessageAny`
//

struct MessageAny final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef MessageAny type_class;
    Ref<CellSlice> x;  	// Message Any
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MessageAny";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const MessageAny t_MessageAny;

//
// headers for type `IntermediateAddress`
//

struct IntermediateAddress final : TLB_Complex {
  enum { interm_addr_regular, interm_addr_simple, interm_addr_ext };
  static constexpr char cons_len[3] = { 1, 2, 2 };
  static constexpr unsigned char cons_tag[3] = { 0, 2, 3 };
  struct Record_interm_addr_regular {
    typedef IntermediateAddress type_class;
    int use_dest_bits;  	// use_dest_bits : #<= 96
    Record_interm_addr_regular() = default;
    Record_interm_addr_regular(int _use_dest_bits) : use_dest_bits(_use_dest_bits) {}
  };
  struct Record_interm_addr_simple {
    typedef IntermediateAddress type_class;
    int workchain_id;  	// workchain_id : int8
    unsigned long long addr_pfx;  	// addr_pfx : uint64
    Record_interm_addr_simple() = default;
    Record_interm_addr_simple(int _workchain_id, unsigned long long _addr_pfx) : workchain_id(_workchain_id), addr_pfx(_addr_pfx) {}
  };
  struct Record_interm_addr_ext {
    typedef IntermediateAddress type_class;
    int workchain_id;  	// workchain_id : int32
    unsigned long long addr_pfx;  	// addr_pfx : uint64
    Record_interm_addr_ext() = default;
    Record_interm_addr_ext(int _workchain_id, unsigned long long _addr_pfx) : workchain_id(_workchain_id), addr_pfx(_addr_pfx) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_interm_addr_regular& data) const;
  bool unpack_interm_addr_regular(vm::CellSlice& cs, int& use_dest_bits) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_interm_addr_regular& data) const;
  bool cell_unpack_interm_addr_regular(Ref<vm::Cell> cell_ref, int& use_dest_bits) const;
  bool pack(vm::CellBuilder& cb, const Record_interm_addr_regular& data) const;
  bool pack_interm_addr_regular(vm::CellBuilder& cb, int use_dest_bits) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_interm_addr_regular& data) const;
  bool cell_pack_interm_addr_regular(Ref<vm::Cell>& cell_ref, int use_dest_bits) const;
  bool unpack(vm::CellSlice& cs, Record_interm_addr_simple& data) const;
  bool unpack_interm_addr_simple(vm::CellSlice& cs, int& workchain_id, unsigned long long& addr_pfx) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_interm_addr_simple& data) const;
  bool cell_unpack_interm_addr_simple(Ref<vm::Cell> cell_ref, int& workchain_id, unsigned long long& addr_pfx) const;
  bool pack(vm::CellBuilder& cb, const Record_interm_addr_simple& data) const;
  bool pack_interm_addr_simple(vm::CellBuilder& cb, int workchain_id, unsigned long long addr_pfx) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_interm_addr_simple& data) const;
  bool cell_pack_interm_addr_simple(Ref<vm::Cell>& cell_ref, int workchain_id, unsigned long long addr_pfx) const;
  bool unpack(vm::CellSlice& cs, Record_interm_addr_ext& data) const;
  bool unpack_interm_addr_ext(vm::CellSlice& cs, int& workchain_id, unsigned long long& addr_pfx) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_interm_addr_ext& data) const;
  bool cell_unpack_interm_addr_ext(Ref<vm::Cell> cell_ref, int& workchain_id, unsigned long long& addr_pfx) const;
  bool pack(vm::CellBuilder& cb, const Record_interm_addr_ext& data) const;
  bool pack_interm_addr_ext(vm::CellBuilder& cb, int workchain_id, unsigned long long addr_pfx) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_interm_addr_ext& data) const;
  bool cell_pack_interm_addr_ext(Ref<vm::Cell>& cell_ref, int workchain_id, unsigned long long addr_pfx) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "IntermediateAddress";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 13);
  }
};

extern const IntermediateAddress t_IntermediateAddress;

//
// headers for type `MsgEnvelope`
//

struct MsgEnvelope final : TLB_Complex {
  enum { msg_envelope };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 4 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MsgEnvelope";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct MsgEnvelope::Record {
  typedef MsgEnvelope type_class;
  Ref<CellSlice> cur_addr;  	// cur_addr : IntermediateAddress
  Ref<CellSlice> next_addr;  	// next_addr : IntermediateAddress
  Ref<CellSlice> fwd_fee_remaining;  	// fwd_fee_remaining : Grams
  Ref<Cell> msg;  	// msg : ^(Message Any)
  Record() = default;
  Record(Ref<CellSlice> _cur_addr, Ref<CellSlice> _next_addr, Ref<CellSlice> _fwd_fee_remaining, Ref<Cell> _msg) : cur_addr(std::move(_cur_addr)), next_addr(std::move(_next_addr)), fwd_fee_remaining(std::move(_fwd_fee_remaining)), msg(std::move(_msg)) {}
};

extern const MsgEnvelope t_MsgEnvelope;

//
// headers for type `InMsg`
//

struct InMsg final : TLB_Complex {
  enum { msg_import_ext, msg_import_ihr, msg_import_imm, msg_import_fin, msg_import_tr, msg_discard_fin, msg_discard_tr };
  static constexpr int cons_len_exact = 3;
  static constexpr unsigned char cons_tag[7] = { 0, 2, 3, 4, 5, 6, 7 };
  struct Record_msg_import_ext {
    typedef InMsg type_class;
    Ref<Cell> msg;  	// msg : ^(Message Any)
    Ref<Cell> transaction;  	// transaction : ^Transaction
    Record_msg_import_ext() = default;
    Record_msg_import_ext(Ref<Cell> _msg, Ref<Cell> _transaction) : msg(std::move(_msg)), transaction(std::move(_transaction)) {}
  };
  struct Record_msg_import_ihr;
  struct Record_msg_import_imm;
  struct Record_msg_import_fin;
  struct Record_msg_import_tr;
  struct Record_msg_discard_fin;
  struct Record_msg_discard_tr;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_msg_import_ext& data) const;
  bool unpack_msg_import_ext(vm::CellSlice& cs, Ref<Cell>& msg, Ref<Cell>& transaction) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_import_ext& data) const;
  bool cell_unpack_msg_import_ext(Ref<vm::Cell> cell_ref, Ref<Cell>& msg, Ref<Cell>& transaction) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_import_ext& data) const;
  bool pack_msg_import_ext(vm::CellBuilder& cb, Ref<Cell> msg, Ref<Cell> transaction) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_import_ext& data) const;
  bool cell_pack_msg_import_ext(Ref<vm::Cell>& cell_ref, Ref<Cell> msg, Ref<Cell> transaction) const;
  bool unpack(vm::CellSlice& cs, Record_msg_import_ihr& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_import_ihr& data) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_import_ihr& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_import_ihr& data) const;
  bool unpack(vm::CellSlice& cs, Record_msg_import_imm& data) const;
  bool unpack_msg_import_imm(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_import_imm& data) const;
  bool cell_unpack_msg_import_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_import_imm& data) const;
  bool pack_msg_import_imm(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_import_imm& data) const;
  bool cell_pack_msg_import_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const;
  bool unpack(vm::CellSlice& cs, Record_msg_import_fin& data) const;
  bool unpack_msg_import_fin(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_import_fin& data) const;
  bool cell_unpack_msg_import_fin(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_import_fin& data) const;
  bool pack_msg_import_fin(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_import_fin& data) const;
  bool cell_pack_msg_import_fin(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const;
  bool unpack(vm::CellSlice& cs, Record_msg_import_tr& data) const;
  bool unpack_msg_import_tr(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& out_msg, Ref<CellSlice>& transit_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_import_tr& data) const;
  bool cell_unpack_msg_import_tr(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& out_msg, Ref<CellSlice>& transit_fee) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_import_tr& data) const;
  bool pack_msg_import_tr(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> out_msg, Ref<CellSlice> transit_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_import_tr& data) const;
  bool cell_pack_msg_import_tr(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> out_msg, Ref<CellSlice> transit_fee) const;
  bool unpack(vm::CellSlice& cs, Record_msg_discard_fin& data) const;
  bool unpack_msg_discard_fin(vm::CellSlice& cs, Ref<Cell>& in_msg, unsigned long long& transaction_id, Ref<CellSlice>& fwd_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_discard_fin& data) const;
  bool cell_unpack_msg_discard_fin(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, unsigned long long& transaction_id, Ref<CellSlice>& fwd_fee) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_discard_fin& data) const;
  bool pack_msg_discard_fin(vm::CellBuilder& cb, Ref<Cell> in_msg, unsigned long long transaction_id, Ref<CellSlice> fwd_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_discard_fin& data) const;
  bool cell_pack_msg_discard_fin(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, unsigned long long transaction_id, Ref<CellSlice> fwd_fee) const;
  bool unpack(vm::CellSlice& cs, Record_msg_discard_tr& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_discard_tr& data) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_discard_tr& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_discard_tr& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "InMsg";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(3, 0xfd);
  }
};

struct InMsg::Record_msg_import_ihr {
  typedef InMsg type_class;
  Ref<Cell> msg;  	// msg : ^(Message Any)
  Ref<Cell> transaction;  	// transaction : ^Transaction
  Ref<CellSlice> ihr_fee;  	// ihr_fee : Grams
  Ref<Cell> proof_created;  	// proof_created : ^Cell
  Record_msg_import_ihr() = default;
  Record_msg_import_ihr(Ref<Cell> _msg, Ref<Cell> _transaction, Ref<CellSlice> _ihr_fee, Ref<Cell> _proof_created) : msg(std::move(_msg)), transaction(std::move(_transaction)), ihr_fee(std::move(_ihr_fee)), proof_created(std::move(_proof_created)) {}
};

struct InMsg::Record_msg_import_imm {
  typedef InMsg type_class;
  Ref<Cell> in_msg;  	// in_msg : ^MsgEnvelope
  Ref<Cell> transaction;  	// transaction : ^Transaction
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  Record_msg_import_imm() = default;
  Record_msg_import_imm(Ref<Cell> _in_msg, Ref<Cell> _transaction, Ref<CellSlice> _fwd_fee) : in_msg(std::move(_in_msg)), transaction(std::move(_transaction)), fwd_fee(std::move(_fwd_fee)) {}
};

struct InMsg::Record_msg_import_fin {
  typedef InMsg type_class;
  Ref<Cell> in_msg;  	// in_msg : ^MsgEnvelope
  Ref<Cell> transaction;  	// transaction : ^Transaction
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  Record_msg_import_fin() = default;
  Record_msg_import_fin(Ref<Cell> _in_msg, Ref<Cell> _transaction, Ref<CellSlice> _fwd_fee) : in_msg(std::move(_in_msg)), transaction(std::move(_transaction)), fwd_fee(std::move(_fwd_fee)) {}
};

struct InMsg::Record_msg_import_tr {
  typedef InMsg type_class;
  Ref<Cell> in_msg;  	// in_msg : ^MsgEnvelope
  Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
  Ref<CellSlice> transit_fee;  	// transit_fee : Grams
  Record_msg_import_tr() = default;
  Record_msg_import_tr(Ref<Cell> _in_msg, Ref<Cell> _out_msg, Ref<CellSlice> _transit_fee) : in_msg(std::move(_in_msg)), out_msg(std::move(_out_msg)), transit_fee(std::move(_transit_fee)) {}
};

struct InMsg::Record_msg_discard_fin {
  typedef InMsg type_class;
  Ref<Cell> in_msg;  	// in_msg : ^MsgEnvelope
  unsigned long long transaction_id;  	// transaction_id : uint64
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  Record_msg_discard_fin() = default;
  Record_msg_discard_fin(Ref<Cell> _in_msg, unsigned long long _transaction_id, Ref<CellSlice> _fwd_fee) : in_msg(std::move(_in_msg)), transaction_id(_transaction_id), fwd_fee(std::move(_fwd_fee)) {}
};

struct InMsg::Record_msg_discard_tr {
  typedef InMsg type_class;
  Ref<Cell> in_msg;  	// in_msg : ^MsgEnvelope
  unsigned long long transaction_id;  	// transaction_id : uint64
  Ref<CellSlice> fwd_fee;  	// fwd_fee : Grams
  Ref<Cell> proof_delivered;  	// proof_delivered : ^Cell
  Record_msg_discard_tr() = default;
  Record_msg_discard_tr(Ref<Cell> _in_msg, unsigned long long _transaction_id, Ref<CellSlice> _fwd_fee, Ref<Cell> _proof_delivered) : in_msg(std::move(_in_msg)), transaction_id(_transaction_id), fwd_fee(std::move(_fwd_fee)), proof_delivered(std::move(_proof_delivered)) {}
};

extern const InMsg t_InMsg;

//
// headers for type `ImportFees`
//

struct ImportFees final : TLB_Complex {
  enum { import_fees };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ImportFees type_class;
    Ref<CellSlice> fees_collected;  	// fees_collected : Grams
    Ref<CellSlice> value_imported;  	// value_imported : CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _fees_collected, Ref<CellSlice> _value_imported) : fees_collected(std::move(_fees_collected)), value_imported(std::move(_value_imported)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_import_fees(vm::CellSlice& cs, Ref<CellSlice>& fees_collected, Ref<CellSlice>& value_imported) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_import_fees(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fees_collected, Ref<CellSlice>& value_imported) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_import_fees(vm::CellBuilder& cb, Ref<CellSlice> fees_collected, Ref<CellSlice> value_imported) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_import_fees(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fees_collected, Ref<CellSlice> value_imported) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ImportFees";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ImportFees t_ImportFees;

//
// headers for type `InMsgDescr`
//

struct InMsgDescr final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef InMsgDescr type_class;
    Ref<CellSlice> x;  	// HashmapAugE 256 InMsg ImportFees
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "InMsgDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const InMsgDescr t_InMsgDescr;

//
// headers for type `OutMsg`
//

struct OutMsg final : TLB_Complex {
  enum { msg_export_ext, msg_export_new, msg_export_imm, msg_export_tr, msg_export_deq_imm, msg_export_deq, msg_export_deq_short, msg_export_tr_req };
  static constexpr char cons_len[8] = { 3, 3, 3, 3, 3, 4, 4, 3 };
  static constexpr unsigned char cons_tag[8] = { 0, 1, 2, 3, 4, 12, 13, 7 };
  struct Record_msg_export_ext {
    typedef OutMsg type_class;
    Ref<Cell> msg;  	// msg : ^(Message Any)
    Ref<Cell> transaction;  	// transaction : ^Transaction
    Record_msg_export_ext() = default;
    Record_msg_export_ext(Ref<Cell> _msg, Ref<Cell> _transaction) : msg(std::move(_msg)), transaction(std::move(_transaction)) {}
  };
  struct Record_msg_export_imm;
  struct Record_msg_export_new {
    typedef OutMsg type_class;
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    Ref<Cell> transaction;  	// transaction : ^Transaction
    Record_msg_export_new() = default;
    Record_msg_export_new(Ref<Cell> _out_msg, Ref<Cell> _transaction) : out_msg(std::move(_out_msg)), transaction(std::move(_transaction)) {}
  };
  struct Record_msg_export_tr {
    typedef OutMsg type_class;
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    Ref<Cell> imported;  	// imported : ^InMsg
    Record_msg_export_tr() = default;
    Record_msg_export_tr(Ref<Cell> _out_msg, Ref<Cell> _imported) : out_msg(std::move(_out_msg)), imported(std::move(_imported)) {}
  };
  struct Record_msg_export_deq {
    typedef OutMsg type_class;
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    long long import_block_lt;  	// import_block_lt : uint63
    Record_msg_export_deq() = default;
    Record_msg_export_deq(Ref<Cell> _out_msg, long long _import_block_lt) : out_msg(std::move(_out_msg)), import_block_lt(_import_block_lt) {}
  };
  struct Record_msg_export_deq_short;
  struct Record_msg_export_tr_req {
    typedef OutMsg type_class;
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    Ref<Cell> imported;  	// imported : ^InMsg
    Record_msg_export_tr_req() = default;
    Record_msg_export_tr_req(Ref<Cell> _out_msg, Ref<Cell> _imported) : out_msg(std::move(_out_msg)), imported(std::move(_imported)) {}
  };
  struct Record_msg_export_deq_imm {
    typedef OutMsg type_class;
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    Ref<Cell> reimport;  	// reimport : ^InMsg
    Record_msg_export_deq_imm() = default;
    Record_msg_export_deq_imm(Ref<Cell> _out_msg, Ref<Cell> _reimport) : out_msg(std::move(_out_msg)), reimport(std::move(_reimport)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_msg_export_ext& data) const;
  bool unpack_msg_export_ext(vm::CellSlice& cs, Ref<Cell>& msg, Ref<Cell>& transaction) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_ext& data) const;
  bool cell_unpack_msg_export_ext(Ref<vm::Cell> cell_ref, Ref<Cell>& msg, Ref<Cell>& transaction) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_ext& data) const;
  bool pack_msg_export_ext(vm::CellBuilder& cb, Ref<Cell> msg, Ref<Cell> transaction) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_ext& data) const;
  bool cell_pack_msg_export_ext(Ref<vm::Cell>& cell_ref, Ref<Cell> msg, Ref<Cell> transaction) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_imm& data) const;
  bool unpack_msg_export_imm(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& transaction, Ref<Cell>& reimport) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_imm& data) const;
  bool cell_unpack_msg_export_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& transaction, Ref<Cell>& reimport) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_imm& data) const;
  bool pack_msg_export_imm(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> transaction, Ref<Cell> reimport) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_imm& data) const;
  bool cell_pack_msg_export_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> transaction, Ref<Cell> reimport) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_new& data) const;
  bool unpack_msg_export_new(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& transaction) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_new& data) const;
  bool cell_unpack_msg_export_new(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& transaction) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_new& data) const;
  bool pack_msg_export_new(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> transaction) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_new& data) const;
  bool cell_pack_msg_export_new(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> transaction) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_tr& data) const;
  bool unpack_msg_export_tr(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& imported) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_tr& data) const;
  bool cell_unpack_msg_export_tr(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& imported) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_tr& data) const;
  bool pack_msg_export_tr(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> imported) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_tr& data) const;
  bool cell_pack_msg_export_tr(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> imported) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_deq& data) const;
  bool unpack_msg_export_deq(vm::CellSlice& cs, Ref<Cell>& out_msg, long long& import_block_lt) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_deq& data) const;
  bool cell_unpack_msg_export_deq(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, long long& import_block_lt) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_deq& data) const;
  bool pack_msg_export_deq(vm::CellBuilder& cb, Ref<Cell> out_msg, long long import_block_lt) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_deq& data) const;
  bool cell_pack_msg_export_deq(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, long long import_block_lt) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_deq_short& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_deq_short& data) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_deq_short& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_deq_short& data) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_tr_req& data) const;
  bool unpack_msg_export_tr_req(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& imported) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_tr_req& data) const;
  bool cell_unpack_msg_export_tr_req(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& imported) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_tr_req& data) const;
  bool pack_msg_export_tr_req(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> imported) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_tr_req& data) const;
  bool cell_pack_msg_export_tr_req(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> imported) const;
  bool unpack(vm::CellSlice& cs, Record_msg_export_deq_imm& data) const;
  bool unpack_msg_export_deq_imm(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& reimport) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_msg_export_deq_imm& data) const;
  bool cell_unpack_msg_export_deq_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& reimport) const;
  bool pack(vm::CellBuilder& cb, const Record_msg_export_deq_imm& data) const;
  bool pack_msg_export_deq_imm(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> reimport) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_msg_export_deq_imm& data) const;
  bool cell_pack_msg_export_deq_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> reimport) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutMsg";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect_ext(4, 0x7155);
  }
};

struct OutMsg::Record_msg_export_imm {
  typedef OutMsg type_class;
  Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
  Ref<Cell> transaction;  	// transaction : ^Transaction
  Ref<Cell> reimport;  	// reimport : ^InMsg
  Record_msg_export_imm() = default;
  Record_msg_export_imm(Ref<Cell> _out_msg, Ref<Cell> _transaction, Ref<Cell> _reimport) : out_msg(std::move(_out_msg)), transaction(std::move(_transaction)), reimport(std::move(_reimport)) {}
};

struct OutMsg::Record_msg_export_deq_short {
  typedef OutMsg type_class;
  td::BitArray<256> msg_env_hash;  	// msg_env_hash : bits256
  int next_workchain;  	// next_workchain : int32
  unsigned long long next_addr_pfx;  	// next_addr_pfx : uint64
  unsigned long long import_block_lt;  	// import_block_lt : uint64
  Record_msg_export_deq_short() = default;
  Record_msg_export_deq_short(const td::BitArray<256>& _msg_env_hash, int _next_workchain, unsigned long long _next_addr_pfx, unsigned long long _import_block_lt) : msg_env_hash(_msg_env_hash), next_workchain(_next_workchain), next_addr_pfx(_next_addr_pfx), import_block_lt(_import_block_lt) {}
};

extern const OutMsg t_OutMsg;

//
// headers for type `EnqueuedMsg`
//

struct EnqueuedMsg final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef EnqueuedMsg type_class;
    unsigned long long enqueued_lt;  	// enqueued_lt : uint64
    Ref<Cell> out_msg;  	// out_msg : ^MsgEnvelope
    Record() = default;
    Record(unsigned long long _enqueued_lt, Ref<Cell> _out_msg) : enqueued_lt(_enqueued_lt), out_msg(std::move(_out_msg)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10040;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10040);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, unsigned long long& enqueued_lt, Ref<Cell>& out_msg) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, unsigned long long& enqueued_lt, Ref<Cell>& out_msg) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, unsigned long long enqueued_lt, Ref<Cell> out_msg) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, unsigned long long enqueued_lt, Ref<Cell> out_msg) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "EnqueuedMsg";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const EnqueuedMsg t_EnqueuedMsg;

//
// headers for type `OutMsgDescr`
//

struct OutMsgDescr final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef OutMsgDescr type_class;
    Ref<CellSlice> x;  	// HashmapAugE 256 OutMsg CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutMsgDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const OutMsgDescr t_OutMsgDescr;

//
// headers for type `OutMsgQueue`
//

struct OutMsgQueue final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef OutMsgQueue type_class;
    Ref<CellSlice> x;  	// HashmapAugE 352 EnqueuedMsg uint64
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutMsgQueue";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const OutMsgQueue t_OutMsgQueue;

//
// headers for type `ProcessedUpto`
//

struct ProcessedUpto final : TLB_Complex {
  enum { processed_upto };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ProcessedUpto type_class;
    unsigned long long last_msg_lt;  	// last_msg_lt : uint64
    td::BitArray<256> last_msg_hash;  	// last_msg_hash : bits256
    Record() = default;
    Record(unsigned long long _last_msg_lt, const td::BitArray<256>& _last_msg_hash) : last_msg_lt(_last_msg_lt), last_msg_hash(_last_msg_hash) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 320;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(320);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(320);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_processed_upto(vm::CellSlice& cs, unsigned long long& last_msg_lt, td::BitArray<256>& last_msg_hash) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_processed_upto(Ref<vm::Cell> cell_ref, unsigned long long& last_msg_lt, td::BitArray<256>& last_msg_hash) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_processed_upto(vm::CellBuilder& cb, unsigned long long last_msg_lt, td::BitArray<256> last_msg_hash) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_processed_upto(Ref<vm::Cell>& cell_ref, unsigned long long last_msg_lt, td::BitArray<256> last_msg_hash) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ProcessedUpto";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ProcessedUpto t_ProcessedUpto;

//
// headers for type `ProcessedInfo`
//

struct ProcessedInfo final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ProcessedInfo type_class;
    Ref<CellSlice> x;  	// HashmapE 96 ProcessedUpto
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ProcessedInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ProcessedInfo t_ProcessedInfo;

//
// headers for type `IhrPendingSince`
//

struct IhrPendingSince final : TLB_Complex {
  enum { ihr_pending };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef IhrPendingSince type_class;
    unsigned long long import_lt;  	// import_lt : uint64
    Record() = default;
    Record(unsigned long long _import_lt) : import_lt(_import_lt) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 64;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(64);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(64);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_ihr_pending(vm::CellSlice& cs, unsigned long long& import_lt) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_ihr_pending(Ref<vm::Cell> cell_ref, unsigned long long& import_lt) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_ihr_pending(vm::CellBuilder& cb, unsigned long long import_lt) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_ihr_pending(Ref<vm::Cell>& cell_ref, unsigned long long import_lt) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "IhrPendingSince";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const IhrPendingSince t_IhrPendingSince;

//
// headers for type `IhrPendingInfo`
//

struct IhrPendingInfo final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef IhrPendingInfo type_class;
    Ref<CellSlice> x;  	// HashmapE 320 IhrPendingSince
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "IhrPendingInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const IhrPendingInfo t_IhrPendingInfo;

//
// headers for type `OutMsgQueueInfo`
//

struct OutMsgQueueInfo final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& out_queue, Ref<CellSlice>& proc_info, Ref<CellSlice>& ihr_pending) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& out_queue, Ref<CellSlice>& proc_info, Ref<CellSlice>& ihr_pending) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> out_queue, Ref<CellSlice> proc_info, Ref<CellSlice> ihr_pending) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> out_queue, Ref<CellSlice> proc_info, Ref<CellSlice> ihr_pending) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutMsgQueueInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct OutMsgQueueInfo::Record {
  typedef OutMsgQueueInfo type_class;
  Ref<CellSlice> out_queue;  	// out_queue : OutMsgQueue
  Ref<CellSlice> proc_info;  	// proc_info : ProcessedInfo
  Ref<CellSlice> ihr_pending;  	// ihr_pending : IhrPendingInfo
  Record() = default;
  Record(Ref<CellSlice> _out_queue, Ref<CellSlice> _proc_info, Ref<CellSlice> _ihr_pending) : out_queue(std::move(_out_queue)), proc_info(std::move(_proc_info)), ihr_pending(std::move(_ihr_pending)) {}
};

extern const OutMsgQueueInfo t_OutMsgQueueInfo;

//
// headers for type `StorageUsed`
//

struct StorageUsed final : TLB_Complex {
  enum { storage_used };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_storage_used(vm::CellSlice& cs, Ref<CellSlice>& cells, Ref<CellSlice>& bits, Ref<CellSlice>& public_cells) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_storage_used(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cells, Ref<CellSlice>& bits, Ref<CellSlice>& public_cells) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_storage_used(vm::CellBuilder& cb, Ref<CellSlice> cells, Ref<CellSlice> bits, Ref<CellSlice> public_cells) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_storage_used(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cells, Ref<CellSlice> bits, Ref<CellSlice> public_cells) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "StorageUsed";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct StorageUsed::Record {
  typedef StorageUsed type_class;
  Ref<CellSlice> cells;  	// cells : VarUInteger 7
  Ref<CellSlice> bits;  	// bits : VarUInteger 7
  Ref<CellSlice> public_cells;  	// public_cells : VarUInteger 7
  Record() = default;
  Record(Ref<CellSlice> _cells, Ref<CellSlice> _bits, Ref<CellSlice> _public_cells) : cells(std::move(_cells)), bits(std::move(_bits)), public_cells(std::move(_public_cells)) {}
};

extern const StorageUsed t_StorageUsed;

//
// headers for type `StorageUsedShort`
//

struct StorageUsedShort final : TLB_Complex {
  enum { storage_used_short };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef StorageUsedShort type_class;
    Ref<CellSlice> cells;  	// cells : VarUInteger 7
    Ref<CellSlice> bits;  	// bits : VarUInteger 7
    Record() = default;
    Record(Ref<CellSlice> _cells, Ref<CellSlice> _bits) : cells(std::move(_cells)), bits(std::move(_bits)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_storage_used_short(vm::CellSlice& cs, Ref<CellSlice>& cells, Ref<CellSlice>& bits) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_storage_used_short(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cells, Ref<CellSlice>& bits) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_storage_used_short(vm::CellBuilder& cb, Ref<CellSlice> cells, Ref<CellSlice> bits) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_storage_used_short(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cells, Ref<CellSlice> bits) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "StorageUsedShort";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const StorageUsedShort t_StorageUsedShort;

//
// headers for type `StorageInfo`
//

struct StorageInfo final : TLB_Complex {
  enum { storage_info };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_storage_info(vm::CellSlice& cs, Ref<CellSlice>& used, unsigned& last_paid, Ref<CellSlice>& due_payment) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_storage_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& used, unsigned& last_paid, Ref<CellSlice>& due_payment) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_storage_info(vm::CellBuilder& cb, Ref<CellSlice> used, unsigned last_paid, Ref<CellSlice> due_payment) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_storage_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> used, unsigned last_paid, Ref<CellSlice> due_payment) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "StorageInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct StorageInfo::Record {
  typedef StorageInfo type_class;
  Ref<CellSlice> used;  	// used : StorageUsed
  unsigned last_paid;  	// last_paid : uint32
  Ref<CellSlice> due_payment;  	// due_payment : Maybe Grams
  Record() = default;
  Record(Ref<CellSlice> _used, unsigned _last_paid, Ref<CellSlice> _due_payment) : used(std::move(_used)), last_paid(_last_paid), due_payment(std::move(_due_payment)) {}
};

extern const StorageInfo t_StorageInfo;

//
// headers for type `Account`
//

struct Account final : TLB_Complex {
  enum { account_none, account };
  static constexpr int cons_len_exact = 1;
  struct Record_account_none {
    typedef Account type_class;
  };
  struct Record_account;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_account_none& data) const;
  bool unpack_account_none(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_account_none& data) const;
  bool cell_unpack_account_none(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_account_none& data) const;
  bool pack_account_none(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_account_none& data) const;
  bool cell_pack_account_none(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_account& data) const;
  bool unpack_account(vm::CellSlice& cs, Ref<CellSlice>& addr, Ref<CellSlice>& storage_stat, Ref<CellSlice>& storage) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_account& data) const;
  bool cell_unpack_account(Ref<vm::Cell> cell_ref, Ref<CellSlice>& addr, Ref<CellSlice>& storage_stat, Ref<CellSlice>& storage) const;
  bool pack(vm::CellBuilder& cb, const Record_account& data) const;
  bool pack_account(vm::CellBuilder& cb, Ref<CellSlice> addr, Ref<CellSlice> storage_stat, Ref<CellSlice> storage) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_account& data) const;
  bool cell_pack_account(Ref<vm::Cell>& cell_ref, Ref<CellSlice> addr, Ref<CellSlice> storage_stat, Ref<CellSlice> storage) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Account";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct Account::Record_account {
  typedef Account type_class;
  Ref<CellSlice> addr;  	// addr : MsgAddressInt
  Ref<CellSlice> storage_stat;  	// storage_stat : StorageInfo
  Ref<CellSlice> storage;  	// storage : AccountStorage
  Record_account() = default;
  Record_account(Ref<CellSlice> _addr, Ref<CellSlice> _storage_stat, Ref<CellSlice> _storage) : addr(std::move(_addr)), storage_stat(std::move(_storage_stat)), storage(std::move(_storage)) {}
};

extern const Account t_Account;

//
// headers for type `AccountStorage`
//

struct AccountStorage final : TLB_Complex {
  enum { account_storage };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_account_storage(vm::CellSlice& cs, unsigned long long& last_trans_lt, Ref<CellSlice>& balance, Ref<CellSlice>& state) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_account_storage(Ref<vm::Cell> cell_ref, unsigned long long& last_trans_lt, Ref<CellSlice>& balance, Ref<CellSlice>& state) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_account_storage(vm::CellBuilder& cb, unsigned long long last_trans_lt, Ref<CellSlice> balance, Ref<CellSlice> state) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_account_storage(Ref<vm::Cell>& cell_ref, unsigned long long last_trans_lt, Ref<CellSlice> balance, Ref<CellSlice> state) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "AccountStorage";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct AccountStorage::Record {
  typedef AccountStorage type_class;
  unsigned long long last_trans_lt;  	// last_trans_lt : uint64
  Ref<CellSlice> balance;  	// balance : CurrencyCollection
  Ref<CellSlice> state;  	// state : AccountState
  Record() = default;
  Record(unsigned long long _last_trans_lt, Ref<CellSlice> _balance, Ref<CellSlice> _state) : last_trans_lt(_last_trans_lt), balance(std::move(_balance)), state(std::move(_state)) {}
};

extern const AccountStorage t_AccountStorage;

//
// headers for type `AccountState`
//

struct AccountState final : TLB_Complex {
  enum { account_uninit, account_frozen, account_active };
  static constexpr char cons_len[3] = { 2, 2, 1 };
  static constexpr unsigned char cons_tag[3] = { 0, 1, 1 };
  struct Record_account_uninit {
    typedef AccountState type_class;
  };
  struct Record_account_active {
    typedef AccountState type_class;
    Ref<CellSlice> x;  	// StateInit
    Record_account_active() = default;
    Record_account_active(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_account_frozen {
    typedef AccountState type_class;
    td::BitArray<256> state_hash;  	// state_hash : bits256
    Record_account_frozen() = default;
    Record_account_frozen(const td::BitArray<256>& _state_hash) : state_hash(_state_hash) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_account_uninit& data) const;
  bool unpack_account_uninit(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_account_uninit& data) const;
  bool cell_unpack_account_uninit(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_account_uninit& data) const;
  bool pack_account_uninit(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_account_uninit& data) const;
  bool cell_pack_account_uninit(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_account_active& data) const;
  bool unpack_account_active(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_account_active& data) const;
  bool cell_unpack_account_active(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_account_active& data) const;
  bool pack_account_active(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_account_active& data) const;
  bool cell_pack_account_active(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_account_frozen& data) const;
  bool unpack_account_frozen(vm::CellSlice& cs, td::BitArray<256>& state_hash) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_account_frozen& data) const;
  bool cell_unpack_account_frozen(Ref<vm::Cell> cell_ref, td::BitArray<256>& state_hash) const;
  bool pack(vm::CellBuilder& cb, const Record_account_frozen& data) const;
  bool pack_account_frozen(vm::CellBuilder& cb, td::BitArray<256> state_hash) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_account_frozen& data) const;
  bool cell_pack_account_frozen(Ref<vm::Cell>& cell_ref, td::BitArray<256> state_hash) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "AccountState";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 7);
  }
};

extern const AccountState t_AccountState;

//
// headers for type `AccountStatus`
//

struct AccountStatus final : TLB_Complex {
  enum { acc_state_uninit, acc_state_frozen, acc_state_active, acc_state_nonexist };
  static constexpr int cons_len_exact = 2;
  struct Record_acc_state_uninit {
    typedef AccountStatus type_class;
  };
  struct Record_acc_state_frozen {
    typedef AccountStatus type_class;
  };
  struct Record_acc_state_active {
    typedef AccountStatus type_class;
  };
  struct Record_acc_state_nonexist {
    typedef AccountStatus type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 2;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(2);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(2);
  }
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record_acc_state_uninit& data) const;
  bool unpack_acc_state_uninit(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acc_state_uninit& data) const;
  bool cell_unpack_acc_state_uninit(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acc_state_uninit& data) const;
  bool pack_acc_state_uninit(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acc_state_uninit& data) const;
  bool cell_pack_acc_state_uninit(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_acc_state_frozen& data) const;
  bool unpack_acc_state_frozen(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acc_state_frozen& data) const;
  bool cell_unpack_acc_state_frozen(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acc_state_frozen& data) const;
  bool pack_acc_state_frozen(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acc_state_frozen& data) const;
  bool cell_pack_acc_state_frozen(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_acc_state_active& data) const;
  bool unpack_acc_state_active(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acc_state_active& data) const;
  bool cell_unpack_acc_state_active(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acc_state_active& data) const;
  bool pack_acc_state_active(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acc_state_active& data) const;
  bool cell_pack_acc_state_active(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_acc_state_nonexist& data) const;
  bool unpack_acc_state_nonexist(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acc_state_nonexist& data) const;
  bool cell_unpack_acc_state_nonexist(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acc_state_nonexist& data) const;
  bool pack_acc_state_nonexist(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acc_state_nonexist& data) const;
  bool cell_pack_acc_state_nonexist(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "AccountStatus";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(2);
  }
};

extern const AccountStatus t_AccountStatus;

//
// headers for type `ShardAccount`
//

struct ShardAccount final : TLB_Complex {
  enum { account_descr };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10140;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10140);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_account_descr(vm::CellSlice& cs, Ref<Cell>& account, td::BitArray<256>& last_trans_hash, unsigned long long& last_trans_lt) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_account_descr(Ref<vm::Cell> cell_ref, Ref<Cell>& account, td::BitArray<256>& last_trans_hash, unsigned long long& last_trans_lt) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_account_descr(vm::CellBuilder& cb, Ref<Cell> account, td::BitArray<256> last_trans_hash, unsigned long long last_trans_lt) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_account_descr(Ref<vm::Cell>& cell_ref, Ref<Cell> account, td::BitArray<256> last_trans_hash, unsigned long long last_trans_lt) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardAccount";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ShardAccount::Record {
  typedef ShardAccount type_class;
  Ref<Cell> account;  	// account : ^Account
  td::BitArray<256> last_trans_hash;  	// last_trans_hash : bits256
  unsigned long long last_trans_lt;  	// last_trans_lt : uint64
  Record() = default;
  Record(Ref<Cell> _account, const td::BitArray<256>& _last_trans_hash, unsigned long long _last_trans_lt) : account(std::move(_account)), last_trans_hash(_last_trans_hash), last_trans_lt(_last_trans_lt) {}
};

extern const ShardAccount t_ShardAccount;

//
// headers for type `DepthBalanceInfo`
//

struct DepthBalanceInfo final : TLB_Complex {
  enum { depth_balance };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef DepthBalanceInfo type_class;
    int split_depth;  	// split_depth : #<= 30
    Ref<CellSlice> balance;  	// balance : CurrencyCollection
    Record() = default;
    Record(int _split_depth, Ref<CellSlice> _balance) : split_depth(_split_depth), balance(std::move(_balance)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_depth_balance(vm::CellSlice& cs, int& split_depth, Ref<CellSlice>& balance) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_depth_balance(Ref<vm::Cell> cell_ref, int& split_depth, Ref<CellSlice>& balance) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_depth_balance(vm::CellBuilder& cb, int split_depth, Ref<CellSlice> balance) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_depth_balance(Ref<vm::Cell>& cell_ref, int split_depth, Ref<CellSlice> balance) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "DepthBalanceInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const DepthBalanceInfo t_DepthBalanceInfo;

//
// headers for type `ShardAccounts`
//

struct ShardAccounts final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardAccounts type_class;
    Ref<CellSlice> x;  	// HashmapAugE 256 ShardAccount DepthBalanceInfo
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardAccounts";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardAccounts t_ShardAccounts;

//
// headers for auxiliary type `Transaction_aux`
//

struct Transaction_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Transaction_aux type_class;
    Ref<CellSlice> in_msg;  	// in_msg : Maybe ^(Message Any)
    Ref<CellSlice> out_msgs;  	// out_msgs : HashmapE 15 ^(Message Any)
    Record() = default;
    Record(Ref<CellSlice> _in_msg, Ref<CellSlice> _out_msgs) : in_msg(std::move(_in_msg)), out_msgs(std::move(_out_msgs)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& in_msg, Ref<CellSlice>& out_msgs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& in_msg, Ref<CellSlice>& out_msgs) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> in_msg, Ref<CellSlice> out_msgs) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> in_msg, Ref<CellSlice> out_msgs) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Transaction_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Transaction_aux t_Transaction_aux;

//
// headers for type `Transaction`
//

struct Transaction final : TLB_Complex {
  enum { transaction };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 7 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Transaction";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Transaction::Record {
  typedef Transaction type_class;
  td::BitArray<256> account_addr;  	// account_addr : bits256
  unsigned long long lt;  	// lt : uint64
  td::BitArray<256> prev_trans_hash;  	// prev_trans_hash : bits256
  unsigned long long prev_trans_lt;  	// prev_trans_lt : uint64
  unsigned now;  	// now : uint32
  int outmsg_cnt;  	// outmsg_cnt : uint15
  char orig_status;  	// orig_status : AccountStatus
  char end_status;  	// end_status : AccountStatus
  Transaction_aux::Record r1;  	// ^[$_ in_msg:(Maybe ^(Message Any)) out_msgs:(HashmapE 15 ^(Message Any)) ]
  Ref<CellSlice> total_fees;  	// total_fees : CurrencyCollection
  Ref<Cell> state_update;  	// state_update : ^(HASH_UPDATE Account)
  Ref<Cell> description;  	// description : ^TransactionDescr
  Record() = default;
  Record(const td::BitArray<256>& _account_addr, unsigned long long _lt, const td::BitArray<256>& _prev_trans_hash, unsigned long long _prev_trans_lt, unsigned _now, int _outmsg_cnt, char _orig_status, char _end_status, const Transaction_aux::Record& _r1, Ref<CellSlice> _total_fees, Ref<Cell> _state_update, Ref<Cell> _description) : account_addr(_account_addr), lt(_lt), prev_trans_hash(_prev_trans_hash), prev_trans_lt(_prev_trans_lt), now(_now), outmsg_cnt(_outmsg_cnt), orig_status(_orig_status), end_status(_end_status), r1(_r1), total_fees(std::move(_total_fees)), state_update(std::move(_state_update)), description(std::move(_description)) {}
};

extern const Transaction t_Transaction;

//
// headers for type `MERKLE_UPDATE`
//

struct MERKLE_UPDATE final : TLB_Complex {
  enum { _merkle_update };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 2 };
  const TLB &X_;
  MERKLE_UPDATE(const TLB& X) : X_(X) {}
  struct Record;
  bool always_special() const override {
    return true;
  }
  int get_size(const vm::CellSlice& cs) const override {
    return 0x20208;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x20208);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(MERKLE_UPDATE " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct MERKLE_UPDATE::Record {
  typedef MERKLE_UPDATE type_class;
  td::BitArray<256> old_hash;  	// old_hash : bits256
  td::BitArray<256> new_hash;  	// new_hash : bits256
  Ref<Cell> old;  	// old : ^X
  Ref<Cell> new1;  	// new : ^X
  Record() = default;
  Record(const td::BitArray<256>& _old_hash, const td::BitArray<256>& _new_hash, Ref<Cell> _old, Ref<Cell> _new1) : old_hash(_old_hash), new_hash(_new_hash), old(std::move(_old)), new1(std::move(_new1)) {}
};

//
// headers for type `HASH_UPDATE`
//

struct HASH_UPDATE final : TLB_Complex {
  enum { update_hashes };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x72 };
  const TLB &X_;
  HASH_UPDATE(const TLB& X) : X_(X) {}
  struct Record {
    typedef HASH_UPDATE type_class;
    td::BitArray<256> old_hash;  	// old_hash : bits256
    td::BitArray<256> new_hash;  	// new_hash : bits256
    Record() = default;
    Record(const td::BitArray<256>& _old_hash, const td::BitArray<256>& _new_hash) : old_hash(_old_hash), new_hash(_new_hash) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 520;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(520);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_update_hashes(vm::CellSlice& cs, td::BitArray<256>& old_hash, td::BitArray<256>& new_hash) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_update_hashes(Ref<vm::Cell> cell_ref, td::BitArray<256>& old_hash, td::BitArray<256>& new_hash) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_update_hashes(vm::CellBuilder& cb, td::BitArray<256> old_hash, td::BitArray<256> new_hash) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_update_hashes(Ref<vm::Cell>& cell_ref, td::BitArray<256> old_hash, td::BitArray<256> new_hash) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(HASH_UPDATE " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

//
// headers for type `MERKLE_PROOF`
//

struct MERKLE_PROOF final : TLB_Complex {
  enum { _merkle_proof };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 3 };
  const TLB &X_;
  MERKLE_PROOF(const TLB& X) : X_(X) {}
  struct Record;
  bool always_special() const override {
    return true;
  }
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10118;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10118);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack__merkle_proof(vm::CellSlice& cs, td::BitArray<256>& virtual_hash, int& depth, Ref<Cell>& virtual_root) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack__merkle_proof(Ref<vm::Cell> cell_ref, td::BitArray<256>& virtual_hash, int& depth, Ref<Cell>& virtual_root) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack__merkle_proof(vm::CellBuilder& cb, td::BitArray<256> virtual_hash, int depth, Ref<Cell> virtual_root) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack__merkle_proof(Ref<vm::Cell>& cell_ref, td::BitArray<256> virtual_hash, int depth, Ref<Cell> virtual_root) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(MERKLE_PROOF " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct MERKLE_PROOF::Record {
  typedef MERKLE_PROOF type_class;
  td::BitArray<256> virtual_hash;  	// virtual_hash : bits256
  int depth;  	// depth : uint16
  Ref<Cell> virtual_root;  	// virtual_root : ^X
  Record() = default;
  Record(const td::BitArray<256>& _virtual_hash, int _depth, Ref<Cell> _virtual_root) : virtual_hash(_virtual_hash), depth(_depth), virtual_root(std::move(_virtual_root)) {}
};

//
// headers for type `AccountBlock`
//

struct AccountBlock final : TLB_Complex {
  enum { acc_trans };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 5 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_acc_trans(vm::CellSlice& cs, td::BitArray<256>& account_addr, Ref<CellSlice>& transactions, Ref<Cell>& state_update) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_acc_trans(Ref<vm::Cell> cell_ref, td::BitArray<256>& account_addr, Ref<CellSlice>& transactions, Ref<Cell>& state_update) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_acc_trans(vm::CellBuilder& cb, td::BitArray<256> account_addr, Ref<CellSlice> transactions, Ref<Cell> state_update) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_acc_trans(Ref<vm::Cell>& cell_ref, td::BitArray<256> account_addr, Ref<CellSlice> transactions, Ref<Cell> state_update) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "AccountBlock";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct AccountBlock::Record {
  typedef AccountBlock type_class;
  td::BitArray<256> account_addr;  	// account_addr : bits256
  Ref<CellSlice> transactions;  	// transactions : HashmapAug 64 ^Transaction CurrencyCollection
  Ref<Cell> state_update;  	// state_update : ^(HASH_UPDATE Account)
  Record() = default;
  Record(const td::BitArray<256>& _account_addr, Ref<CellSlice> _transactions, Ref<Cell> _state_update) : account_addr(_account_addr), transactions(std::move(_transactions)), state_update(std::move(_state_update)) {}
};

extern const AccountBlock t_AccountBlock;

//
// headers for type `ShardAccountBlocks`
//

struct ShardAccountBlocks final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardAccountBlocks type_class;
    Ref<CellSlice> x;  	// HashmapAugE 256 AccountBlock CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardAccountBlocks";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardAccountBlocks t_ShardAccountBlocks;

//
// headers for type `TrStoragePhase`
//

struct TrStoragePhase final : TLB_Complex {
  enum { tr_phase_storage };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_tr_phase_storage(vm::CellSlice& cs, Ref<CellSlice>& storage_fees_collected, Ref<CellSlice>& storage_fees_due, char& status_change) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_tr_phase_storage(Ref<vm::Cell> cell_ref, Ref<CellSlice>& storage_fees_collected, Ref<CellSlice>& storage_fees_due, char& status_change) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_tr_phase_storage(vm::CellBuilder& cb, Ref<CellSlice> storage_fees_collected, Ref<CellSlice> storage_fees_due, char status_change) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_tr_phase_storage(Ref<vm::Cell>& cell_ref, Ref<CellSlice> storage_fees_collected, Ref<CellSlice> storage_fees_due, char status_change) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrStoragePhase";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct TrStoragePhase::Record {
  typedef TrStoragePhase type_class;
  Ref<CellSlice> storage_fees_collected;  	// storage_fees_collected : Grams
  Ref<CellSlice> storage_fees_due;  	// storage_fees_due : Maybe Grams
  char status_change;  	// status_change : AccStatusChange
  Record() = default;
  Record(Ref<CellSlice> _storage_fees_collected, Ref<CellSlice> _storage_fees_due, char _status_change) : storage_fees_collected(std::move(_storage_fees_collected)), storage_fees_due(std::move(_storage_fees_due)), status_change(_status_change) {}
};

extern const TrStoragePhase t_TrStoragePhase;

//
// headers for type `AccStatusChange`
//

struct AccStatusChange final : TLB_Complex {
  enum { acst_unchanged, acst_frozen, acst_deleted };
  static constexpr char cons_len[3] = { 1, 2, 2 };
  static constexpr unsigned char cons_tag[3] = { 0, 2, 3 };
  struct Record_acst_unchanged {
    typedef AccStatusChange type_class;
  };
  struct Record_acst_frozen {
    typedef AccStatusChange type_class;
  };
  struct Record_acst_deleted {
    typedef AccStatusChange type_class;
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record_acst_unchanged& data) const;
  bool unpack_acst_unchanged(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acst_unchanged& data) const;
  bool cell_unpack_acst_unchanged(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acst_unchanged& data) const;
  bool pack_acst_unchanged(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acst_unchanged& data) const;
  bool cell_pack_acst_unchanged(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_acst_frozen& data) const;
  bool unpack_acst_frozen(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acst_frozen& data) const;
  bool cell_unpack_acst_frozen(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acst_frozen& data) const;
  bool pack_acst_frozen(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acst_frozen& data) const;
  bool cell_pack_acst_frozen(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_acst_deleted& data) const;
  bool unpack_acst_deleted(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_acst_deleted& data) const;
  bool cell_unpack_acst_deleted(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_acst_deleted& data) const;
  bool pack_acst_deleted(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_acst_deleted& data) const;
  bool cell_pack_acst_deleted(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "AccStatusChange";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect_ext(2, 13);
  }
};

extern const AccStatusChange t_AccStatusChange;

//
// headers for type `TrCreditPhase`
//

struct TrCreditPhase final : TLB_Complex {
  enum { tr_phase_credit };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef TrCreditPhase type_class;
    Ref<CellSlice> due_fees_collected;  	// due_fees_collected : Maybe Grams
    Ref<CellSlice> credit;  	// credit : CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _due_fees_collected, Ref<CellSlice> _credit) : due_fees_collected(std::move(_due_fees_collected)), credit(std::move(_credit)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_tr_phase_credit(vm::CellSlice& cs, Ref<CellSlice>& due_fees_collected, Ref<CellSlice>& credit) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_tr_phase_credit(Ref<vm::Cell> cell_ref, Ref<CellSlice>& due_fees_collected, Ref<CellSlice>& credit) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_tr_phase_credit(vm::CellBuilder& cb, Ref<CellSlice> due_fees_collected, Ref<CellSlice> credit) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_tr_phase_credit(Ref<vm::Cell>& cell_ref, Ref<CellSlice> due_fees_collected, Ref<CellSlice> credit) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrCreditPhase";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const TrCreditPhase t_TrCreditPhase;

//
// headers for auxiliary type `TrComputePhase_aux`
//

struct TrComputePhase_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrComputePhase_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct TrComputePhase_aux::Record {
  typedef TrComputePhase_aux type_class;
  Ref<CellSlice> gas_used;  	// gas_used : VarUInteger 7
  Ref<CellSlice> gas_limit;  	// gas_limit : VarUInteger 7
  Ref<CellSlice> gas_credit;  	// gas_credit : Maybe (VarUInteger 3)
  int mode;  	// mode : int8
  int exit_code;  	// exit_code : int32
  Ref<CellSlice> exit_arg;  	// exit_arg : Maybe int32
  unsigned vm_steps;  	// vm_steps : uint32
  td::BitArray<256> vm_init_state_hash;  	// vm_init_state_hash : bits256
  td::BitArray<256> vm_final_state_hash;  	// vm_final_state_hash : bits256
  Record() = default;
  Record(Ref<CellSlice> _gas_used, Ref<CellSlice> _gas_limit, Ref<CellSlice> _gas_credit, int _mode, int _exit_code, Ref<CellSlice> _exit_arg, unsigned _vm_steps, const td::BitArray<256>& _vm_init_state_hash, const td::BitArray<256>& _vm_final_state_hash) : gas_used(std::move(_gas_used)), gas_limit(std::move(_gas_limit)), gas_credit(std::move(_gas_credit)), mode(_mode), exit_code(_exit_code), exit_arg(std::move(_exit_arg)), vm_steps(_vm_steps), vm_init_state_hash(_vm_init_state_hash), vm_final_state_hash(_vm_final_state_hash) {}
};

extern const TrComputePhase_aux t_TrComputePhase_aux;

//
// headers for type `TrComputePhase`
//

struct TrComputePhase final : TLB_Complex {
  enum { tr_phase_compute_skipped, tr_phase_compute_vm };
  static constexpr int cons_len_exact = 1;
  struct Record_tr_phase_compute_skipped {
    typedef TrComputePhase type_class;
    char reason;  	// reason : ComputeSkipReason
    Record_tr_phase_compute_skipped() = default;
    Record_tr_phase_compute_skipped(char _reason) : reason(_reason) {}
  };
  struct Record_tr_phase_compute_vm;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_tr_phase_compute_skipped& data) const;
  bool unpack_tr_phase_compute_skipped(vm::CellSlice& cs, char& reason) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_tr_phase_compute_skipped& data) const;
  bool cell_unpack_tr_phase_compute_skipped(Ref<vm::Cell> cell_ref, char& reason) const;
  bool pack(vm::CellBuilder& cb, const Record_tr_phase_compute_skipped& data) const;
  bool pack_tr_phase_compute_skipped(vm::CellBuilder& cb, char reason) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_tr_phase_compute_skipped& data) const;
  bool cell_pack_tr_phase_compute_skipped(Ref<vm::Cell>& cell_ref, char reason) const;
  bool unpack(vm::CellSlice& cs, Record_tr_phase_compute_vm& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_tr_phase_compute_vm& data) const;
  bool pack(vm::CellBuilder& cb, const Record_tr_phase_compute_vm& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_tr_phase_compute_vm& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrComputePhase";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct TrComputePhase::Record_tr_phase_compute_vm {
  typedef TrComputePhase type_class;
  bool success;  	// success : Bool
  bool msg_state_used;  	// msg_state_used : Bool
  bool account_activated;  	// account_activated : Bool
  Ref<CellSlice> gas_fees;  	// gas_fees : Grams
  TrComputePhase_aux::Record r1;  	// ^[$_ gas_used:(VarUInteger 7) gas_limit:(VarUInteger 7) gas_credit:(Maybe (VarUInteger 3)) mode:int8 exit_code:int32 exit_arg:(Maybe int32) vm_steps:uint32 vm_init_state_hash:bits256 vm_final_state_hash:bits256 ]
  Record_tr_phase_compute_vm() = default;
  Record_tr_phase_compute_vm(bool _success, bool _msg_state_used, bool _account_activated, Ref<CellSlice> _gas_fees, const TrComputePhase_aux::Record& _r1) : success(_success), msg_state_used(_msg_state_used), account_activated(_account_activated), gas_fees(std::move(_gas_fees)), r1(_r1) {}
};

extern const TrComputePhase t_TrComputePhase;

//
// headers for type `ComputeSkipReason`
//

struct ComputeSkipReason final : TLB_Complex {
  enum { cskip_no_state, cskip_bad_state, cskip_no_gas };
  static constexpr int cons_len_exact = 2;
  struct Record_cskip_no_state {
    typedef ComputeSkipReason type_class;
  };
  struct Record_cskip_bad_state {
    typedef ComputeSkipReason type_class;
  };
  struct Record_cskip_no_gas {
    typedef ComputeSkipReason type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 2;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(2);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record_cskip_no_state& data) const;
  bool unpack_cskip_no_state(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cskip_no_state& data) const;
  bool cell_unpack_cskip_no_state(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cskip_no_state& data) const;
  bool pack_cskip_no_state(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cskip_no_state& data) const;
  bool cell_pack_cskip_no_state(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cskip_bad_state& data) const;
  bool unpack_cskip_bad_state(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cskip_bad_state& data) const;
  bool cell_unpack_cskip_bad_state(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cskip_bad_state& data) const;
  bool pack_cskip_bad_state(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cskip_bad_state& data) const;
  bool cell_pack_cskip_bad_state(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cskip_no_gas& data) const;
  bool unpack_cskip_no_gas(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cskip_no_gas& data) const;
  bool cell_unpack_cskip_no_gas(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cskip_no_gas& data) const;
  bool pack_cskip_no_gas(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cskip_no_gas& data) const;
  bool cell_pack_cskip_no_gas(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ComputeSkipReason";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 7);
  }
};

extern const ComputeSkipReason t_ComputeSkipReason;

//
// headers for type `TrActionPhase`
//

struct TrActionPhase final : TLB_Complex {
  enum { tr_phase_action };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrActionPhase";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct TrActionPhase::Record {
  typedef TrActionPhase type_class;
  bool success;  	// success : Bool
  bool valid;  	// valid : Bool
  bool no_funds;  	// no_funds : Bool
  char status_change;  	// status_change : AccStatusChange
  Ref<CellSlice> total_fwd_fees;  	// total_fwd_fees : Maybe Grams
  Ref<CellSlice> total_action_fees;  	// total_action_fees : Maybe Grams
  int result_code;  	// result_code : int32
  Ref<CellSlice> result_arg;  	// result_arg : Maybe int32
  int tot_actions;  	// tot_actions : uint16
  int spec_actions;  	// spec_actions : uint16
  int skipped_actions;  	// skipped_actions : uint16
  int msgs_created;  	// msgs_created : uint16
  td::BitArray<256> action_list_hash;  	// action_list_hash : bits256
  Ref<CellSlice> tot_msg_size;  	// tot_msg_size : StorageUsedShort
  Record() = default;
  Record(bool _success, bool _valid, bool _no_funds, char _status_change, Ref<CellSlice> _total_fwd_fees, Ref<CellSlice> _total_action_fees, int _result_code, Ref<CellSlice> _result_arg, int _tot_actions, int _spec_actions, int _skipped_actions, int _msgs_created, const td::BitArray<256>& _action_list_hash, Ref<CellSlice> _tot_msg_size) : success(_success), valid(_valid), no_funds(_no_funds), status_change(_status_change), total_fwd_fees(std::move(_total_fwd_fees)), total_action_fees(std::move(_total_action_fees)), result_code(_result_code), result_arg(std::move(_result_arg)), tot_actions(_tot_actions), spec_actions(_spec_actions), skipped_actions(_skipped_actions), msgs_created(_msgs_created), action_list_hash(_action_list_hash), tot_msg_size(std::move(_tot_msg_size)) {}
};

extern const TrActionPhase t_TrActionPhase;

//
// headers for type `TrBouncePhase`
//

struct TrBouncePhase final : TLB_Complex {
  enum { tr_phase_bounce_negfunds, tr_phase_bounce_nofunds, tr_phase_bounce_ok };
  static constexpr char cons_len[3] = { 2, 2, 1 };
  static constexpr unsigned char cons_tag[3] = { 0, 1, 1 };
  struct Record_tr_phase_bounce_negfunds {
    typedef TrBouncePhase type_class;
  };
  struct Record_tr_phase_bounce_nofunds {
    typedef TrBouncePhase type_class;
    Ref<CellSlice> msg_size;  	// msg_size : StorageUsedShort
    Ref<CellSlice> req_fwd_fees;  	// req_fwd_fees : Grams
    Record_tr_phase_bounce_nofunds() = default;
    Record_tr_phase_bounce_nofunds(Ref<CellSlice> _msg_size, Ref<CellSlice> _req_fwd_fees) : msg_size(std::move(_msg_size)), req_fwd_fees(std::move(_req_fwd_fees)) {}
  };
  struct Record_tr_phase_bounce_ok;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_tr_phase_bounce_negfunds& data) const;
  bool unpack_tr_phase_bounce_negfunds(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_tr_phase_bounce_negfunds& data) const;
  bool cell_unpack_tr_phase_bounce_negfunds(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_tr_phase_bounce_negfunds& data) const;
  bool pack_tr_phase_bounce_negfunds(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_tr_phase_bounce_negfunds& data) const;
  bool cell_pack_tr_phase_bounce_negfunds(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_tr_phase_bounce_nofunds& data) const;
  bool unpack_tr_phase_bounce_nofunds(vm::CellSlice& cs, Ref<CellSlice>& msg_size, Ref<CellSlice>& req_fwd_fees) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_tr_phase_bounce_nofunds& data) const;
  bool cell_unpack_tr_phase_bounce_nofunds(Ref<vm::Cell> cell_ref, Ref<CellSlice>& msg_size, Ref<CellSlice>& req_fwd_fees) const;
  bool pack(vm::CellBuilder& cb, const Record_tr_phase_bounce_nofunds& data) const;
  bool pack_tr_phase_bounce_nofunds(vm::CellBuilder& cb, Ref<CellSlice> msg_size, Ref<CellSlice> req_fwd_fees) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_tr_phase_bounce_nofunds& data) const;
  bool cell_pack_tr_phase_bounce_nofunds(Ref<vm::Cell>& cell_ref, Ref<CellSlice> msg_size, Ref<CellSlice> req_fwd_fees) const;
  bool unpack(vm::CellSlice& cs, Record_tr_phase_bounce_ok& data) const;
  bool unpack_tr_phase_bounce_ok(vm::CellSlice& cs, Ref<CellSlice>& msg_size, Ref<CellSlice>& msg_fees, Ref<CellSlice>& fwd_fees) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_tr_phase_bounce_ok& data) const;
  bool cell_unpack_tr_phase_bounce_ok(Ref<vm::Cell> cell_ref, Ref<CellSlice>& msg_size, Ref<CellSlice>& msg_fees, Ref<CellSlice>& fwd_fees) const;
  bool pack(vm::CellBuilder& cb, const Record_tr_phase_bounce_ok& data) const;
  bool pack_tr_phase_bounce_ok(vm::CellBuilder& cb, Ref<CellSlice> msg_size, Ref<CellSlice> msg_fees, Ref<CellSlice> fwd_fees) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_tr_phase_bounce_ok& data) const;
  bool cell_pack_tr_phase_bounce_ok(Ref<vm::Cell>& cell_ref, Ref<CellSlice> msg_size, Ref<CellSlice> msg_fees, Ref<CellSlice> fwd_fees) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TrBouncePhase";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect_ext(2, 7);
  }
};

struct TrBouncePhase::Record_tr_phase_bounce_ok {
  typedef TrBouncePhase type_class;
  Ref<CellSlice> msg_size;  	// msg_size : StorageUsedShort
  Ref<CellSlice> msg_fees;  	// msg_fees : Grams
  Ref<CellSlice> fwd_fees;  	// fwd_fees : Grams
  Record_tr_phase_bounce_ok() = default;
  Record_tr_phase_bounce_ok(Ref<CellSlice> _msg_size, Ref<CellSlice> _msg_fees, Ref<CellSlice> _fwd_fees) : msg_size(std::move(_msg_size)), msg_fees(std::move(_msg_fees)), fwd_fees(std::move(_fwd_fees)) {}
};

extern const TrBouncePhase t_TrBouncePhase;

//
// headers for type `SplitMergeInfo`
//

struct SplitMergeInfo final : TLB_Complex {
  enum { split_merge_info };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 524;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(524);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(524);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SplitMergeInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct SplitMergeInfo::Record {
  typedef SplitMergeInfo type_class;
  int cur_shard_pfx_len;  	// cur_shard_pfx_len : ## 6
  int acc_split_depth;  	// acc_split_depth : ## 6
  td::BitArray<256> this_addr;  	// this_addr : bits256
  td::BitArray<256> sibling_addr;  	// sibling_addr : bits256
  Record() = default;
  Record(int _cur_shard_pfx_len, int _acc_split_depth, const td::BitArray<256>& _this_addr, const td::BitArray<256>& _sibling_addr) : cur_shard_pfx_len(_cur_shard_pfx_len), acc_split_depth(_acc_split_depth), this_addr(_this_addr), sibling_addr(_sibling_addr) {}
};

extern const SplitMergeInfo t_SplitMergeInfo;

//
// headers for type `TransactionDescr`
//

struct TransactionDescr final : TLB_Complex {
  enum { trans_ord, trans_storage, trans_tick_tock, trans_split_prepare, trans_split_install, trans_merge_prepare, trans_merge_install };
  static constexpr char cons_len[7] = { 4, 4, 3, 4, 4, 4, 4 };
  static constexpr unsigned char cons_tag[7] = { 0, 1, 1, 4, 5, 6, 7 };
  struct Record_trans_ord;
  struct Record_trans_storage {
    typedef TransactionDescr type_class;
    Ref<CellSlice> storage_ph;  	// storage_ph : TrStoragePhase
    Record_trans_storage() = default;
    Record_trans_storage(Ref<CellSlice> _storage_ph) : storage_ph(std::move(_storage_ph)) {}
  };
  struct Record_trans_tick_tock;
  struct Record_trans_split_prepare;
  struct Record_trans_split_install;
  struct Record_trans_merge_prepare;
  struct Record_trans_merge_install;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_trans_ord& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_ord& data) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_ord& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_ord& data) const;
  bool unpack(vm::CellSlice& cs, Record_trans_storage& data) const;
  bool unpack_trans_storage(vm::CellSlice& cs, Ref<CellSlice>& storage_ph) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_storage& data) const;
  bool cell_unpack_trans_storage(Ref<vm::Cell> cell_ref, Ref<CellSlice>& storage_ph) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_storage& data) const;
  bool pack_trans_storage(vm::CellBuilder& cb, Ref<CellSlice> storage_ph) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_storage& data) const;
  bool cell_pack_trans_storage(Ref<vm::Cell>& cell_ref, Ref<CellSlice> storage_ph) const;
  bool unpack(vm::CellSlice& cs, Record_trans_tick_tock& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_tick_tock& data) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_tick_tock& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_tick_tock& data) const;
  bool unpack(vm::CellSlice& cs, Record_trans_split_prepare& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_split_prepare& data) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_split_prepare& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_split_prepare& data) const;
  bool unpack(vm::CellSlice& cs, Record_trans_split_install& data) const;
  bool unpack_trans_split_install(vm::CellSlice& cs, Ref<CellSlice>& split_info, Ref<Cell>& prepare_transaction, bool& installed) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_split_install& data) const;
  bool cell_unpack_trans_split_install(Ref<vm::Cell> cell_ref, Ref<CellSlice>& split_info, Ref<Cell>& prepare_transaction, bool& installed) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_split_install& data) const;
  bool pack_trans_split_install(vm::CellBuilder& cb, Ref<CellSlice> split_info, Ref<Cell> prepare_transaction, bool installed) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_split_install& data) const;
  bool cell_pack_trans_split_install(Ref<vm::Cell>& cell_ref, Ref<CellSlice> split_info, Ref<Cell> prepare_transaction, bool installed) const;
  bool unpack(vm::CellSlice& cs, Record_trans_merge_prepare& data) const;
  bool unpack_trans_merge_prepare(vm::CellSlice& cs, Ref<CellSlice>& split_info, Ref<CellSlice>& storage_ph, bool& aborted) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_merge_prepare& data) const;
  bool cell_unpack_trans_merge_prepare(Ref<vm::Cell> cell_ref, Ref<CellSlice>& split_info, Ref<CellSlice>& storage_ph, bool& aborted) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_merge_prepare& data) const;
  bool pack_trans_merge_prepare(vm::CellBuilder& cb, Ref<CellSlice> split_info, Ref<CellSlice> storage_ph, bool aborted) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_merge_prepare& data) const;
  bool cell_pack_trans_merge_prepare(Ref<vm::Cell>& cell_ref, Ref<CellSlice> split_info, Ref<CellSlice> storage_ph, bool aborted) const;
  bool unpack(vm::CellSlice& cs, Record_trans_merge_install& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_trans_merge_install& data) const;
  bool pack(vm::CellBuilder& cb, const Record_trans_merge_install& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_trans_merge_install& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TransactionDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(4, 0xf7);
  }
};

struct TransactionDescr::Record_trans_ord {
  typedef TransactionDescr type_class;
  bool credit_first;  	// credit_first : Bool
  Ref<CellSlice> storage_ph;  	// storage_ph : Maybe TrStoragePhase
  Ref<CellSlice> credit_ph;  	// credit_ph : Maybe TrCreditPhase
  Ref<CellSlice> compute_ph;  	// compute_ph : TrComputePhase
  Ref<CellSlice> action;  	// action : Maybe ^TrActionPhase
  bool aborted;  	// aborted : Bool
  Ref<CellSlice> bounce;  	// bounce : Maybe TrBouncePhase
  bool destroyed;  	// destroyed : Bool
  Record_trans_ord() = default;
  Record_trans_ord(bool _credit_first, Ref<CellSlice> _storage_ph, Ref<CellSlice> _credit_ph, Ref<CellSlice> _compute_ph, Ref<CellSlice> _action, bool _aborted, Ref<CellSlice> _bounce, bool _destroyed) : credit_first(_credit_first), storage_ph(std::move(_storage_ph)), credit_ph(std::move(_credit_ph)), compute_ph(std::move(_compute_ph)), action(std::move(_action)), aborted(_aborted), bounce(std::move(_bounce)), destroyed(_destroyed) {}
};

struct TransactionDescr::Record_trans_tick_tock {
  typedef TransactionDescr type_class;
  bool is_tock;  	// is_tock : Bool
  Ref<CellSlice> storage_ph;  	// storage_ph : TrStoragePhase
  Ref<CellSlice> compute_ph;  	// compute_ph : TrComputePhase
  Ref<CellSlice> action;  	// action : Maybe ^TrActionPhase
  bool aborted;  	// aborted : Bool
  bool destroyed;  	// destroyed : Bool
  Record_trans_tick_tock() = default;
  Record_trans_tick_tock(bool _is_tock, Ref<CellSlice> _storage_ph, Ref<CellSlice> _compute_ph, Ref<CellSlice> _action, bool _aborted, bool _destroyed) : is_tock(_is_tock), storage_ph(std::move(_storage_ph)), compute_ph(std::move(_compute_ph)), action(std::move(_action)), aborted(_aborted), destroyed(_destroyed) {}
};

struct TransactionDescr::Record_trans_split_prepare {
  typedef TransactionDescr type_class;
  Ref<CellSlice> split_info;  	// split_info : SplitMergeInfo
  Ref<CellSlice> storage_ph;  	// storage_ph : Maybe TrStoragePhase
  Ref<CellSlice> compute_ph;  	// compute_ph : TrComputePhase
  Ref<CellSlice> action;  	// action : Maybe ^TrActionPhase
  bool aborted;  	// aborted : Bool
  bool destroyed;  	// destroyed : Bool
  Record_trans_split_prepare() = default;
  Record_trans_split_prepare(Ref<CellSlice> _split_info, Ref<CellSlice> _storage_ph, Ref<CellSlice> _compute_ph, Ref<CellSlice> _action, bool _aborted, bool _destroyed) : split_info(std::move(_split_info)), storage_ph(std::move(_storage_ph)), compute_ph(std::move(_compute_ph)), action(std::move(_action)), aborted(_aborted), destroyed(_destroyed) {}
};

struct TransactionDescr::Record_trans_split_install {
  typedef TransactionDescr type_class;
  Ref<CellSlice> split_info;  	// split_info : SplitMergeInfo
  Ref<Cell> prepare_transaction;  	// prepare_transaction : ^Transaction
  bool installed;  	// installed : Bool
  Record_trans_split_install() = default;
  Record_trans_split_install(Ref<CellSlice> _split_info, Ref<Cell> _prepare_transaction, bool _installed) : split_info(std::move(_split_info)), prepare_transaction(std::move(_prepare_transaction)), installed(_installed) {}
};

struct TransactionDescr::Record_trans_merge_prepare {
  typedef TransactionDescr type_class;
  Ref<CellSlice> split_info;  	// split_info : SplitMergeInfo
  Ref<CellSlice> storage_ph;  	// storage_ph : TrStoragePhase
  bool aborted;  	// aborted : Bool
  Record_trans_merge_prepare() = default;
  Record_trans_merge_prepare(Ref<CellSlice> _split_info, Ref<CellSlice> _storage_ph, bool _aborted) : split_info(std::move(_split_info)), storage_ph(std::move(_storage_ph)), aborted(_aborted) {}
};

struct TransactionDescr::Record_trans_merge_install {
  typedef TransactionDescr type_class;
  Ref<CellSlice> split_info;  	// split_info : SplitMergeInfo
  Ref<Cell> prepare_transaction;  	// prepare_transaction : ^Transaction
  Ref<CellSlice> storage_ph;  	// storage_ph : Maybe TrStoragePhase
  Ref<CellSlice> credit_ph;  	// credit_ph : Maybe TrCreditPhase
  Ref<CellSlice> compute_ph;  	// compute_ph : TrComputePhase
  Ref<CellSlice> action;  	// action : Maybe ^TrActionPhase
  bool aborted;  	// aborted : Bool
  bool destroyed;  	// destroyed : Bool
  Record_trans_merge_install() = default;
  Record_trans_merge_install(Ref<CellSlice> _split_info, Ref<Cell> _prepare_transaction, Ref<CellSlice> _storage_ph, Ref<CellSlice> _credit_ph, Ref<CellSlice> _compute_ph, Ref<CellSlice> _action, bool _aborted, bool _destroyed) : split_info(std::move(_split_info)), prepare_transaction(std::move(_prepare_transaction)), storage_ph(std::move(_storage_ph)), credit_ph(std::move(_credit_ph)), compute_ph(std::move(_compute_ph)), action(std::move(_action)), aborted(_aborted), destroyed(_destroyed) {}
};

extern const TransactionDescr t_TransactionDescr;

//
// headers for type `SmartContractInfo`
//

struct SmartContractInfo final : TLB_Complex {
  enum { smc_info };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x76ef1ea };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SmartContractInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct SmartContractInfo::Record {
  typedef SmartContractInfo type_class;
  int actions;  	// actions : uint16
  int msgs_sent;  	// msgs_sent : uint16
  unsigned unixtime;  	// unixtime : uint32
  unsigned long long block_lt;  	// block_lt : uint64
  unsigned long long trans_lt;  	// trans_lt : uint64
  td::BitArray<256> rand_seed;  	// rand_seed : bits256
  Ref<CellSlice> balance_remaining;  	// balance_remaining : CurrencyCollection
  Ref<CellSlice> myself;  	// myself : MsgAddressInt
  Record() = default;
  Record(int _actions, int _msgs_sent, unsigned _unixtime, unsigned long long _block_lt, unsigned long long _trans_lt, const td::BitArray<256>& _rand_seed, Ref<CellSlice> _balance_remaining, Ref<CellSlice> _myself) : actions(_actions), msgs_sent(_msgs_sent), unixtime(_unixtime), block_lt(_block_lt), trans_lt(_trans_lt), rand_seed(_rand_seed), balance_remaining(std::move(_balance_remaining)), myself(std::move(_myself)) {}
};

extern const SmartContractInfo t_SmartContractInfo;

//
// headers for type `OutList`
//

struct OutList final : TLB_Complex {
  enum { out_list, out_list_empty };
  static constexpr int cons_len_exact = 0;
  int m_;
  OutList(int m) : m_(m) {}
  struct Record_out_list_empty {
    typedef OutList type_class;
  };
  struct Record_out_list;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_out_list_empty& data) const;
  bool unpack_out_list_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_out_list_empty& data) const;
  bool cell_unpack_out_list_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_out_list_empty& data) const;
  bool pack_out_list_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_out_list_empty& data) const;
  bool cell_pack_out_list_empty(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_out_list& data) const;
  bool unpack_out_list(vm::CellSlice& cs, int& n, Ref<Cell>& prev, Ref<CellSlice>& action) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_out_list& data) const;
  bool cell_unpack_out_list(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& prev, Ref<CellSlice>& action) const;
  bool pack(vm::CellBuilder& cb, const Record_out_list& data) const;
  bool pack_out_list(vm::CellBuilder& cb, Ref<Cell> prev, Ref<CellSlice> action) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_out_list& data) const;
  bool cell_pack_out_list(Ref<vm::Cell>& cell_ref, Ref<Cell> prev, Ref<CellSlice> action) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(OutList " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct OutList::Record_out_list {
  typedef OutList type_class;
  int n;  	// n : #
  Ref<Cell> prev;  	// prev : ^(OutList n)
  Ref<CellSlice> action;  	// action : OutAction
  Record_out_list() = default;
  Record_out_list(Ref<Cell> _prev, Ref<CellSlice> _action) : n(-1), prev(std::move(_prev)), action(std::move(_action)) {}
};

//
// headers for type `LibRef`
//

struct LibRef final : TLB_Complex {
  enum { libref_hash, libref_ref };
  static constexpr int cons_len_exact = 1;
  struct Record_libref_hash {
    typedef LibRef type_class;
    td::BitArray<256> lib_hash;  	// lib_hash : bits256
    Record_libref_hash() = default;
    Record_libref_hash(const td::BitArray<256>& _lib_hash) : lib_hash(_lib_hash) {}
  };
  struct Record_libref_ref {
    typedef LibRef type_class;
    Ref<Cell> library;  	// library : ^Cell
    Record_libref_ref() = default;
    Record_libref_ref(Ref<Cell> _library) : library(std::move(_library)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_libref_hash& data) const;
  bool unpack_libref_hash(vm::CellSlice& cs, td::BitArray<256>& lib_hash) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_libref_hash& data) const;
  bool cell_unpack_libref_hash(Ref<vm::Cell> cell_ref, td::BitArray<256>& lib_hash) const;
  bool pack(vm::CellBuilder& cb, const Record_libref_hash& data) const;
  bool pack_libref_hash(vm::CellBuilder& cb, td::BitArray<256> lib_hash) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_libref_hash& data) const;
  bool cell_pack_libref_hash(Ref<vm::Cell>& cell_ref, td::BitArray<256> lib_hash) const;
  bool unpack(vm::CellSlice& cs, Record_libref_ref& data) const;
  bool unpack_libref_ref(vm::CellSlice& cs, Ref<Cell>& library) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_libref_ref& data) const;
  bool cell_unpack_libref_ref(Ref<vm::Cell> cell_ref, Ref<Cell>& library) const;
  bool pack(vm::CellBuilder& cb, const Record_libref_ref& data) const;
  bool pack_libref_ref(vm::CellBuilder& cb, Ref<Cell> library) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_libref_ref& data) const;
  bool cell_pack_libref_ref(Ref<vm::Cell>& cell_ref, Ref<Cell> library) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "LibRef";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const LibRef t_LibRef;

//
// headers for type `OutAction`
//

struct OutAction final : TLB_Complex {
  enum { action_send_msg, action_change_library, action_reserve_currency, action_set_code };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[4] = { 0xec3c86d, 0x26fa1dd4, 0x36e6b809, 0xad4de08eU };
  struct Record_action_send_msg {
    typedef OutAction type_class;
    int mode;  	// mode : ## 8
    Ref<Cell> out_msg;  	// out_msg : ^(MessageRelaxed Any)
    Record_action_send_msg() = default;
    Record_action_send_msg(int _mode, Ref<Cell> _out_msg) : mode(_mode), out_msg(std::move(_out_msg)) {}
  };
  struct Record_action_set_code {
    typedef OutAction type_class;
    Ref<Cell> new_code;  	// new_code : ^Cell
    Record_action_set_code() = default;
    Record_action_set_code(Ref<Cell> _new_code) : new_code(std::move(_new_code)) {}
  };
  struct Record_action_reserve_currency {
    typedef OutAction type_class;
    int mode;  	// mode : ## 8
    Ref<CellSlice> currency;  	// currency : CurrencyCollection
    Record_action_reserve_currency() = default;
    Record_action_reserve_currency(int _mode, Ref<CellSlice> _currency) : mode(_mode), currency(std::move(_currency)) {}
  };
  struct Record_action_change_library {
    typedef OutAction type_class;
    int mode;  	// mode : ## 7
    Ref<CellSlice> libref;  	// libref : LibRef
    Record_action_change_library() = default;
    Record_action_change_library(int _mode, Ref<CellSlice> _libref) : mode(_mode), libref(std::move(_libref)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_action_send_msg& data) const;
  bool unpack_action_send_msg(vm::CellSlice& cs, int& mode, Ref<Cell>& out_msg) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_action_send_msg& data) const;
  bool cell_unpack_action_send_msg(Ref<vm::Cell> cell_ref, int& mode, Ref<Cell>& out_msg) const;
  bool pack(vm::CellBuilder& cb, const Record_action_send_msg& data) const;
  bool pack_action_send_msg(vm::CellBuilder& cb, int mode, Ref<Cell> out_msg) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_action_send_msg& data) const;
  bool cell_pack_action_send_msg(Ref<vm::Cell>& cell_ref, int mode, Ref<Cell> out_msg) const;
  bool unpack(vm::CellSlice& cs, Record_action_set_code& data) const;
  bool unpack_action_set_code(vm::CellSlice& cs, Ref<Cell>& new_code) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_action_set_code& data) const;
  bool cell_unpack_action_set_code(Ref<vm::Cell> cell_ref, Ref<Cell>& new_code) const;
  bool pack(vm::CellBuilder& cb, const Record_action_set_code& data) const;
  bool pack_action_set_code(vm::CellBuilder& cb, Ref<Cell> new_code) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_action_set_code& data) const;
  bool cell_pack_action_set_code(Ref<vm::Cell>& cell_ref, Ref<Cell> new_code) const;
  bool unpack(vm::CellSlice& cs, Record_action_reserve_currency& data) const;
  bool unpack_action_reserve_currency(vm::CellSlice& cs, int& mode, Ref<CellSlice>& currency) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_action_reserve_currency& data) const;
  bool cell_unpack_action_reserve_currency(Ref<vm::Cell> cell_ref, int& mode, Ref<CellSlice>& currency) const;
  bool pack(vm::CellBuilder& cb, const Record_action_reserve_currency& data) const;
  bool pack_action_reserve_currency(vm::CellBuilder& cb, int mode, Ref<CellSlice> currency) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_action_reserve_currency& data) const;
  bool cell_pack_action_reserve_currency(Ref<vm::Cell>& cell_ref, int mode, Ref<CellSlice> currency) const;
  bool unpack(vm::CellSlice& cs, Record_action_change_library& data) const;
  bool unpack_action_change_library(vm::CellSlice& cs, int& mode, Ref<CellSlice>& libref) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_action_change_library& data) const;
  bool cell_unpack_action_change_library(Ref<vm::Cell> cell_ref, int& mode, Ref<CellSlice>& libref) const;
  bool pack(vm::CellBuilder& cb, const Record_action_change_library& data) const;
  bool pack_action_change_library(vm::CellBuilder& cb, int mode, Ref<CellSlice> libref) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_action_change_library& data) const;
  bool cell_pack_action_change_library(Ref<vm::Cell>& cell_ref, int mode, Ref<CellSlice> libref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutAction";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(4, 0x40d);
  }
};

extern const OutAction t_OutAction;

//
// headers for type `OutListNode`
//

struct OutListNode final : TLB_Complex {
  enum { out_list_node };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef OutListNode type_class;
    Ref<Cell> prev;  	// prev : ^Cell
    Ref<CellSlice> action;  	// action : OutAction
    Record() = default;
    Record(Ref<Cell> _prev, Ref<CellSlice> _action) : prev(std::move(_prev)), action(std::move(_action)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_out_list_node(vm::CellSlice& cs, Ref<Cell>& prev, Ref<CellSlice>& action) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_out_list_node(Ref<vm::Cell> cell_ref, Ref<Cell>& prev, Ref<CellSlice>& action) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_out_list_node(vm::CellBuilder& cb, Ref<Cell> prev, Ref<CellSlice> action) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_out_list_node(Ref<vm::Cell>& cell_ref, Ref<Cell> prev, Ref<CellSlice> action) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OutListNode";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const OutListNode t_OutListNode;

//
// headers for type `ShardIdent`
//

struct ShardIdent final : TLB_Complex {
  enum { shard_ident };
  static constexpr int cons_len_exact = 2;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 104;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(104);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_shard_ident(vm::CellSlice& cs, int& shard_pfx_bits, int& workchain_id, unsigned long long& shard_prefix) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_shard_ident(Ref<vm::Cell> cell_ref, int& shard_pfx_bits, int& workchain_id, unsigned long long& shard_prefix) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_shard_ident(vm::CellBuilder& cb, int shard_pfx_bits, int workchain_id, unsigned long long shard_prefix) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_shard_ident(Ref<vm::Cell>& cell_ref, int shard_pfx_bits, int workchain_id, unsigned long long shard_prefix) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardIdent";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ShardIdent::Record {
  typedef ShardIdent type_class;
  int shard_pfx_bits;  	// shard_pfx_bits : #<= 60
  int workchain_id;  	// workchain_id : int32
  unsigned long long shard_prefix;  	// shard_prefix : uint64
  Record() = default;
  Record(int _shard_pfx_bits, int _workchain_id, unsigned long long _shard_prefix) : shard_pfx_bits(_shard_pfx_bits), workchain_id(_workchain_id), shard_prefix(_shard_prefix) {}
};

extern const ShardIdent t_ShardIdent;

//
// headers for type `ExtBlkRef`
//

struct ExtBlkRef final : TLB_Complex {
  enum { ext_blk_ref };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 608;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(608);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(608);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ExtBlkRef";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ExtBlkRef::Record {
  typedef ExtBlkRef type_class;
  unsigned long long end_lt;  	// end_lt : uint64
  unsigned seq_no;  	// seq_no : uint32
  td::BitArray<256> root_hash;  	// root_hash : bits256
  td::BitArray<256> file_hash;  	// file_hash : bits256
  Record() = default;
  Record(unsigned long long _end_lt, unsigned _seq_no, const td::BitArray<256>& _root_hash, const td::BitArray<256>& _file_hash) : end_lt(_end_lt), seq_no(_seq_no), root_hash(_root_hash), file_hash(_file_hash) {}
};

extern const ExtBlkRef t_ExtBlkRef;

//
// headers for type `BlockIdExt`
//

struct BlockIdExt final : TLB_Complex {
  enum { block_id_ext };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 648;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(648);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockIdExt";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockIdExt::Record {
  typedef BlockIdExt type_class;
  Ref<CellSlice> shard_id;  	// shard_id : ShardIdent
  unsigned seq_no;  	// seq_no : uint32
  td::BitArray<256> root_hash;  	// root_hash : bits256
  td::BitArray<256> file_hash;  	// file_hash : bits256
  Record() = default;
  Record(Ref<CellSlice> _shard_id, unsigned _seq_no, const td::BitArray<256>& _root_hash, const td::BitArray<256>& _file_hash) : shard_id(std::move(_shard_id)), seq_no(_seq_no), root_hash(_root_hash), file_hash(_file_hash) {}
};

extern const BlockIdExt t_BlockIdExt;

//
// headers for type `BlkMasterInfo`
//

struct BlkMasterInfo final : TLB_Complex {
  enum { master_info };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef BlkMasterInfo type_class;
    Ref<CellSlice> master;  	// master : ExtBlkRef
    Record() = default;
    Record(Ref<CellSlice> _master) : master(std::move(_master)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 608;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(608);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(608);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_master_info(vm::CellSlice& cs, Ref<CellSlice>& master) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_master_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& master) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_master_info(vm::CellBuilder& cb, Ref<CellSlice> master) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_master_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> master) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlkMasterInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const BlkMasterInfo t_BlkMasterInfo;

//
// headers for auxiliary type `ShardStateUnsplit_aux`
//

struct ShardStateUnsplit_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardStateUnsplit_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ShardStateUnsplit_aux::Record {
  typedef ShardStateUnsplit_aux type_class;
  unsigned long long overload_history;  	// overload_history : uint64
  unsigned long long underload_history;  	// underload_history : uint64
  Ref<CellSlice> total_balance;  	// total_balance : CurrencyCollection
  Ref<CellSlice> total_validator_fees;  	// total_validator_fees : CurrencyCollection
  Ref<CellSlice> libraries;  	// libraries : HashmapE 256 LibDescr
  Ref<CellSlice> master_ref;  	// master_ref : Maybe BlkMasterInfo
  Record() = default;
  Record(unsigned long long _overload_history, unsigned long long _underload_history, Ref<CellSlice> _total_balance, Ref<CellSlice> _total_validator_fees, Ref<CellSlice> _libraries, Ref<CellSlice> _master_ref) : overload_history(_overload_history), underload_history(_underload_history), total_balance(std::move(_total_balance)), total_validator_fees(std::move(_total_validator_fees)), libraries(std::move(_libraries)), master_ref(std::move(_master_ref)) {}
};

extern const ShardStateUnsplit_aux t_ShardStateUnsplit_aux;

//
// headers for type `ShardStateUnsplit`
//

struct ShardStateUnsplit final : TLB_Complex {
  enum { shard_state };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x9023afe2U };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardStateUnsplit";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ShardStateUnsplit::Record {
  typedef ShardStateUnsplit type_class;
  int global_id;  	// global_id : int32
  Ref<CellSlice> shard_id;  	// shard_id : ShardIdent
  unsigned seq_no;  	// seq_no : uint32
  int vert_seq_no;  	// vert_seq_no : #
  unsigned gen_utime;  	// gen_utime : uint32
  unsigned long long gen_lt;  	// gen_lt : uint64
  unsigned min_ref_mc_seqno;  	// min_ref_mc_seqno : uint32
  Ref<Cell> out_msg_queue_info;  	// out_msg_queue_info : ^OutMsgQueueInfo
  bool before_split;  	// before_split : ## 1
  Ref<Cell> accounts;  	// accounts : ^ShardAccounts
  ShardStateUnsplit_aux::Record r1;  	// ^[$_ overload_history:uint64 underload_history:uint64 total_balance:CurrencyCollection total_validator_fees:CurrencyCollection libraries:(HashmapE 256 LibDescr) master_ref:(Maybe BlkMasterInfo) ]
  Ref<CellSlice> custom;  	// custom : Maybe ^McStateExtra
  Record() = default;
  Record(int _global_id, Ref<CellSlice> _shard_id, unsigned _seq_no, int _vert_seq_no, unsigned _gen_utime, unsigned long long _gen_lt, unsigned _min_ref_mc_seqno, Ref<Cell> _out_msg_queue_info, bool _before_split, Ref<Cell> _accounts, const ShardStateUnsplit_aux::Record& _r1, Ref<CellSlice> _custom) : global_id(_global_id), shard_id(std::move(_shard_id)), seq_no(_seq_no), vert_seq_no(_vert_seq_no), gen_utime(_gen_utime), gen_lt(_gen_lt), min_ref_mc_seqno(_min_ref_mc_seqno), out_msg_queue_info(std::move(_out_msg_queue_info)), before_split(_before_split), accounts(std::move(_accounts)), r1(_r1), custom(std::move(_custom)) {}
};

extern const ShardStateUnsplit t_ShardStateUnsplit;

//
// headers for type `ShardState`
//

struct ShardState final : TLB_Complex {
  enum { split_state, cons1 };
  static constexpr char cons_len[2] = { 32, 0 };
  static constexpr unsigned cons_tag[2] = { 0x5f327da5, 0 };
  struct Record_cons1 {
    typedef ShardState type_class;
    Ref<CellSlice> x;  	// ShardStateUnsplit
    Record_cons1() = default;
    Record_cons1(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_split_state {
    typedef ShardState type_class;
    Ref<Cell> left;  	// left : ^ShardStateUnsplit
    Ref<Cell> right;  	// right : ^ShardStateUnsplit
    Record_split_state() = default;
    Record_split_state(Ref<Cell> _left, Ref<Cell> _right) : left(std::move(_left)), right(std::move(_right)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cons1& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons1& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons1& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons1& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_split_state& data) const;
  bool unpack_split_state(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_split_state& data) const;
  bool cell_unpack_split_state(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right) const;
  bool pack(vm::CellBuilder& cb, const Record_split_state& data) const;
  bool pack_split_state(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_split_state& data) const;
  bool cell_pack_split_state(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardState";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const ShardState t_ShardState;

//
// headers for type `LibDescr`
//

struct LibDescr final : TLB_Complex {
  enum { shared_lib_descr };
  static constexpr int cons_len_exact = 2;
  struct Record {
    typedef LibDescr type_class;
    Ref<Cell> lib;  	// lib : ^Cell
    Ref<CellSlice> publishers;  	// publishers : Hashmap 256 True
    Record() = default;
    Record(Ref<Cell> _lib, Ref<CellSlice> _publishers) : lib(std::move(_lib)), publishers(std::move(_publishers)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_shared_lib_descr(vm::CellSlice& cs, Ref<Cell>& lib, Ref<CellSlice>& publishers) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_shared_lib_descr(Ref<vm::Cell> cell_ref, Ref<Cell>& lib, Ref<CellSlice>& publishers) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_shared_lib_descr(vm::CellBuilder& cb, Ref<Cell> lib, Ref<CellSlice> publishers) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_shared_lib_descr(Ref<vm::Cell>& cell_ref, Ref<Cell> lib, Ref<CellSlice> publishers) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "LibDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const LibDescr t_LibDescr;

//
// headers for type `BlockInfo`
//

struct BlockInfo final : TLB_Complex {
  enum { block_info };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x9bc7a987U };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockInfo::Record {
  typedef BlockInfo type_class;
  unsigned version;  	// version : uint32
  bool not_master;  	// not_master : ## 1
  bool after_merge;  	// after_merge : ## 1
  bool before_split;  	// before_split : ## 1
  bool after_split;  	// after_split : ## 1
  bool want_split;  	// want_split : Bool
  bool want_merge;  	// want_merge : Bool
  bool key_block;  	// key_block : Bool
  bool vert_seqno_incr;  	// vert_seqno_incr : ## 1
  int flags;  	// flags : ## 8
  int seq_no;  	// seq_no : #
  int vert_seq_no;  	// vert_seq_no : #
  Ref<CellSlice> shard;  	// shard : ShardIdent
  unsigned gen_utime;  	// gen_utime : uint32
  unsigned long long start_lt;  	// start_lt : uint64
  unsigned long long end_lt;  	// end_lt : uint64
  unsigned gen_validator_list_hash_short;  	// gen_validator_list_hash_short : uint32
  unsigned gen_catchain_seqno;  	// gen_catchain_seqno : uint32
  unsigned min_ref_mc_seqno;  	// min_ref_mc_seqno : uint32
  unsigned prev_key_block_seqno;  	// prev_key_block_seqno : uint32
  Ref<CellSlice> gen_software;  	// gen_software : flags.0?GlobalVersion
  Ref<Cell> master_ref;  	// master_ref : not_master?^BlkMasterInfo
  Ref<Cell> prev_ref;  	// prev_ref : ^(BlkPrevInfo after_merge)
  Ref<Cell> prev_vert_ref;  	// prev_vert_ref : vert_seqno_incr?^(BlkPrevInfo 0)
  Record() = default;
  Record(unsigned _version, bool _not_master, bool _after_merge, bool _before_split, bool _after_split, bool _want_split, bool _want_merge, bool _key_block, bool _vert_seqno_incr, int _flags, int _seq_no, int _vert_seq_no, Ref<CellSlice> _shard, unsigned _gen_utime, unsigned long long _start_lt, unsigned long long _end_lt, unsigned _gen_validator_list_hash_short, unsigned _gen_catchain_seqno, unsigned _min_ref_mc_seqno, unsigned _prev_key_block_seqno, Ref<CellSlice> _gen_software, Ref<Cell> _master_ref, Ref<Cell> _prev_ref, Ref<Cell> _prev_vert_ref) : version(_version), not_master(_not_master), after_merge(_after_merge), before_split(_before_split), after_split(_after_split), want_split(_want_split), want_merge(_want_merge), key_block(_key_block), vert_seqno_incr(_vert_seqno_incr), flags(_flags), seq_no(_seq_no), vert_seq_no(_vert_seq_no), shard(std::move(_shard)), gen_utime(_gen_utime), start_lt(_start_lt), end_lt(_end_lt), gen_validator_list_hash_short(_gen_validator_list_hash_short), gen_catchain_seqno(_gen_catchain_seqno), min_ref_mc_seqno(_min_ref_mc_seqno), prev_key_block_seqno(_prev_key_block_seqno), gen_software(std::move(_gen_software)), master_ref(std::move(_master_ref)), prev_ref(std::move(_prev_ref)), prev_vert_ref(std::move(_prev_vert_ref)) {}
};

extern const BlockInfo t_BlockInfo;

//
// headers for type `BlkPrevInfo`
//

struct BlkPrevInfo final : TLB_Complex {
  enum { prev_blk_info, prev_blks_info };
  static constexpr int cons_len_exact = 0;
  int m_;
  BlkPrevInfo(int m) : m_(m) {}
  struct Record_prev_blk_info {
    typedef BlkPrevInfo type_class;
    Ref<CellSlice> prev;  	// prev : ExtBlkRef
    Record_prev_blk_info() = default;
    Record_prev_blk_info(Ref<CellSlice> _prev) : prev(std::move(_prev)) {}
  };
  struct Record_prev_blks_info {
    typedef BlkPrevInfo type_class;
    Ref<Cell> prev1;  	// prev1 : ^ExtBlkRef
    Ref<Cell> prev2;  	// prev2 : ^ExtBlkRef
    Record_prev_blks_info() = default;
    Record_prev_blks_info(Ref<Cell> _prev1, Ref<Cell> _prev2) : prev1(std::move(_prev1)), prev2(std::move(_prev2)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_prev_blk_info& data) const;
  bool unpack_prev_blk_info(vm::CellSlice& cs, Ref<CellSlice>& prev) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_prev_blk_info& data) const;
  bool cell_unpack_prev_blk_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev) const;
  bool pack(vm::CellBuilder& cb, const Record_prev_blk_info& data) const;
  bool pack_prev_blk_info(vm::CellBuilder& cb, Ref<CellSlice> prev) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_prev_blk_info& data) const;
  bool cell_pack_prev_blk_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev) const;
  bool unpack(vm::CellSlice& cs, Record_prev_blks_info& data) const;
  bool unpack_prev_blks_info(vm::CellSlice& cs, Ref<Cell>& prev1, Ref<Cell>& prev2) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_prev_blks_info& data) const;
  bool cell_unpack_prev_blks_info(Ref<vm::Cell> cell_ref, Ref<Cell>& prev1, Ref<Cell>& prev2) const;
  bool pack(vm::CellBuilder& cb, const Record_prev_blks_info& data) const;
  bool pack_prev_blks_info(vm::CellBuilder& cb, Ref<Cell> prev1, Ref<Cell> prev2) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_prev_blks_info& data) const;
  bool cell_pack_prev_blks_info(Ref<vm::Cell>& cell_ref, Ref<Cell> prev1, Ref<Cell> prev2) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(BlkPrevInfo " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

//
// headers for type `Block`
//

struct Block final : TLB_Complex {
  enum { block };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x11ef55aa };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 0x40040;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x40040);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Block";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Block::Record {
  typedef Block type_class;
  int global_id;  	// global_id : int32
  Ref<Cell> info;  	// info : ^BlockInfo
  Ref<Cell> value_flow;  	// value_flow : ^ValueFlow
  Ref<Cell> state_update;  	// state_update : ^(MERKLE_UPDATE ShardState)
  Ref<Cell> extra;  	// extra : ^BlockExtra
  Record() = default;
  Record(int _global_id, Ref<Cell> _info, Ref<Cell> _value_flow, Ref<Cell> _state_update, Ref<Cell> _extra) : global_id(_global_id), info(std::move(_info)), value_flow(std::move(_value_flow)), state_update(std::move(_state_update)), extra(std::move(_extra)) {}
};

extern const Block t_Block;

//
// headers for type `BlockExtra`
//

struct BlockExtra final : TLB_Complex {
  enum { block_extra };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x4a33f6fd };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockExtra";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockExtra::Record {
  typedef BlockExtra type_class;
  Ref<Cell> in_msg_descr;  	// in_msg_descr : ^InMsgDescr
  Ref<Cell> out_msg_descr;  	// out_msg_descr : ^OutMsgDescr
  Ref<Cell> account_blocks;  	// account_blocks : ^ShardAccountBlocks
  td::BitArray<256> rand_seed;  	// rand_seed : bits256
  td::BitArray<256> created_by;  	// created_by : bits256
  Ref<CellSlice> custom;  	// custom : Maybe ^McBlockExtra
  Record() = default;
  Record(Ref<Cell> _in_msg_descr, Ref<Cell> _out_msg_descr, Ref<Cell> _account_blocks, const td::BitArray<256>& _rand_seed, const td::BitArray<256>& _created_by, Ref<CellSlice> _custom) : in_msg_descr(std::move(_in_msg_descr)), out_msg_descr(std::move(_out_msg_descr)), account_blocks(std::move(_account_blocks)), rand_seed(_rand_seed), created_by(_created_by), custom(std::move(_custom)) {}
};

extern const BlockExtra t_BlockExtra;

//
// headers for auxiliary type `ValueFlow_aux`
//

struct ValueFlow_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValueFlow_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValueFlow_aux::Record {
  typedef ValueFlow_aux type_class;
  Ref<CellSlice> from_prev_blk;  	// from_prev_blk : CurrencyCollection
  Ref<CellSlice> to_next_blk;  	// to_next_blk : CurrencyCollection
  Ref<CellSlice> imported;  	// imported : CurrencyCollection
  Ref<CellSlice> exported;  	// exported : CurrencyCollection
  Record() = default;
  Record(Ref<CellSlice> _from_prev_blk, Ref<CellSlice> _to_next_blk, Ref<CellSlice> _imported, Ref<CellSlice> _exported) : from_prev_blk(std::move(_from_prev_blk)), to_next_blk(std::move(_to_next_blk)), imported(std::move(_imported)), exported(std::move(_exported)) {}
};

extern const ValueFlow_aux t_ValueFlow_aux;

//
// headers for auxiliary type `ValueFlow_aux1`
//

struct ValueFlow_aux1 final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValueFlow_aux1";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValueFlow_aux1::Record {
  typedef ValueFlow_aux1 type_class;
  Ref<CellSlice> fees_imported;  	// fees_imported : CurrencyCollection
  Ref<CellSlice> recovered;  	// recovered : CurrencyCollection
  Ref<CellSlice> created;  	// created : CurrencyCollection
  Ref<CellSlice> minted;  	// minted : CurrencyCollection
  Record() = default;
  Record(Ref<CellSlice> _fees_imported, Ref<CellSlice> _recovered, Ref<CellSlice> _created, Ref<CellSlice> _minted) : fees_imported(std::move(_fees_imported)), recovered(std::move(_recovered)), created(std::move(_created)), minted(std::move(_minted)) {}
};

extern const ValueFlow_aux1 t_ValueFlow_aux1;

//
// headers for type `ValueFlow`
//

struct ValueFlow final : TLB_Complex {
  enum { value_flow };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0xb8e48dfbU };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValueFlow";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValueFlow::Record {
  typedef ValueFlow type_class;
  ValueFlow_aux::Record r1;  	// ^[$_ from_prev_blk:CurrencyCollection to_next_blk:CurrencyCollection imported:CurrencyCollection exported:CurrencyCollection ]
  Ref<CellSlice> fees_collected;  	// fees_collected : CurrencyCollection
  ValueFlow_aux1::Record r2;  	// ^[$_ fees_imported:CurrencyCollection recovered:CurrencyCollection created:CurrencyCollection minted:CurrencyCollection ]
  Record() = default;
  Record(const ValueFlow_aux::Record& _r1, Ref<CellSlice> _fees_collected, const ValueFlow_aux1::Record& _r2) : r1(_r1), fees_collected(std::move(_fees_collected)), r2(_r2) {}
};

extern const ValueFlow t_ValueFlow;

//
// headers for type `BinTree`
//

struct BinTree final : TLB_Complex {
  enum { bt_leaf, bt_fork };
  static constexpr int cons_len_exact = 1;
  const TLB &X_;
  BinTree(const TLB& X) : X_(X) {}
  struct Record_bt_leaf {
    typedef BinTree type_class;
    Ref<CellSlice> leaf;  	// leaf : X
    Record_bt_leaf() = default;
    Record_bt_leaf(Ref<CellSlice> _leaf) : leaf(std::move(_leaf)) {}
  };
  struct Record_bt_fork {
    typedef BinTree type_class;
    Ref<Cell> left;  	// left : ^(BinTree X)
    Ref<Cell> right;  	// right : ^(BinTree X)
    Record_bt_fork() = default;
    Record_bt_fork(Ref<Cell> _left, Ref<Cell> _right) : left(std::move(_left)), right(std::move(_right)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_bt_leaf& data) const;
  bool unpack_bt_leaf(vm::CellSlice& cs, Ref<CellSlice>& leaf) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bt_leaf& data) const;
  bool cell_unpack_bt_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& leaf) const;
  bool pack(vm::CellBuilder& cb, const Record_bt_leaf& data) const;
  bool pack_bt_leaf(vm::CellBuilder& cb, Ref<CellSlice> leaf) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bt_leaf& data) const;
  bool cell_pack_bt_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> leaf) const;
  bool unpack(vm::CellSlice& cs, Record_bt_fork& data) const;
  bool unpack_bt_fork(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bt_fork& data) const;
  bool cell_unpack_bt_fork(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right) const;
  bool pack(vm::CellBuilder& cb, const Record_bt_fork& data) const;
  bool pack_bt_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bt_fork& data) const;
  bool cell_pack_bt_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(BinTree " << X_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

//
// headers for type `FutureSplitMerge`
//

struct FutureSplitMerge final : TLB_Complex {
  enum { fsm_none, fsm_split, fsm_merge };
  static constexpr char cons_len[3] = { 1, 2, 2 };
  static constexpr unsigned char cons_tag[3] = { 0, 2, 3 };
  struct Record_fsm_none {
    typedef FutureSplitMerge type_class;
  };
  struct Record_fsm_split {
    typedef FutureSplitMerge type_class;
    unsigned split_utime;  	// split_utime : uint32
    unsigned interval;  	// interval : uint32
    Record_fsm_split() = default;
    Record_fsm_split(unsigned _split_utime, unsigned _interval) : split_utime(_split_utime), interval(_interval) {}
  };
  struct Record_fsm_merge {
    typedef FutureSplitMerge type_class;
    unsigned merge_utime;  	// merge_utime : uint32
    unsigned interval;  	// interval : uint32
    Record_fsm_merge() = default;
    Record_fsm_merge(unsigned _merge_utime, unsigned _interval) : merge_utime(_merge_utime), interval(_interval) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_fsm_none& data) const;
  bool unpack_fsm_none(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_fsm_none& data) const;
  bool cell_unpack_fsm_none(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_fsm_none& data) const;
  bool pack_fsm_none(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_fsm_none& data) const;
  bool cell_pack_fsm_none(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_fsm_split& data) const;
  bool unpack_fsm_split(vm::CellSlice& cs, unsigned& split_utime, unsigned& interval) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_fsm_split& data) const;
  bool cell_unpack_fsm_split(Ref<vm::Cell> cell_ref, unsigned& split_utime, unsigned& interval) const;
  bool pack(vm::CellBuilder& cb, const Record_fsm_split& data) const;
  bool pack_fsm_split(vm::CellBuilder& cb, unsigned split_utime, unsigned interval) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_fsm_split& data) const;
  bool cell_pack_fsm_split(Ref<vm::Cell>& cell_ref, unsigned split_utime, unsigned interval) const;
  bool unpack(vm::CellSlice& cs, Record_fsm_merge& data) const;
  bool unpack_fsm_merge(vm::CellSlice& cs, unsigned& merge_utime, unsigned& interval) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_fsm_merge& data) const;
  bool cell_unpack_fsm_merge(Ref<vm::Cell> cell_ref, unsigned& merge_utime, unsigned& interval) const;
  bool pack(vm::CellBuilder& cb, const Record_fsm_merge& data) const;
  bool pack_fsm_merge(vm::CellBuilder& cb, unsigned merge_utime, unsigned interval) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_fsm_merge& data) const;
  bool cell_pack_fsm_merge(Ref<vm::Cell>& cell_ref, unsigned merge_utime, unsigned interval) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "FutureSplitMerge";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect_ext(2, 13);
  }
};

extern const FutureSplitMerge t_FutureSplitMerge;

//
// headers for auxiliary type `ShardDescr_aux`
//

struct ShardDescr_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardDescr_aux type_class;
    Ref<CellSlice> fees_collected;  	// fees_collected : CurrencyCollection
    Ref<CellSlice> funds_created;  	// funds_created : CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _fees_collected, Ref<CellSlice> _funds_created) : fees_collected(std::move(_fees_collected)), funds_created(std::move(_funds_created)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& fees_collected, Ref<CellSlice>& funds_created) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fees_collected, Ref<CellSlice>& funds_created) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> fees_collected, Ref<CellSlice> funds_created) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fees_collected, Ref<CellSlice> funds_created) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardDescr_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardDescr_aux t_ShardDescr_aux;

//
// headers for type `ShardDescr`
//

struct ShardDescr final : TLB_Complex {
  enum { shard_descr_new, shard_descr };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[2] = { 10, 11 };
  struct Record_shard_descr;
  struct Record_shard_descr_new;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_shard_descr& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_shard_descr& data) const;
  bool pack(vm::CellBuilder& cb, const Record_shard_descr& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_shard_descr& data) const;
  bool unpack(vm::CellSlice& cs, Record_shard_descr_new& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_shard_descr_new& data) const;
  bool pack(vm::CellBuilder& cb, const Record_shard_descr_new& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_shard_descr_new& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(4, 0xc00);
  }
};

struct ShardDescr::Record_shard_descr {
  typedef ShardDescr type_class;
  unsigned seq_no;  	// seq_no : uint32
  unsigned reg_mc_seqno;  	// reg_mc_seqno : uint32
  unsigned long long start_lt;  	// start_lt : uint64
  unsigned long long end_lt;  	// end_lt : uint64
  td::BitArray<256> root_hash;  	// root_hash : bits256
  td::BitArray<256> file_hash;  	// file_hash : bits256
  bool before_split;  	// before_split : Bool
  bool before_merge;  	// before_merge : Bool
  bool want_split;  	// want_split : Bool
  bool want_merge;  	// want_merge : Bool
  bool nx_cc_updated;  	// nx_cc_updated : Bool
  int flags;  	// flags : ## 3
  unsigned next_catchain_seqno;  	// next_catchain_seqno : uint32
  unsigned long long next_validator_shard;  	// next_validator_shard : uint64
  unsigned min_ref_mc_seqno;  	// min_ref_mc_seqno : uint32
  unsigned gen_utime;  	// gen_utime : uint32
  Ref<CellSlice> split_merge_at;  	// split_merge_at : FutureSplitMerge
  Ref<CellSlice> fees_collected;  	// fees_collected : CurrencyCollection
  Ref<CellSlice> funds_created;  	// funds_created : CurrencyCollection
  Record_shard_descr() = default;
  Record_shard_descr(unsigned _seq_no, unsigned _reg_mc_seqno, unsigned long long _start_lt, unsigned long long _end_lt, const td::BitArray<256>& _root_hash, const td::BitArray<256>& _file_hash, bool _before_split, bool _before_merge, bool _want_split, bool _want_merge, bool _nx_cc_updated, int _flags, unsigned _next_catchain_seqno, unsigned long long _next_validator_shard, unsigned _min_ref_mc_seqno, unsigned _gen_utime, Ref<CellSlice> _split_merge_at, Ref<CellSlice> _fees_collected, Ref<CellSlice> _funds_created) : seq_no(_seq_no), reg_mc_seqno(_reg_mc_seqno), start_lt(_start_lt), end_lt(_end_lt), root_hash(_root_hash), file_hash(_file_hash), before_split(_before_split), before_merge(_before_merge), want_split(_want_split), want_merge(_want_merge), nx_cc_updated(_nx_cc_updated), flags(_flags), next_catchain_seqno(_next_catchain_seqno), next_validator_shard(_next_validator_shard), min_ref_mc_seqno(_min_ref_mc_seqno), gen_utime(_gen_utime), split_merge_at(std::move(_split_merge_at)), fees_collected(std::move(_fees_collected)), funds_created(std::move(_funds_created)) {}
};

struct ShardDescr::Record_shard_descr_new {
  typedef ShardDescr type_class;
  unsigned seq_no;  	// seq_no : uint32
  unsigned reg_mc_seqno;  	// reg_mc_seqno : uint32
  unsigned long long start_lt;  	// start_lt : uint64
  unsigned long long end_lt;  	// end_lt : uint64
  td::BitArray<256> root_hash;  	// root_hash : bits256
  td::BitArray<256> file_hash;  	// file_hash : bits256
  bool before_split;  	// before_split : Bool
  bool before_merge;  	// before_merge : Bool
  bool want_split;  	// want_split : Bool
  bool want_merge;  	// want_merge : Bool
  bool nx_cc_updated;  	// nx_cc_updated : Bool
  int flags;  	// flags : ## 3
  unsigned next_catchain_seqno;  	// next_catchain_seqno : uint32
  unsigned long long next_validator_shard;  	// next_validator_shard : uint64
  unsigned min_ref_mc_seqno;  	// min_ref_mc_seqno : uint32
  unsigned gen_utime;  	// gen_utime : uint32
  Ref<CellSlice> split_merge_at;  	// split_merge_at : FutureSplitMerge
  ShardDescr_aux::Record r1;  	// ^[$_ fees_collected:CurrencyCollection funds_created:CurrencyCollection ]
  Record_shard_descr_new() = default;
  Record_shard_descr_new(unsigned _seq_no, unsigned _reg_mc_seqno, unsigned long long _start_lt, unsigned long long _end_lt, const td::BitArray<256>& _root_hash, const td::BitArray<256>& _file_hash, bool _before_split, bool _before_merge, bool _want_split, bool _want_merge, bool _nx_cc_updated, int _flags, unsigned _next_catchain_seqno, unsigned long long _next_validator_shard, unsigned _min_ref_mc_seqno, unsigned _gen_utime, Ref<CellSlice> _split_merge_at, const ShardDescr_aux::Record& _r1) : seq_no(_seq_no), reg_mc_seqno(_reg_mc_seqno), start_lt(_start_lt), end_lt(_end_lt), root_hash(_root_hash), file_hash(_file_hash), before_split(_before_split), before_merge(_before_merge), want_split(_want_split), want_merge(_want_merge), nx_cc_updated(_nx_cc_updated), flags(_flags), next_catchain_seqno(_next_catchain_seqno), next_validator_shard(_next_validator_shard), min_ref_mc_seqno(_min_ref_mc_seqno), gen_utime(_gen_utime), split_merge_at(std::move(_split_merge_at)), r1(_r1) {}
};

extern const ShardDescr t_ShardDescr;

//
// headers for type `ShardHashes`
//

struct ShardHashes final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardHashes type_class;
    Ref<CellSlice> x;  	// HashmapE 32 ^(BinTree ShardDescr)
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardHashes";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardHashes t_ShardHashes;

//
// headers for type `BinTreeAug`
//

struct BinTreeAug final : TLB_Complex {
  enum { bta_leaf, bta_fork };
  static constexpr int cons_len_exact = 1;
  const TLB &X_, &Y_;
  BinTreeAug(const TLB& X, const TLB& Y) : X_(X), Y_(Y) {}
  struct Record_bta_leaf {
    typedef BinTreeAug type_class;
    Ref<CellSlice> extra;  	// extra : Y
    Ref<CellSlice> leaf;  	// leaf : X
    Record_bta_leaf() = default;
    Record_bta_leaf(Ref<CellSlice> _extra, Ref<CellSlice> _leaf) : extra(std::move(_extra)), leaf(std::move(_leaf)) {}
  };
  struct Record_bta_fork;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_bta_leaf& data) const;
  bool unpack_bta_leaf(vm::CellSlice& cs, Ref<CellSlice>& extra, Ref<CellSlice>& leaf) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bta_leaf& data) const;
  bool cell_unpack_bta_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra, Ref<CellSlice>& leaf) const;
  bool pack(vm::CellBuilder& cb, const Record_bta_leaf& data) const;
  bool pack_bta_leaf(vm::CellBuilder& cb, Ref<CellSlice> extra, Ref<CellSlice> leaf) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bta_leaf& data) const;
  bool cell_pack_bta_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra, Ref<CellSlice> leaf) const;
  bool unpack(vm::CellSlice& cs, Record_bta_fork& data) const;
  bool unpack_bta_fork(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right, Ref<CellSlice>& extra) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_bta_fork& data) const;
  bool cell_unpack_bta_fork(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right, Ref<CellSlice>& extra) const;
  bool pack(vm::CellBuilder& cb, const Record_bta_fork& data) const;
  bool pack_bta_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right, Ref<CellSlice> extra) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_bta_fork& data) const;
  bool cell_pack_bta_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right, Ref<CellSlice> extra) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(BinTreeAug " << X_ << " " << Y_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

struct BinTreeAug::Record_bta_fork {
  typedef BinTreeAug type_class;
  Ref<Cell> left;  	// left : ^(BinTreeAug X Y)
  Ref<Cell> right;  	// right : ^(BinTreeAug X Y)
  Ref<CellSlice> extra;  	// extra : Y
  Record_bta_fork() = default;
  Record_bta_fork(Ref<Cell> _left, Ref<Cell> _right, Ref<CellSlice> _extra) : left(std::move(_left)), right(std::move(_right)), extra(std::move(_extra)) {}
};

//
// headers for type `ShardFeeCreated`
//

struct ShardFeeCreated final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardFeeCreated type_class;
    Ref<CellSlice> fees;  	// fees : CurrencyCollection
    Ref<CellSlice> create;  	// create : CurrencyCollection
    Record() = default;
    Record(Ref<CellSlice> _fees, Ref<CellSlice> _create) : fees(std::move(_fees)), create(std::move(_create)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& fees, Ref<CellSlice>& create) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fees, Ref<CellSlice>& create) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> fees, Ref<CellSlice> create) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fees, Ref<CellSlice> create) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardFeeCreated";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardFeeCreated t_ShardFeeCreated;

//
// headers for type `ShardFees`
//

struct ShardFees final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ShardFees type_class;
    Ref<CellSlice> x;  	// HashmapAugE 96 ShardFeeCreated ShardFeeCreated
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ShardFees";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ShardFees t_ShardFees;

//
// headers for type `ConfigParams`
//

struct ConfigParams final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ConfigParams type_class;
    td::BitArray<256> config_addr;  	// config_addr : bits256
    Ref<Cell> config;  	// config : ^(Hashmap 32 ^Cell)
    Record() = default;
    Record(const td::BitArray<256>& _config_addr, Ref<Cell> _config) : config_addr(_config_addr), config(std::move(_config)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10100;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10100);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, td::BitArray<256>& config_addr, Ref<Cell>& config) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, td::BitArray<256>& config_addr, Ref<Cell>& config) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, td::BitArray<256> config_addr, Ref<Cell> config) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, td::BitArray<256> config_addr, Ref<Cell> config) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConfigParams";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ConfigParams t_ConfigParams;

//
// headers for type `ValidatorInfo`
//

struct ValidatorInfo final : TLB_Complex {
  enum { validator_info };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 65;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(65);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(65);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_validator_info(vm::CellSlice& cs, unsigned& validator_list_hash_short, unsigned& catchain_seqno, bool& nx_cc_updated) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_validator_info(Ref<vm::Cell> cell_ref, unsigned& validator_list_hash_short, unsigned& catchain_seqno, bool& nx_cc_updated) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_validator_info(vm::CellBuilder& cb, unsigned validator_list_hash_short, unsigned catchain_seqno, bool nx_cc_updated) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_validator_info(Ref<vm::Cell>& cell_ref, unsigned validator_list_hash_short, unsigned catchain_seqno, bool nx_cc_updated) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValidatorInfo::Record {
  typedef ValidatorInfo type_class;
  unsigned validator_list_hash_short;  	// validator_list_hash_short : uint32
  unsigned catchain_seqno;  	// catchain_seqno : uint32
  bool nx_cc_updated;  	// nx_cc_updated : Bool
  Record() = default;
  Record(unsigned _validator_list_hash_short, unsigned _catchain_seqno, bool _nx_cc_updated) : validator_list_hash_short(_validator_list_hash_short), catchain_seqno(_catchain_seqno), nx_cc_updated(_nx_cc_updated) {}
};

extern const ValidatorInfo t_ValidatorInfo;

//
// headers for type `ValidatorBaseInfo`
//

struct ValidatorBaseInfo final : TLB_Complex {
  enum { validator_base_info };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ValidatorBaseInfo type_class;
    unsigned validator_list_hash_short;  	// validator_list_hash_short : uint32
    unsigned catchain_seqno;  	// catchain_seqno : uint32
    Record() = default;
    Record(unsigned _validator_list_hash_short, unsigned _catchain_seqno) : validator_list_hash_short(_validator_list_hash_short), catchain_seqno(_catchain_seqno) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 64;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(64);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(64);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_validator_base_info(vm::CellSlice& cs, unsigned& validator_list_hash_short, unsigned& catchain_seqno) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_validator_base_info(Ref<vm::Cell> cell_ref, unsigned& validator_list_hash_short, unsigned& catchain_seqno) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_validator_base_info(vm::CellBuilder& cb, unsigned validator_list_hash_short, unsigned catchain_seqno) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_validator_base_info(Ref<vm::Cell>& cell_ref, unsigned validator_list_hash_short, unsigned catchain_seqno) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorBaseInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ValidatorBaseInfo t_ValidatorBaseInfo;

//
// headers for type `KeyMaxLt`
//

struct KeyMaxLt final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef KeyMaxLt type_class;
    bool key;  	// key : Bool
    unsigned long long max_end_lt;  	// max_end_lt : uint64
    Record() = default;
    Record(bool _key, unsigned long long _max_end_lt) : key(_key), max_end_lt(_max_end_lt) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 65;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(65);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(65);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, bool& key, unsigned long long& max_end_lt) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, bool& key, unsigned long long& max_end_lt) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, bool key, unsigned long long max_end_lt) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, bool key, unsigned long long max_end_lt) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "KeyMaxLt";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const KeyMaxLt t_KeyMaxLt;

//
// headers for type `KeyExtBlkRef`
//

struct KeyExtBlkRef final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef KeyExtBlkRef type_class;
    bool key;  	// key : Bool
    Ref<CellSlice> blk_ref;  	// blk_ref : ExtBlkRef
    Record() = default;
    Record(bool _key, Ref<CellSlice> _blk_ref) : key(_key), blk_ref(std::move(_blk_ref)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 609;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(609);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(609);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, bool& key, Ref<CellSlice>& blk_ref) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, bool& key, Ref<CellSlice>& blk_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, bool key, Ref<CellSlice> blk_ref) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, bool key, Ref<CellSlice> blk_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "KeyExtBlkRef";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const KeyExtBlkRef t_KeyExtBlkRef;

//
// headers for type `OldMcBlocksInfo`
//

struct OldMcBlocksInfo final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef OldMcBlocksInfo type_class;
    Ref<CellSlice> x;  	// HashmapAugE 32 KeyExtBlkRef KeyMaxLt
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "OldMcBlocksInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const OldMcBlocksInfo t_OldMcBlocksInfo;

//
// headers for type `Counters`
//

struct Counters final : TLB_Complex {
  enum { counters };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 224;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(224);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(224);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Counters";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Counters::Record {
  typedef Counters type_class;
  unsigned last_updated;  	// last_updated : uint32
  unsigned long long total;  	// total : uint64
  unsigned long long cnt2048;  	// cnt2048 : uint64
  unsigned long long cnt65536;  	// cnt65536 : uint64
  Record() = default;
  Record(unsigned _last_updated, unsigned long long _total, unsigned long long _cnt2048, unsigned long long _cnt65536) : last_updated(_last_updated), total(_total), cnt2048(_cnt2048), cnt65536(_cnt65536) {}
};

extern const Counters t_Counters;

//
// headers for type `CreatorStats`
//

struct CreatorStats final : TLB_Complex {
  enum { creator_info };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 4 };
  struct Record {
    typedef CreatorStats type_class;
    Ref<CellSlice> mc_blocks;  	// mc_blocks : Counters
    Ref<CellSlice> shard_blocks;  	// shard_blocks : Counters
    Record() = default;
    Record(Ref<CellSlice> _mc_blocks, Ref<CellSlice> _shard_blocks) : mc_blocks(std::move(_mc_blocks)), shard_blocks(std::move(_shard_blocks)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 452;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(452);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_creator_info(vm::CellSlice& cs, Ref<CellSlice>& mc_blocks, Ref<CellSlice>& shard_blocks) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_creator_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mc_blocks, Ref<CellSlice>& shard_blocks) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_creator_info(vm::CellBuilder& cb, Ref<CellSlice> mc_blocks, Ref<CellSlice> shard_blocks) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_creator_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mc_blocks, Ref<CellSlice> shard_blocks) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CreatorStats";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const CreatorStats t_CreatorStats;

//
// headers for type `BlockCreateStats`
//

struct BlockCreateStats final : TLB_Complex {
  enum { block_create_stats, block_create_stats_ext };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[2] = { 23, 0x34 };
  struct Record_block_create_stats {
    typedef BlockCreateStats type_class;
    Ref<CellSlice> counters;  	// counters : HashmapE 256 CreatorStats
    Record_block_create_stats() = default;
    Record_block_create_stats(Ref<CellSlice> _counters) : counters(std::move(_counters)) {}
  };
  struct Record_block_create_stats_ext {
    typedef BlockCreateStats type_class;
    Ref<CellSlice> counters;  	// counters : HashmapAugE 256 CreatorStats uint32
    Record_block_create_stats_ext() = default;
    Record_block_create_stats_ext(Ref<CellSlice> _counters) : counters(std::move(_counters)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_block_create_stats& data) const;
  bool unpack_block_create_stats(vm::CellSlice& cs, Ref<CellSlice>& counters) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_block_create_stats& data) const;
  bool cell_unpack_block_create_stats(Ref<vm::Cell> cell_ref, Ref<CellSlice>& counters) const;
  bool pack(vm::CellBuilder& cb, const Record_block_create_stats& data) const;
  bool pack_block_create_stats(vm::CellBuilder& cb, Ref<CellSlice> counters) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_block_create_stats& data) const;
  bool cell_pack_block_create_stats(Ref<vm::Cell>& cell_ref, Ref<CellSlice> counters) const;
  bool unpack(vm::CellSlice& cs, Record_block_create_stats_ext& data) const;
  bool unpack_block_create_stats_ext(vm::CellSlice& cs, Ref<CellSlice>& counters) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_block_create_stats_ext& data) const;
  bool cell_unpack_block_create_stats_ext(Ref<vm::Cell> cell_ref, Ref<CellSlice>& counters) const;
  bool pack(vm::CellBuilder& cb, const Record_block_create_stats_ext& data) const;
  bool pack_block_create_stats_ext(vm::CellBuilder& cb, Ref<CellSlice> counters) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_block_create_stats_ext& data) const;
  bool cell_pack_block_create_stats_ext(Ref<vm::Cell>& cell_ref, Ref<CellSlice> counters) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockCreateStats";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(3, 3);
  }
};

extern const BlockCreateStats t_BlockCreateStats;

//
// headers for auxiliary type `McStateExtra_aux`
//

struct McStateExtra_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "McStateExtra_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct McStateExtra_aux::Record {
  typedef McStateExtra_aux type_class;
  int flags;  	// flags : ## 16
  Ref<CellSlice> validator_info;  	// validator_info : ValidatorInfo
  Ref<CellSlice> prev_blocks;  	// prev_blocks : OldMcBlocksInfo
  bool after_key_block;  	// after_key_block : Bool
  Ref<CellSlice> last_key_block;  	// last_key_block : Maybe ExtBlkRef
  Ref<CellSlice> block_create_stats;  	// block_create_stats : flags.0?BlockCreateStats
  Record() = default;
  Record(int _flags, Ref<CellSlice> _validator_info, Ref<CellSlice> _prev_blocks, bool _after_key_block, Ref<CellSlice> _last_key_block, Ref<CellSlice> _block_create_stats) : flags(_flags), validator_info(std::move(_validator_info)), prev_blocks(std::move(_prev_blocks)), after_key_block(_after_key_block), last_key_block(std::move(_last_key_block)), block_create_stats(std::move(_block_create_stats)) {}
};

extern const McStateExtra_aux t_McStateExtra_aux;

//
// headers for type `McStateExtra`
//

struct McStateExtra final : TLB_Complex {
  enum { masterchain_state_extra };
  static constexpr int cons_len_exact = 16;
  static constexpr unsigned short cons_tag[1] = { 0xcc26 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "McStateExtra";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct McStateExtra::Record {
  typedef McStateExtra type_class;
  Ref<CellSlice> shard_hashes;  	// shard_hashes : ShardHashes
  Ref<CellSlice> config;  	// config : ConfigParams
  McStateExtra_aux::Record r1;  	// ^[$_ flags:(## 16) {<= flags 1} validator_info:ValidatorInfo prev_blocks:OldMcBlocksInfo after_key_block:Bool last_key_block:(Maybe ExtBlkRef) block_create_stats:flags.0?BlockCreateStats ]
  Ref<CellSlice> global_balance;  	// global_balance : CurrencyCollection
  Record() = default;
  Record(Ref<CellSlice> _shard_hashes, Ref<CellSlice> _config, const McStateExtra_aux::Record& _r1, Ref<CellSlice> _global_balance) : shard_hashes(std::move(_shard_hashes)), config(std::move(_config)), r1(_r1), global_balance(std::move(_global_balance)) {}
};

extern const McStateExtra t_McStateExtra;

//
// headers for type `SigPubKey`
//

struct SigPubKey final : TLB_Complex {
  enum { ed25519_pubkey };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x8e81278aU };
  struct Record {
    typedef SigPubKey type_class;
    td::BitArray<256> pubkey;  	// pubkey : bits256
    Record() = default;
    Record(const td::BitArray<256>& _pubkey) : pubkey(_pubkey) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 288;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(288);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_ed25519_pubkey(vm::CellSlice& cs, td::BitArray<256>& pubkey) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_ed25519_pubkey(Ref<vm::Cell> cell_ref, td::BitArray<256>& pubkey) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_ed25519_pubkey(vm::CellBuilder& cb, td::BitArray<256> pubkey) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_ed25519_pubkey(Ref<vm::Cell>& cell_ref, td::BitArray<256> pubkey) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SigPubKey";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const SigPubKey t_SigPubKey;

//
// headers for type `CryptoSignatureSimple`
//

struct CryptoSignatureSimple final : TLB_Complex {
  enum { ed25519_signature };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 5 };
  struct Record {
    typedef CryptoSignatureSimple type_class;
    td::BitArray<256> R;  	// R : bits256
    td::BitArray<256> s;  	// s : bits256
    Record() = default;
    Record(const td::BitArray<256>& _R, const td::BitArray<256>& _s) : R(_R), s(_s) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 516;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(516);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_ed25519_signature(vm::CellSlice& cs, td::BitArray<256>& R, td::BitArray<256>& s) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_ed25519_signature(Ref<vm::Cell> cell_ref, td::BitArray<256>& R, td::BitArray<256>& s) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_ed25519_signature(vm::CellBuilder& cb, td::BitArray<256> R, td::BitArray<256> s) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_ed25519_signature(Ref<vm::Cell>& cell_ref, td::BitArray<256> R, td::BitArray<256> s) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CryptoSignatureSimple";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const CryptoSignatureSimple t_CryptoSignatureSimple;

//
// headers for type `CryptoSignaturePair`
//

struct CryptoSignaturePair final : TLB_Complex {
  enum { sig_pair };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef CryptoSignaturePair type_class;
    td::BitArray<256> node_id_short;  	// node_id_short : bits256
    Ref<CellSlice> sign;  	// sign : CryptoSignature
    Record() = default;
    Record(const td::BitArray<256>& _node_id_short, Ref<CellSlice> _sign) : node_id_short(_node_id_short), sign(std::move(_sign)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_sig_pair(vm::CellSlice& cs, td::BitArray<256>& node_id_short, Ref<CellSlice>& sign) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_sig_pair(Ref<vm::Cell> cell_ref, td::BitArray<256>& node_id_short, Ref<CellSlice>& sign) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_sig_pair(vm::CellBuilder& cb, td::BitArray<256> node_id_short, Ref<CellSlice> sign) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_sig_pair(Ref<vm::Cell>& cell_ref, td::BitArray<256> node_id_short, Ref<CellSlice> sign) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CryptoSignaturePair";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const CryptoSignaturePair t_CryptoSignaturePair;

//
// headers for type `Certificate`
//

struct Certificate final : TLB_Complex {
  enum { certificate };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 4 };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 356;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(356);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_certificate(vm::CellSlice& cs, Ref<CellSlice>& temp_key, unsigned& valid_since, unsigned& valid_until) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_certificate(Ref<vm::Cell> cell_ref, Ref<CellSlice>& temp_key, unsigned& valid_since, unsigned& valid_until) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_certificate(vm::CellBuilder& cb, Ref<CellSlice> temp_key, unsigned valid_since, unsigned valid_until) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_certificate(Ref<vm::Cell>& cell_ref, Ref<CellSlice> temp_key, unsigned valid_since, unsigned valid_until) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Certificate";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct Certificate::Record {
  typedef Certificate type_class;
  Ref<CellSlice> temp_key;  	// temp_key : SigPubKey
  unsigned valid_since;  	// valid_since : uint32
  unsigned valid_until;  	// valid_until : uint32
  Record() = default;
  Record(Ref<CellSlice> _temp_key, unsigned _valid_since, unsigned _valid_until) : temp_key(std::move(_temp_key)), valid_since(_valid_since), valid_until(_valid_until) {}
};

extern const Certificate t_Certificate;

//
// headers for type `CertificateEnv`
//

struct CertificateEnv final : TLB_Complex {
  enum { certificate_env };
  static constexpr int cons_len_exact = 28;
  static constexpr unsigned cons_tag[1] = { 0xa419b7d };
  struct Record {
    typedef CertificateEnv type_class;
    Ref<CellSlice> certificate;  	// certificate : Certificate
    Record() = default;
    Record(Ref<CellSlice> _certificate) : certificate(std::move(_certificate)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 384;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(384);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_certificate_env(vm::CellSlice& cs, Ref<CellSlice>& certificate) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_certificate_env(Ref<vm::Cell> cell_ref, Ref<CellSlice>& certificate) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_certificate_env(vm::CellBuilder& cb, Ref<CellSlice> certificate) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_certificate_env(Ref<vm::Cell>& cell_ref, Ref<CellSlice> certificate) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CertificateEnv";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const CertificateEnv t_CertificateEnv;

//
// headers for type `SignedCertificate`
//

struct SignedCertificate final : TLB_Complex {
  enum { signed_certificate };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef SignedCertificate type_class;
    Ref<CellSlice> certificate;  	// certificate : Certificate
    Ref<CellSlice> certificate_signature;  	// certificate_signature : CryptoSignature
    Record() = default;
    Record(Ref<CellSlice> _certificate, Ref<CellSlice> _certificate_signature) : certificate(std::move(_certificate)), certificate_signature(std::move(_certificate_signature)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_signed_certificate(vm::CellSlice& cs, Ref<CellSlice>& certificate, Ref<CellSlice>& certificate_signature) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_signed_certificate(Ref<vm::Cell> cell_ref, Ref<CellSlice>& certificate, Ref<CellSlice>& certificate_signature) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_signed_certificate(vm::CellBuilder& cb, Ref<CellSlice> certificate, Ref<CellSlice> certificate_signature) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_signed_certificate(Ref<vm::Cell>& cell_ref, Ref<CellSlice> certificate, Ref<CellSlice> certificate_signature) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SignedCertificate";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const SignedCertificate t_SignedCertificate;

//
// headers for type `CryptoSignature`
//

struct CryptoSignature final : TLB_Complex {
  enum { cons1, chained_signature };
  static constexpr char cons_len[2] = { 0, 4 };
  static constexpr unsigned char cons_tag[2] = { 0, 15 };
  struct Record_cons1 {
    typedef CryptoSignature type_class;
    Ref<CellSlice> x;  	// CryptoSignatureSimple
    Record_cons1() = default;
    Record_cons1(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_chained_signature {
    typedef CryptoSignature type_class;
    Ref<Cell> signed_cert;  	// signed_cert : ^SignedCertificate
    Ref<CellSlice> temp_key_signature;  	// temp_key_signature : CryptoSignatureSimple
    Record_chained_signature() = default;
    Record_chained_signature(Ref<Cell> _signed_cert, Ref<CellSlice> _temp_key_signature) : signed_cert(std::move(_signed_cert)), temp_key_signature(std::move(_temp_key_signature)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cons1& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons1& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons1& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons1& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_chained_signature& data) const;
  bool unpack_chained_signature(vm::CellSlice& cs, Ref<Cell>& signed_cert, Ref<CellSlice>& temp_key_signature) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chained_signature& data) const;
  bool cell_unpack_chained_signature(Ref<vm::Cell> cell_ref, Ref<Cell>& signed_cert, Ref<CellSlice>& temp_key_signature) const;
  bool pack(vm::CellBuilder& cb, const Record_chained_signature& data) const;
  bool pack_chained_signature(vm::CellBuilder& cb, Ref<Cell> signed_cert, Ref<CellSlice> temp_key_signature) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chained_signature& data) const;
  bool cell_pack_chained_signature(Ref<vm::Cell>& cell_ref, Ref<Cell> signed_cert, Ref<CellSlice> temp_key_signature) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CryptoSignature";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const CryptoSignature t_CryptoSignature;

//
// headers for auxiliary type `McBlockExtra_aux`
//

struct McBlockExtra_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& prev_blk_signatures, Ref<CellSlice>& recover_create_msg, Ref<CellSlice>& mint_msg) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_blk_signatures, Ref<CellSlice>& recover_create_msg, Ref<CellSlice>& mint_msg) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> prev_blk_signatures, Ref<CellSlice> recover_create_msg, Ref<CellSlice> mint_msg) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_blk_signatures, Ref<CellSlice> recover_create_msg, Ref<CellSlice> mint_msg) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "McBlockExtra_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct McBlockExtra_aux::Record {
  typedef McBlockExtra_aux type_class;
  Ref<CellSlice> prev_blk_signatures;  	// prev_blk_signatures : HashmapE 16 CryptoSignaturePair
  Ref<CellSlice> recover_create_msg;  	// recover_create_msg : Maybe ^InMsg
  Ref<CellSlice> mint_msg;  	// mint_msg : Maybe ^InMsg
  Record() = default;
  Record(Ref<CellSlice> _prev_blk_signatures, Ref<CellSlice> _recover_create_msg, Ref<CellSlice> _mint_msg) : prev_blk_signatures(std::move(_prev_blk_signatures)), recover_create_msg(std::move(_recover_create_msg)), mint_msg(std::move(_mint_msg)) {}
};

extern const McBlockExtra_aux t_McBlockExtra_aux;

//
// headers for type `McBlockExtra`
//

struct McBlockExtra final : TLB_Complex {
  enum { masterchain_block_extra };
  static constexpr int cons_len_exact = 16;
  static constexpr unsigned short cons_tag[1] = { 0xcca5 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "McBlockExtra";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct McBlockExtra::Record {
  typedef McBlockExtra type_class;
  bool key_block;  	// key_block : ## 1
  Ref<CellSlice> shard_hashes;  	// shard_hashes : ShardHashes
  Ref<CellSlice> shard_fees;  	// shard_fees : ShardFees
  McBlockExtra_aux::Record r1;  	// ^[$_ prev_blk_signatures:(HashmapE 16 CryptoSignaturePair) recover_create_msg:(Maybe ^InMsg) mint_msg:(Maybe ^InMsg) ]
  Ref<CellSlice> config;  	// config : key_block?ConfigParams
  Record() = default;
  Record(bool _key_block, Ref<CellSlice> _shard_hashes, Ref<CellSlice> _shard_fees, const McBlockExtra_aux::Record& _r1, Ref<CellSlice> _config) : key_block(_key_block), shard_hashes(std::move(_shard_hashes)), shard_fees(std::move(_shard_fees)), r1(_r1), config(std::move(_config)) {}
};

extern const McBlockExtra t_McBlockExtra;

//
// headers for type `ValidatorDescr`
//

struct ValidatorDescr final : TLB_Complex {
  enum { validator, validator_addr };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[2] = { 0x53, 0x73 };
  struct Record_validator {
    typedef ValidatorDescr type_class;
    Ref<CellSlice> public_key;  	// public_key : SigPubKey
    unsigned long long weight;  	// weight : uint64
    Record_validator() = default;
    Record_validator(Ref<CellSlice> _public_key, unsigned long long _weight) : public_key(std::move(_public_key)), weight(_weight) {}
  };
  struct Record_validator_addr;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_validator& data) const;
  bool unpack_validator(vm::CellSlice& cs, Ref<CellSlice>& public_key, unsigned long long& weight) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_validator& data) const;
  bool cell_unpack_validator(Ref<vm::Cell> cell_ref, Ref<CellSlice>& public_key, unsigned long long& weight) const;
  bool pack(vm::CellBuilder& cb, const Record_validator& data) const;
  bool pack_validator(vm::CellBuilder& cb, Ref<CellSlice> public_key, unsigned long long weight) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_validator& data) const;
  bool cell_pack_validator(Ref<vm::Cell>& cell_ref, Ref<CellSlice> public_key, unsigned long long weight) const;
  bool unpack(vm::CellSlice& cs, Record_validator_addr& data) const;
  bool unpack_validator_addr(vm::CellSlice& cs, Ref<CellSlice>& public_key, unsigned long long& weight, td::BitArray<256>& adnl_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_validator_addr& data) const;
  bool cell_unpack_validator_addr(Ref<vm::Cell> cell_ref, Ref<CellSlice>& public_key, unsigned long long& weight, td::BitArray<256>& adnl_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_validator_addr& data) const;
  bool pack_validator_addr(vm::CellBuilder& cb, Ref<CellSlice> public_key, unsigned long long weight, td::BitArray<256> adnl_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_validator_addr& data) const;
  bool cell_pack_validator_addr(Ref<vm::Cell>& cell_ref, Ref<CellSlice> public_key, unsigned long long weight, td::BitArray<256> adnl_addr) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(3, 12);
  }
};

struct ValidatorDescr::Record_validator_addr {
  typedef ValidatorDescr type_class;
  Ref<CellSlice> public_key;  	// public_key : SigPubKey
  unsigned long long weight;  	// weight : uint64
  td::BitArray<256> adnl_addr;  	// adnl_addr : bits256
  Record_validator_addr() = default;
  Record_validator_addr(Ref<CellSlice> _public_key, unsigned long long _weight, const td::BitArray<256>& _adnl_addr) : public_key(std::move(_public_key)), weight(_weight), adnl_addr(_adnl_addr) {}
};

extern const ValidatorDescr t_ValidatorDescr;

//
// headers for type `ValidatorSet`
//

struct ValidatorSet final : TLB_Complex {
  enum { validators, validators_ext };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[2] = { 17, 18 };
  struct Record_validators;
  struct Record_validators_ext;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_validators& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_validators& data) const;
  bool pack(vm::CellBuilder& cb, const Record_validators& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_validators& data) const;
  bool unpack(vm::CellSlice& cs, Record_validators_ext& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_validators_ext& data) const;
  bool pack(vm::CellBuilder& cb, const Record_validators_ext& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_validators_ext& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorSet";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct ValidatorSet::Record_validators {
  typedef ValidatorSet type_class;
  unsigned utime_since;  	// utime_since : uint32
  unsigned utime_until;  	// utime_until : uint32
  int total;  	// total : ## 16
  int main;  	// main : ## 16
  Ref<CellSlice> list;  	// list : Hashmap 16 ValidatorDescr
  Record_validators() = default;
  Record_validators(unsigned _utime_since, unsigned _utime_until, int _total, int _main, Ref<CellSlice> _list) : utime_since(_utime_since), utime_until(_utime_until), total(_total), main(_main), list(std::move(_list)) {}
};

struct ValidatorSet::Record_validators_ext {
  typedef ValidatorSet type_class;
  unsigned utime_since;  	// utime_since : uint32
  unsigned utime_until;  	// utime_until : uint32
  int total;  	// total : ## 16
  int main;  	// main : ## 16
  unsigned long long total_weight;  	// total_weight : uint64
  Ref<CellSlice> list;  	// list : HashmapE 16 ValidatorDescr
  Record_validators_ext() = default;
  Record_validators_ext(unsigned _utime_since, unsigned _utime_until, int _total, int _main, unsigned long long _total_weight, Ref<CellSlice> _list) : utime_since(_utime_since), utime_until(_utime_until), total(_total), main(_main), total_weight(_total_weight), list(std::move(_list)) {}
};

extern const ValidatorSet t_ValidatorSet;

//
// headers for type `GlobalVersion`
//

struct GlobalVersion final : TLB_Complex {
  enum { capabilities };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xc4 };
  struct Record {
    typedef GlobalVersion type_class;
    unsigned version;  	// version : uint32
    unsigned long long capabilities;  	// capabilities : uint64
    Record() = default;
    Record(unsigned _version, unsigned long long _capabilities) : version(_version), capabilities(_capabilities) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 104;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(104);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_capabilities(vm::CellSlice& cs, unsigned& version, unsigned long long& capabilities) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_capabilities(Ref<vm::Cell> cell_ref, unsigned& version, unsigned long long& capabilities) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_capabilities(vm::CellBuilder& cb, unsigned version, unsigned long long capabilities) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_capabilities(Ref<vm::Cell>& cell_ref, unsigned version, unsigned long long capabilities) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "GlobalVersion";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const GlobalVersion t_GlobalVersion;

//
// headers for type `ConfigProposalSetup`
//

struct ConfigProposalSetup final : TLB_Complex {
  enum { cfg_vote_cfg };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x36 };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 168;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(168);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConfigProposalSetup";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ConfigProposalSetup::Record {
  typedef ConfigProposalSetup type_class;
  int min_tot_rounds;  	// min_tot_rounds : uint8
  int max_tot_rounds;  	// max_tot_rounds : uint8
  int min_wins;  	// min_wins : uint8
  int max_losses;  	// max_losses : uint8
  unsigned min_store_sec;  	// min_store_sec : uint32
  unsigned max_store_sec;  	// max_store_sec : uint32
  unsigned bit_price;  	// bit_price : uint32
  unsigned cell_price;  	// cell_price : uint32
  Record() = default;
  Record(int _min_tot_rounds, int _max_tot_rounds, int _min_wins, int _max_losses, unsigned _min_store_sec, unsigned _max_store_sec, unsigned _bit_price, unsigned _cell_price) : min_tot_rounds(_min_tot_rounds), max_tot_rounds(_max_tot_rounds), min_wins(_min_wins), max_losses(_max_losses), min_store_sec(_min_store_sec), max_store_sec(_max_store_sec), bit_price(_bit_price), cell_price(_cell_price) {}
};

extern const ConfigProposalSetup t_ConfigProposalSetup;

//
// headers for type `ConfigVotingSetup`
//

struct ConfigVotingSetup final : TLB_Complex {
  enum { cfg_vote_setup };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x91 };
  struct Record {
    typedef ConfigVotingSetup type_class;
    Ref<Cell> normal_params;  	// normal_params : ^ConfigProposalSetup
    Ref<Cell> critical_params;  	// critical_params : ^ConfigProposalSetup
    Record() = default;
    Record(Ref<Cell> _normal_params, Ref<Cell> _critical_params) : normal_params(std::move(_normal_params)), critical_params(std::move(_critical_params)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x20008;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x20008);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cfg_vote_setup(vm::CellSlice& cs, Ref<Cell>& normal_params, Ref<Cell>& critical_params) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cfg_vote_setup(Ref<vm::Cell> cell_ref, Ref<Cell>& normal_params, Ref<Cell>& critical_params) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cfg_vote_setup(vm::CellBuilder& cb, Ref<Cell> normal_params, Ref<Cell> critical_params) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cfg_vote_setup(Ref<vm::Cell>& cell_ref, Ref<Cell> normal_params, Ref<Cell> critical_params) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConfigVotingSetup";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ConfigVotingSetup t_ConfigVotingSetup;

//
// headers for type `ConfigProposal`
//

struct ConfigProposal final : TLB_Complex {
  enum { cfg_proposal };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xf3 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cfg_proposal(vm::CellSlice& cs, int& param_id, Ref<CellSlice>& param_value, Ref<CellSlice>& if_hash_equal) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cfg_proposal(Ref<vm::Cell> cell_ref, int& param_id, Ref<CellSlice>& param_value, Ref<CellSlice>& if_hash_equal) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cfg_proposal(vm::CellBuilder& cb, int param_id, Ref<CellSlice> param_value, Ref<CellSlice> if_hash_equal) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cfg_proposal(Ref<vm::Cell>& cell_ref, int param_id, Ref<CellSlice> param_value, Ref<CellSlice> if_hash_equal) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConfigProposal";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ConfigProposal::Record {
  typedef ConfigProposal type_class;
  int param_id;  	// param_id : int32
  Ref<CellSlice> param_value;  	// param_value : Maybe ^Cell
  Ref<CellSlice> if_hash_equal;  	// if_hash_equal : Maybe uint256
  Record() = default;
  Record(int _param_id, Ref<CellSlice> _param_value, Ref<CellSlice> _if_hash_equal) : param_id(_param_id), param_value(std::move(_param_value)), if_hash_equal(std::move(_if_hash_equal)) {}
};

extern const ConfigProposal t_ConfigProposal;

//
// headers for type `ConfigProposalStatus`
//

struct ConfigProposalStatus final : TLB_Complex {
  enum { cfg_proposal_status };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xce };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConfigProposalStatus";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ConfigProposalStatus::Record {
  typedef ConfigProposalStatus type_class;
  unsigned expires;  	// expires : uint32
  Ref<Cell> proposal;  	// proposal : ^ConfigProposal
  bool is_critical;  	// is_critical : Bool
  Ref<CellSlice> voters;  	// voters : HashmapE 16 True
  long long remaining_weight;  	// remaining_weight : int64
  RefInt256 validator_set_id;  	// validator_set_id : uint256
  int rounds_remaining;  	// rounds_remaining : uint8
  int wins;  	// wins : uint8
  int losses;  	// losses : uint8
  Record() = default;
  Record(unsigned _expires, Ref<Cell> _proposal, bool _is_critical, Ref<CellSlice> _voters, long long _remaining_weight, RefInt256 _validator_set_id, int _rounds_remaining, int _wins, int _losses) : expires(_expires), proposal(std::move(_proposal)), is_critical(_is_critical), voters(std::move(_voters)), remaining_weight(_remaining_weight), validator_set_id(std::move(_validator_set_id)), rounds_remaining(_rounds_remaining), wins(_wins), losses(_losses) {}
};

extern const ConfigProposalStatus t_ConfigProposalStatus;

//
// headers for type `WorkchainFormat`
//

struct WorkchainFormat final : TLB_Complex {
  enum { wfmt_ext, wfmt_basic };
  static constexpr int cons_len_exact = 4;
  int m_;
  WorkchainFormat(int m) : m_(m) {}
  struct Record_wfmt_basic {
    typedef WorkchainFormat type_class;
    int vm_version;  	// vm_version : int32
    unsigned long long vm_mode;  	// vm_mode : uint64
    Record_wfmt_basic() = default;
    Record_wfmt_basic(int _vm_version, unsigned long long _vm_mode) : vm_version(_vm_version), vm_mode(_vm_mode) {}
  };
  struct Record_wfmt_ext;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_wfmt_basic& data) const;
  bool unpack_wfmt_basic(vm::CellSlice& cs, int& vm_version, unsigned long long& vm_mode) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_wfmt_basic& data) const;
  bool cell_unpack_wfmt_basic(Ref<vm::Cell> cell_ref, int& vm_version, unsigned long long& vm_mode) const;
  bool pack(vm::CellBuilder& cb, const Record_wfmt_basic& data) const;
  bool pack_wfmt_basic(vm::CellBuilder& cb, int vm_version, unsigned long long vm_mode) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_wfmt_basic& data) const;
  bool cell_pack_wfmt_basic(Ref<vm::Cell>& cell_ref, int vm_version, unsigned long long vm_mode) const;
  bool unpack(vm::CellSlice& cs, Record_wfmt_ext& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_wfmt_ext& data) const;
  bool pack(vm::CellBuilder& cb, const Record_wfmt_ext& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_wfmt_ext& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(WorkchainFormat " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(4, 3);
  }
};

struct WorkchainFormat::Record_wfmt_ext {
  typedef WorkchainFormat type_class;
  int min_addr_len;  	// min_addr_len : ## 12
  int max_addr_len;  	// max_addr_len : ## 12
  int addr_len_step;  	// addr_len_step : ## 12
  int workchain_type_id;  	// workchain_type_id : ## 32
  Record_wfmt_ext() = default;
  Record_wfmt_ext(int _min_addr_len, int _max_addr_len, int _addr_len_step, int _workchain_type_id) : min_addr_len(_min_addr_len), max_addr_len(_max_addr_len), addr_len_step(_addr_len_step), workchain_type_id(_workchain_type_id) {}
};

//
// headers for type `WorkchainDescr`
//

struct WorkchainDescr final : TLB_Complex {
  enum { workchain };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xa6 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "WorkchainDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct WorkchainDescr::Record {
  typedef WorkchainDescr type_class;
  unsigned enabled_since;  	// enabled_since : uint32
  int actual_min_split;  	// actual_min_split : ## 8
  int min_split;  	// min_split : ## 8
  int max_split;  	// max_split : ## 8
  bool basic;  	// basic : ## 1
  bool active;  	// active : Bool
  bool accept_msgs;  	// accept_msgs : Bool
  int flags;  	// flags : ## 13
  td::BitArray<256> zerostate_root_hash;  	// zerostate_root_hash : bits256
  td::BitArray<256> zerostate_file_hash;  	// zerostate_file_hash : bits256
  unsigned version;  	// version : uint32
  Ref<CellSlice> format;  	// format : WorkchainFormat basic
  Record() = default;
  Record(unsigned _enabled_since, int _actual_min_split, int _min_split, int _max_split, bool _basic, bool _active, bool _accept_msgs, int _flags, const td::BitArray<256>& _zerostate_root_hash, const td::BitArray<256>& _zerostate_file_hash, unsigned _version, Ref<CellSlice> _format) : enabled_since(_enabled_since), actual_min_split(_actual_min_split), min_split(_min_split), max_split(_max_split), basic(_basic), active(_active), accept_msgs(_accept_msgs), flags(_flags), zerostate_root_hash(_zerostate_root_hash), zerostate_file_hash(_zerostate_file_hash), version(_version), format(std::move(_format)) {}
};

extern const WorkchainDescr t_WorkchainDescr;

//
// headers for type `ComplaintPricing`
//

struct ComplaintPricing final : TLB_Complex {
  enum { complaint_prices };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 26 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_complaint_prices(vm::CellSlice& cs, Ref<CellSlice>& deposit, Ref<CellSlice>& bit_price, Ref<CellSlice>& cell_price) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_complaint_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& deposit, Ref<CellSlice>& bit_price, Ref<CellSlice>& cell_price) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_complaint_prices(vm::CellBuilder& cb, Ref<CellSlice> deposit, Ref<CellSlice> bit_price, Ref<CellSlice> cell_price) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_complaint_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> deposit, Ref<CellSlice> bit_price, Ref<CellSlice> cell_price) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ComplaintPricing";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ComplaintPricing::Record {
  typedef ComplaintPricing type_class;
  Ref<CellSlice> deposit;  	// deposit : Grams
  Ref<CellSlice> bit_price;  	// bit_price : Grams
  Ref<CellSlice> cell_price;  	// cell_price : Grams
  Record() = default;
  Record(Ref<CellSlice> _deposit, Ref<CellSlice> _bit_price, Ref<CellSlice> _cell_price) : deposit(std::move(_deposit)), bit_price(std::move(_bit_price)), cell_price(std::move(_cell_price)) {}
};

extern const ComplaintPricing t_ComplaintPricing;

//
// headers for type `BlockCreateFees`
//

struct BlockCreateFees final : TLB_Complex {
  enum { block_grams_created };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x6b };
  struct Record {
    typedef BlockCreateFees type_class;
    Ref<CellSlice> masterchain_block_fee;  	// masterchain_block_fee : Grams
    Ref<CellSlice> basechain_block_fee;  	// basechain_block_fee : Grams
    Record() = default;
    Record(Ref<CellSlice> _masterchain_block_fee, Ref<CellSlice> _basechain_block_fee) : masterchain_block_fee(std::move(_masterchain_block_fee)), basechain_block_fee(std::move(_basechain_block_fee)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_block_grams_created(vm::CellSlice& cs, Ref<CellSlice>& masterchain_block_fee, Ref<CellSlice>& basechain_block_fee) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_block_grams_created(Ref<vm::Cell> cell_ref, Ref<CellSlice>& masterchain_block_fee, Ref<CellSlice>& basechain_block_fee) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_block_grams_created(vm::CellBuilder& cb, Ref<CellSlice> masterchain_block_fee, Ref<CellSlice> basechain_block_fee) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_block_grams_created(Ref<vm::Cell>& cell_ref, Ref<CellSlice> masterchain_block_fee, Ref<CellSlice> basechain_block_fee) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockCreateFees";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const BlockCreateFees t_BlockCreateFees;

//
// headers for type `StoragePrices`
//

struct StoragePrices final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xcc };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 296;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(296);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "StoragePrices";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct StoragePrices::Record {
  typedef StoragePrices type_class;
  unsigned utime_since;  	// utime_since : uint32
  unsigned long long bit_price_ps;  	// bit_price_ps : uint64
  unsigned long long cell_price_ps;  	// cell_price_ps : uint64
  unsigned long long mc_bit_price_ps;  	// mc_bit_price_ps : uint64
  unsigned long long mc_cell_price_ps;  	// mc_cell_price_ps : uint64
  Record() = default;
  Record(unsigned _utime_since, unsigned long long _bit_price_ps, unsigned long long _cell_price_ps, unsigned long long _mc_bit_price_ps, unsigned long long _mc_cell_price_ps) : utime_since(_utime_since), bit_price_ps(_bit_price_ps), cell_price_ps(_cell_price_ps), mc_bit_price_ps(_mc_bit_price_ps), mc_cell_price_ps(_mc_cell_price_ps) {}
};

extern const StoragePrices t_StoragePrices;

//
// headers for type `GasLimitsPrices`
//

struct GasLimitsPrices final : TLB_Complex {
  enum { gas_flat_pfx, gas_prices, gas_prices_ext };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[3] = { 0xd1, 0xdd, 0xde };
  struct Record_gas_prices;
  struct Record_gas_prices_ext;
  struct Record_gas_flat_pfx;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_gas_prices& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_gas_prices& data) const;
  bool pack(vm::CellBuilder& cb, const Record_gas_prices& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_gas_prices& data) const;
  bool unpack(vm::CellSlice& cs, Record_gas_prices_ext& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_gas_prices_ext& data) const;
  bool pack(vm::CellBuilder& cb, const Record_gas_prices_ext& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_gas_prices_ext& data) const;
  bool unpack(vm::CellSlice& cs, Record_gas_flat_pfx& data) const;
  bool unpack_gas_flat_pfx(vm::CellSlice& cs, unsigned long long& flat_gas_limit, unsigned long long& flat_gas_price, Ref<CellSlice>& other) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_gas_flat_pfx& data) const;
  bool cell_unpack_gas_flat_pfx(Ref<vm::Cell> cell_ref, unsigned long long& flat_gas_limit, unsigned long long& flat_gas_price, Ref<CellSlice>& other) const;
  bool pack(vm::CellBuilder& cb, const Record_gas_flat_pfx& data) const;
  bool pack_gas_flat_pfx(vm::CellBuilder& cb, unsigned long long flat_gas_limit, unsigned long long flat_gas_price, Ref<CellSlice> other) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_gas_flat_pfx& data) const;
  bool cell_pack_gas_flat_pfx(Ref<vm::Cell>& cell_ref, unsigned long long flat_gas_limit, unsigned long long flat_gas_price, Ref<CellSlice> other) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "GasLimitsPrices";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct GasLimitsPrices::Record_gas_prices {
  typedef GasLimitsPrices type_class;
  unsigned long long gas_price;  	// gas_price : uint64
  unsigned long long gas_limit;  	// gas_limit : uint64
  unsigned long long gas_credit;  	// gas_credit : uint64
  unsigned long long block_gas_limit;  	// block_gas_limit : uint64
  unsigned long long freeze_due_limit;  	// freeze_due_limit : uint64
  unsigned long long delete_due_limit;  	// delete_due_limit : uint64
  Record_gas_prices() = default;
  Record_gas_prices(unsigned long long _gas_price, unsigned long long _gas_limit, unsigned long long _gas_credit, unsigned long long _block_gas_limit, unsigned long long _freeze_due_limit, unsigned long long _delete_due_limit) : gas_price(_gas_price), gas_limit(_gas_limit), gas_credit(_gas_credit), block_gas_limit(_block_gas_limit), freeze_due_limit(_freeze_due_limit), delete_due_limit(_delete_due_limit) {}
};

struct GasLimitsPrices::Record_gas_prices_ext {
  typedef GasLimitsPrices type_class;
  unsigned long long gas_price;  	// gas_price : uint64
  unsigned long long gas_limit;  	// gas_limit : uint64
  unsigned long long special_gas_limit;  	// special_gas_limit : uint64
  unsigned long long gas_credit;  	// gas_credit : uint64
  unsigned long long block_gas_limit;  	// block_gas_limit : uint64
  unsigned long long freeze_due_limit;  	// freeze_due_limit : uint64
  unsigned long long delete_due_limit;  	// delete_due_limit : uint64
  Record_gas_prices_ext() = default;
  Record_gas_prices_ext(unsigned long long _gas_price, unsigned long long _gas_limit, unsigned long long _special_gas_limit, unsigned long long _gas_credit, unsigned long long _block_gas_limit, unsigned long long _freeze_due_limit, unsigned long long _delete_due_limit) : gas_price(_gas_price), gas_limit(_gas_limit), special_gas_limit(_special_gas_limit), gas_credit(_gas_credit), block_gas_limit(_block_gas_limit), freeze_due_limit(_freeze_due_limit), delete_due_limit(_delete_due_limit) {}
};

struct GasLimitsPrices::Record_gas_flat_pfx {
  typedef GasLimitsPrices type_class;
  unsigned long long flat_gas_limit;  	// flat_gas_limit : uint64
  unsigned long long flat_gas_price;  	// flat_gas_price : uint64
  Ref<CellSlice> other;  	// other : GasLimitsPrices
  Record_gas_flat_pfx() = default;
  Record_gas_flat_pfx(unsigned long long _flat_gas_limit, unsigned long long _flat_gas_price, Ref<CellSlice> _other) : flat_gas_limit(_flat_gas_limit), flat_gas_price(_flat_gas_price), other(std::move(_other)) {}
};

extern const GasLimitsPrices t_GasLimitsPrices;

//
// headers for type `ParamLimits`
//

struct ParamLimits final : TLB_Complex {
  enum { param_limits };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xc3 };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 104;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(104);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_param_limits(vm::CellSlice& cs, int& underload, int& soft_limit, int& hard_limit) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_param_limits(Ref<vm::Cell> cell_ref, int& underload, int& soft_limit, int& hard_limit) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_param_limits(vm::CellBuilder& cb, int underload, int soft_limit, int hard_limit) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_param_limits(Ref<vm::Cell>& cell_ref, int underload, int soft_limit, int hard_limit) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ParamLimits";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ParamLimits::Record {
  typedef ParamLimits type_class;
  int underload;  	// underload : #
  int soft_limit;  	// soft_limit : #
  int hard_limit;  	// hard_limit : #
  Record() = default;
  Record(int _underload, int _soft_limit, int _hard_limit) : underload(_underload), soft_limit(_soft_limit), hard_limit(_hard_limit) {}
};

extern const ParamLimits t_ParamLimits;

//
// headers for type `BlockLimits`
//

struct BlockLimits final : TLB_Complex {
  enum { block_limits };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x5d };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 320;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(320);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_block_limits(vm::CellSlice& cs, Ref<CellSlice>& bytes, Ref<CellSlice>& gas, Ref<CellSlice>& lt_delta) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& bytes, Ref<CellSlice>& gas, Ref<CellSlice>& lt_delta) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_block_limits(vm::CellBuilder& cb, Ref<CellSlice> bytes, Ref<CellSlice> gas, Ref<CellSlice> lt_delta) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> bytes, Ref<CellSlice> gas, Ref<CellSlice> lt_delta) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockLimits";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockLimits::Record {
  typedef BlockLimits type_class;
  Ref<CellSlice> bytes;  	// bytes : ParamLimits
  Ref<CellSlice> gas;  	// gas : ParamLimits
  Ref<CellSlice> lt_delta;  	// lt_delta : ParamLimits
  Record() = default;
  Record(Ref<CellSlice> _bytes, Ref<CellSlice> _gas, Ref<CellSlice> _lt_delta) : bytes(std::move(_bytes)), gas(std::move(_gas)), lt_delta(std::move(_lt_delta)) {}
};

extern const BlockLimits t_BlockLimits;

//
// headers for type `MsgForwardPrices`
//

struct MsgForwardPrices final : TLB_Complex {
  enum { msg_forward_prices };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xea };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 264;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(264);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "MsgForwardPrices";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct MsgForwardPrices::Record {
  typedef MsgForwardPrices type_class;
  unsigned long long lump_price;  	// lump_price : uint64
  unsigned long long bit_price;  	// bit_price : uint64
  unsigned long long cell_price;  	// cell_price : uint64
  unsigned ihr_price_factor;  	// ihr_price_factor : uint32
  int first_frac;  	// first_frac : uint16
  int next_frac;  	// next_frac : uint16
  Record() = default;
  Record(unsigned long long _lump_price, unsigned long long _bit_price, unsigned long long _cell_price, unsigned _ihr_price_factor, int _first_frac, int _next_frac) : lump_price(_lump_price), bit_price(_bit_price), cell_price(_cell_price), ihr_price_factor(_ihr_price_factor), first_frac(_first_frac), next_frac(_next_frac) {}
};

extern const MsgForwardPrices t_MsgForwardPrices;

//
// headers for type `CatchainConfig`
//

struct CatchainConfig final : TLB_Complex {
  enum { catchain_config, catchain_config_new };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[2] = { 0xc1, 0xc2 };
  struct Record_catchain_config;
  struct Record_catchain_config_new;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_catchain_config& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_catchain_config& data) const;
  bool pack(vm::CellBuilder& cb, const Record_catchain_config& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_catchain_config& data) const;
  bool unpack(vm::CellSlice& cs, Record_catchain_config_new& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_catchain_config_new& data) const;
  bool pack(vm::CellBuilder& cb, const Record_catchain_config_new& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_catchain_config_new& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "CatchainConfig";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct CatchainConfig::Record_catchain_config {
  typedef CatchainConfig type_class;
  unsigned mc_catchain_lifetime;  	// mc_catchain_lifetime : uint32
  unsigned shard_catchain_lifetime;  	// shard_catchain_lifetime : uint32
  unsigned shard_validators_lifetime;  	// shard_validators_lifetime : uint32
  unsigned shard_validators_num;  	// shard_validators_num : uint32
  Record_catchain_config() = default;
  Record_catchain_config(unsigned _mc_catchain_lifetime, unsigned _shard_catchain_lifetime, unsigned _shard_validators_lifetime, unsigned _shard_validators_num) : mc_catchain_lifetime(_mc_catchain_lifetime), shard_catchain_lifetime(_shard_catchain_lifetime), shard_validators_lifetime(_shard_validators_lifetime), shard_validators_num(_shard_validators_num) {}
};

struct CatchainConfig::Record_catchain_config_new {
  typedef CatchainConfig type_class;
  int flags;  	// flags : ## 7
  bool shuffle_mc_validators;  	// shuffle_mc_validators : Bool
  unsigned mc_catchain_lifetime;  	// mc_catchain_lifetime : uint32
  unsigned shard_catchain_lifetime;  	// shard_catchain_lifetime : uint32
  unsigned shard_validators_lifetime;  	// shard_validators_lifetime : uint32
  unsigned shard_validators_num;  	// shard_validators_num : uint32
  Record_catchain_config_new() = default;
  Record_catchain_config_new(int _flags, bool _shuffle_mc_validators, unsigned _mc_catchain_lifetime, unsigned _shard_catchain_lifetime, unsigned _shard_validators_lifetime, unsigned _shard_validators_num) : flags(_flags), shuffle_mc_validators(_shuffle_mc_validators), mc_catchain_lifetime(_mc_catchain_lifetime), shard_catchain_lifetime(_shard_catchain_lifetime), shard_validators_lifetime(_shard_validators_lifetime), shard_validators_num(_shard_validators_num) {}
};

extern const CatchainConfig t_CatchainConfig;

//
// headers for type `ConsensusConfig`
//

struct ConsensusConfig final : TLB_Complex {
  enum { consensus_config, consensus_config_new };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[2] = { 0xd6, 0xd7 };
  struct Record_consensus_config;
  struct Record_consensus_config_new;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_consensus_config& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_consensus_config& data) const;
  bool pack(vm::CellBuilder& cb, const Record_consensus_config& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_consensus_config& data) const;
  bool unpack(vm::CellSlice& cs, Record_consensus_config_new& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_consensus_config_new& data) const;
  bool pack(vm::CellBuilder& cb, const Record_consensus_config_new& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_consensus_config_new& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ConsensusConfig";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct ConsensusConfig::Record_consensus_config {
  typedef ConsensusConfig type_class;
  int round_candidates;  	// round_candidates : #
  unsigned next_candidate_delay_ms;  	// next_candidate_delay_ms : uint32
  unsigned consensus_timeout_ms;  	// consensus_timeout_ms : uint32
  unsigned fast_attempts;  	// fast_attempts : uint32
  unsigned attempt_duration;  	// attempt_duration : uint32
  unsigned catchain_max_deps;  	// catchain_max_deps : uint32
  unsigned max_block_bytes;  	// max_block_bytes : uint32
  unsigned max_collated_bytes;  	// max_collated_bytes : uint32
  Record_consensus_config() = default;
  Record_consensus_config(int _round_candidates, unsigned _next_candidate_delay_ms, unsigned _consensus_timeout_ms, unsigned _fast_attempts, unsigned _attempt_duration, unsigned _catchain_max_deps, unsigned _max_block_bytes, unsigned _max_collated_bytes) : round_candidates(_round_candidates), next_candidate_delay_ms(_next_candidate_delay_ms), consensus_timeout_ms(_consensus_timeout_ms), fast_attempts(_fast_attempts), attempt_duration(_attempt_duration), catchain_max_deps(_catchain_max_deps), max_block_bytes(_max_block_bytes), max_collated_bytes(_max_collated_bytes) {}
};

struct ConsensusConfig::Record_consensus_config_new {
  typedef ConsensusConfig type_class;
  int flags;  	// flags : ## 7
  bool new_catchain_ids;  	// new_catchain_ids : Bool
  int round_candidates;  	// round_candidates : ## 8
  unsigned next_candidate_delay_ms;  	// next_candidate_delay_ms : uint32
  unsigned consensus_timeout_ms;  	// consensus_timeout_ms : uint32
  unsigned fast_attempts;  	// fast_attempts : uint32
  unsigned attempt_duration;  	// attempt_duration : uint32
  unsigned catchain_max_deps;  	// catchain_max_deps : uint32
  unsigned max_block_bytes;  	// max_block_bytes : uint32
  unsigned max_collated_bytes;  	// max_collated_bytes : uint32
  Record_consensus_config_new() = default;
  Record_consensus_config_new(int _flags, bool _new_catchain_ids, int _round_candidates, unsigned _next_candidate_delay_ms, unsigned _consensus_timeout_ms, unsigned _fast_attempts, unsigned _attempt_duration, unsigned _catchain_max_deps, unsigned _max_block_bytes, unsigned _max_collated_bytes) : flags(_flags), new_catchain_ids(_new_catchain_ids), round_candidates(_round_candidates), next_candidate_delay_ms(_next_candidate_delay_ms), consensus_timeout_ms(_consensus_timeout_ms), fast_attempts(_fast_attempts), attempt_duration(_attempt_duration), catchain_max_deps(_catchain_max_deps), max_block_bytes(_max_block_bytes), max_collated_bytes(_max_collated_bytes) {}
};

extern const ConsensusConfig t_ConsensusConfig;

//
// headers for type `ValidatorTempKey`
//

struct ValidatorTempKey final : TLB_Complex {
  enum { validator_temp_key };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 3 };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 612;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(612);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorTempKey";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValidatorTempKey::Record {
  typedef ValidatorTempKey type_class;
  td::BitArray<256> adnl_addr;  	// adnl_addr : bits256
  Ref<CellSlice> temp_public_key;  	// temp_public_key : SigPubKey
  int seqno;  	// seqno : #
  unsigned valid_until;  	// valid_until : uint32
  Record() = default;
  Record(const td::BitArray<256>& _adnl_addr, Ref<CellSlice> _temp_public_key, int _seqno, unsigned _valid_until) : adnl_addr(_adnl_addr), temp_public_key(std::move(_temp_public_key)), seqno(_seqno), valid_until(_valid_until) {}
};

extern const ValidatorTempKey t_ValidatorTempKey;

//
// headers for type `ValidatorSignedTempKey`
//

struct ValidatorSignedTempKey final : TLB_Complex {
  enum { signed_temp_key };
  static constexpr int cons_len_exact = 4;
  static constexpr unsigned char cons_tag[1] = { 4 };
  struct Record {
    typedef ValidatorSignedTempKey type_class;
    Ref<Cell> key;  	// key : ^ValidatorTempKey
    Ref<CellSlice> signature;  	// signature : CryptoSignature
    Record() = default;
    Record(Ref<Cell> _key, Ref<CellSlice> _signature) : key(std::move(_key)), signature(std::move(_signature)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_signed_temp_key(vm::CellSlice& cs, Ref<Cell>& key, Ref<CellSlice>& signature) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_signed_temp_key(Ref<vm::Cell> cell_ref, Ref<Cell>& key, Ref<CellSlice>& signature) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_signed_temp_key(vm::CellBuilder& cb, Ref<Cell> key, Ref<CellSlice> signature) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_signed_temp_key(Ref<vm::Cell>& cell_ref, Ref<Cell> key, Ref<CellSlice> signature) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorSignedTempKey";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ValidatorSignedTempKey t_ValidatorSignedTempKey;

//
// headers for type `ConfigParam`
//

struct ConfigParam final : TLB_Complex {
  enum { cons32, cons33, cons34, cons35, cons36, cons37, cons13, config_mc_block_limits, config_block_limits, cons14, cons0, cons1, cons2, cons3, cons4, cons6, cons7, cons9, cons10, cons12, cons15, cons16, cons17, cons18, cons31, cons39, cons11, cons28, cons8, config_mc_gas_prices, config_gas_prices, cons29, config_mc_fwd_prices, config_fwd_prices };
  static constexpr int cons_len_exact = 0;
  int m_;
  ConfigParam(int m) : m_(m) {}
  struct Record_cons0 {
    typedef ConfigParam type_class;
    td::BitArray<256> config_addr;  	// config_addr : bits256
    Record_cons0() = default;
    Record_cons0(const td::BitArray<256>& _config_addr) : config_addr(_config_addr) {}
  };
  struct Record_cons1 {
    typedef ConfigParam type_class;
    td::BitArray<256> elector_addr;  	// elector_addr : bits256
    Record_cons1() = default;
    Record_cons1(const td::BitArray<256>& _elector_addr) : elector_addr(_elector_addr) {}
  };
  struct Record_cons2 {
    typedef ConfigParam type_class;
    td::BitArray<256> minter_addr;  	// minter_addr : bits256
    Record_cons2() = default;
    Record_cons2(const td::BitArray<256>& _minter_addr) : minter_addr(_minter_addr) {}
  };
  struct Record_cons3 {
    typedef ConfigParam type_class;
    td::BitArray<256> fee_collector_addr;  	// fee_collector_addr : bits256
    Record_cons3() = default;
    Record_cons3(const td::BitArray<256>& _fee_collector_addr) : fee_collector_addr(_fee_collector_addr) {}
  };
  struct Record_cons4 {
    typedef ConfigParam type_class;
    td::BitArray<256> dns_root_addr;  	// dns_root_addr : bits256
    Record_cons4() = default;
    Record_cons4(const td::BitArray<256>& _dns_root_addr) : dns_root_addr(_dns_root_addr) {}
  };
  struct Record_cons6 {
    typedef ConfigParam type_class;
    Ref<CellSlice> mint_new_price;  	// mint_new_price : Grams
    Ref<CellSlice> mint_add_price;  	// mint_add_price : Grams
    Record_cons6() = default;
    Record_cons6(Ref<CellSlice> _mint_new_price, Ref<CellSlice> _mint_add_price) : mint_new_price(std::move(_mint_new_price)), mint_add_price(std::move(_mint_add_price)) {}
  };
  struct Record_cons7 {
    typedef ConfigParam type_class;
    Ref<CellSlice> to_mint;  	// to_mint : ExtraCurrencyCollection
    Record_cons7() = default;
    Record_cons7(Ref<CellSlice> _to_mint) : to_mint(std::move(_to_mint)) {}
  };
  struct Record_cons8 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// GlobalVersion
    Record_cons8() = default;
    Record_cons8(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons9 {
    typedef ConfigParam type_class;
    Ref<CellSlice> mandatory_params;  	// mandatory_params : Hashmap 32 True
    Record_cons9() = default;
    Record_cons9(Ref<CellSlice> _mandatory_params) : mandatory_params(std::move(_mandatory_params)) {}
  };
  struct Record_cons10 {
    typedef ConfigParam type_class;
    Ref<CellSlice> critical_params;  	// critical_params : Hashmap 32 True
    Record_cons10() = default;
    Record_cons10(Ref<CellSlice> _critical_params) : critical_params(std::move(_critical_params)) {}
  };
  struct Record_cons11 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// ConfigVotingSetup
    Record_cons11() = default;
    Record_cons11(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons12 {
    typedef ConfigParam type_class;
    Ref<CellSlice> workchains;  	// workchains : HashmapE 32 WorkchainDescr
    Record_cons12() = default;
    Record_cons12(Ref<CellSlice> _workchains) : workchains(std::move(_workchains)) {}
  };
  struct Record_cons13 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// ComplaintPricing
    Record_cons13() = default;
    Record_cons13(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons14 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// BlockCreateFees
    Record_cons14() = default;
    Record_cons14(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons15;
  struct Record_cons16;
  struct Record_cons17;
  struct Record_cons18 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// Hashmap 32 StoragePrices
    Record_cons18() = default;
    Record_cons18(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_mc_gas_prices {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// GasLimitsPrices
    Record_config_mc_gas_prices() = default;
    Record_config_mc_gas_prices(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_gas_prices {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// GasLimitsPrices
    Record_config_gas_prices() = default;
    Record_config_gas_prices(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_mc_block_limits {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// BlockLimits
    Record_config_mc_block_limits() = default;
    Record_config_mc_block_limits(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_block_limits {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// BlockLimits
    Record_config_block_limits() = default;
    Record_config_block_limits(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_mc_fwd_prices {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// MsgForwardPrices
    Record_config_mc_fwd_prices() = default;
    Record_config_mc_fwd_prices(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_config_fwd_prices {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// MsgForwardPrices
    Record_config_fwd_prices() = default;
    Record_config_fwd_prices(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons28 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// CatchainConfig
    Record_cons28() = default;
    Record_cons28(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons29 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// ConsensusConfig
    Record_cons29() = default;
    Record_cons29(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_cons31 {
    typedef ConfigParam type_class;
    Ref<CellSlice> fundamental_smc_addr;  	// fundamental_smc_addr : HashmapE 256 True
    Record_cons31() = default;
    Record_cons31(Ref<CellSlice> _fundamental_smc_addr) : fundamental_smc_addr(std::move(_fundamental_smc_addr)) {}
  };
  struct Record_cons32 {
    typedef ConfigParam type_class;
    Ref<CellSlice> prev_validators;  	// prev_validators : ValidatorSet
    Record_cons32() = default;
    Record_cons32(Ref<CellSlice> _prev_validators) : prev_validators(std::move(_prev_validators)) {}
  };
  struct Record_cons33 {
    typedef ConfigParam type_class;
    Ref<CellSlice> prev_temp_validators;  	// prev_temp_validators : ValidatorSet
    Record_cons33() = default;
    Record_cons33(Ref<CellSlice> _prev_temp_validators) : prev_temp_validators(std::move(_prev_temp_validators)) {}
  };
  struct Record_cons34 {
    typedef ConfigParam type_class;
    Ref<CellSlice> cur_validators;  	// cur_validators : ValidatorSet
    Record_cons34() = default;
    Record_cons34(Ref<CellSlice> _cur_validators) : cur_validators(std::move(_cur_validators)) {}
  };
  struct Record_cons35 {
    typedef ConfigParam type_class;
    Ref<CellSlice> cur_temp_validators;  	// cur_temp_validators : ValidatorSet
    Record_cons35() = default;
    Record_cons35(Ref<CellSlice> _cur_temp_validators) : cur_temp_validators(std::move(_cur_temp_validators)) {}
  };
  struct Record_cons36 {
    typedef ConfigParam type_class;
    Ref<CellSlice> next_validators;  	// next_validators : ValidatorSet
    Record_cons36() = default;
    Record_cons36(Ref<CellSlice> _next_validators) : next_validators(std::move(_next_validators)) {}
  };
  struct Record_cons37 {
    typedef ConfigParam type_class;
    Ref<CellSlice> next_temp_validators;  	// next_temp_validators : ValidatorSet
    Record_cons37() = default;
    Record_cons37(Ref<CellSlice> _next_temp_validators) : next_temp_validators(std::move(_next_temp_validators)) {}
  };
  struct Record_cons39 {
    typedef ConfigParam type_class;
    Ref<CellSlice> x;  	// HashmapE 256 ValidatorSignedTempKey
    Record_cons39() = default;
    Record_cons39(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cons0& data) const;
  bool unpack_cons0(vm::CellSlice& cs, td::BitArray<256>& config_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons0& data) const;
  bool cell_unpack_cons0(Ref<vm::Cell> cell_ref, td::BitArray<256>& config_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons0& data) const;
  bool pack_cons0(vm::CellBuilder& cb, td::BitArray<256> config_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons0& data) const;
  bool cell_pack_cons0(Ref<vm::Cell>& cell_ref, td::BitArray<256> config_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons1& data) const;
  bool unpack_cons1(vm::CellSlice& cs, td::BitArray<256>& elector_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons1& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, td::BitArray<256>& elector_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons1& data) const;
  bool pack_cons1(vm::CellBuilder& cb, td::BitArray<256> elector_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons1& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, td::BitArray<256> elector_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons2& data) const;
  bool unpack_cons2(vm::CellSlice& cs, td::BitArray<256>& minter_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons2& data) const;
  bool cell_unpack_cons2(Ref<vm::Cell> cell_ref, td::BitArray<256>& minter_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons2& data) const;
  bool pack_cons2(vm::CellBuilder& cb, td::BitArray<256> minter_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons2& data) const;
  bool cell_pack_cons2(Ref<vm::Cell>& cell_ref, td::BitArray<256> minter_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons3& data) const;
  bool unpack_cons3(vm::CellSlice& cs, td::BitArray<256>& fee_collector_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons3& data) const;
  bool cell_unpack_cons3(Ref<vm::Cell> cell_ref, td::BitArray<256>& fee_collector_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons3& data) const;
  bool pack_cons3(vm::CellBuilder& cb, td::BitArray<256> fee_collector_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons3& data) const;
  bool cell_pack_cons3(Ref<vm::Cell>& cell_ref, td::BitArray<256> fee_collector_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons4& data) const;
  bool unpack_cons4(vm::CellSlice& cs, td::BitArray<256>& dns_root_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons4& data) const;
  bool cell_unpack_cons4(Ref<vm::Cell> cell_ref, td::BitArray<256>& dns_root_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons4& data) const;
  bool pack_cons4(vm::CellBuilder& cb, td::BitArray<256> dns_root_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons4& data) const;
  bool cell_pack_cons4(Ref<vm::Cell>& cell_ref, td::BitArray<256> dns_root_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons6& data) const;
  bool unpack_cons6(vm::CellSlice& cs, Ref<CellSlice>& mint_new_price, Ref<CellSlice>& mint_add_price) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons6& data) const;
  bool cell_unpack_cons6(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mint_new_price, Ref<CellSlice>& mint_add_price) const;
  bool pack(vm::CellBuilder& cb, const Record_cons6& data) const;
  bool pack_cons6(vm::CellBuilder& cb, Ref<CellSlice> mint_new_price, Ref<CellSlice> mint_add_price) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons6& data) const;
  bool cell_pack_cons6(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mint_new_price, Ref<CellSlice> mint_add_price) const;
  bool unpack(vm::CellSlice& cs, Record_cons7& data) const;
  bool unpack_cons7(vm::CellSlice& cs, Ref<CellSlice>& to_mint) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons7& data) const;
  bool cell_unpack_cons7(Ref<vm::Cell> cell_ref, Ref<CellSlice>& to_mint) const;
  bool pack(vm::CellBuilder& cb, const Record_cons7& data) const;
  bool pack_cons7(vm::CellBuilder& cb, Ref<CellSlice> to_mint) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons7& data) const;
  bool cell_pack_cons7(Ref<vm::Cell>& cell_ref, Ref<CellSlice> to_mint) const;
  bool unpack(vm::CellSlice& cs, Record_cons8& data) const;
  bool unpack_cons8(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons8& data) const;
  bool cell_unpack_cons8(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons8& data) const;
  bool pack_cons8(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons8& data) const;
  bool cell_pack_cons8(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons9& data) const;
  bool unpack_cons9(vm::CellSlice& cs, Ref<CellSlice>& mandatory_params) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons9& data) const;
  bool cell_unpack_cons9(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mandatory_params) const;
  bool pack(vm::CellBuilder& cb, const Record_cons9& data) const;
  bool pack_cons9(vm::CellBuilder& cb, Ref<CellSlice> mandatory_params) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons9& data) const;
  bool cell_pack_cons9(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mandatory_params) const;
  bool unpack(vm::CellSlice& cs, Record_cons10& data) const;
  bool unpack_cons10(vm::CellSlice& cs, Ref<CellSlice>& critical_params) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons10& data) const;
  bool cell_unpack_cons10(Ref<vm::Cell> cell_ref, Ref<CellSlice>& critical_params) const;
  bool pack(vm::CellBuilder& cb, const Record_cons10& data) const;
  bool pack_cons10(vm::CellBuilder& cb, Ref<CellSlice> critical_params) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons10& data) const;
  bool cell_pack_cons10(Ref<vm::Cell>& cell_ref, Ref<CellSlice> critical_params) const;
  bool unpack(vm::CellSlice& cs, Record_cons11& data) const;
  bool unpack_cons11(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons11& data) const;
  bool cell_unpack_cons11(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons11& data) const;
  bool pack_cons11(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons11& data) const;
  bool cell_pack_cons11(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons12& data) const;
  bool unpack_cons12(vm::CellSlice& cs, Ref<CellSlice>& workchains) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons12& data) const;
  bool cell_unpack_cons12(Ref<vm::Cell> cell_ref, Ref<CellSlice>& workchains) const;
  bool pack(vm::CellBuilder& cb, const Record_cons12& data) const;
  bool pack_cons12(vm::CellBuilder& cb, Ref<CellSlice> workchains) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons12& data) const;
  bool cell_pack_cons12(Ref<vm::Cell>& cell_ref, Ref<CellSlice> workchains) const;
  bool unpack(vm::CellSlice& cs, Record_cons13& data) const;
  bool unpack_cons13(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons13& data) const;
  bool cell_unpack_cons13(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons13& data) const;
  bool pack_cons13(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons13& data) const;
  bool cell_pack_cons13(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons14& data) const;
  bool unpack_cons14(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons14& data) const;
  bool cell_unpack_cons14(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons14& data) const;
  bool pack_cons14(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons14& data) const;
  bool cell_pack_cons14(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons15& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons15& data) const;
  bool pack(vm::CellBuilder& cb, const Record_cons15& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons15& data) const;
  bool unpack(vm::CellSlice& cs, Record_cons16& data) const;
  bool unpack_cons16(vm::CellSlice& cs, int& max_validators, int& max_main_validators, int& min_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons16& data) const;
  bool cell_unpack_cons16(Ref<vm::Cell> cell_ref, int& max_validators, int& max_main_validators, int& min_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons16& data) const;
  bool pack_cons16(vm::CellBuilder& cb, int max_validators, int max_main_validators, int min_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons16& data) const;
  bool cell_pack_cons16(Ref<vm::Cell>& cell_ref, int max_validators, int max_main_validators, int min_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons17& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons17& data) const;
  bool pack(vm::CellBuilder& cb, const Record_cons17& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons17& data) const;
  bool unpack(vm::CellSlice& cs, Record_cons18& data) const;
  bool unpack_cons18(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons18& data) const;
  bool cell_unpack_cons18(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons18& data) const;
  bool pack_cons18(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons18& data) const;
  bool cell_pack_cons18(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_mc_gas_prices& data) const;
  bool unpack_config_mc_gas_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_mc_gas_prices& data) const;
  bool cell_unpack_config_mc_gas_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_mc_gas_prices& data) const;
  bool pack_config_mc_gas_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_mc_gas_prices& data) const;
  bool cell_pack_config_mc_gas_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_gas_prices& data) const;
  bool unpack_config_gas_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_gas_prices& data) const;
  bool cell_unpack_config_gas_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_gas_prices& data) const;
  bool pack_config_gas_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_gas_prices& data) const;
  bool cell_pack_config_gas_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_mc_block_limits& data) const;
  bool unpack_config_mc_block_limits(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_mc_block_limits& data) const;
  bool cell_unpack_config_mc_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_mc_block_limits& data) const;
  bool pack_config_mc_block_limits(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_mc_block_limits& data) const;
  bool cell_pack_config_mc_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_block_limits& data) const;
  bool unpack_config_block_limits(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_block_limits& data) const;
  bool cell_unpack_config_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_block_limits& data) const;
  bool pack_config_block_limits(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_block_limits& data) const;
  bool cell_pack_config_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_mc_fwd_prices& data) const;
  bool unpack_config_mc_fwd_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_mc_fwd_prices& data) const;
  bool cell_unpack_config_mc_fwd_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_mc_fwd_prices& data) const;
  bool pack_config_mc_fwd_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_mc_fwd_prices& data) const;
  bool cell_pack_config_mc_fwd_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_config_fwd_prices& data) const;
  bool unpack_config_fwd_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_config_fwd_prices& data) const;
  bool cell_unpack_config_fwd_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_config_fwd_prices& data) const;
  bool pack_config_fwd_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_config_fwd_prices& data) const;
  bool cell_pack_config_fwd_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons28& data) const;
  bool unpack_cons28(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons28& data) const;
  bool cell_unpack_cons28(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons28& data) const;
  bool pack_cons28(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons28& data) const;
  bool cell_pack_cons28(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons29& data) const;
  bool unpack_cons29(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons29& data) const;
  bool cell_unpack_cons29(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons29& data) const;
  bool pack_cons29(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons29& data) const;
  bool cell_pack_cons29(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_cons31& data) const;
  bool unpack_cons31(vm::CellSlice& cs, Ref<CellSlice>& fundamental_smc_addr) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons31& data) const;
  bool cell_unpack_cons31(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fundamental_smc_addr) const;
  bool pack(vm::CellBuilder& cb, const Record_cons31& data) const;
  bool pack_cons31(vm::CellBuilder& cb, Ref<CellSlice> fundamental_smc_addr) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons31& data) const;
  bool cell_pack_cons31(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fundamental_smc_addr) const;
  bool unpack(vm::CellSlice& cs, Record_cons32& data) const;
  bool unpack_cons32(vm::CellSlice& cs, Ref<CellSlice>& prev_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons32& data) const;
  bool cell_unpack_cons32(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons32& data) const;
  bool pack_cons32(vm::CellBuilder& cb, Ref<CellSlice> prev_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons32& data) const;
  bool cell_pack_cons32(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons33& data) const;
  bool unpack_cons33(vm::CellSlice& cs, Ref<CellSlice>& prev_temp_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons33& data) const;
  bool cell_unpack_cons33(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_temp_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons33& data) const;
  bool pack_cons33(vm::CellBuilder& cb, Ref<CellSlice> prev_temp_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons33& data) const;
  bool cell_pack_cons33(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_temp_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons34& data) const;
  bool unpack_cons34(vm::CellSlice& cs, Ref<CellSlice>& cur_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons34& data) const;
  bool cell_unpack_cons34(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cur_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons34& data) const;
  bool pack_cons34(vm::CellBuilder& cb, Ref<CellSlice> cur_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons34& data) const;
  bool cell_pack_cons34(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cur_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons35& data) const;
  bool unpack_cons35(vm::CellSlice& cs, Ref<CellSlice>& cur_temp_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons35& data) const;
  bool cell_unpack_cons35(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cur_temp_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons35& data) const;
  bool pack_cons35(vm::CellBuilder& cb, Ref<CellSlice> cur_temp_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons35& data) const;
  bool cell_pack_cons35(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cur_temp_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons36& data) const;
  bool unpack_cons36(vm::CellSlice& cs, Ref<CellSlice>& next_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons36& data) const;
  bool cell_unpack_cons36(Ref<vm::Cell> cell_ref, Ref<CellSlice>& next_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons36& data) const;
  bool pack_cons36(vm::CellBuilder& cb, Ref<CellSlice> next_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons36& data) const;
  bool cell_pack_cons36(Ref<vm::Cell>& cell_ref, Ref<CellSlice> next_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons37& data) const;
  bool unpack_cons37(vm::CellSlice& cs, Ref<CellSlice>& next_temp_validators) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons37& data) const;
  bool cell_unpack_cons37(Ref<vm::Cell> cell_ref, Ref<CellSlice>& next_temp_validators) const;
  bool pack(vm::CellBuilder& cb, const Record_cons37& data) const;
  bool pack_cons37(vm::CellBuilder& cb, Ref<CellSlice> next_temp_validators) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons37& data) const;
  bool cell_pack_cons37(Ref<vm::Cell>& cell_ref, Ref<CellSlice> next_temp_validators) const;
  bool unpack(vm::CellSlice& cs, Record_cons39& data) const;
  bool unpack_cons39(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cons39& data) const;
  bool cell_unpack_cons39(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_cons39& data) const;
  bool pack_cons39(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cons39& data) const;
  bool cell_pack_cons39(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(ConfigParam " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct ConfigParam::Record_cons15 {
  typedef ConfigParam type_class;
  unsigned validators_elected_for;  	// validators_elected_for : uint32
  unsigned elections_start_before;  	// elections_start_before : uint32
  unsigned elections_end_before;  	// elections_end_before : uint32
  unsigned stake_held_for;  	// stake_held_for : uint32
  Record_cons15() = default;
  Record_cons15(unsigned _validators_elected_for, unsigned _elections_start_before, unsigned _elections_end_before, unsigned _stake_held_for) : validators_elected_for(_validators_elected_for), elections_start_before(_elections_start_before), elections_end_before(_elections_end_before), stake_held_for(_stake_held_for) {}
};

struct ConfigParam::Record_cons16 {
  typedef ConfigParam type_class;
  int max_validators;  	// max_validators : ## 16
  int max_main_validators;  	// max_main_validators : ## 16
  int min_validators;  	// min_validators : ## 16
  Record_cons16() = default;
  Record_cons16(int _max_validators, int _max_main_validators, int _min_validators) : max_validators(_max_validators), max_main_validators(_max_main_validators), min_validators(_min_validators) {}
};

struct ConfigParam::Record_cons17 {
  typedef ConfigParam type_class;
  Ref<CellSlice> min_stake;  	// min_stake : Grams
  Ref<CellSlice> max_stake;  	// max_stake : Grams
  Ref<CellSlice> min_total_stake;  	// min_total_stake : Grams
  unsigned max_stake_factor;  	// max_stake_factor : uint32
  Record_cons17() = default;
  Record_cons17(Ref<CellSlice> _min_stake, Ref<CellSlice> _max_stake, Ref<CellSlice> _min_total_stake, unsigned _max_stake_factor) : min_stake(std::move(_min_stake)), max_stake(std::move(_max_stake)), min_total_stake(std::move(_min_total_stake)), max_stake_factor(_max_stake_factor) {}
};

//
// headers for type `BlockSignaturesPure`
//

struct BlockSignaturesPure final : TLB_Complex {
  enum { block_signatures_pure };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_block_signatures_pure(vm::CellSlice& cs, unsigned& sig_count, unsigned long long& sig_weight, Ref<CellSlice>& signatures) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_block_signatures_pure(Ref<vm::Cell> cell_ref, unsigned& sig_count, unsigned long long& sig_weight, Ref<CellSlice>& signatures) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_block_signatures_pure(vm::CellBuilder& cb, unsigned sig_count, unsigned long long sig_weight, Ref<CellSlice> signatures) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_block_signatures_pure(Ref<vm::Cell>& cell_ref, unsigned sig_count, unsigned long long sig_weight, Ref<CellSlice> signatures) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockSignaturesPure";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockSignaturesPure::Record {
  typedef BlockSignaturesPure type_class;
  unsigned sig_count;  	// sig_count : uint32
  unsigned long long sig_weight;  	// sig_weight : uint64
  Ref<CellSlice> signatures;  	// signatures : HashmapE 16 CryptoSignaturePair
  Record() = default;
  Record(unsigned _sig_count, unsigned long long _sig_weight, Ref<CellSlice> _signatures) : sig_count(_sig_count), sig_weight(_sig_weight), signatures(std::move(_signatures)) {}
};

extern const BlockSignaturesPure t_BlockSignaturesPure;

//
// headers for type `BlockSignatures`
//

struct BlockSignatures final : TLB_Complex {
  enum { block_signatures };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 17 };
  struct Record {
    typedef BlockSignatures type_class;
    Ref<CellSlice> validator_info;  	// validator_info : ValidatorBaseInfo
    Ref<CellSlice> pure_signatures;  	// pure_signatures : BlockSignaturesPure
    Record() = default;
    Record(Ref<CellSlice> _validator_info, Ref<CellSlice> _pure_signatures) : validator_info(std::move(_validator_info)), pure_signatures(std::move(_pure_signatures)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_block_signatures(vm::CellSlice& cs, Ref<CellSlice>& validator_info, Ref<CellSlice>& pure_signatures) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_block_signatures(Ref<vm::Cell> cell_ref, Ref<CellSlice>& validator_info, Ref<CellSlice>& pure_signatures) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_block_signatures(vm::CellBuilder& cb, Ref<CellSlice> validator_info, Ref<CellSlice> pure_signatures) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_block_signatures(Ref<vm::Cell>& cell_ref, Ref<CellSlice> validator_info, Ref<CellSlice> pure_signatures) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockSignatures";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const BlockSignatures t_BlockSignatures;

//
// headers for type `BlockProof`
//

struct BlockProof final : TLB_Complex {
  enum { block_proof };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xc3 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_block_proof(vm::CellSlice& cs, Ref<CellSlice>& proof_for, Ref<Cell>& root, Ref<CellSlice>& signatures) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_block_proof(Ref<vm::Cell> cell_ref, Ref<CellSlice>& proof_for, Ref<Cell>& root, Ref<CellSlice>& signatures) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_block_proof(vm::CellBuilder& cb, Ref<CellSlice> proof_for, Ref<Cell> root, Ref<CellSlice> signatures) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_block_proof(Ref<vm::Cell>& cell_ref, Ref<CellSlice> proof_for, Ref<Cell> root, Ref<CellSlice> signatures) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "BlockProof";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct BlockProof::Record {
  typedef BlockProof type_class;
  Ref<CellSlice> proof_for;  	// proof_for : BlockIdExt
  Ref<Cell> root;  	// root : ^Cell
  Ref<CellSlice> signatures;  	// signatures : Maybe ^BlockSignatures
  Record() = default;
  Record(Ref<CellSlice> _proof_for, Ref<Cell> _root, Ref<CellSlice> _signatures) : proof_for(std::move(_proof_for)), root(std::move(_root)), signatures(std::move(_signatures)) {}
};

extern const BlockProof t_BlockProof;

//
// headers for type `ProofChain`
//

struct ProofChain final : TLB_Complex {
  enum { chain_empty, chain_link };
  static constexpr int cons_len_exact = 0;
  int m_;
  ProofChain(int m) : m_(m) {}
  struct Record_chain_empty {
    typedef ProofChain type_class;
  };
  struct Record_chain_link;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_chain_empty& data) const;
  bool unpack_chain_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chain_empty& data) const;
  bool cell_unpack_chain_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_chain_empty& data) const;
  bool pack_chain_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chain_empty& data) const;
  bool cell_pack_chain_empty(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_chain_link& data) const;
  bool unpack_chain_link(vm::CellSlice& cs, int& n, Ref<Cell>& root, Ref<Cell>& prev) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chain_link& data) const;
  bool cell_unpack_chain_link(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root, Ref<Cell>& prev) const;
  bool pack(vm::CellBuilder& cb, const Record_chain_link& data) const;
  bool pack_chain_link(vm::CellBuilder& cb, Ref<Cell> root, Ref<Cell> prev) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chain_link& data) const;
  bool cell_pack_chain_link(Ref<vm::Cell>& cell_ref, Ref<Cell> root, Ref<Cell> prev) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(ProofChain " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct ProofChain::Record_chain_link {
  typedef ProofChain type_class;
  int n;  	// n : #
  Ref<Cell> root;  	// root : ^Cell
  Ref<Cell> prev;  	// prev : n?^(ProofChain n)
  Record_chain_link() = default;
  Record_chain_link(Ref<Cell> _root, Ref<Cell> _prev) : n(-1), root(std::move(_root)), prev(std::move(_prev)) {}
};

//
// headers for type `TopBlockDescr`
//

struct TopBlockDescr final : TLB_Complex {
  enum { top_block_descr };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xd5 };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TopBlockDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct TopBlockDescr::Record {
  typedef TopBlockDescr type_class;
  Ref<CellSlice> proof_for;  	// proof_for : BlockIdExt
  Ref<CellSlice> signatures;  	// signatures : Maybe ^BlockSignatures
  int len;  	// len : ## 8
  Ref<CellSlice> chain;  	// chain : ProofChain len
  Record() = default;
  Record(Ref<CellSlice> _proof_for, Ref<CellSlice> _signatures, int _len, Ref<CellSlice> _chain) : proof_for(std::move(_proof_for)), signatures(std::move(_signatures)), len(_len), chain(std::move(_chain)) {}
};

extern const TopBlockDescr t_TopBlockDescr;

//
// headers for type `TopBlockDescrSet`
//

struct TopBlockDescrSet final : TLB_Complex {
  enum { top_block_descr_set };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[1] = { 0x4ac789f3 };
  struct Record {
    typedef TopBlockDescrSet type_class;
    Ref<CellSlice> collection;  	// collection : HashmapE 96 ^TopBlockDescr
    Record() = default;
    Record(Ref<CellSlice> _collection) : collection(std::move(_collection)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_top_block_descr_set(vm::CellSlice& cs, Ref<CellSlice>& collection) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_top_block_descr_set(Ref<vm::Cell> cell_ref, Ref<CellSlice>& collection) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_top_block_descr_set(vm::CellBuilder& cb, Ref<CellSlice> collection) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_top_block_descr_set(Ref<vm::Cell>& cell_ref, Ref<CellSlice> collection) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "TopBlockDescrSet";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const TopBlockDescrSet t_TopBlockDescrSet;

//
// headers for type `ProducerInfo`
//

struct ProducerInfo final : TLB_Complex {
  enum { prod_info };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x34 };
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 0x20288;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x20288);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ProducerInfo";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ProducerInfo::Record {
  typedef ProducerInfo type_class;
  unsigned utime;  	// utime : uint32
  Ref<CellSlice> mc_blk_ref;  	// mc_blk_ref : ExtBlkRef
  Ref<Cell> state_proof;  	// state_proof : ^(MERKLE_PROOF Block)
  Ref<Cell> prod_proof;  	// prod_proof : ^(MERKLE_PROOF ShardState)
  Record() = default;
  Record(unsigned _utime, Ref<CellSlice> _mc_blk_ref, Ref<Cell> _state_proof, Ref<Cell> _prod_proof) : utime(_utime), mc_blk_ref(std::move(_mc_blk_ref)), state_proof(std::move(_state_proof)), prod_proof(std::move(_prod_proof)) {}
};

extern const ProducerInfo t_ProducerInfo;

//
// headers for type `ComplaintDescr`
//

struct ComplaintDescr final : TLB_Complex {
  enum { no_blk_gen, no_blk_gen_diff };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[2] = { 0x450e8bd9, 0xc737b0caU };
  struct Record_no_blk_gen {
    typedef ComplaintDescr type_class;
    unsigned from_utime;  	// from_utime : uint32
    Ref<Cell> prod_info;  	// prod_info : ^ProducerInfo
    Record_no_blk_gen() = default;
    Record_no_blk_gen(unsigned _from_utime, Ref<Cell> _prod_info) : from_utime(_from_utime), prod_info(std::move(_prod_info)) {}
  };
  struct Record_no_blk_gen_diff {
    typedef ComplaintDescr type_class;
    Ref<Cell> prod_info_old;  	// prod_info_old : ^ProducerInfo
    Ref<Cell> prod_info_new;  	// prod_info_new : ^ProducerInfo
    Record_no_blk_gen_diff() = default;
    Record_no_blk_gen_diff(Ref<Cell> _prod_info_old, Ref<Cell> _prod_info_new) : prod_info_old(std::move(_prod_info_old)), prod_info_new(std::move(_prod_info_new)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_no_blk_gen& data) const;
  bool unpack_no_blk_gen(vm::CellSlice& cs, unsigned& from_utime, Ref<Cell>& prod_info) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_no_blk_gen& data) const;
  bool cell_unpack_no_blk_gen(Ref<vm::Cell> cell_ref, unsigned& from_utime, Ref<Cell>& prod_info) const;
  bool pack(vm::CellBuilder& cb, const Record_no_blk_gen& data) const;
  bool pack_no_blk_gen(vm::CellBuilder& cb, unsigned from_utime, Ref<Cell> prod_info) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_no_blk_gen& data) const;
  bool cell_pack_no_blk_gen(Ref<vm::Cell>& cell_ref, unsigned from_utime, Ref<Cell> prod_info) const;
  bool unpack(vm::CellSlice& cs, Record_no_blk_gen_diff& data) const;
  bool unpack_no_blk_gen_diff(vm::CellSlice& cs, Ref<Cell>& prod_info_old, Ref<Cell>& prod_info_new) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_no_blk_gen_diff& data) const;
  bool cell_unpack_no_blk_gen_diff(Ref<vm::Cell> cell_ref, Ref<Cell>& prod_info_old, Ref<Cell>& prod_info_new) const;
  bool pack(vm::CellBuilder& cb, const Record_no_blk_gen_diff& data) const;
  bool pack_no_blk_gen_diff(vm::CellBuilder& cb, Ref<Cell> prod_info_old, Ref<Cell> prod_info_new) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_no_blk_gen_diff& data) const;
  bool cell_pack_no_blk_gen_diff(Ref<vm::Cell>& cell_ref, Ref<Cell> prod_info_old, Ref<Cell> prod_info_new) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ComplaintDescr";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const ComplaintDescr t_ComplaintDescr;

//
// headers for type `ValidatorComplaint`
//

struct ValidatorComplaint final : TLB_Complex {
  enum { validator_complaint };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0xbc };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorComplaint";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValidatorComplaint::Record {
  typedef ValidatorComplaint type_class;
  RefInt256 validator_pubkey;  	// validator_pubkey : uint256
  Ref<Cell> description;  	// description : ^ComplaintDescr
  unsigned created_at;  	// created_at : uint32
  int severity;  	// severity : uint8
  RefInt256 reward_addr;  	// reward_addr : uint256
  Ref<CellSlice> paid;  	// paid : Grams
  Ref<CellSlice> suggested_fine;  	// suggested_fine : Grams
  unsigned suggested_fine_part;  	// suggested_fine_part : uint32
  Record() = default;
  Record(RefInt256 _validator_pubkey, Ref<Cell> _description, unsigned _created_at, int _severity, RefInt256 _reward_addr, Ref<CellSlice> _paid, Ref<CellSlice> _suggested_fine, unsigned _suggested_fine_part) : validator_pubkey(std::move(_validator_pubkey)), description(std::move(_description)), created_at(_created_at), severity(_severity), reward_addr(std::move(_reward_addr)), paid(std::move(_paid)), suggested_fine(std::move(_suggested_fine)), suggested_fine_part(_suggested_fine_part) {}
};

extern const ValidatorComplaint t_ValidatorComplaint;

//
// headers for type `ValidatorComplaintStatus`
//

struct ValidatorComplaintStatus final : TLB_Complex {
  enum { complaint_status };
  static constexpr int cons_len_exact = 8;
  static constexpr unsigned char cons_tag[1] = { 0x2d };
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ValidatorComplaintStatus";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ValidatorComplaintStatus::Record {
  typedef ValidatorComplaintStatus type_class;
  Ref<Cell> complaint;  	// complaint : ^ValidatorComplaint
  Ref<CellSlice> voters;  	// voters : HashmapE 16 True
  RefInt256 vset_id;  	// vset_id : uint256
  long long weight_remaining;  	// weight_remaining : int64
  Record() = default;
  Record(Ref<Cell> _complaint, Ref<CellSlice> _voters, RefInt256 _vset_id, long long _weight_remaining) : complaint(std::move(_complaint)), voters(std::move(_voters)), vset_id(std::move(_vset_id)), weight_remaining(_weight_remaining) {}
};

extern const ValidatorComplaintStatus t_ValidatorComplaintStatus;

//
// headers for type `VmCellSlice`
//

struct VmCellSlice final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 0x1001a;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x1001a);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmCellSlice";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VmCellSlice::Record {
  typedef VmCellSlice type_class;
  Ref<Cell> cell;  	// cell : ^Cell
  int st_bits;  	// st_bits : ## 10
  int end_bits;  	// end_bits : ## 10
  int st_ref;  	// st_ref : #<= 4
  int end_ref;  	// end_ref : #<= 4
  Record() = default;
  Record(Ref<Cell> _cell, int _st_bits, int _end_bits, int _st_ref, int _end_ref) : cell(std::move(_cell)), st_bits(_st_bits), end_bits(_end_bits), st_ref(_st_ref), end_ref(_end_ref) {}
};

extern const VmCellSlice t_VmCellSlice;

//
// headers for type `VmTupleRef`
//

struct VmTupleRef final : TLB_Complex {
  enum { vm_tupref_nil, vm_tupref_single, vm_tupref_any };
  static constexpr int cons_len_exact = 0;
  int m_;
  VmTupleRef(int m) : m_(m) {}
  struct Record_vm_tupref_nil {
    typedef VmTupleRef type_class;
  };
  struct Record_vm_tupref_single {
    typedef VmTupleRef type_class;
    Ref<Cell> entry;  	// entry : ^VmStackValue
    Record_vm_tupref_single() = default;
    Record_vm_tupref_single(Ref<Cell> _entry) : entry(std::move(_entry)) {}
  };
  struct Record_vm_tupref_any {
    typedef VmTupleRef type_class;
    int n;  	// n : #
    Ref<Cell> ref;  	// ref : ^(VmTuple (n + 2))
    Record_vm_tupref_any() = default;
    Record_vm_tupref_any(Ref<Cell> _ref) : n(-1), ref(std::move(_ref)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vm_tupref_nil& data) const;
  bool unpack_vm_tupref_nil(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_tupref_nil& data) const;
  bool cell_unpack_vm_tupref_nil(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_tupref_nil& data) const;
  bool pack_vm_tupref_nil(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_tupref_nil& data) const;
  bool cell_pack_vm_tupref_nil(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vm_tupref_single& data) const;
  bool unpack_vm_tupref_single(vm::CellSlice& cs, Ref<Cell>& entry) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_tupref_single& data) const;
  bool cell_unpack_vm_tupref_single(Ref<vm::Cell> cell_ref, Ref<Cell>& entry) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_tupref_single& data) const;
  bool pack_vm_tupref_single(vm::CellBuilder& cb, Ref<Cell> entry) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_tupref_single& data) const;
  bool cell_pack_vm_tupref_single(Ref<vm::Cell>& cell_ref, Ref<Cell> entry) const;
  bool unpack(vm::CellSlice& cs, Record_vm_tupref_any& data) const;
  bool unpack_vm_tupref_any(vm::CellSlice& cs, int& n, Ref<Cell>& ref) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_tupref_any& data) const;
  bool cell_unpack_vm_tupref_any(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_tupref_any& data) const;
  bool pack_vm_tupref_any(vm::CellBuilder& cb, Ref<Cell> ref) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_tupref_any& data) const;
  bool cell_pack_vm_tupref_any(Ref<vm::Cell>& cell_ref, Ref<Cell> ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VmTupleRef " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

//
// headers for type `VmTuple`
//

struct VmTuple final : TLB_Complex {
  enum { vm_tuple_nil, vm_tuple_tcons };
  static constexpr int cons_len_exact = 0;
  int m_;
  VmTuple(int m) : m_(m) {}
  struct Record_vm_tuple_nil {
    typedef VmTuple type_class;
  };
  struct Record_vm_tuple_tcons;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vm_tuple_nil& data) const;
  bool unpack_vm_tuple_nil(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_tuple_nil& data) const;
  bool cell_unpack_vm_tuple_nil(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_tuple_nil& data) const;
  bool pack_vm_tuple_nil(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_tuple_nil& data) const;
  bool cell_pack_vm_tuple_nil(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vm_tuple_tcons& data) const;
  bool unpack_vm_tuple_tcons(vm::CellSlice& cs, int& n, Ref<CellSlice>& head, Ref<Cell>& tail) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_tuple_tcons& data) const;
  bool cell_unpack_vm_tuple_tcons(Ref<vm::Cell> cell_ref, int& n, Ref<CellSlice>& head, Ref<Cell>& tail) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_tuple_tcons& data) const;
  bool pack_vm_tuple_tcons(vm::CellBuilder& cb, Ref<CellSlice> head, Ref<Cell> tail) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_tuple_tcons& data) const;
  bool cell_pack_vm_tuple_tcons(Ref<vm::Cell>& cell_ref, Ref<CellSlice> head, Ref<Cell> tail) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VmTuple " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct VmTuple::Record_vm_tuple_tcons {
  typedef VmTuple type_class;
  int n;  	// n : #
  Ref<CellSlice> head;  	// head : VmTupleRef n
  Ref<Cell> tail;  	// tail : ^VmStackValue
  Record_vm_tuple_tcons() = default;
  Record_vm_tuple_tcons(Ref<CellSlice> _head, Ref<Cell> _tail) : n(-1), head(std::move(_head)), tail(std::move(_tail)) {}
};

//
// headers for type `VmStackValue`
//

struct VmStackValue final : TLB_Complex {
  enum { vm_stk_null, vm_stk_tinyint, vm_stk_int, vm_stk_nan, vm_stk_cell, vm_stk_slice, vm_stk_builder, vm_stk_cont, vm_stk_tuple };
  static constexpr char cons_len[9] = { 8, 8, 15, 16, 8, 8, 8, 8, 8 };
  static constexpr unsigned short cons_tag[9] = { 0, 1, 0x100, 0x2ff, 3, 4, 5, 6, 7 };
  struct Record_vm_stk_null {
    typedef VmStackValue type_class;
  };
  struct Record_vm_stk_tinyint {
    typedef VmStackValue type_class;
    long long value;  	// value : int64
    Record_vm_stk_tinyint() = default;
    Record_vm_stk_tinyint(long long _value) : value(_value) {}
  };
  struct Record_vm_stk_int {
    typedef VmStackValue type_class;
    RefInt256 value;  	// value : int257
    Record_vm_stk_int() = default;
    Record_vm_stk_int(RefInt256 _value) : value(std::move(_value)) {}
  };
  struct Record_vm_stk_nan {
    typedef VmStackValue type_class;
  };
  struct Record_vm_stk_cell {
    typedef VmStackValue type_class;
    Ref<Cell> cell;  	// cell : ^Cell
    Record_vm_stk_cell() = default;
    Record_vm_stk_cell(Ref<Cell> _cell) : cell(std::move(_cell)) {}
  };
  struct Record_vm_stk_slice {
    typedef VmStackValue type_class;
    Ref<CellSlice> x;  	// VmCellSlice
    Record_vm_stk_slice() = default;
    Record_vm_stk_slice(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_vm_stk_builder {
    typedef VmStackValue type_class;
    Ref<Cell> cell;  	// cell : ^Cell
    Record_vm_stk_builder() = default;
    Record_vm_stk_builder(Ref<Cell> _cell) : cell(std::move(_cell)) {}
  };
  struct Record_vm_stk_cont {
    typedef VmStackValue type_class;
    Ref<CellSlice> cont;  	// cont : VmCont
    Record_vm_stk_cont() = default;
    Record_vm_stk_cont(Ref<CellSlice> _cont) : cont(std::move(_cont)) {}
  };
  struct Record_vm_stk_tuple {
    typedef VmStackValue type_class;
    int len;  	// len : ## 16
    Ref<CellSlice> data;  	// data : VmTuple len
    Record_vm_stk_tuple() = default;
    Record_vm_stk_tuple(int _len, Ref<CellSlice> _data) : len(_len), data(std::move(_data)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_null& data) const;
  bool unpack_vm_stk_null(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_null& data) const;
  bool cell_unpack_vm_stk_null(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_null& data) const;
  bool pack_vm_stk_null(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_null& data) const;
  bool cell_pack_vm_stk_null(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_tinyint& data) const;
  bool unpack_vm_stk_tinyint(vm::CellSlice& cs, long long& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_tinyint& data) const;
  bool cell_unpack_vm_stk_tinyint(Ref<vm::Cell> cell_ref, long long& value) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_tinyint& data) const;
  bool pack_vm_stk_tinyint(vm::CellBuilder& cb, long long value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_tinyint& data) const;
  bool cell_pack_vm_stk_tinyint(Ref<vm::Cell>& cell_ref, long long value) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_int& data) const;
  bool unpack_vm_stk_int(vm::CellSlice& cs, RefInt256& value) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_int& data) const;
  bool cell_unpack_vm_stk_int(Ref<vm::Cell> cell_ref, RefInt256& value) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_int& data) const;
  bool pack_vm_stk_int(vm::CellBuilder& cb, RefInt256 value) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_int& data) const;
  bool cell_pack_vm_stk_int(Ref<vm::Cell>& cell_ref, RefInt256 value) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_nan& data) const;
  bool unpack_vm_stk_nan(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_nan& data) const;
  bool cell_unpack_vm_stk_nan(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_nan& data) const;
  bool pack_vm_stk_nan(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_nan& data) const;
  bool cell_pack_vm_stk_nan(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_cell& data) const;
  bool unpack_vm_stk_cell(vm::CellSlice& cs, Ref<Cell>& cell) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_cell& data) const;
  bool cell_unpack_vm_stk_cell(Ref<vm::Cell> cell_ref, Ref<Cell>& cell) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_cell& data) const;
  bool pack_vm_stk_cell(vm::CellBuilder& cb, Ref<Cell> cell) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_cell& data) const;
  bool cell_pack_vm_stk_cell(Ref<vm::Cell>& cell_ref, Ref<Cell> cell) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_slice& data) const;
  bool unpack_vm_stk_slice(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_slice& data) const;
  bool cell_unpack_vm_stk_slice(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_slice& data) const;
  bool pack_vm_stk_slice(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_slice& data) const;
  bool cell_pack_vm_stk_slice(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_builder& data) const;
  bool unpack_vm_stk_builder(vm::CellSlice& cs, Ref<Cell>& cell) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_builder& data) const;
  bool cell_unpack_vm_stk_builder(Ref<vm::Cell> cell_ref, Ref<Cell>& cell) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_builder& data) const;
  bool pack_vm_stk_builder(vm::CellBuilder& cb, Ref<Cell> cell) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_builder& data) const;
  bool cell_pack_vm_stk_builder(Ref<vm::Cell>& cell_ref, Ref<Cell> cell) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_cont& data) const;
  bool unpack_vm_stk_cont(vm::CellSlice& cs, Ref<CellSlice>& cont) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_cont& data) const;
  bool cell_unpack_vm_stk_cont(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cont) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_cont& data) const;
  bool pack_vm_stk_cont(vm::CellBuilder& cb, Ref<CellSlice> cont) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_cont& data) const;
  bool cell_pack_vm_stk_cont(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cont) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_tuple& data) const;
  bool unpack_vm_stk_tuple(vm::CellSlice& cs, int& len, Ref<CellSlice>& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_tuple& data) const;
  bool cell_unpack_vm_stk_tuple(Ref<vm::Cell> cell_ref, int& len, Ref<CellSlice>& data) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_tuple& data) const;
  bool pack_vm_stk_tuple(vm::CellBuilder& cb, int len, Ref<CellSlice> data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_tuple& data) const;
  bool cell_pack_vm_stk_tuple(Ref<vm::Cell>& cell_ref, int len, Ref<CellSlice> data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmStackValue";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

extern const VmStackValue t_VmStackValue;

//
// headers for type `VmStack`
//

struct VmStack final : TLB_Complex {
  enum { vm_stack };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef VmStack type_class;
    int depth;  	// depth : ## 24
    Ref<CellSlice> stack;  	// stack : VmStackList depth
    Record() = default;
    Record(int _depth, Ref<CellSlice> _stack) : depth(_depth), stack(std::move(_stack)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_vm_stack(vm::CellSlice& cs, int& depth, Ref<CellSlice>& stack) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_vm_stack(Ref<vm::Cell> cell_ref, int& depth, Ref<CellSlice>& stack) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_vm_stack(vm::CellBuilder& cb, int depth, Ref<CellSlice> stack) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_vm_stack(Ref<vm::Cell>& cell_ref, int depth, Ref<CellSlice> stack) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmStack";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const VmStack t_VmStack;

//
// headers for type `VmStackList`
//

struct VmStackList final : TLB_Complex {
  enum { vm_stk_cons, vm_stk_nil };
  static constexpr int cons_len_exact = 0;
  int m_;
  VmStackList(int m) : m_(m) {}
  struct Record_vm_stk_cons;
  struct Record_vm_stk_nil {
    typedef VmStackList type_class;
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_cons& data) const;
  bool unpack_vm_stk_cons(vm::CellSlice& cs, int& n, Ref<Cell>& rest, Ref<CellSlice>& tos) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_cons& data) const;
  bool cell_unpack_vm_stk_cons(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& rest, Ref<CellSlice>& tos) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_cons& data) const;
  bool pack_vm_stk_cons(vm::CellBuilder& cb, Ref<Cell> rest, Ref<CellSlice> tos) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_cons& data) const;
  bool cell_pack_vm_stk_cons(Ref<vm::Cell>& cell_ref, Ref<Cell> rest, Ref<CellSlice> tos) const;
  bool unpack(vm::CellSlice& cs, Record_vm_stk_nil& data) const;
  bool unpack_vm_stk_nil(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vm_stk_nil& data) const;
  bool cell_unpack_vm_stk_nil(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vm_stk_nil& data) const;
  bool pack_vm_stk_nil(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vm_stk_nil& data) const;
  bool cell_pack_vm_stk_nil(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(VmStackList " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct VmStackList::Record_vm_stk_cons {
  typedef VmStackList type_class;
  int n;  	// n : #
  Ref<Cell> rest;  	// rest : ^(VmStackList n)
  Ref<CellSlice> tos;  	// tos : VmStackValue
  Record_vm_stk_cons() = default;
  Record_vm_stk_cons(Ref<Cell> _rest, Ref<CellSlice> _tos) : n(-1), rest(std::move(_rest)), tos(std::move(_tos)) {}
};

//
// headers for type `VmSaveList`
//

struct VmSaveList final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef VmSaveList type_class;
    Ref<CellSlice> cregs;  	// cregs : HashmapE 4 VmStackValue
    Record() = default;
    Record(Ref<CellSlice> _cregs) : cregs(std::move(_cregs)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& cregs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cregs) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> cregs) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cregs) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmSaveList";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const VmSaveList t_VmSaveList;

//
// headers for auxiliary type `VmGasLimits_aux`
//

struct VmGasLimits_aux final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 192;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(192);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override {
    return cs.advance(192);
  }
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, long long& max_limit, long long& cur_limit, long long& credit) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, long long& max_limit, long long& cur_limit, long long& credit) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, long long max_limit, long long cur_limit, long long credit) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, long long max_limit, long long cur_limit, long long credit) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmGasLimits_aux";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VmGasLimits_aux::Record {
  typedef VmGasLimits_aux type_class;
  long long max_limit;  	// max_limit : int64
  long long cur_limit;  	// cur_limit : int64
  long long credit;  	// credit : int64
  Record() = default;
  Record(long long _max_limit, long long _cur_limit, long long _credit) : max_limit(_max_limit), cur_limit(_cur_limit), credit(_credit) {}
};

extern const VmGasLimits_aux t_VmGasLimits_aux;

//
// headers for type `VmGasLimits`
//

struct VmGasLimits final : TLB_Complex {
  enum { gas_limits };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef VmGasLimits type_class;
    long long remaining;  	// remaining : int64
    VmGasLimits_aux::Record r1;  	// ^[$_ max_limit:int64 cur_limit:int64 credit:int64 ]
    Record() = default;
    Record(long long _remaining, const VmGasLimits_aux::Record& _r1) : remaining(_remaining), r1(_r1) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x10040;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x10040);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmGasLimits";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const VmGasLimits t_VmGasLimits;

//
// headers for type `VmLibraries`
//

struct VmLibraries final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef VmLibraries type_class;
    Ref<CellSlice> libraries;  	// libraries : HashmapE 256 ^Cell
    Record() = default;
    Record(Ref<CellSlice> _libraries) : libraries(std::move(_libraries)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& libraries) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& libraries) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> libraries) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> libraries) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmLibraries";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const VmLibraries t_VmLibraries;

//
// headers for type `VmControlData`
//

struct VmControlData final : TLB_Complex {
  enum { vm_ctl_data };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmControlData";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct VmControlData::Record {
  typedef VmControlData type_class;
  Ref<CellSlice> nargs;  	// nargs : Maybe uint13
  Ref<CellSlice> stack;  	// stack : Maybe VmStack
  Ref<CellSlice> save;  	// save : VmSaveList
  Ref<CellSlice> cp;  	// cp : Maybe int16
  Record() = default;
  Record(Ref<CellSlice> _nargs, Ref<CellSlice> _stack, Ref<CellSlice> _save, Ref<CellSlice> _cp) : nargs(std::move(_nargs)), stack(std::move(_stack)), save(std::move(_save)), cp(std::move(_cp)) {}
};

extern const VmControlData t_VmControlData;

//
// headers for type `VmCont`
//

struct VmCont final : TLB_Complex {
  enum { vmc_std, vmc_envelope, vmc_quit, vmc_quit_exc, vmc_repeat, vmc_until, vmc_again, vmc_while_cond, vmc_while_body, vmc_pushint };
  static constexpr char cons_len[10] = { 2, 2, 4, 4, 5, 6, 6, 6, 6, 4 };
  static constexpr unsigned char cons_tag[10] = { 0, 1, 8, 9, 20, 0x30, 0x31, 0x32, 0x33, 15 };
  struct Record_vmc_std {
    typedef VmCont type_class;
    Ref<CellSlice> cdata;  	// cdata : VmControlData
    Ref<CellSlice> code;  	// code : VmCellSlice
    Record_vmc_std() = default;
    Record_vmc_std(Ref<CellSlice> _cdata, Ref<CellSlice> _code) : cdata(std::move(_cdata)), code(std::move(_code)) {}
  };
  struct Record_vmc_envelope {
    typedef VmCont type_class;
    Ref<CellSlice> cdata;  	// cdata : VmControlData
    Ref<Cell> next;  	// next : ^VmCont
    Record_vmc_envelope() = default;
    Record_vmc_envelope(Ref<CellSlice> _cdata, Ref<Cell> _next) : cdata(std::move(_cdata)), next(std::move(_next)) {}
  };
  struct Record_vmc_quit {
    typedef VmCont type_class;
    int exit_code;  	// exit_code : int32
    Record_vmc_quit() = default;
    Record_vmc_quit(int _exit_code) : exit_code(_exit_code) {}
  };
  struct Record_vmc_quit_exc {
    typedef VmCont type_class;
  };
  struct Record_vmc_repeat;
  struct Record_vmc_until {
    typedef VmCont type_class;
    Ref<Cell> body;  	// body : ^VmCont
    Ref<Cell> after;  	// after : ^VmCont
    Record_vmc_until() = default;
    Record_vmc_until(Ref<Cell> _body, Ref<Cell> _after) : body(std::move(_body)), after(std::move(_after)) {}
  };
  struct Record_vmc_again {
    typedef VmCont type_class;
    Ref<Cell> body;  	// body : ^VmCont
    Record_vmc_again() = default;
    Record_vmc_again(Ref<Cell> _body) : body(std::move(_body)) {}
  };
  struct Record_vmc_while_cond;
  struct Record_vmc_while_body;
  struct Record_vmc_pushint {
    typedef VmCont type_class;
    int value;  	// value : int32
    Ref<Cell> next;  	// next : ^VmCont
    Record_vmc_pushint() = default;
    Record_vmc_pushint(int _value, Ref<Cell> _next) : value(_value), next(std::move(_next)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_vmc_std& data) const;
  bool unpack_vmc_std(vm::CellSlice& cs, Ref<CellSlice>& cdata, Ref<CellSlice>& code) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_std& data) const;
  bool cell_unpack_vmc_std(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cdata, Ref<CellSlice>& code) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_std& data) const;
  bool pack_vmc_std(vm::CellBuilder& cb, Ref<CellSlice> cdata, Ref<CellSlice> code) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_std& data) const;
  bool cell_pack_vmc_std(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cdata, Ref<CellSlice> code) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_envelope& data) const;
  bool unpack_vmc_envelope(vm::CellSlice& cs, Ref<CellSlice>& cdata, Ref<Cell>& next) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_envelope& data) const;
  bool cell_unpack_vmc_envelope(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cdata, Ref<Cell>& next) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_envelope& data) const;
  bool pack_vmc_envelope(vm::CellBuilder& cb, Ref<CellSlice> cdata, Ref<Cell> next) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_envelope& data) const;
  bool cell_pack_vmc_envelope(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cdata, Ref<Cell> next) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_quit& data) const;
  bool unpack_vmc_quit(vm::CellSlice& cs, int& exit_code) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_quit& data) const;
  bool cell_unpack_vmc_quit(Ref<vm::Cell> cell_ref, int& exit_code) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_quit& data) const;
  bool pack_vmc_quit(vm::CellBuilder& cb, int exit_code) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_quit& data) const;
  bool cell_pack_vmc_quit(Ref<vm::Cell>& cell_ref, int exit_code) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_quit_exc& data) const;
  bool unpack_vmc_quit_exc(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_quit_exc& data) const;
  bool cell_unpack_vmc_quit_exc(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_quit_exc& data) const;
  bool pack_vmc_quit_exc(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_quit_exc& data) const;
  bool cell_pack_vmc_quit_exc(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_repeat& data) const;
  bool unpack_vmc_repeat(vm::CellSlice& cs, long long& count, Ref<Cell>& body, Ref<Cell>& after) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_repeat& data) const;
  bool cell_unpack_vmc_repeat(Ref<vm::Cell> cell_ref, long long& count, Ref<Cell>& body, Ref<Cell>& after) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_repeat& data) const;
  bool pack_vmc_repeat(vm::CellBuilder& cb, long long count, Ref<Cell> body, Ref<Cell> after) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_repeat& data) const;
  bool cell_pack_vmc_repeat(Ref<vm::Cell>& cell_ref, long long count, Ref<Cell> body, Ref<Cell> after) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_until& data) const;
  bool unpack_vmc_until(vm::CellSlice& cs, Ref<Cell>& body, Ref<Cell>& after) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_until& data) const;
  bool cell_unpack_vmc_until(Ref<vm::Cell> cell_ref, Ref<Cell>& body, Ref<Cell>& after) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_until& data) const;
  bool pack_vmc_until(vm::CellBuilder& cb, Ref<Cell> body, Ref<Cell> after) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_until& data) const;
  bool cell_pack_vmc_until(Ref<vm::Cell>& cell_ref, Ref<Cell> body, Ref<Cell> after) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_again& data) const;
  bool unpack_vmc_again(vm::CellSlice& cs, Ref<Cell>& body) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_again& data) const;
  bool cell_unpack_vmc_again(Ref<vm::Cell> cell_ref, Ref<Cell>& body) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_again& data) const;
  bool pack_vmc_again(vm::CellBuilder& cb, Ref<Cell> body) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_again& data) const;
  bool cell_pack_vmc_again(Ref<vm::Cell>& cell_ref, Ref<Cell> body) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_while_cond& data) const;
  bool unpack_vmc_while_cond(vm::CellSlice& cs, Ref<Cell>& cond, Ref<Cell>& body, Ref<Cell>& after) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_while_cond& data) const;
  bool cell_unpack_vmc_while_cond(Ref<vm::Cell> cell_ref, Ref<Cell>& cond, Ref<Cell>& body, Ref<Cell>& after) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_while_cond& data) const;
  bool pack_vmc_while_cond(vm::CellBuilder& cb, Ref<Cell> cond, Ref<Cell> body, Ref<Cell> after) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_while_cond& data) const;
  bool cell_pack_vmc_while_cond(Ref<vm::Cell>& cell_ref, Ref<Cell> cond, Ref<Cell> body, Ref<Cell> after) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_while_body& data) const;
  bool unpack_vmc_while_body(vm::CellSlice& cs, Ref<Cell>& cond, Ref<Cell>& body, Ref<Cell>& after) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_while_body& data) const;
  bool cell_unpack_vmc_while_body(Ref<vm::Cell> cell_ref, Ref<Cell>& cond, Ref<Cell>& body, Ref<Cell>& after) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_while_body& data) const;
  bool pack_vmc_while_body(vm::CellBuilder& cb, Ref<Cell> cond, Ref<Cell> body, Ref<Cell> after) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_while_body& data) const;
  bool cell_pack_vmc_while_body(Ref<vm::Cell>& cell_ref, Ref<Cell> cond, Ref<Cell> body, Ref<Cell> after) const;
  bool unpack(vm::CellSlice& cs, Record_vmc_pushint& data) const;
  bool unpack_vmc_pushint(vm::CellSlice& cs, int& value, Ref<Cell>& next) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_vmc_pushint& data) const;
  bool cell_unpack_vmc_pushint(Ref<vm::Cell> cell_ref, int& value, Ref<Cell>& next) const;
  bool pack(vm::CellBuilder& cb, const Record_vmc_pushint& data) const;
  bool pack_vmc_pushint(vm::CellBuilder& cb, int value, Ref<Cell> next) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_vmc_pushint& data) const;
  bool cell_pack_vmc_pushint(Ref<vm::Cell>& cell_ref, int value, Ref<Cell> next) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "VmCont";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect_ext(6, 0x100f011100010001ULL);
  }
};

struct VmCont::Record_vmc_repeat {
  typedef VmCont type_class;
  long long count;  	// count : uint63
  Ref<Cell> body;  	// body : ^VmCont
  Ref<Cell> after;  	// after : ^VmCont
  Record_vmc_repeat() = default;
  Record_vmc_repeat(long long _count, Ref<Cell> _body, Ref<Cell> _after) : count(_count), body(std::move(_body)), after(std::move(_after)) {}
};

struct VmCont::Record_vmc_while_cond {
  typedef VmCont type_class;
  Ref<Cell> cond;  	// cond : ^VmCont
  Ref<Cell> body;  	// body : ^VmCont
  Ref<Cell> after;  	// after : ^VmCont
  Record_vmc_while_cond() = default;
  Record_vmc_while_cond(Ref<Cell> _cond, Ref<Cell> _body, Ref<Cell> _after) : cond(std::move(_cond)), body(std::move(_body)), after(std::move(_after)) {}
};

struct VmCont::Record_vmc_while_body {
  typedef VmCont type_class;
  Ref<Cell> cond;  	// cond : ^VmCont
  Ref<Cell> body;  	// body : ^VmCont
  Ref<Cell> after;  	// after : ^VmCont
  Record_vmc_while_body() = default;
  Record_vmc_while_body(Ref<Cell> _cond, Ref<Cell> _body, Ref<Cell> _after) : cond(std::move(_cond)), body(std::move(_body)), after(std::move(_after)) {}
};

extern const VmCont t_VmCont;

//
// headers for type `DNS_RecordSet`
//

struct DNS_RecordSet final : TLB_Complex {
  enum { cons1 };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef DNS_RecordSet type_class;
    Ref<CellSlice> x;  	// HashmapE 16 ^DNSRecord
    Record() = default;
    Record(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "DNS_RecordSet";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const DNS_RecordSet t_DNS_RecordSet;

//
// headers for type `TextChunkRef`
//

struct TextChunkRef final : TLB_Complex {
  enum { chunk_ref, chunk_ref_empty };
  static constexpr int cons_len_exact = 0;
  int m_;
  TextChunkRef(int m) : m_(m) {}
  struct Record_chunk_ref {
    typedef TextChunkRef type_class;
    int n;  	// n : #
    Ref<Cell> ref;  	// ref : ^(TextChunks (n + 1))
    Record_chunk_ref() = default;
    Record_chunk_ref(Ref<Cell> _ref) : n(-1), ref(std::move(_ref)) {}
  };
  struct Record_chunk_ref_empty {
    typedef TextChunkRef type_class;
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_chunk_ref& data) const;
  bool unpack_chunk_ref(vm::CellSlice& cs, int& n, Ref<Cell>& ref) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chunk_ref& data) const;
  bool cell_unpack_chunk_ref(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& ref) const;
  bool pack(vm::CellBuilder& cb, const Record_chunk_ref& data) const;
  bool pack_chunk_ref(vm::CellBuilder& cb, Ref<Cell> ref) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chunk_ref& data) const;
  bool cell_pack_chunk_ref(Ref<vm::Cell>& cell_ref, Ref<Cell> ref) const;
  bool unpack(vm::CellSlice& cs, Record_chunk_ref_empty& data) const;
  bool unpack_chunk_ref_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chunk_ref_empty& data) const;
  bool cell_unpack_chunk_ref_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_chunk_ref_empty& data) const;
  bool pack_chunk_ref_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chunk_ref_empty& data) const;
  bool cell_pack_chunk_ref_empty(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(TextChunkRef " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

//
// headers for type `TextChunks`
//

struct TextChunks final : TLB_Complex {
  enum { text_chunk, text_chunk_empty };
  static constexpr int cons_len_exact = 0;
  int m_;
  TextChunks(int m) : m_(m) {}
  struct Record_text_chunk;
  struct Record_text_chunk_empty {
    typedef TextChunks type_class;
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_text_chunk& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_text_chunk& data) const;
  bool pack(vm::CellBuilder& cb, const Record_text_chunk& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_text_chunk& data) const;
  bool unpack(vm::CellSlice& cs, Record_text_chunk_empty& data) const;
  bool unpack_text_chunk_empty(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_text_chunk_empty& data) const;
  bool cell_unpack_text_chunk_empty(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_text_chunk_empty& data) const;
  bool pack_text_chunk_empty(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_text_chunk_empty& data) const;
  bool cell_pack_text_chunk_empty(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "(TextChunks " << m_ << ")";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override;
};

struct TextChunks::Record_text_chunk {
  typedef TextChunks type_class;
  int n;  	// n : #
  int len;  	// len : ## 8
  Ref<td::BitString> data;  	// data : bits (8 * len)
  Ref<CellSlice> next;  	// next : TextChunkRef n
  Record_text_chunk() = default;
  Record_text_chunk(int _len, Ref<td::BitString> _data, Ref<CellSlice> _next) : n(-1), len(_len), data(std::move(_data)), next(std::move(_next)) {}
};

//
// headers for type `Text`
//

struct Text final : TLB_Complex {
  enum { text };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef Text type_class;
    int chunks;  	// chunks : ## 8
    Ref<CellSlice> rest;  	// rest : TextChunks chunks
    Record() = default;
    Record(int _chunks, Ref<CellSlice> _rest) : chunks(_chunks), rest(std::move(_rest)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_text(vm::CellSlice& cs, int& chunks, Ref<CellSlice>& rest) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_text(Ref<vm::Cell> cell_ref, int& chunks, Ref<CellSlice>& rest) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_text(vm::CellBuilder& cb, int chunks, Ref<CellSlice> rest) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_text(Ref<vm::Cell>& cell_ref, int chunks, Ref<CellSlice> rest) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Text";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Text t_Text;

//
// headers for type `ProtoList`
//

struct ProtoList final : TLB_Complex {
  enum { proto_list_nil, proto_list_next };
  static constexpr int cons_len_exact = 1;
  struct Record_proto_list_nil {
    typedef ProtoList type_class;
  };
  struct Record_proto_list_next {
    typedef ProtoList type_class;
    char head;  	// head : Protocol
    Ref<CellSlice> tail;  	// tail : ProtoList
    Record_proto_list_next() = default;
    Record_proto_list_next(char _head, Ref<CellSlice> _tail) : head(_head), tail(std::move(_tail)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_proto_list_nil& data) const;
  bool unpack_proto_list_nil(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_proto_list_nil& data) const;
  bool cell_unpack_proto_list_nil(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_proto_list_nil& data) const;
  bool pack_proto_list_nil(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_proto_list_nil& data) const;
  bool cell_pack_proto_list_nil(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_proto_list_next& data) const;
  bool unpack_proto_list_next(vm::CellSlice& cs, char& head, Ref<CellSlice>& tail) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_proto_list_next& data) const;
  bool cell_unpack_proto_list_next(Ref<vm::Cell> cell_ref, char& head, Ref<CellSlice>& tail) const;
  bool pack(vm::CellBuilder& cb, const Record_proto_list_next& data) const;
  bool pack_proto_list_next(vm::CellBuilder& cb, char head, Ref<CellSlice> tail) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_proto_list_next& data) const;
  bool cell_pack_proto_list_next(Ref<vm::Cell>& cell_ref, char head, Ref<CellSlice> tail) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ProtoList";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const ProtoList t_ProtoList;

//
// headers for type `Protocol`
//

struct Protocol final : TLB_Complex {
  enum { proto_http };
  static constexpr int cons_len_exact = 16;
  static constexpr unsigned short cons_tag[1] = { 0x4854 };
  struct Record {
    typedef Protocol type_class;
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 16;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance(16);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool fetch_enum_to(vm::CellSlice& cs, char& value) const;
  bool store_enum_from(vm::CellBuilder& cb, int value) const;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_proto_http(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_proto_http(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_proto_http(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_proto_http(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "Protocol";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const Protocol t_Protocol;

//
// headers for type `DNSRecord`
//

struct DNSRecord final : TLB_Complex {
  enum { dns_text, dns_smc_address, dns_adnl_address, dns_next_resolver };
  static constexpr int cons_len_exact = 16;
  static constexpr unsigned short cons_tag[4] = { 0x1eda, 0x9fd3, 0xad01, 0xba93 };
  struct Record_dns_text {
    typedef DNSRecord type_class;
    Ref<CellSlice> x;  	// Text
    Record_dns_text() = default;
    Record_dns_text(Ref<CellSlice> _x) : x(std::move(_x)) {}
  };
  struct Record_dns_next_resolver {
    typedef DNSRecord type_class;
    Ref<CellSlice> resolver;  	// resolver : MsgAddressInt
    Record_dns_next_resolver() = default;
    Record_dns_next_resolver(Ref<CellSlice> _resolver) : resolver(std::move(_resolver)) {}
  };
  struct Record_dns_adnl_address;
  struct Record_dns_smc_address;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_dns_text& data) const;
  bool unpack_dns_text(vm::CellSlice& cs, Ref<CellSlice>& x) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_dns_text& data) const;
  bool cell_unpack_dns_text(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const;
  bool pack(vm::CellBuilder& cb, const Record_dns_text& data) const;
  bool pack_dns_text(vm::CellBuilder& cb, Ref<CellSlice> x) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_dns_text& data) const;
  bool cell_pack_dns_text(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const;
  bool unpack(vm::CellSlice& cs, Record_dns_next_resolver& data) const;
  bool unpack_dns_next_resolver(vm::CellSlice& cs, Ref<CellSlice>& resolver) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_dns_next_resolver& data) const;
  bool cell_unpack_dns_next_resolver(Ref<vm::Cell> cell_ref, Ref<CellSlice>& resolver) const;
  bool pack(vm::CellBuilder& cb, const Record_dns_next_resolver& data) const;
  bool pack_dns_next_resolver(vm::CellBuilder& cb, Ref<CellSlice> resolver) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_dns_next_resolver& data) const;
  bool cell_pack_dns_next_resolver(Ref<vm::Cell>& cell_ref, Ref<CellSlice> resolver) const;
  bool unpack(vm::CellSlice& cs, Record_dns_adnl_address& data) const;
  bool unpack_dns_adnl_address(vm::CellSlice& cs, td::BitArray<256>& adnl_addr, int& flags, Ref<CellSlice>& proto_list) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_dns_adnl_address& data) const;
  bool cell_unpack_dns_adnl_address(Ref<vm::Cell> cell_ref, td::BitArray<256>& adnl_addr, int& flags, Ref<CellSlice>& proto_list) const;
  bool pack(vm::CellBuilder& cb, const Record_dns_adnl_address& data) const;
  bool pack_dns_adnl_address(vm::CellBuilder& cb, td::BitArray<256> adnl_addr, int flags, Ref<CellSlice> proto_list) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_dns_adnl_address& data) const;
  bool cell_pack_dns_adnl_address(Ref<vm::Cell>& cell_ref, td::BitArray<256> adnl_addr, int flags, Ref<CellSlice> proto_list) const;
  bool unpack(vm::CellSlice& cs, Record_dns_smc_address& data) const;
  bool unpack_dns_smc_address(vm::CellSlice& cs, Ref<CellSlice>& smc_addr, int& flags, Ref<CellSlice>& cap_list) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_dns_smc_address& data) const;
  bool cell_unpack_dns_smc_address(Ref<vm::Cell> cell_ref, Ref<CellSlice>& smc_addr, int& flags, Ref<CellSlice>& cap_list) const;
  bool pack(vm::CellBuilder& cb, const Record_dns_smc_address& data) const;
  bool pack_dns_smc_address(vm::CellBuilder& cb, Ref<CellSlice> smc_addr, int flags, Ref<CellSlice> cap_list) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_dns_smc_address& data) const;
  bool cell_pack_dns_smc_address(Ref<vm::Cell>& cell_ref, Ref<CellSlice> smc_addr, int flags, Ref<CellSlice> cap_list) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "DNSRecord";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(4, 0xe02);
  }
};

struct DNSRecord::Record_dns_adnl_address {
  typedef DNSRecord type_class;
  td::BitArray<256> adnl_addr;  	// adnl_addr : bits256
  int flags;  	// flags : ## 8
  Ref<CellSlice> proto_list;  	// proto_list : flags.0?ProtoList
  Record_dns_adnl_address() = default;
  Record_dns_adnl_address(const td::BitArray<256>& _adnl_addr, int _flags, Ref<CellSlice> _proto_list) : adnl_addr(_adnl_addr), flags(_flags), proto_list(std::move(_proto_list)) {}
};

struct DNSRecord::Record_dns_smc_address {
  typedef DNSRecord type_class;
  Ref<CellSlice> smc_addr;  	// smc_addr : MsgAddressInt
  int flags;  	// flags : ## 8
  Ref<CellSlice> cap_list;  	// cap_list : flags.0?SmcCapList
  Record_dns_smc_address() = default;
  Record_dns_smc_address(Ref<CellSlice> _smc_addr, int _flags, Ref<CellSlice> _cap_list) : smc_addr(std::move(_smc_addr)), flags(_flags), cap_list(std::move(_cap_list)) {}
};

extern const DNSRecord t_DNSRecord;

//
// headers for type `SmcCapList`
//

struct SmcCapList final : TLB_Complex {
  enum { cap_list_nil, cap_list_next };
  static constexpr int cons_len_exact = 1;
  struct Record_cap_list_nil {
    typedef SmcCapList type_class;
  };
  struct Record_cap_list_next {
    typedef SmcCapList type_class;
    Ref<CellSlice> head;  	// head : SmcCapability
    Ref<CellSlice> tail;  	// tail : SmcCapList
    Record_cap_list_next() = default;
    Record_cap_list_next(Ref<CellSlice> _head, Ref<CellSlice> _tail) : head(std::move(_head)), tail(std::move(_tail)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cap_list_nil& data) const;
  bool unpack_cap_list_nil(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_list_nil& data) const;
  bool cell_unpack_cap_list_nil(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_list_nil& data) const;
  bool pack_cap_list_nil(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_list_nil& data) const;
  bool cell_pack_cap_list_nil(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cap_list_next& data) const;
  bool unpack_cap_list_next(vm::CellSlice& cs, Ref<CellSlice>& head, Ref<CellSlice>& tail) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_list_next& data) const;
  bool cell_unpack_cap_list_next(Ref<vm::Cell> cell_ref, Ref<CellSlice>& head, Ref<CellSlice>& tail) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_list_next& data) const;
  bool pack_cap_list_next(vm::CellBuilder& cb, Ref<CellSlice> head, Ref<CellSlice> tail) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_list_next& data) const;
  bool cell_pack_cap_list_next(Ref<vm::Cell>& cell_ref, Ref<CellSlice> head, Ref<CellSlice> tail) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SmcCapList";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return (int)cs.prefetch_ulong(1);
  }
};

extern const SmcCapList t_SmcCapList;

//
// headers for type `SmcCapability`
//

struct SmcCapability final : TLB_Complex {
  enum { cap_is_wallet, cap_method_seqno, cap_method_pubkey, cap_name };
  static constexpr char cons_len[4] = { 16, 16, 16, 8 };
  static constexpr unsigned short cons_tag[4] = { 0x2177, 0x5371, 0x71f4, 0xff };
  struct Record_cap_method_seqno {
    typedef SmcCapability type_class;
  };
  struct Record_cap_method_pubkey {
    typedef SmcCapability type_class;
  };
  struct Record_cap_is_wallet {
    typedef SmcCapability type_class;
  };
  struct Record_cap_name {
    typedef SmcCapability type_class;
    Ref<CellSlice> name;  	// name : Text
    Record_cap_name() = default;
    Record_cap_name(Ref<CellSlice> _name) : name(std::move(_name)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_cap_method_seqno& data) const;
  bool unpack_cap_method_seqno(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_method_seqno& data) const;
  bool cell_unpack_cap_method_seqno(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_method_seqno& data) const;
  bool pack_cap_method_seqno(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_method_seqno& data) const;
  bool cell_pack_cap_method_seqno(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cap_method_pubkey& data) const;
  bool unpack_cap_method_pubkey(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_method_pubkey& data) const;
  bool cell_unpack_cap_method_pubkey(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_method_pubkey& data) const;
  bool pack_cap_method_pubkey(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_method_pubkey& data) const;
  bool cell_pack_cap_method_pubkey(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cap_is_wallet& data) const;
  bool unpack_cap_is_wallet(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_is_wallet& data) const;
  bool cell_unpack_cap_is_wallet(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_is_wallet& data) const;
  bool pack_cap_is_wallet(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_is_wallet& data) const;
  bool cell_pack_cap_is_wallet(Ref<vm::Cell>& cell_ref) const;
  bool unpack(vm::CellSlice& cs, Record_cap_name& data) const;
  bool unpack_cap_name(vm::CellSlice& cs, Ref<CellSlice>& name) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_cap_name& data) const;
  bool cell_unpack_cap_name(Ref<vm::Cell> cell_ref, Ref<CellSlice>& name) const;
  bool pack(vm::CellBuilder& cb, const Record_cap_name& data) const;
  bool pack_cap_name(vm::CellBuilder& cb, Ref<CellSlice> name) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_cap_name& data) const;
  bool cell_pack_cap_name(Ref<vm::Cell>& cell_ref, Ref<CellSlice> name) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "SmcCapability";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(3, 0x8e);
  }
};

extern const SmcCapability t_SmcCapability;

//
// headers for type `ChanConfig`
//

struct ChanConfig final : TLB_Complex {
  enum { chan_config };
  static constexpr int cons_len_exact = 0;
  struct Record;
  int get_size(const vm::CellSlice& cs) const override {
    return 0x20280;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x20280);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanConfig";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ChanConfig::Record {
  typedef ChanConfig type_class;
  unsigned init_timeout;  	// init_timeout : uint32
  unsigned close_timeout;  	// close_timeout : uint32
  td::BitArray<256> a_key;  	// a_key : bits256
  td::BitArray<256> b_key;  	// b_key : bits256
  Ref<Cell> a_addr;  	// a_addr : ^MsgAddressInt
  Ref<Cell> b_addr;  	// b_addr : ^MsgAddressInt
  unsigned long long channel_id;  	// channel_id : uint64
  Record() = default;
  Record(unsigned _init_timeout, unsigned _close_timeout, const td::BitArray<256>& _a_key, const td::BitArray<256>& _b_key, Ref<Cell> _a_addr, Ref<Cell> _b_addr, unsigned long long _channel_id) : init_timeout(_init_timeout), close_timeout(_close_timeout), a_key(_a_key), b_key(_b_key), a_addr(std::move(_a_addr)), b_addr(std::move(_b_addr)), channel_id(_channel_id) {}
};

extern const ChanConfig t_ChanConfig;

//
// headers for type `ChanState`
//

struct ChanState final : TLB_Complex {
  enum { chan_state_init, chan_state_close, chan_state_payout };
  static constexpr int cons_len_exact = 3;
  struct Record_chan_state_init;
  struct Record_chan_state_close;
  struct Record_chan_state_payout {
    typedef ChanState type_class;
    Ref<CellSlice> A;  	// A : Grams
    Ref<CellSlice> B;  	// B : Grams
    Record_chan_state_payout() = default;
    Record_chan_state_payout(Ref<CellSlice> _A, Ref<CellSlice> _B) : A(std::move(_A)), B(std::move(_B)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_chan_state_init& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_state_init& data) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_state_init& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_state_init& data) const;
  bool unpack(vm::CellSlice& cs, Record_chan_state_close& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_state_close& data) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_state_close& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_state_close& data) const;
  bool unpack(vm::CellSlice& cs, Record_chan_state_payout& data) const;
  bool unpack_chan_state_payout(vm::CellSlice& cs, Ref<CellSlice>& A, Ref<CellSlice>& B) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_state_payout& data) const;
  bool cell_unpack_chan_state_payout(Ref<vm::Cell> cell_ref, Ref<CellSlice>& A, Ref<CellSlice>& B) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_state_payout& data) const;
  bool pack_chan_state_payout(vm::CellBuilder& cb, Ref<CellSlice> A, Ref<CellSlice> B) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_state_payout& data) const;
  bool cell_pack_chan_state_payout(Ref<vm::Cell>& cell_ref, Ref<CellSlice> A, Ref<CellSlice> B) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanState";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(3, 7);
  }
};

struct ChanState::Record_chan_state_init {
  typedef ChanState type_class;
  bool signed_A;  	// signed_A : Bool
  bool signed_B;  	// signed_B : Bool
  Ref<CellSlice> min_A;  	// min_A : Grams
  Ref<CellSlice> min_B;  	// min_B : Grams
  unsigned expire_at;  	// expire_at : uint32
  Ref<CellSlice> A;  	// A : Grams
  Ref<CellSlice> B;  	// B : Grams
  Record_chan_state_init() = default;
  Record_chan_state_init(bool _signed_A, bool _signed_B, Ref<CellSlice> _min_A, Ref<CellSlice> _min_B, unsigned _expire_at, Ref<CellSlice> _A, Ref<CellSlice> _B) : signed_A(_signed_A), signed_B(_signed_B), min_A(std::move(_min_A)), min_B(std::move(_min_B)), expire_at(_expire_at), A(std::move(_A)), B(std::move(_B)) {}
};

struct ChanState::Record_chan_state_close {
  typedef ChanState type_class;
  bool signed_A;  	// signed_A : Bool
  bool signed_B;  	// signed_B : Bool
  Ref<CellSlice> promise_A;  	// promise_A : Grams
  Ref<CellSlice> promise_B;  	// promise_B : Grams
  unsigned expire_at;  	// expire_at : uint32
  Ref<CellSlice> A;  	// A : Grams
  Ref<CellSlice> B;  	// B : Grams
  Record_chan_state_close() = default;
  Record_chan_state_close(bool _signed_A, bool _signed_B, Ref<CellSlice> _promise_A, Ref<CellSlice> _promise_B, unsigned _expire_at, Ref<CellSlice> _A, Ref<CellSlice> _B) : signed_A(_signed_A), signed_B(_signed_B), promise_A(std::move(_promise_A)), promise_B(std::move(_promise_B)), expire_at(_expire_at), A(std::move(_A)), B(std::move(_B)) {}
};

extern const ChanState t_ChanState;

//
// headers for type `ChanPromise`
//

struct ChanPromise final : TLB_Complex {
  enum { chan_promise };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_chan_promise(vm::CellSlice& cs, unsigned long long& channel_id, Ref<CellSlice>& promise_A, Ref<CellSlice>& promise_B) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_chan_promise(Ref<vm::Cell> cell_ref, unsigned long long& channel_id, Ref<CellSlice>& promise_A, Ref<CellSlice>& promise_B) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_chan_promise(vm::CellBuilder& cb, unsigned long long channel_id, Ref<CellSlice> promise_A, Ref<CellSlice> promise_B) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_chan_promise(Ref<vm::Cell>& cell_ref, unsigned long long channel_id, Ref<CellSlice> promise_A, Ref<CellSlice> promise_B) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanPromise";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ChanPromise::Record {
  typedef ChanPromise type_class;
  unsigned long long channel_id;  	// channel_id : uint64
  Ref<CellSlice> promise_A;  	// promise_A : Grams
  Ref<CellSlice> promise_B;  	// promise_B : Grams
  Record() = default;
  Record(unsigned long long _channel_id, Ref<CellSlice> _promise_A, Ref<CellSlice> _promise_B) : channel_id(_channel_id), promise_A(std::move(_promise_A)), promise_B(std::move(_promise_B)) {}
};

extern const ChanPromise t_ChanPromise;

//
// headers for type `ChanSignedPromise`
//

struct ChanSignedPromise final : TLB_Complex {
  enum { chan_signed_promise };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ChanSignedPromise type_class;
    Ref<CellSlice> sig;  	// sig : Maybe ^bits512
    Ref<CellSlice> promise;  	// promise : ChanPromise
    Record() = default;
    Record(Ref<CellSlice> _sig, Ref<CellSlice> _promise) : sig(std::move(_sig)), promise(std::move(_promise)) {}
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_chan_signed_promise(vm::CellSlice& cs, Ref<CellSlice>& sig, Ref<CellSlice>& promise) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_chan_signed_promise(Ref<vm::Cell> cell_ref, Ref<CellSlice>& sig, Ref<CellSlice>& promise) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_chan_signed_promise(vm::CellBuilder& cb, Ref<CellSlice> sig, Ref<CellSlice> promise) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_chan_signed_promise(Ref<vm::Cell>& cell_ref, Ref<CellSlice> sig, Ref<CellSlice> promise) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanSignedPromise";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ChanSignedPromise t_ChanSignedPromise;

//
// headers for type `ChanMsg`
//

struct ChanMsg final : TLB_Complex {
  enum { chan_msg_init, chan_msg_timeout, chan_msg_close };
  static constexpr int cons_len_exact = 32;
  static constexpr unsigned cons_tag[3] = { 0x27317822, 0x43278a28, 0xf28ae183U };
  struct Record_chan_msg_init;
  struct Record_chan_msg_close;
  struct Record_chan_msg_timeout {
    typedef ChanMsg type_class;
  };
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record_chan_msg_init& data) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_msg_init& data) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_msg_init& data) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_msg_init& data) const;
  bool unpack(vm::CellSlice& cs, Record_chan_msg_close& data) const;
  bool unpack_chan_msg_close(vm::CellSlice& cs, Ref<CellSlice>& extra_A, Ref<CellSlice>& extra_B, Ref<CellSlice>& promise) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_msg_close& data) const;
  bool cell_unpack_chan_msg_close(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra_A, Ref<CellSlice>& extra_B, Ref<CellSlice>& promise) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_msg_close& data) const;
  bool pack_chan_msg_close(vm::CellBuilder& cb, Ref<CellSlice> extra_A, Ref<CellSlice> extra_B, Ref<CellSlice> promise) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_msg_close& data) const;
  bool cell_pack_chan_msg_close(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra_A, Ref<CellSlice> extra_B, Ref<CellSlice> promise) const;
  bool unpack(vm::CellSlice& cs, Record_chan_msg_timeout& data) const;
  bool unpack_chan_msg_timeout(vm::CellSlice& cs) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record_chan_msg_timeout& data) const;
  bool cell_unpack_chan_msg_timeout(Ref<vm::Cell> cell_ref) const;
  bool pack(vm::CellBuilder& cb, const Record_chan_msg_timeout& data) const;
  bool pack_chan_msg_timeout(vm::CellBuilder& cb) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record_chan_msg_timeout& data) const;
  bool cell_pack_chan_msg_timeout(Ref<vm::Cell>& cell_ref) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanMsg";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return cs.bselect(2, 11);
  }
};

struct ChanMsg::Record_chan_msg_init {
  typedef ChanMsg type_class;
  Ref<CellSlice> inc_A;  	// inc_A : Grams
  Ref<CellSlice> inc_B;  	// inc_B : Grams
  Ref<CellSlice> min_A;  	// min_A : Grams
  Ref<CellSlice> min_B;  	// min_B : Grams
  unsigned long long channel_id;  	// channel_id : uint64
  Record_chan_msg_init() = default;
  Record_chan_msg_init(Ref<CellSlice> _inc_A, Ref<CellSlice> _inc_B, Ref<CellSlice> _min_A, Ref<CellSlice> _min_B, unsigned long long _channel_id) : inc_A(std::move(_inc_A)), inc_B(std::move(_inc_B)), min_A(std::move(_min_A)), min_B(std::move(_min_B)), channel_id(_channel_id) {}
};

struct ChanMsg::Record_chan_msg_close {
  typedef ChanMsg type_class;
  Ref<CellSlice> extra_A;  	// extra_A : Grams
  Ref<CellSlice> extra_B;  	// extra_B : Grams
  Ref<CellSlice> promise;  	// promise : ChanSignedPromise
  Record_chan_msg_close() = default;
  Record_chan_msg_close(Ref<CellSlice> _extra_A, Ref<CellSlice> _extra_B, Ref<CellSlice> _promise) : extra_A(std::move(_extra_A)), extra_B(std::move(_extra_B)), promise(std::move(_promise)) {}
};

extern const ChanMsg t_ChanMsg;

//
// headers for type `ChanSignedMsg`
//

struct ChanSignedMsg final : TLB_Complex {
  enum { chan_signed_msg };
  static constexpr int cons_len_exact = 0;
  struct Record;
  bool skip(vm::CellSlice& cs) const override;
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_chan_signed_msg(vm::CellSlice& cs, Ref<CellSlice>& sig_A, Ref<CellSlice>& sig_B, Ref<CellSlice>& msg) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_chan_signed_msg(Ref<vm::Cell> cell_ref, Ref<CellSlice>& sig_A, Ref<CellSlice>& sig_B, Ref<CellSlice>& msg) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_chan_signed_msg(vm::CellBuilder& cb, Ref<CellSlice> sig_A, Ref<CellSlice> sig_B, Ref<CellSlice> msg) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_chan_signed_msg(Ref<vm::Cell>& cell_ref, Ref<CellSlice> sig_A, Ref<CellSlice> sig_B, Ref<CellSlice> msg) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanSignedMsg";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

struct ChanSignedMsg::Record {
  typedef ChanSignedMsg type_class;
  Ref<CellSlice> sig_A;  	// sig_A : Maybe ^bits512
  Ref<CellSlice> sig_B;  	// sig_B : Maybe ^bits512
  Ref<CellSlice> msg;  	// msg : ChanMsg
  Record() = default;
  Record(Ref<CellSlice> _sig_A, Ref<CellSlice> _sig_B, Ref<CellSlice> _msg) : sig_A(std::move(_sig_A)), sig_B(std::move(_sig_B)), msg(std::move(_msg)) {}
};

extern const ChanSignedMsg t_ChanSignedMsg;

//
// headers for type `ChanData`
//

struct ChanData final : TLB_Complex {
  enum { chan_data };
  static constexpr int cons_len_exact = 0;
  struct Record {
    typedef ChanData type_class;
    Ref<Cell> config;  	// config : ^ChanConfig
    Ref<Cell> state;  	// state : ^ChanState
    Record() = default;
    Record(Ref<Cell> _config, Ref<Cell> _state) : config(std::move(_config)), state(std::move(_state)) {}
  };
  int get_size(const vm::CellSlice& cs) const override {
    return 0x20000;
  }
  bool skip(vm::CellSlice& cs) const override {
    return cs.advance_ext(0x20000);
  }
  bool validate_skip(int* ops, vm::CellSlice& cs, bool weak = false) const override;
  bool unpack(vm::CellSlice& cs, Record& data) const;
  bool unpack_chan_data(vm::CellSlice& cs, Ref<Cell>& config, Ref<Cell>& state) const;
  bool cell_unpack(Ref<vm::Cell> cell_ref, Record& data) const;
  bool cell_unpack_chan_data(Ref<vm::Cell> cell_ref, Ref<Cell>& config, Ref<Cell>& state) const;
  bool pack(vm::CellBuilder& cb, const Record& data) const;
  bool pack_chan_data(vm::CellBuilder& cb, Ref<Cell> config, Ref<Cell> state) const;
  bool cell_pack(Ref<vm::Cell>& cell_ref, const Record& data) const;
  bool cell_pack_chan_data(Ref<vm::Cell>& cell_ref, Ref<Cell> config, Ref<Cell> state) const;
  bool print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const override;
  std::ostream& print_type(std::ostream& os) const override {
    return os << "ChanData";
  }
  int check_tag(const vm::CellSlice& cs) const override;
  int get_tag(const vm::CellSlice& cs) const override {
    return 0;
  }
};

extern const ChanData t_ChanData;

// declarations of constant types used

// ## 1
extern const NatWidth t_natwidth_1;
// ## 9
extern const NatWidth t_natwidth_9;
// #<= 30
extern const NatLeq t_natleq_30;
// Maybe Anycast
extern const Maybe t_Maybe_Anycast;
// int8
extern const Int t_int8;
// bits256
extern const Bits t_bits256;
// int32
extern const Int t_int32;
// VarUInteger 16
extern const VarUInteger t_VarUInteger_16;
// VarUInteger 32
extern const VarUInteger t_VarUInteger_32;
// HashmapE 32 (VarUInteger 32)
extern const HashmapE t_HashmapE_32_VarUInteger_32;
// uint64
extern const UInt t_uint64;
// uint32
extern const UInt t_uint32;
// ## 5
extern const NatWidth t_natwidth_5;
// Maybe (## 5)
extern const Maybe t_Maybe_natwidth_5;
// Maybe TickTock
extern const Maybe t_Maybe_TickTock;
// Maybe ^Cell
extern const Maybe t_Maybe_Ref_Cell;
// HashmapE 256 SimpleLib
extern const HashmapE t_HashmapE_256_SimpleLib;
// ^StateInit
extern const RefT t_Ref_StateInit;
// Either StateInit ^StateInit
extern const Either t_Either_StateInit_Ref_StateInit;
// Maybe (Either StateInit ^StateInit)
extern const Maybe t_Maybe_Either_StateInit_Ref_StateInit;
// Message Any
extern const Message t_Message_Any;
// #<= 96
extern const NatLeq t_natleq_96;
// ^(Message Any)
extern const RefT t_Ref_Message_Any;
// ^Transaction
extern const RefT t_Ref_Transaction;
// ^MsgEnvelope
extern const RefT t_Ref_MsgEnvelope;
// HashmapAugE 256 InMsg ImportFees
extern const HashmapAugE t_HashmapAugE_256_InMsg_ImportFees;
// ^InMsg
extern const RefT t_Ref_InMsg;
// uint63
extern const UInt t_uint63;
// HashmapAugE 256 OutMsg CurrencyCollection
extern const HashmapAugE t_HashmapAugE_256_OutMsg_CurrencyCollection;
// HashmapAugE 352 EnqueuedMsg uint64
extern const HashmapAugE t_HashmapAugE_352_EnqueuedMsg_uint64;
// HashmapE 96 ProcessedUpto
extern const HashmapE t_HashmapE_96_ProcessedUpto;
// HashmapE 320 IhrPendingSince
extern const HashmapE t_HashmapE_320_IhrPendingSince;
// VarUInteger 7
extern const VarUInteger t_VarUInteger_7;
// Maybe Grams
extern const Maybe t_Maybe_Grams;
// ^Account
extern const RefT t_Ref_Account;
// HashmapAugE 256 ShardAccount DepthBalanceInfo
extern const HashmapAugE t_HashmapAugE_256_ShardAccount_DepthBalanceInfo;
// uint15
extern const UInt t_uint15;
// Maybe ^(Message Any)
extern const Maybe t_Maybe_Ref_Message_Any;
// HashmapE 15 ^(Message Any)
extern const HashmapE t_HashmapE_15_Ref_Message_Any;
// ^[$_ in_msg:(Maybe ^(Message Any)) out_msgs:(HashmapE 15 ^(Message Any)) ]
extern const RefT t_Ref_TYPE_1614;
// HASH_UPDATE Account
extern const HASH_UPDATE t_HASH_UPDATE_Account;
// ^(HASH_UPDATE Account)
extern const RefT t_Ref_HASH_UPDATE_Account;
// ^TransactionDescr
extern const RefT t_Ref_TransactionDescr;
// uint16
extern const UInt t_uint16;
// HashmapAug 64 ^Transaction CurrencyCollection
extern const HashmapAug t_HashmapAug_64_Ref_Transaction_CurrencyCollection;
// HashmapAugE 256 AccountBlock CurrencyCollection
extern const HashmapAugE t_HashmapAugE_256_AccountBlock_CurrencyCollection;
// VarUInteger 3
extern const VarUInteger t_VarUInteger_3;
// Maybe (VarUInteger 3)
extern const Maybe t_Maybe_VarUInteger_3;
// Maybe int32
extern const Maybe t_Maybe_int32;
// ^[$_ gas_used:(VarUInteger 7) gas_limit:(VarUInteger 7) gas_credit:(Maybe (VarUInteger 3)) mode:int8 exit_code:int32 exit_arg:(Maybe int32) vm_steps:uint32 vm_init_state_hash:bits256 vm_final_state_hash:bits256 ]
extern const RefT t_Ref_TYPE_1626;
// Maybe TrStoragePhase
extern const Maybe t_Maybe_TrStoragePhase;
// Maybe TrCreditPhase
extern const Maybe t_Maybe_TrCreditPhase;
// ^TrActionPhase
extern const RefT t_Ref_TrActionPhase;
// Maybe ^TrActionPhase
extern const Maybe t_Maybe_Ref_TrActionPhase;
// Maybe TrBouncePhase
extern const Maybe t_Maybe_TrBouncePhase;
// ## 6
extern const NatWidth t_natwidth_6;
// ## 8
extern const NatWidth t_natwidth_8;
// MessageRelaxed Any
extern const MessageRelaxed t_MessageRelaxed_Any;
// ^(MessageRelaxed Any)
extern const RefT t_Ref_MessageRelaxed_Any;
// ## 7
extern const NatWidth t_natwidth_7;
// #<= 60
extern const NatLeq t_natleq_60;
// ^OutMsgQueueInfo
extern const RefT t_Ref_OutMsgQueueInfo;
// ^ShardAccounts
extern const RefT t_Ref_ShardAccounts;
// HashmapE 256 LibDescr
extern const HashmapE t_HashmapE_256_LibDescr;
// Maybe BlkMasterInfo
extern const Maybe t_Maybe_BlkMasterInfo;
// ^[$_ overload_history:uint64 underload_history:uint64 total_balance:CurrencyCollection total_validator_fees:CurrencyCollection libraries:(HashmapE 256 LibDescr) master_ref:(Maybe BlkMasterInfo) ]
extern const RefT t_Ref_TYPE_1640;
// ^McStateExtra
extern const RefT t_Ref_McStateExtra;
// Maybe ^McStateExtra
extern const Maybe t_Maybe_Ref_McStateExtra;
// ^ShardStateUnsplit
extern const RefT t_Ref_ShardStateUnsplit;
// Hashmap 256 True
extern const Hashmap t_Hashmap_256_True;
// ^BlkMasterInfo
extern const RefT t_Ref_BlkMasterInfo;
// BlkPrevInfo 0
extern const BlkPrevInfo t_BlkPrevInfo_0;
// ^(BlkPrevInfo 0)
extern const RefT t_Ref_BlkPrevInfo_0;
// ^ExtBlkRef
extern const RefT t_Ref_ExtBlkRef;
// ^BlockInfo
extern const RefT t_Ref_BlockInfo;
// ^ValueFlow
extern const RefT t_Ref_ValueFlow;
// MERKLE_UPDATE ShardState
extern const MERKLE_UPDATE t_MERKLE_UPDATE_ShardState;
// ^(MERKLE_UPDATE ShardState)
extern const RefT t_Ref_MERKLE_UPDATE_ShardState;
// ^BlockExtra
extern const RefT t_Ref_BlockExtra;
// ^InMsgDescr
extern const RefT t_Ref_InMsgDescr;
// ^OutMsgDescr
extern const RefT t_Ref_OutMsgDescr;
// ^ShardAccountBlocks
extern const RefT t_Ref_ShardAccountBlocks;
// ^McBlockExtra
extern const RefT t_Ref_McBlockExtra;
// Maybe ^McBlockExtra
extern const Maybe t_Maybe_Ref_McBlockExtra;
// ^[$_ from_prev_blk:CurrencyCollection to_next_blk:CurrencyCollection imported:CurrencyCollection exported:CurrencyCollection ]
extern const RefT t_Ref_TYPE_1651;
// ^[$_ fees_imported:CurrencyCollection recovered:CurrencyCollection created:CurrencyCollection minted:CurrencyCollection ]
extern const RefT t_Ref_TYPE_1652;
// ## 3
extern const NatWidth t_natwidth_3;
// ^[$_ fees_collected:CurrencyCollection funds_created:CurrencyCollection ]
extern const RefT t_Ref_TYPE_1656;
// BinTree ShardDescr
extern const BinTree t_BinTree_ShardDescr;
// ^(BinTree ShardDescr)
extern const RefT t_Ref_BinTree_ShardDescr;
// HashmapE 32 ^(BinTree ShardDescr)
extern const HashmapE t_HashmapE_32_Ref_BinTree_ShardDescr;
// HashmapAugE 96 ShardFeeCreated ShardFeeCreated
extern const HashmapAugE t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated;
// Hashmap 32 ^Cell
extern const Hashmap t_Hashmap_32_Ref_Cell;
// ^(Hashmap 32 ^Cell)
extern const RefT t_Ref_Hashmap_32_Ref_Cell;
// HashmapAugE 32 KeyExtBlkRef KeyMaxLt
extern const HashmapAugE t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt;
// HashmapE 256 CreatorStats
extern const HashmapE t_HashmapE_256_CreatorStats;
// HashmapAugE 256 CreatorStats uint32
extern const HashmapAugE t_HashmapAugE_256_CreatorStats_uint32;
// ## 16
extern const NatWidth t_natwidth_16;
// Maybe ExtBlkRef
extern const Maybe t_Maybe_ExtBlkRef;
// ^[$_ flags:(## 16) {<= flags 1} validator_info:ValidatorInfo prev_blocks:OldMcBlocksInfo after_key_block:Bool last_key_block:(Maybe ExtBlkRef) block_create_stats:flags.0?BlockCreateStats ]
extern const RefT t_Ref_TYPE_1670;
// ^SignedCertificate
extern const RefT t_Ref_SignedCertificate;
// HashmapE 16 CryptoSignaturePair
extern const HashmapE t_HashmapE_16_CryptoSignaturePair;
// Maybe ^InMsg
extern const Maybe t_Maybe_Ref_InMsg;
// ^[$_ prev_blk_signatures:(HashmapE 16 CryptoSignaturePair) recover_create_msg:(Maybe ^InMsg) mint_msg:(Maybe ^InMsg) ]
extern const RefT t_Ref_TYPE_1678;
// Hashmap 16 ValidatorDescr
extern const Hashmap t_Hashmap_16_ValidatorDescr;
// HashmapE 16 ValidatorDescr
extern const HashmapE t_HashmapE_16_ValidatorDescr;
// Hashmap 32 True
extern const Hashmap t_Hashmap_32_True;
// uint8
extern const UInt t_uint8;
// ^ConfigProposalSetup
extern const RefT t_Ref_ConfigProposalSetup;
// uint256
extern const UInt t_uint256;
// Maybe uint256
extern const Maybe t_Maybe_uint256;
// ^ConfigProposal
extern const RefT t_Ref_ConfigProposal;
// HashmapE 16 True
extern const HashmapE t_HashmapE_16_True;
// int64
extern const Int t_int64;
// ## 12
extern const NatWidth t_natwidth_12;
// ## 32
extern const NatWidth t_natwidth_32;
// ## 13
extern const NatWidth t_natwidth_13;
// HashmapE 32 WorkchainDescr
extern const HashmapE t_HashmapE_32_WorkchainDescr;
// Hashmap 32 StoragePrices
extern const Hashmap t_Hashmap_32_StoragePrices;
// HashmapE 256 True
extern const HashmapE t_HashmapE_256_True;
// ^ValidatorTempKey
extern const RefT t_Ref_ValidatorTempKey;
// HashmapE 256 ValidatorSignedTempKey
extern const HashmapE t_HashmapE_256_ValidatorSignedTempKey;
// ^BlockSignatures
extern const RefT t_Ref_BlockSignatures;
// Maybe ^BlockSignatures
extern const Maybe t_Maybe_Ref_BlockSignatures;
// ^TopBlockDescr
extern const RefT t_Ref_TopBlockDescr;
// HashmapE 96 ^TopBlockDescr
extern const HashmapE t_HashmapE_96_Ref_TopBlockDescr;
// MERKLE_PROOF Block
extern const MERKLE_PROOF t_MERKLE_PROOF_Block;
// ^(MERKLE_PROOF Block)
extern const RefT t_Ref_MERKLE_PROOF_Block;
// MERKLE_PROOF ShardState
extern const MERKLE_PROOF t_MERKLE_PROOF_ShardState;
// ^(MERKLE_PROOF ShardState)
extern const RefT t_Ref_MERKLE_PROOF_ShardState;
// ^ProducerInfo
extern const RefT t_Ref_ProducerInfo;
// ^ComplaintDescr
extern const RefT t_Ref_ComplaintDescr;
// ^ValidatorComplaint
extern const RefT t_Ref_ValidatorComplaint;
// int257
extern const Int t_int257;
// ## 10
extern const NatWidth t_natwidth_10;
// #<= 4
extern const NatLeq t_natleq_4;
// ^VmStackValue
extern const RefT t_Ref_VmStackValue;
// ## 24
extern const NatWidth t_natwidth_24;
// HashmapE 4 VmStackValue
extern const HashmapE t_HashmapE_4_VmStackValue;
// ^[$_ max_limit:int64 cur_limit:int64 credit:int64 ]
extern const RefT t_Ref_TYPE_1717;
// HashmapE 256 ^Cell
extern const HashmapE t_HashmapE_256_Ref_Cell;
// uint13
extern const UInt t_uint13;
// Maybe uint13
extern const Maybe t_Maybe_uint13;
// Maybe VmStack
extern const Maybe t_Maybe_VmStack;
// int16
extern const Int t_int16;
// Maybe int16
extern const Maybe t_Maybe_int16;
// ^VmCont
extern const RefT t_Ref_VmCont;
// ^DNSRecord
extern const RefT t_Ref_DNSRecord;
// HashmapE 16 ^DNSRecord
extern const HashmapE t_HashmapE_16_Ref_DNSRecord;
// ^MsgAddressInt
extern const RefT t_Ref_MsgAddressInt;
// bits512
extern const Bits t_bits512;
// ^bits512
extern const RefT t_Ref_bits512;
// Maybe ^bits512
extern const Maybe t_Maybe_Ref_bits512;
// ^ChanConfig
extern const RefT t_Ref_ChanConfig;
// ^ChanState
extern const RefT t_Ref_ChanState;

// declaration of type name registration function
extern bool register_simple_types(std::function<bool(const char*, const TLB*)> func);

} // namespace gen

} // namespace block
