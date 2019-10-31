#include "block-auto.h"
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
// uses built-in type `uint15`
// uses built-in type `uint16`
// uses built-in type `int32`
// uses built-in type `uint32`
// uses built-in type `uint64`
// uses built-in type `bits256`

namespace block {

namespace gen {
using namespace ::tlb;
using td::Ref;
using vm::CellSlice;
using vm::Cell;
using td::RefInt256;

//
// code for type `Unit`
//

int Unit::check_tag(const vm::CellSlice& cs) const {
  return unit;
}

bool Unit::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = 0;
  return true;
}

bool Unit::store_enum_from(vm::CellBuilder& cb, int value) const {
  return !value;
}

bool Unit::unpack(vm::CellSlice& cs, Unit::Record& data) const {
  return true;
}

bool Unit::unpack_unit(vm::CellSlice& cs) const {
  return true;
}

bool Unit::cell_unpack(Ref<vm::Cell> cell_ref, Unit::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Unit::cell_unpack_unit(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_unit(cs) && cs.empty_ext();
}

bool Unit::pack(vm::CellBuilder& cb, const Unit::Record& data) const {
  return true;
}

bool Unit::pack_unit(vm::CellBuilder& cb) const {
  return true;
}

bool Unit::cell_pack(Ref<vm::Cell>& cell_ref, const Unit::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Unit::cell_pack_unit(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_unit(cb) && std::move(cb).finalize_to(cell_ref);
}

bool Unit::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.cons("unit");
}

const Unit t_Unit;

//
// code for type `True`
//

int True::check_tag(const vm::CellSlice& cs) const {
  return true1;
}

bool True::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = 0;
  return true;
}

bool True::store_enum_from(vm::CellBuilder& cb, int value) const {
  return !value;
}

bool True::unpack(vm::CellSlice& cs, True::Record& data) const {
  return true;
}

bool True::unpack_true1(vm::CellSlice& cs) const {
  return true;
}

bool True::cell_unpack(Ref<vm::Cell> cell_ref, True::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool True::cell_unpack_true1(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_true1(cs) && cs.empty_ext();
}

bool True::pack(vm::CellBuilder& cb, const True::Record& data) const {
  return true;
}

bool True::pack_true1(vm::CellBuilder& cb) const {
  return true;
}

bool True::cell_pack(Ref<vm::Cell>& cell_ref, const True::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool True::cell_pack_true1(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_true1(cb) && std::move(cb).finalize_to(cell_ref);
}

bool True::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.cons("true");
}

const True t_True;

//
// code for type `Bool`
//

int Bool::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bool_false:
    return cs.have(1) ? bool_false : -1;
  case bool_true:
    return cs.have(1) ? bool_true : -1;
  }
  return -1;
}

bool Bool::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = (char)cs.fetch_ulong(1);
  return value >= 0;
}

bool Bool::store_enum_from(vm::CellBuilder& cb, int value) const {
  return cb.store_long_rchk_bool(value, 1);
}

bool Bool::unpack(vm::CellSlice& cs, Bool::Record_bool_false& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool Bool::unpack_bool_false(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool Bool::cell_unpack(Ref<vm::Cell> cell_ref, Bool::Record_bool_false& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Bool::cell_unpack_bool_false(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bool_false(cs) && cs.empty_ext();
}

bool Bool::unpack(vm::CellSlice& cs, Bool::Record_bool_true& data) const {
  return cs.fetch_ulong(1) == 1;
}

bool Bool::unpack_bool_true(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 1;
}

bool Bool::cell_unpack(Ref<vm::Cell> cell_ref, Bool::Record_bool_true& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Bool::cell_unpack_bool_true(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bool_true(cs) && cs.empty_ext();
}

bool Bool::pack(vm::CellBuilder& cb, const Bool::Record_bool_false& data) const {
  return cb.store_long_bool(0, 1);
}

bool Bool::pack_bool_false(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool Bool::cell_pack(Ref<vm::Cell>& cell_ref, const Bool::Record_bool_false& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Bool::cell_pack_bool_false(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_bool_false(cb) && std::move(cb).finalize_to(cell_ref);
}

bool Bool::pack(vm::CellBuilder& cb, const Bool::Record_bool_true& data) const {
  return cb.store_long_bool(1, 1);
}

bool Bool::pack_bool_true(vm::CellBuilder& cb) const {
  return cb.store_long_bool(1, 1);
}

bool Bool::cell_pack(Ref<vm::Cell>& cell_ref, const Bool::Record_bool_true& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Bool::cell_pack_bool_true(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_bool_true(cb) && std::move(cb).finalize_to(cell_ref);
}

bool Bool::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bool_false:
    return cs.advance(1)
        && pp.cons("bool_false");
  case bool_true:
    return cs.advance(1)
        && pp.cons("bool_true");
  }
  return pp.fail("unknown constructor for Bool");
}

const Bool t_Bool;

//
// code for type `BoolFalse`
//

int BoolFalse::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(1) == 0 ? bool_false : -1;
}

bool BoolFalse::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(1) == 0;
}

bool BoolFalse::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = (cs.fetch_ulong(1) == 0) ? 0 : -1;
  return !value;
}

bool BoolFalse::store_enum_from(vm::CellBuilder& cb, int value) const {
  return !value && cb.store_long_bool(0, 1);
}

bool BoolFalse::unpack(vm::CellSlice& cs, BoolFalse::Record& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool BoolFalse::unpack_bool_false(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool BoolFalse::cell_unpack(Ref<vm::Cell> cell_ref, BoolFalse::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BoolFalse::cell_unpack_bool_false(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bool_false(cs) && cs.empty_ext();
}

bool BoolFalse::pack(vm::CellBuilder& cb, const BoolFalse::Record& data) const {
  return cb.store_long_bool(0, 1);
}

bool BoolFalse::pack_bool_false(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool BoolFalse::cell_pack(Ref<vm::Cell>& cell_ref, const BoolFalse::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BoolFalse::cell_pack_bool_false(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_bool_false(cb) && std::move(cb).finalize_to(cell_ref);
}

bool BoolFalse::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0
      && pp.cons("bool_false");
}

const BoolFalse t_BoolFalse;

//
// code for type `BoolTrue`
//
constexpr unsigned char BoolTrue::cons_tag[1];

int BoolTrue::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(1) == 1 ? bool_true : -1;
}

bool BoolTrue::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(1) == 1;
}

bool BoolTrue::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = (cs.fetch_ulong(1) == 1) ? 0 : -1;
  return !value;
}

bool BoolTrue::store_enum_from(vm::CellBuilder& cb, int value) const {
  return !value && cb.store_long_bool(1, 1);
}

bool BoolTrue::unpack(vm::CellSlice& cs, BoolTrue::Record& data) const {
  return cs.fetch_ulong(1) == 1;
}

bool BoolTrue::unpack_bool_true(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 1;
}

bool BoolTrue::cell_unpack(Ref<vm::Cell> cell_ref, BoolTrue::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BoolTrue::cell_unpack_bool_true(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bool_true(cs) && cs.empty_ext();
}

bool BoolTrue::pack(vm::CellBuilder& cb, const BoolTrue::Record& data) const {
  return cb.store_long_bool(1, 1);
}

bool BoolTrue::pack_bool_true(vm::CellBuilder& cb) const {
  return cb.store_long_bool(1, 1);
}

bool BoolTrue::cell_pack(Ref<vm::Cell>& cell_ref, const BoolTrue::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BoolTrue::cell_pack_bool_true(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_bool_true(cb) && std::move(cb).finalize_to(cell_ref);
}

bool BoolTrue::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 1
      && pp.cons("bool_true");
}

const BoolTrue t_BoolTrue;

//
// code for type `Maybe`
//

int Maybe::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case nothing:
    return cs.have(1) ? nothing : -1;
  case just:
    return cs.have(1) ? just : -1;
  }
  return -1;
}

bool Maybe::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case nothing:
    return cs.advance(1);
  case just:
    return cs.advance(1)
        && X_.skip(cs);
  }
  return false;
}

bool Maybe::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case nothing:
    return cs.advance(1);
  case just:
    return cs.advance(1)
        && X_.validate_skip(cs, weak);
  }
  return false;
}

bool Maybe::unpack(vm::CellSlice& cs, Maybe::Record_nothing& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool Maybe::unpack_nothing(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool Maybe::cell_unpack(Ref<vm::Cell> cell_ref, Maybe::Record_nothing& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Maybe::cell_unpack_nothing(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_nothing(cs) && cs.empty_ext();
}

bool Maybe::unpack(vm::CellSlice& cs, Maybe::Record_just& data) const {
  return cs.fetch_ulong(1) == 1
      && X_.fetch_to(cs, data.value);
}

bool Maybe::unpack_just(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return cs.fetch_ulong(1) == 1
      && X_.fetch_to(cs, value);
}

bool Maybe::cell_unpack(Ref<vm::Cell> cell_ref, Maybe::Record_just& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Maybe::cell_unpack_just(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_just(cs, value) && cs.empty_ext();
}

bool Maybe::pack(vm::CellBuilder& cb, const Maybe::Record_nothing& data) const {
  return cb.store_long_bool(0, 1);
}

bool Maybe::pack_nothing(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool Maybe::cell_pack(Ref<vm::Cell>& cell_ref, const Maybe::Record_nothing& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Maybe::cell_pack_nothing(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_nothing(cb) && std::move(cb).finalize_to(cell_ref);
}

bool Maybe::pack(vm::CellBuilder& cb, const Maybe::Record_just& data) const {
  return cb.store_long_bool(1, 1)
      && X_.store_from(cb, data.value);
}

bool Maybe::pack_just(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return cb.store_long_bool(1, 1)
      && X_.store_from(cb, value);
}

bool Maybe::cell_pack(Ref<vm::Cell>& cell_ref, const Maybe::Record_just& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Maybe::cell_pack_just(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_just(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool Maybe::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case nothing:
    return cs.advance(1)
        && pp.cons("nothing");
  case just:
    return cs.advance(1)
        && pp.open("just")
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for Maybe");
}


//
// code for type `Either`
//

int Either::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case left:
    return cs.have(1) ? left : -1;
  case right:
    return cs.have(1) ? right : -1;
  }
  return -1;
}

bool Either::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case left:
    return cs.advance(1)
        && X_.skip(cs);
  case right:
    return cs.advance(1)
        && Y_.skip(cs);
  }
  return false;
}

bool Either::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case left:
    return cs.advance(1)
        && X_.validate_skip(cs, weak);
  case right:
    return cs.advance(1)
        && Y_.validate_skip(cs, weak);
  }
  return false;
}

bool Either::unpack(vm::CellSlice& cs, Either::Record_left& data) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, data.value);
}

bool Either::unpack_left(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, value);
}

bool Either::cell_unpack(Ref<vm::Cell> cell_ref, Either::Record_left& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Either::cell_unpack_left(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_left(cs, value) && cs.empty_ext();
}

bool Either::unpack(vm::CellSlice& cs, Either::Record_right& data) const {
  return cs.fetch_ulong(1) == 1
      && Y_.fetch_to(cs, data.value);
}

bool Either::unpack_right(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return cs.fetch_ulong(1) == 1
      && Y_.fetch_to(cs, value);
}

bool Either::cell_unpack(Ref<vm::Cell> cell_ref, Either::Record_right& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Either::cell_unpack_right(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_right(cs, value) && cs.empty_ext();
}

bool Either::pack(vm::CellBuilder& cb, const Either::Record_left& data) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, data.value);
}

bool Either::pack_left(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, value);
}

bool Either::cell_pack(Ref<vm::Cell>& cell_ref, const Either::Record_left& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Either::cell_pack_left(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_left(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool Either::pack(vm::CellBuilder& cb, const Either::Record_right& data) const {
  return cb.store_long_bool(1, 1)
      && Y_.store_from(cb, data.value);
}

bool Either::pack_right(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return cb.store_long_bool(1, 1)
      && Y_.store_from(cb, value);
}

bool Either::cell_pack(Ref<vm::Cell>& cell_ref, const Either::Record_right& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Either::cell_pack_right(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_right(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool Either::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case left:
    return cs.advance(1)
        && pp.open("left")
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  case right:
    return cs.advance(1)
        && pp.open("right")
        && pp.field("value")
        && Y_.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for Either");
}


//
// code for type `Both`
//

int Both::check_tag(const vm::CellSlice& cs) const {
  return pair;
}

bool Both::skip(vm::CellSlice& cs) const {
  return X_.skip(cs)
      && Y_.skip(cs);
}

bool Both::validate_skip(vm::CellSlice& cs, bool weak) const {
  return X_.validate_skip(cs, weak)
      && Y_.validate_skip(cs, weak);
}

bool Both::unpack(vm::CellSlice& cs, Both::Record& data) const {
  return X_.fetch_to(cs, data.first)
      && Y_.fetch_to(cs, data.second);
}

bool Both::unpack_pair(vm::CellSlice& cs, Ref<CellSlice>& first, Ref<CellSlice>& second) const {
  return X_.fetch_to(cs, first)
      && Y_.fetch_to(cs, second);
}

bool Both::cell_unpack(Ref<vm::Cell> cell_ref, Both::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Both::cell_unpack_pair(Ref<vm::Cell> cell_ref, Ref<CellSlice>& first, Ref<CellSlice>& second) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_pair(cs, first, second) && cs.empty_ext();
}

bool Both::pack(vm::CellBuilder& cb, const Both::Record& data) const {
  return X_.store_from(cb, data.first)
      && Y_.store_from(cb, data.second);
}

bool Both::pack_pair(vm::CellBuilder& cb, Ref<CellSlice> first, Ref<CellSlice> second) const {
  return X_.store_from(cb, first)
      && Y_.store_from(cb, second);
}

bool Both::cell_pack(Ref<vm::Cell>& cell_ref, const Both::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Both::cell_pack_pair(Ref<vm::Cell>& cell_ref, Ref<CellSlice> first, Ref<CellSlice> second) const {
  vm::CellBuilder cb;
  return pack_pair(cb, std::move(first), std::move(second)) && std::move(cb).finalize_to(cell_ref);
}

bool Both::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("pair")
      && pp.field("first")
      && X_.print_skip(pp, cs)
      && pp.field("second")
      && Y_.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `Bit`
//

int Bit::check_tag(const vm::CellSlice& cs) const {
  return bit;
}

bool Bit::unpack(vm::CellSlice& cs, Bit::Record& data) const {
  return cs.fetch_bool_to(data.x);
}

bool Bit::unpack_bit(vm::CellSlice& cs, bool& x) const {
  return cs.fetch_bool_to(x);
}

bool Bit::cell_unpack(Ref<vm::Cell> cell_ref, Bit::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Bit::cell_unpack_bit(Ref<vm::Cell> cell_ref, bool& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bit(cs, x) && cs.empty_ext();
}

bool Bit::pack(vm::CellBuilder& cb, const Bit::Record& data) const {
  return cb.store_ulong_rchk_bool(data.x, 1);
}

bool Bit::pack_bit(vm::CellBuilder& cb, bool x) const {
  return cb.store_ulong_rchk_bool(x, 1);
}

bool Bit::cell_pack(Ref<vm::Cell>& cell_ref, const Bit::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Bit::cell_pack_bit(Ref<vm::Cell>& cell_ref, bool x) const {
  vm::CellBuilder cb;
  return pack_bit(cb, x) && std::move(cb).finalize_to(cell_ref);
}

bool Bit::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int t1;
  return pp.open("bit")
      && cs.fetch_bool_to(t1)
      && pp.field_int(t1)
      && pp.close();
}

const Bit t_Bit;

//
// code for type `Hashmap`
//

int Hashmap::check_tag(const vm::CellSlice& cs) const {
  return hm_edge;
}

bool Hashmap::skip(vm::CellSlice& cs) const {
  int l, m;
  return HmLabel{m_}.skip(cs, l)
      && add_r1(m, l, m_)
      && HashmapNode{m, X_}.skip(cs);
}

bool Hashmap::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l, m;
  return HmLabel{m_}.validate_skip(cs, weak, l)
      && add_r1(m, l, m_)
      && HashmapNode{m, X_}.validate_skip(cs, weak);
}

bool Hashmap::unpack(vm::CellSlice& cs, Hashmap::Record& data) const {
  return (data.n = m_) >= 0
      && HmLabel{m_}.fetch_to(cs, data.label, data.l)
      && add_r1(data.m, data.l, m_)
      && HashmapNode{data.m, X_}.fetch_to(cs, data.node);
}

bool Hashmap::cell_unpack(Ref<vm::Cell> cell_ref, Hashmap::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Hashmap::pack(vm::CellBuilder& cb, const Hashmap::Record& data) const {
  int l, m;
  return tlb::store_from(cb, HmLabel{m_}, data.label, l)
      && add_r1(m, l, m_)
      && HashmapNode{m, X_}.store_from(cb, data.node);
}

bool Hashmap::cell_pack(Ref<vm::Cell>& cell_ref, const Hashmap::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Hashmap::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int l, m;
  return pp.open("hm_edge")
      && pp.field("label")
      && HmLabel{m_}.print_skip(pp, cs, l)
      && add_r1(m, l, m_)
      && pp.field("node")
      && HashmapNode{m, X_}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `HashmapNode`
//

int HashmapNode::get_tag(const vm::CellSlice& cs) const {
  // distinguish by parameter `m_` using 1 2 2 2
  return m_ ? hmn_fork : hmn_leaf;
}

int HashmapNode::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hmn_leaf:
    return hmn_leaf;
  case hmn_fork:
    return hmn_fork;
  }
  return -1;
}

bool HashmapNode::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hmn_leaf:
    return m_ == 0
        && X_.skip(cs);
  case hmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_refs(2);
    }
  }
  return false;
}

bool HashmapNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case hmn_leaf:
    return m_ == 0
        && X_.validate_skip(cs, weak);
  case hmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && Hashmap{n, X_}.validate_skip_ref(cs, weak)
        && Hashmap{n, X_}.validate_skip_ref(cs, weak);
    }
  }
  return false;
}

bool HashmapNode::unpack(vm::CellSlice& cs, HashmapNode::Record_hmn_leaf& data) const {
  return m_ == 0
      && X_.fetch_to(cs, data.value);
}

bool HashmapNode::unpack_hmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return m_ == 0
      && X_.fetch_to(cs, value);
}

bool HashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, HashmapNode::Record_hmn_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapNode::cell_unpack_hmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hmn_leaf(cs, value) && cs.empty_ext();
}

bool HashmapNode::unpack(vm::CellSlice& cs, HashmapNode::Record_hmn_fork& data) const {
  return add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right);
}

bool HashmapNode::unpack_hmn_fork(vm::CellSlice& cs, int& n, Ref<Cell>& left, Ref<Cell>& right) const {
  return add_r1(n, 1, m_)
      && cs.fetch_ref_to(left)
      && cs.fetch_ref_to(right);
}

bool HashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, HashmapNode::Record_hmn_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapNode::cell_unpack_hmn_fork(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& left, Ref<Cell>& right) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hmn_fork(cs, n, left, right) && cs.empty_ext();
}

bool HashmapNode::pack(vm::CellBuilder& cb, const HashmapNode::Record_hmn_leaf& data) const {
  return m_ == 0
      && X_.store_from(cb, data.value);
}

bool HashmapNode::pack_hmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return m_ == 0
      && X_.store_from(cb, value);
}

bool HashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapNode::Record_hmn_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapNode::cell_pack_hmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_hmn_leaf(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapNode::pack(vm::CellBuilder& cb, const HashmapNode::Record_hmn_fork& data) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right);
}

bool HashmapNode::pack_hmn_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(left)
      && cb.store_ref_bool(right);
}

bool HashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapNode::Record_hmn_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapNode::cell_pack_hmn_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const {
  vm::CellBuilder cb;
  return pack_hmn_fork(cb, std::move(left), std::move(right)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapNode::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hmn_leaf:
    return pp.open("hmn_leaf")
        && m_ == 0
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  case hmn_fork: {
    int n;
    return pp.open("hmn_fork")
        && add_r1(n, 1, m_)
        && pp.field("left")
        && Hashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && Hashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for HashmapNode");
}


//
// code for type `HmLabel`
//
constexpr char HmLabel::cons_len[3];
constexpr unsigned char HmLabel::cons_tag[3];

int HmLabel::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hml_short:
    return cs.have(1) ? hml_short : -1;
  case hml_long:
    return cs.have(2) ? hml_long : -1;
  case hml_same:
    return cs.have(2) ? hml_same : -1;
  }
  return -1;
}

bool HmLabel::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hml_short: {
    int m_;
    return cs.advance(1)
        && t_Unary.skip(cs, m_)
        && m_ <= n_
        && cs.advance(m_);
    }
  case hml_long: {
    int m_;
    return cs.advance(2)
        && cs.fetch_uint_leq(n_, m_)
        && cs.advance(m_);
    }
  case hml_same: {
    int m_;
    return cs.advance(3)
        && cs.fetch_uint_leq(n_, m_);
    }
  }
  return false;
}

bool HmLabel::skip(vm::CellSlice& cs, int& m_) const {
  switch (get_tag(cs)) {
  case hml_short:
    return cs.advance(1)
        && t_Unary.skip(cs, m_)
        && m_ <= n_
        && cs.advance(m_);
  case hml_long:
    return cs.advance(2)
        && cs.fetch_uint_leq(n_, m_)
        && cs.advance(m_);
  case hml_same:
    return cs.advance(3)
        && cs.fetch_uint_leq(n_, m_);
  }
  return false;
}

bool HmLabel::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case hml_short: {
    int m_;
    return cs.advance(1)
        && t_Unary.validate_skip(cs, weak, m_)
        && m_ <= n_
        && cs.advance(m_);
    }
  case hml_long: {
    int m_;
    return cs.advance(2)
        && cs.fetch_uint_leq(n_, m_)
        && cs.advance(m_);
    }
  case hml_same: {
    int m_;
    return cs.advance(3)
        && cs.fetch_uint_leq(n_, m_);
    }
  }
  return false;
}

bool HmLabel::validate_skip(vm::CellSlice& cs, bool weak, int& m_) const {
  switch (get_tag(cs)) {
  case hml_short:
    return cs.advance(1)
        && t_Unary.validate_skip(cs, weak, m_)
        && m_ <= n_
        && cs.advance(m_);
  case hml_long:
    return cs.advance(2)
        && cs.fetch_uint_leq(n_, m_)
        && cs.advance(m_);
  case hml_same:
    return cs.advance(3)
        && cs.fetch_uint_leq(n_, m_);
  }
  return false;
}

bool HmLabel::fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res, int& m_) const {
  res = Ref<vm::CellSlice>{true, cs};
  return skip(cs, m_) && res.unique_write().cut_tail(cs);
}

bool HmLabel::unpack(vm::CellSlice& cs, HmLabel::Record_hml_short& data, int& m_) const {
  return cs.fetch_ulong(1) == 0
      && (data.m = n_) >= 0
      && t_Unary.fetch_to(cs, data.len, data.n)
      && data.n <= n_
      && cs.fetch_bitstring_to(data.n, data.s)
      && (m_ = data.n) >= 0;
}

bool HmLabel::cell_unpack(Ref<vm::Cell> cell_ref, HmLabel::Record_hml_short& data, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data, m_) && cs.empty_ext();
}

bool HmLabel::unpack(vm::CellSlice& cs, HmLabel::Record_hml_long& data, int& m_) const {
  return cs.fetch_ulong(2) == 2
      && (data.m = n_) >= 0
      && cs.fetch_uint_leq(n_, data.n)
      && cs.fetch_bitstring_to(data.n, data.s)
      && (m_ = data.n) >= 0;
}

bool HmLabel::unpack_hml_long(vm::CellSlice& cs, int& m, int& n, Ref<td::BitString>& s, int& m_) const {
  return cs.fetch_ulong(2) == 2
      && (m = n_) >= 0
      && cs.fetch_uint_leq(n_, n)
      && cs.fetch_bitstring_to(n, s)
      && (m_ = n) >= 0;
}

bool HmLabel::cell_unpack(Ref<vm::Cell> cell_ref, HmLabel::Record_hml_long& data, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data, m_) && cs.empty_ext();
}

bool HmLabel::cell_unpack_hml_long(Ref<vm::Cell> cell_ref, int& m, int& n, Ref<td::BitString>& s, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hml_long(cs, m, n, s, m_) && cs.empty_ext();
}

bool HmLabel::unpack(vm::CellSlice& cs, HmLabel::Record_hml_same& data, int& m_) const {
  return cs.fetch_ulong(2) == 3
      && (data.m = n_) >= 0
      && cs.fetch_bool_to(data.v)
      && cs.fetch_uint_leq(n_, data.n)
      && (m_ = data.n) >= 0;
}

bool HmLabel::unpack_hml_same(vm::CellSlice& cs, int& m, bool& v, int& n, int& m_) const {
  return cs.fetch_ulong(2) == 3
      && (m = n_) >= 0
      && cs.fetch_bool_to(v)
      && cs.fetch_uint_leq(n_, n)
      && (m_ = n) >= 0;
}

bool HmLabel::cell_unpack(Ref<vm::Cell> cell_ref, HmLabel::Record_hml_same& data, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data, m_) && cs.empty_ext();
}

bool HmLabel::cell_unpack_hml_same(Ref<vm::Cell> cell_ref, int& m, bool& v, int& n, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hml_same(cs, m, v, n, m_) && cs.empty_ext();
}

bool HmLabel::pack(vm::CellBuilder& cb, const HmLabel::Record_hml_short& data, int& m_) const {
  return cb.store_long_bool(0, 1)
      && tlb::store_from(cb, t_Unary, data.len, m_)
      && m_ <= n_
      && cb.append_bitstring_chk(data.s, m_);
}

bool HmLabel::cell_pack(Ref<vm::Cell>& cell_ref, const HmLabel::Record_hml_short& data, int& m_) const {
  vm::CellBuilder cb;
  return pack(cb, data, m_) && std::move(cb).finalize_to(cell_ref);
}

bool HmLabel::pack(vm::CellBuilder& cb, const HmLabel::Record_hml_long& data, int& m_) const {
  return cb.store_long_bool(2, 2)
      && cb.store_uint_leq(n_, data.n)
      && cb.append_bitstring_chk(data.s, data.n)
      && (m_ = data.n) >= 0;
}

bool HmLabel::pack_hml_long(vm::CellBuilder& cb, int n, Ref<td::BitString> s, int& m_) const {
  return cb.store_long_bool(2, 2)
      && cb.store_uint_leq(n_, n)
      && cb.append_bitstring_chk(s, n)
      && (m_ = n) >= 0;
}

bool HmLabel::cell_pack(Ref<vm::Cell>& cell_ref, const HmLabel::Record_hml_long& data, int& m_) const {
  vm::CellBuilder cb;
  return pack(cb, data, m_) && std::move(cb).finalize_to(cell_ref);
}

bool HmLabel::cell_pack_hml_long(Ref<vm::Cell>& cell_ref, int n, Ref<td::BitString> s, int& m_) const {
  vm::CellBuilder cb;
  return pack_hml_long(cb, n, std::move(s), m_) && std::move(cb).finalize_to(cell_ref);
}

bool HmLabel::pack(vm::CellBuilder& cb, const HmLabel::Record_hml_same& data, int& m_) const {
  return cb.store_long_bool(3, 2)
      && cb.store_ulong_rchk_bool(data.v, 1)
      && cb.store_uint_leq(n_, data.n)
      && (m_ = data.n) >= 0;
}

bool HmLabel::pack_hml_same(vm::CellBuilder& cb, bool v, int n, int& m_) const {
  return cb.store_long_bool(3, 2)
      && cb.store_ulong_rchk_bool(v, 1)
      && cb.store_uint_leq(n_, n)
      && (m_ = n) >= 0;
}

bool HmLabel::cell_pack(Ref<vm::Cell>& cell_ref, const HmLabel::Record_hml_same& data, int& m_) const {
  vm::CellBuilder cb;
  return pack(cb, data, m_) && std::move(cb).finalize_to(cell_ref);
}

bool HmLabel::cell_pack_hml_same(Ref<vm::Cell>& cell_ref, bool v, int n, int& m_) const {
  vm::CellBuilder cb;
  return pack_hml_same(cb, v, n, m_) && std::move(cb).finalize_to(cell_ref);
}

bool HmLabel::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hml_short: {
    int m_;
    return cs.advance(1)
        && pp.open("hml_short")
        && pp.field("len")
        && t_Unary.print_skip(pp, cs, m_)
        && m_ <= n_
        && pp.fetch_bits_field(cs, m_, "s")
        && pp.close();
    }
  case hml_long: {
    int m_;
    return cs.advance(2)
        && pp.open("hml_long")
        && cs.fetch_uint_leq(n_, m_)
        && pp.field_int(m_, "n")
        && pp.fetch_bits_field(cs, m_, "s")
        && pp.close();
    }
  case hml_same: {
    int m_;
    return cs.advance(2)
        && pp.open("hml_same")
        && pp.fetch_uint_field(cs, 1, "v")
        && cs.fetch_uint_leq(n_, m_)
        && pp.field_int(m_, "n")
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for HmLabel");
}

bool HmLabel::print_skip(PrettyPrinter& pp, vm::CellSlice& cs, int& m_) const {
  switch (get_tag(cs)) {
  case hml_short:
    return cs.advance(1)
        && pp.open("hml_short")
        && pp.field("len")
        && t_Unary.print_skip(pp, cs, m_)
        && m_ <= n_
        && pp.fetch_bits_field(cs, m_, "s")
        && pp.close();
  case hml_long:
    return cs.advance(2)
        && pp.open("hml_long")
        && cs.fetch_uint_leq(n_, m_)
        && pp.field_int(m_, "n")
        && pp.fetch_bits_field(cs, m_, "s")
        && pp.close();
  case hml_same:
    return cs.advance(2)
        && pp.open("hml_same")
        && pp.fetch_uint_field(cs, 1, "v")
        && cs.fetch_uint_leq(n_, m_)
        && pp.field_int(m_, "n")
        && pp.close();
  }
  return pp.fail("unknown constructor for HmLabel");
}


//
// code for type `Unary`
//

int Unary::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return cs.have(1) ? unary_zero : -1;
  case unary_succ:
    return cs.have(1) ? unary_succ : -1;
  }
  return -1;
}

bool Unary::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return cs.advance(1);
  case unary_succ: {
    int n;
    return cs.advance(1)
        && skip(cs, n);
    }
  }
  return false;
}

bool Unary::skip(vm::CellSlice& cs, int& m_) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return (m_ = 0) >= 0
        && cs.advance(1);
  case unary_succ: {
    int n;
    return cs.advance(1)
        && skip(cs, n)
        && (m_ = n + 1) >= 0;
    }
  }
  return false;
}

bool Unary::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return cs.advance(1);
  case unary_succ: {
    int n;
    return cs.advance(1)
        && validate_skip(cs, weak, n);
    }
  }
  return false;
}

bool Unary::validate_skip(vm::CellSlice& cs, bool weak, int& m_) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return (m_ = 0) >= 0
        && cs.advance(1);
  case unary_succ: {
    int n;
    return cs.advance(1)
        && validate_skip(cs, weak, n)
        && (m_ = n + 1) >= 0;
    }
  }
  return false;
}

bool Unary::fetch_to(vm::CellSlice& cs, Ref<vm::CellSlice>& res, int& m_) const {
  res = Ref<vm::CellSlice>{true, cs};
  return skip(cs, m_) && res.unique_write().cut_tail(cs);
}

bool Unary::unpack(vm::CellSlice& cs, Unary::Record_unary_zero& data, int& m_) const {
  return cs.fetch_ulong(1) == 0
      && (m_ = 0) >= 0;
}

bool Unary::unpack_unary_zero(vm::CellSlice& cs, int& m_) const {
  return cs.fetch_ulong(1) == 0
      && (m_ = 0) >= 0;
}

bool Unary::cell_unpack(Ref<vm::Cell> cell_ref, Unary::Record_unary_zero& data, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data, m_) && cs.empty_ext();
}

bool Unary::cell_unpack_unary_zero(Ref<vm::Cell> cell_ref, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_unary_zero(cs, m_) && cs.empty_ext();
}

bool Unary::unpack(vm::CellSlice& cs, Unary::Record_unary_succ& data, int& m_) const {
  return cs.fetch_ulong(1) == 1
      && fetch_to(cs, data.x, data.n)
      && (m_ = data.n + 1) >= 0;
}

bool Unary::unpack_unary_succ(vm::CellSlice& cs, int& n, Ref<CellSlice>& x, int& m_) const {
  return cs.fetch_ulong(1) == 1
      && fetch_to(cs, x, n)
      && (m_ = n + 1) >= 0;
}

bool Unary::cell_unpack(Ref<vm::Cell> cell_ref, Unary::Record_unary_succ& data, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data, m_) && cs.empty_ext();
}

bool Unary::cell_unpack_unary_succ(Ref<vm::Cell> cell_ref, int& n, Ref<CellSlice>& x, int& m_) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_unary_succ(cs, n, x, m_) && cs.empty_ext();
}

bool Unary::pack(vm::CellBuilder& cb, const Unary::Record_unary_zero& data, int& m_) const {
  return cb.store_long_bool(0, 1)
      && (m_ = 0) >= 0;
}

bool Unary::pack_unary_zero(vm::CellBuilder& cb, int& m_) const {
  return cb.store_long_bool(0, 1)
      && (m_ = 0) >= 0;
}

bool Unary::cell_pack(Ref<vm::Cell>& cell_ref, const Unary::Record_unary_zero& data, int& m_) const {
  vm::CellBuilder cb;
  return pack(cb, data, m_) && std::move(cb).finalize_to(cell_ref);
}

bool Unary::cell_pack_unary_zero(Ref<vm::Cell>& cell_ref, int& m_) const {
  vm::CellBuilder cb;
  return pack_unary_zero(cb, m_) && std::move(cb).finalize_to(cell_ref);
}

bool Unary::pack(vm::CellBuilder& cb, const Unary::Record_unary_succ& data, int& m_) const {
  int n;
  return cb.store_long_bool(1, 1)
      && tlb::store_from(cb, *this, data.x, n)
      && (m_ = n + 1) >= 0;
}

bool Unary::pack_unary_succ(vm::CellBuilder& cb, Ref<CellSlice> x, int& m_) const {
  int n;
  return cb.store_long_bool(1, 1)
      && tlb::store_from(cb, *this, x, n)
      && (m_ = n + 1) >= 0;
}

bool Unary::cell_pack(Ref<vm::Cell>& cell_ref, const Unary::Record_unary_succ& data, int& m_) const {
  vm::CellBuilder cb;
  return pack(cb, data, m_) && std::move(cb).finalize_to(cell_ref);
}

bool Unary::cell_pack_unary_succ(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x, int& m_) const {
  vm::CellBuilder cb;
  return pack_unary_succ(cb, std::move(x), m_) && std::move(cb).finalize_to(cell_ref);
}

bool Unary::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return cs.advance(1)
        && pp.cons("unary_zero");
  case unary_succ: {
    int n;
    return cs.advance(1)
        && pp.open("unary_succ")
        && pp.field("x")
        && print_skip(pp, cs, n)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for Unary");
}

bool Unary::print_skip(PrettyPrinter& pp, vm::CellSlice& cs, int& m_) const {
  switch (get_tag(cs)) {
  case unary_zero:
    return cs.advance(1)
        && pp.cons("unary_zero")
        && (m_ = 0) >= 0;
  case unary_succ: {
    int n;
    return cs.advance(1)
        && pp.open("unary_succ")
        && pp.field("x")
        && print_skip(pp, cs, n)
        && (m_ = n + 1) >= 0
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for Unary");
}

const Unary t_Unary;

//
// code for type `HashmapE`
//

int HashmapE::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hme_empty:
    return cs.have(1) ? hme_empty : -1;
  case hme_root:
    return cs.have(1) ? hme_root : -1;
  }
  return -1;
}

bool HashmapE::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hme_empty:
    return cs.advance(1);
  case hme_root:
    return cs.advance_ext(0x10001);
  }
  return false;
}

bool HashmapE::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case hme_empty:
    return cs.advance(1);
  case hme_root:
    return cs.advance(1)
        && Hashmap{m_, X_}.validate_skip_ref(cs, weak);
  }
  return false;
}

bool HashmapE::unpack(vm::CellSlice& cs, HashmapE::Record_hme_empty& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool HashmapE::unpack_hme_empty(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool HashmapE::cell_unpack(Ref<vm::Cell> cell_ref, HashmapE::Record_hme_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapE::cell_unpack_hme_empty(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hme_empty(cs) && cs.empty_ext();
}

bool HashmapE::unpack(vm::CellSlice& cs, HashmapE::Record_hme_root& data) const {
  return cs.fetch_ulong(1) == 1
      && (data.n = m_) >= 0
      && cs.fetch_ref_to(data.root);
}

bool HashmapE::unpack_hme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const {
  return cs.fetch_ulong(1) == 1
      && (n = m_) >= 0
      && cs.fetch_ref_to(root);
}

bool HashmapE::cell_unpack(Ref<vm::Cell> cell_ref, HashmapE::Record_hme_root& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapE::cell_unpack_hme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_hme_root(cs, n, root) && cs.empty_ext();
}

bool HashmapE::pack(vm::CellBuilder& cb, const HashmapE::Record_hme_empty& data) const {
  return cb.store_long_bool(0, 1);
}

bool HashmapE::pack_hme_empty(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool HashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapE::Record_hme_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapE::cell_pack_hme_empty(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_hme_empty(cb) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapE::pack(vm::CellBuilder& cb, const HashmapE::Record_hme_root& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.root);
}

bool HashmapE::pack_hme_root(vm::CellBuilder& cb, Ref<Cell> root) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(root);
}

bool HashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapE::Record_hme_root& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapE::cell_pack_hme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const {
  vm::CellBuilder cb;
  return pack_hme_root(cb, std::move(root)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case hme_empty:
    return cs.advance(1)
        && pp.cons("hme_empty");
  case hme_root:
    return cs.advance(1)
        && pp.open("hme_root")
        && pp.field("root")
        && Hashmap{m_, X_}.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for HashmapE");
}


//
// code for type `BitstringSet`
//

int BitstringSet::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool BitstringSet::skip(vm::CellSlice& cs) const {
  return Hashmap{m_, t_True}.skip(cs);
}

bool BitstringSet::validate_skip(vm::CellSlice& cs, bool weak) const {
  return Hashmap{m_, t_True}.validate_skip(cs, weak);
}

bool BitstringSet::unpack(vm::CellSlice& cs, BitstringSet::Record& data) const {
  return (data.n = m_) >= 0
      && Hashmap{m_, t_True}.fetch_to(cs, data.x);
}

bool BitstringSet::unpack_cons1(vm::CellSlice& cs, int& n, Ref<CellSlice>& x) const {
  return (n = m_) >= 0
      && Hashmap{m_, t_True}.fetch_to(cs, x);
}

bool BitstringSet::cell_unpack(Ref<vm::Cell> cell_ref, BitstringSet::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BitstringSet::cell_unpack_cons1(Ref<vm::Cell> cell_ref, int& n, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, n, x) && cs.empty_ext();
}

bool BitstringSet::pack(vm::CellBuilder& cb, const BitstringSet::Record& data) const {
  return Hashmap{m_, t_True}.store_from(cb, data.x);
}

bool BitstringSet::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return Hashmap{m_, t_True}.store_from(cb, x);
}

bool BitstringSet::cell_pack(Ref<vm::Cell>& cell_ref, const BitstringSet::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BitstringSet::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool BitstringSet::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && Hashmap{m_, t_True}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `HashmapAug`
//

int HashmapAug::check_tag(const vm::CellSlice& cs) const {
  return ahm_edge;
}

bool HashmapAug::skip(vm::CellSlice& cs) const {
  int l, m;
  return HmLabel{m_}.skip(cs, l)
      && add_r1(m, l, m_)
      && HashmapAugNode{m, X_, Y_}.skip(cs);
}

bool HashmapAug::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l, m;
  return HmLabel{m_}.validate_skip(cs, weak, l)
      && add_r1(m, l, m_)
      && HashmapAugNode{m, X_, Y_}.validate_skip(cs, weak);
}

bool HashmapAug::unpack(vm::CellSlice& cs, HashmapAug::Record& data) const {
  return (data.n = m_) >= 0
      && HmLabel{m_}.fetch_to(cs, data.label, data.l)
      && add_r1(data.m, data.l, m_)
      && HashmapAugNode{data.m, X_, Y_}.fetch_to(cs, data.node);
}

bool HashmapAug::cell_unpack(Ref<vm::Cell> cell_ref, HashmapAug::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapAug::pack(vm::CellBuilder& cb, const HashmapAug::Record& data) const {
  int l, m;
  return tlb::store_from(cb, HmLabel{m_}, data.label, l)
      && add_r1(m, l, m_)
      && HashmapAugNode{m, X_, Y_}.store_from(cb, data.node);
}

bool HashmapAug::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapAug::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAug::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int l, m;
  return pp.open("ahm_edge")
      && pp.field("label")
      && HmLabel{m_}.print_skip(pp, cs, l)
      && add_r1(m, l, m_)
      && pp.field("node")
      && HashmapAugNode{m, X_, Y_}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `HashmapAugNode`
//

int HashmapAugNode::get_tag(const vm::CellSlice& cs) const {
  // distinguish by parameter `m_` using 1 2 2 2
  return m_ ? ahmn_fork : ahmn_leaf;
}

int HashmapAugNode::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahmn_leaf:
    return ahmn_leaf;
  case ahmn_fork:
    return ahmn_fork;
  }
  return -1;
}

bool HashmapAugNode::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahmn_leaf:
    return m_ == 0
        && Y_.skip(cs)
        && X_.skip(cs);
  case ahmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_refs(2)
        && Y_.skip(cs);
    }
  }
  return false;
}

bool HashmapAugNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case ahmn_leaf:
    return m_ == 0
        && Y_.validate_skip(cs, weak)
        && X_.validate_skip(cs, weak);
  case ahmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && HashmapAug{n, X_, Y_}.validate_skip_ref(cs, weak)
        && HashmapAug{n, X_, Y_}.validate_skip_ref(cs, weak)
        && Y_.validate_skip(cs, weak);
    }
  }
  return false;
}

bool HashmapAugNode::unpack(vm::CellSlice& cs, HashmapAugNode::Record_ahmn_leaf& data) const {
  return m_ == 0
      && Y_.fetch_to(cs, data.extra)
      && X_.fetch_to(cs, data.value);
}

bool HashmapAugNode::unpack_ahmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& extra, Ref<CellSlice>& value) const {
  return m_ == 0
      && Y_.fetch_to(cs, extra)
      && X_.fetch_to(cs, value);
}

bool HashmapAugNode::cell_unpack(Ref<vm::Cell> cell_ref, HashmapAugNode::Record_ahmn_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapAugNode::cell_unpack_ahmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ahmn_leaf(cs, extra, value) && cs.empty_ext();
}

bool HashmapAugNode::unpack(vm::CellSlice& cs, HashmapAugNode::Record_ahmn_fork& data) const {
  return add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right)
      && Y_.fetch_to(cs, data.extra);
}

bool HashmapAugNode::cell_unpack(Ref<vm::Cell> cell_ref, HashmapAugNode::Record_ahmn_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapAugNode::pack(vm::CellBuilder& cb, const HashmapAugNode::Record_ahmn_leaf& data) const {
  return m_ == 0
      && Y_.store_from(cb, data.extra)
      && X_.store_from(cb, data.value);
}

bool HashmapAugNode::pack_ahmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> extra, Ref<CellSlice> value) const {
  return m_ == 0
      && Y_.store_from(cb, extra)
      && X_.store_from(cb, value);
}

bool HashmapAugNode::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapAugNode::Record_ahmn_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugNode::cell_pack_ahmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_ahmn_leaf(cb, std::move(extra), std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugNode::pack(vm::CellBuilder& cb, const HashmapAugNode::Record_ahmn_fork& data) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right)
      && Y_.store_from(cb, data.extra);
}

bool HashmapAugNode::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapAugNode::Record_ahmn_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugNode::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahmn_leaf:
    return pp.open("ahmn_leaf")
        && m_ == 0
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  case ahmn_fork: {
    int n;
    return pp.open("ahmn_fork")
        && add_r1(n, 1, m_)
        && pp.field("left")
        && HashmapAug{n, X_, Y_}.print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && HashmapAug{n, X_, Y_}.print_ref(pp, cs.fetch_ref())
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for HashmapAugNode");
}


//
// code for type `HashmapAugE`
//

int HashmapAugE::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahme_empty:
    return cs.have(1) ? ahme_empty : -1;
  case ahme_root:
    return cs.have(1) ? ahme_root : -1;
  }
  return -1;
}

bool HashmapAugE::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahme_empty:
    return cs.advance(1)
        && Y_.skip(cs);
  case ahme_root:
    return cs.advance_ext(0x10001)
        && Y_.skip(cs);
  }
  return false;
}

bool HashmapAugE::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case ahme_empty:
    return cs.advance(1)
        && Y_.validate_skip(cs, weak);
  case ahme_root:
    return cs.advance(1)
        && HashmapAug{m_, X_, Y_}.validate_skip_ref(cs, weak)
        && Y_.validate_skip(cs, weak);
  }
  return false;
}

bool HashmapAugE::unpack(vm::CellSlice& cs, HashmapAugE::Record_ahme_empty& data) const {
  return cs.fetch_ulong(1) == 0
      && Y_.fetch_to(cs, data.extra);
}

bool HashmapAugE::unpack_ahme_empty(vm::CellSlice& cs, Ref<CellSlice>& extra) const {
  return cs.fetch_ulong(1) == 0
      && Y_.fetch_to(cs, extra);
}

bool HashmapAugE::cell_unpack(Ref<vm::Cell> cell_ref, HashmapAugE::Record_ahme_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapAugE::cell_unpack_ahme_empty(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ahme_empty(cs, extra) && cs.empty_ext();
}

bool HashmapAugE::unpack(vm::CellSlice& cs, HashmapAugE::Record_ahme_root& data) const {
  return cs.fetch_ulong(1) == 1
      && (data.n = m_) >= 0
      && cs.fetch_ref_to(data.root)
      && Y_.fetch_to(cs, data.extra);
}

bool HashmapAugE::unpack_ahme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root, Ref<CellSlice>& extra) const {
  return cs.fetch_ulong(1) == 1
      && (n = m_) >= 0
      && cs.fetch_ref_to(root)
      && Y_.fetch_to(cs, extra);
}

bool HashmapAugE::cell_unpack(Ref<vm::Cell> cell_ref, HashmapAugE::Record_ahme_root& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HashmapAugE::cell_unpack_ahme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root, Ref<CellSlice>& extra) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ahme_root(cs, n, root, extra) && cs.empty_ext();
}

bool HashmapAugE::pack(vm::CellBuilder& cb, const HashmapAugE::Record_ahme_empty& data) const {
  return cb.store_long_bool(0, 1)
      && Y_.store_from(cb, data.extra);
}

bool HashmapAugE::pack_ahme_empty(vm::CellBuilder& cb, Ref<CellSlice> extra) const {
  return cb.store_long_bool(0, 1)
      && Y_.store_from(cb, extra);
}

bool HashmapAugE::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapAugE::Record_ahme_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugE::cell_pack_ahme_empty(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra) const {
  vm::CellBuilder cb;
  return pack_ahme_empty(cb, std::move(extra)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugE::pack(vm::CellBuilder& cb, const HashmapAugE::Record_ahme_root& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.root)
      && Y_.store_from(cb, data.extra);
}

bool HashmapAugE::pack_ahme_root(vm::CellBuilder& cb, Ref<Cell> root, Ref<CellSlice> extra) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(root)
      && Y_.store_from(cb, extra);
}

bool HashmapAugE::cell_pack(Ref<vm::Cell>& cell_ref, const HashmapAugE::Record_ahme_root& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugE::cell_pack_ahme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root, Ref<CellSlice> extra) const {
  vm::CellBuilder cb;
  return pack_ahme_root(cb, std::move(root), std::move(extra)) && std::move(cb).finalize_to(cell_ref);
}

bool HashmapAugE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case ahme_empty:
    return cs.advance(1)
        && pp.open("ahme_empty")
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.close();
  case ahme_root:
    return cs.advance(1)
        && pp.open("ahme_root")
        && pp.field("root")
        && HashmapAug{m_, X_, Y_}.print_ref(pp, cs.fetch_ref())
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for HashmapAugE");
}


//
// code for type `VarHashmap`
//

int VarHashmap::check_tag(const vm::CellSlice& cs) const {
  return vhm_edge;
}

bool VarHashmap::skip(vm::CellSlice& cs) const {
  int l, m;
  return HmLabel{m_}.skip(cs, l)
      && add_r1(m, l, m_)
      && VarHashmapNode{m, X_}.skip(cs);
}

bool VarHashmap::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l, m;
  return HmLabel{m_}.validate_skip(cs, weak, l)
      && add_r1(m, l, m_)
      && VarHashmapNode{m, X_}.validate_skip(cs, weak);
}

bool VarHashmap::unpack(vm::CellSlice& cs, VarHashmap::Record& data) const {
  return (data.n = m_) >= 0
      && HmLabel{m_}.fetch_to(cs, data.label, data.l)
      && add_r1(data.m, data.l, m_)
      && VarHashmapNode{data.m, X_}.fetch_to(cs, data.node);
}

bool VarHashmap::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmap::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmap::pack(vm::CellBuilder& cb, const VarHashmap::Record& data) const {
  int l, m;
  return tlb::store_from(cb, HmLabel{m_}, data.label, l)
      && add_r1(m, l, m_)
      && VarHashmapNode{m, X_}.store_from(cb, data.node);
}

bool VarHashmap::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmap::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmap::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int l, m;
  return pp.open("vhm_edge")
      && pp.field("label")
      && HmLabel{m_}.print_skip(pp, cs, l)
      && add_r1(m, l, m_)
      && pp.field("node")
      && VarHashmapNode{m, X_}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `VarHashmapNode`
//
constexpr char VarHashmapNode::cons_len[3];
constexpr unsigned char VarHashmapNode::cons_tag[3];

int VarHashmapNode::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhmn_leaf:
    return cs.have(2) ? vhmn_leaf : -1;
  case vhmn_fork:
    return cs.have(2) ? vhmn_fork : -1;
  case vhmn_cont:
    return cs.have(1) ? vhmn_cont : -1;
  }
  return -1;
}

bool VarHashmapNode::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhmn_leaf:
    return cs.advance(2)
        && X_.skip(cs);
  case vhmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_ext(0x20002)
        && Maybe{X_}.skip(cs);
    }
  case vhmn_cont: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_ext(0x10002)
        && X_.skip(cs);
    }
  }
  return false;
}

bool VarHashmapNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case vhmn_leaf:
    return cs.advance(2)
        && X_.validate_skip(cs, weak);
  case vhmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance(2)
        && VarHashmap{n, X_}.validate_skip_ref(cs, weak)
        && VarHashmap{n, X_}.validate_skip_ref(cs, weak)
        && Maybe{X_}.validate_skip(cs, weak);
    }
  case vhmn_cont: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance(2)
        && VarHashmap{n, X_}.validate_skip_ref(cs, weak)
        && X_.validate_skip(cs, weak);
    }
  }
  return false;
}

bool VarHashmapNode::unpack(vm::CellSlice& cs, VarHashmapNode::Record_vhmn_leaf& data) const {
  return cs.fetch_ulong(2) == 0
      && X_.fetch_to(cs, data.value);
}

bool VarHashmapNode::unpack_vhmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return cs.fetch_ulong(2) == 0
      && X_.fetch_to(cs, value);
}

bool VarHashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmapNode::Record_vhmn_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmapNode::cell_unpack_vhmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_vhmn_leaf(cs, value) && cs.empty_ext();
}

bool VarHashmapNode::unpack(vm::CellSlice& cs, VarHashmapNode::Record_vhmn_fork& data) const {
  return cs.fetch_ulong(2) == 1
      && add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right)
      && Maybe{X_}.fetch_to(cs, data.value);
}

bool VarHashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmapNode::Record_vhmn_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmapNode::unpack(vm::CellSlice& cs, VarHashmapNode::Record_vhmn_cont& data) const {
  return cs.fetch_ulong(1) == 1
      && add_r1(data.n, 1, m_)
      && cs.fetch_bool_to(data.branch)
      && cs.fetch_ref_to(data.child)
      && X_.fetch_to(cs, data.value);
}

bool VarHashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmapNode::Record_vhmn_cont& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmapNode::pack(vm::CellBuilder& cb, const VarHashmapNode::Record_vhmn_leaf& data) const {
  return cb.store_long_bool(0, 2)
      && X_.store_from(cb, data.value);
}

bool VarHashmapNode::pack_vhmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return cb.store_long_bool(0, 2)
      && X_.store_from(cb, value);
}

bool VarHashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmapNode::Record_vhmn_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapNode::cell_pack_vhmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_vhmn_leaf(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapNode::pack(vm::CellBuilder& cb, const VarHashmapNode::Record_vhmn_fork& data) const {
  int n;
  return cb.store_long_bool(1, 2)
      && add_r1(n, 1, m_)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right)
      && Maybe{X_}.store_from(cb, data.value);
}

bool VarHashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmapNode::Record_vhmn_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapNode::pack(vm::CellBuilder& cb, const VarHashmapNode::Record_vhmn_cont& data) const {
  int n;
  return cb.store_long_bool(1, 1)
      && add_r1(n, 1, m_)
      && cb.store_ulong_rchk_bool(data.branch, 1)
      && cb.store_ref_bool(data.child)
      && X_.store_from(cb, data.value);
}

bool VarHashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmapNode::Record_vhmn_cont& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapNode::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhmn_leaf:
    return cs.advance(2)
        && pp.open("vhmn_leaf")
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  case vhmn_fork: {
    int n;
    return cs.advance(2)
        && pp.open("vhmn_fork")
        && add_r1(n, 1, m_)
        && pp.field("left")
        && VarHashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && VarHashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.field("value")
        && Maybe{X_}.print_skip(pp, cs)
        && pp.close();
    }
  case vhmn_cont: {
    int n;
    return cs.advance(1)
        && pp.open("vhmn_cont")
        && add_r1(n, 1, m_)
        && pp.fetch_uint_field(cs, 1, "branch")
        && pp.field("child")
        && VarHashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for VarHashmapNode");
}


//
// code for type `VarHashmapE`
//

int VarHashmapE::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhme_empty:
    return cs.have(1) ? vhme_empty : -1;
  case vhme_root:
    return cs.have(1) ? vhme_root : -1;
  }
  return -1;
}

bool VarHashmapE::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhme_empty:
    return cs.advance(1);
  case vhme_root:
    return cs.advance_ext(0x10001);
  }
  return false;
}

bool VarHashmapE::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case vhme_empty:
    return cs.advance(1);
  case vhme_root:
    return cs.advance(1)
        && VarHashmap{m_, X_}.validate_skip_ref(cs, weak);
  }
  return false;
}

bool VarHashmapE::unpack(vm::CellSlice& cs, VarHashmapE::Record_vhme_empty& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool VarHashmapE::unpack_vhme_empty(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool VarHashmapE::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmapE::Record_vhme_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmapE::cell_unpack_vhme_empty(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_vhme_empty(cs) && cs.empty_ext();
}

bool VarHashmapE::unpack(vm::CellSlice& cs, VarHashmapE::Record_vhme_root& data) const {
  return cs.fetch_ulong(1) == 1
      && (data.n = m_) >= 0
      && cs.fetch_ref_to(data.root);
}

bool VarHashmapE::unpack_vhme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const {
  return cs.fetch_ulong(1) == 1
      && (n = m_) >= 0
      && cs.fetch_ref_to(root);
}

bool VarHashmapE::cell_unpack(Ref<vm::Cell> cell_ref, VarHashmapE::Record_vhme_root& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarHashmapE::cell_unpack_vhme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_vhme_root(cs, n, root) && cs.empty_ext();
}

bool VarHashmapE::pack(vm::CellBuilder& cb, const VarHashmapE::Record_vhme_empty& data) const {
  return cb.store_long_bool(0, 1);
}

bool VarHashmapE::pack_vhme_empty(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool VarHashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmapE::Record_vhme_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapE::cell_pack_vhme_empty(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_vhme_empty(cb) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapE::pack(vm::CellBuilder& cb, const VarHashmapE::Record_vhme_root& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.root);
}

bool VarHashmapE::pack_vhme_root(vm::CellBuilder& cb, Ref<Cell> root) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(root);
}

bool VarHashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const VarHashmapE::Record_vhme_root& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapE::cell_pack_vhme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const {
  vm::CellBuilder cb;
  return pack_vhme_root(cb, std::move(root)) && std::move(cb).finalize_to(cell_ref);
}

bool VarHashmapE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case vhme_empty:
    return cs.advance(1)
        && pp.cons("vhme_empty");
  case vhme_root:
    return cs.advance(1)
        && pp.open("vhme_root")
        && pp.field("root")
        && VarHashmap{m_, X_}.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for VarHashmapE");
}


//
// code for type `PfxHashmap`
//

int PfxHashmap::check_tag(const vm::CellSlice& cs) const {
  return phm_edge;
}

bool PfxHashmap::skip(vm::CellSlice& cs) const {
  int l, m;
  return HmLabel{m_}.skip(cs, l)
      && add_r1(m, l, m_)
      && PfxHashmapNode{m, X_}.skip(cs);
}

bool PfxHashmap::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l, m;
  return HmLabel{m_}.validate_skip(cs, weak, l)
      && add_r1(m, l, m_)
      && PfxHashmapNode{m, X_}.validate_skip(cs, weak);
}

bool PfxHashmap::unpack(vm::CellSlice& cs, PfxHashmap::Record& data) const {
  return (data.n = m_) >= 0
      && HmLabel{m_}.fetch_to(cs, data.label, data.l)
      && add_r1(data.m, data.l, m_)
      && PfxHashmapNode{data.m, X_}.fetch_to(cs, data.node);
}

bool PfxHashmap::cell_unpack(Ref<vm::Cell> cell_ref, PfxHashmap::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool PfxHashmap::pack(vm::CellBuilder& cb, const PfxHashmap::Record& data) const {
  int l, m;
  return tlb::store_from(cb, HmLabel{m_}, data.label, l)
      && add_r1(m, l, m_)
      && PfxHashmapNode{m, X_}.store_from(cb, data.node);
}

bool PfxHashmap::cell_pack(Ref<vm::Cell>& cell_ref, const PfxHashmap::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmap::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int l, m;
  return pp.open("phm_edge")
      && pp.field("label")
      && HmLabel{m_}.print_skip(pp, cs, l)
      && add_r1(m, l, m_)
      && pp.field("node")
      && PfxHashmapNode{m, X_}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `PfxHashmapNode`
//

int PfxHashmapNode::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phmn_leaf:
    return cs.have(1) ? phmn_leaf : -1;
  case phmn_fork:
    return cs.have(1) ? phmn_fork : -1;
  }
  return -1;
}

bool PfxHashmapNode::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phmn_leaf:
    return cs.advance(1)
        && X_.skip(cs);
  case phmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_ext(0x20001);
    }
  }
  return false;
}

bool PfxHashmapNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case phmn_leaf:
    return cs.advance(1)
        && X_.validate_skip(cs, weak);
  case phmn_fork: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance(1)
        && PfxHashmap{n, X_}.validate_skip_ref(cs, weak)
        && PfxHashmap{n, X_}.validate_skip_ref(cs, weak);
    }
  }
  return false;
}

bool PfxHashmapNode::unpack(vm::CellSlice& cs, PfxHashmapNode::Record_phmn_leaf& data) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, data.value);
}

bool PfxHashmapNode::unpack_phmn_leaf(vm::CellSlice& cs, Ref<CellSlice>& value) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, value);
}

bool PfxHashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, PfxHashmapNode::Record_phmn_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool PfxHashmapNode::cell_unpack_phmn_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_phmn_leaf(cs, value) && cs.empty_ext();
}

bool PfxHashmapNode::unpack(vm::CellSlice& cs, PfxHashmapNode::Record_phmn_fork& data) const {
  return cs.fetch_ulong(1) == 1
      && add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right);
}

bool PfxHashmapNode::unpack_phmn_fork(vm::CellSlice& cs, int& n, Ref<Cell>& left, Ref<Cell>& right) const {
  return cs.fetch_ulong(1) == 1
      && add_r1(n, 1, m_)
      && cs.fetch_ref_to(left)
      && cs.fetch_ref_to(right);
}

bool PfxHashmapNode::cell_unpack(Ref<vm::Cell> cell_ref, PfxHashmapNode::Record_phmn_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool PfxHashmapNode::cell_unpack_phmn_fork(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& left, Ref<Cell>& right) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_phmn_fork(cs, n, left, right) && cs.empty_ext();
}

bool PfxHashmapNode::pack(vm::CellBuilder& cb, const PfxHashmapNode::Record_phmn_leaf& data) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, data.value);
}

bool PfxHashmapNode::pack_phmn_leaf(vm::CellBuilder& cb, Ref<CellSlice> value) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, value);
}

bool PfxHashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const PfxHashmapNode::Record_phmn_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapNode::cell_pack_phmn_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> value) const {
  vm::CellBuilder cb;
  return pack_phmn_leaf(cb, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapNode::pack(vm::CellBuilder& cb, const PfxHashmapNode::Record_phmn_fork& data) const {
  int n;
  return cb.store_long_bool(1, 1)
      && add_r1(n, 1, m_)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right);
}

bool PfxHashmapNode::pack_phmn_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const {
  int n;
  return cb.store_long_bool(1, 1)
      && add_r1(n, 1, m_)
      && cb.store_ref_bool(left)
      && cb.store_ref_bool(right);
}

bool PfxHashmapNode::cell_pack(Ref<vm::Cell>& cell_ref, const PfxHashmapNode::Record_phmn_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapNode::cell_pack_phmn_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const {
  vm::CellBuilder cb;
  return pack_phmn_fork(cb, std::move(left), std::move(right)) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapNode::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phmn_leaf:
    return cs.advance(1)
        && pp.open("phmn_leaf")
        && pp.field("value")
        && X_.print_skip(pp, cs)
        && pp.close();
  case phmn_fork: {
    int n;
    return cs.advance(1)
        && pp.open("phmn_fork")
        && add_r1(n, 1, m_)
        && pp.field("left")
        && PfxHashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && PfxHashmap{n, X_}.print_ref(pp, cs.fetch_ref())
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for PfxHashmapNode");
}


//
// code for type `PfxHashmapE`
//

int PfxHashmapE::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phme_empty:
    return cs.have(1) ? phme_empty : -1;
  case phme_root:
    return cs.have(1) ? phme_root : -1;
  }
  return -1;
}

bool PfxHashmapE::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phme_empty:
    return cs.advance(1);
  case phme_root:
    return cs.advance_ext(0x10001);
  }
  return false;
}

bool PfxHashmapE::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case phme_empty:
    return cs.advance(1);
  case phme_root:
    return cs.advance(1)
        && PfxHashmap{m_, X_}.validate_skip_ref(cs, weak);
  }
  return false;
}

bool PfxHashmapE::unpack(vm::CellSlice& cs, PfxHashmapE::Record_phme_empty& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool PfxHashmapE::unpack_phme_empty(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool PfxHashmapE::cell_unpack(Ref<vm::Cell> cell_ref, PfxHashmapE::Record_phme_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool PfxHashmapE::cell_unpack_phme_empty(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_phme_empty(cs) && cs.empty_ext();
}

bool PfxHashmapE::unpack(vm::CellSlice& cs, PfxHashmapE::Record_phme_root& data) const {
  return cs.fetch_ulong(1) == 1
      && (data.n = m_) >= 0
      && cs.fetch_ref_to(data.root);
}

bool PfxHashmapE::unpack_phme_root(vm::CellSlice& cs, int& n, Ref<Cell>& root) const {
  return cs.fetch_ulong(1) == 1
      && (n = m_) >= 0
      && cs.fetch_ref_to(root);
}

bool PfxHashmapE::cell_unpack(Ref<vm::Cell> cell_ref, PfxHashmapE::Record_phme_root& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool PfxHashmapE::cell_unpack_phme_root(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_phme_root(cs, n, root) && cs.empty_ext();
}

bool PfxHashmapE::pack(vm::CellBuilder& cb, const PfxHashmapE::Record_phme_empty& data) const {
  return cb.store_long_bool(0, 1);
}

bool PfxHashmapE::pack_phme_empty(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool PfxHashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const PfxHashmapE::Record_phme_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapE::cell_pack_phme_empty(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_phme_empty(cb) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapE::pack(vm::CellBuilder& cb, const PfxHashmapE::Record_phme_root& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.root);
}

bool PfxHashmapE::pack_phme_root(vm::CellBuilder& cb, Ref<Cell> root) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(root);
}

bool PfxHashmapE::cell_pack(Ref<vm::Cell>& cell_ref, const PfxHashmapE::Record_phme_root& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapE::cell_pack_phme_root(Ref<vm::Cell>& cell_ref, Ref<Cell> root) const {
  vm::CellBuilder cb;
  return pack_phme_root(cb, std::move(root)) && std::move(cb).finalize_to(cell_ref);
}

bool PfxHashmapE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case phme_empty:
    return cs.advance(1)
        && pp.cons("phme_empty");
  case phme_root:
    return cs.advance(1)
        && pp.open("phme_root")
        && pp.field("root")
        && PfxHashmap{m_, X_}.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for PfxHashmapE");
}


//
// code for type `MsgAddressExt`
//

int MsgAddressExt::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_none:
    return cs.have(2) ? addr_none : -1;
  case addr_extern:
    return cs.prefetch_ulong(2) == 1 ? addr_extern : -1;
  }
  return -1;
}

bool MsgAddressExt::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_none:
    return cs.advance(2);
  case addr_extern: {
    int len;
    return cs.advance(2)
        && cs.fetch_uint_to(9, len)
        && cs.advance(len);
    }
  }
  return false;
}

bool MsgAddressExt::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case addr_none:
    return cs.advance(2);
  case addr_extern: {
    int len;
    return cs.fetch_ulong(2) == 1
        && cs.fetch_uint_to(9, len)
        && cs.advance(len);
    }
  }
  return false;
}

bool MsgAddressExt::unpack(vm::CellSlice& cs, MsgAddressExt::Record_addr_none& data) const {
  return cs.fetch_ulong(2) == 0;
}

bool MsgAddressExt::unpack_addr_none(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0;
}

bool MsgAddressExt::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddressExt::Record_addr_none& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddressExt::cell_unpack_addr_none(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_addr_none(cs) && cs.empty_ext();
}

bool MsgAddressExt::unpack(vm::CellSlice& cs, MsgAddressExt::Record_addr_extern& data) const {
  return cs.fetch_ulong(2) == 1
      && cs.fetch_uint_to(9, data.len)
      && cs.fetch_bitstring_to(data.len, data.external_address);
}

bool MsgAddressExt::unpack_addr_extern(vm::CellSlice& cs, int& len, Ref<td::BitString>& external_address) const {
  return cs.fetch_ulong(2) == 1
      && cs.fetch_uint_to(9, len)
      && cs.fetch_bitstring_to(len, external_address);
}

bool MsgAddressExt::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddressExt::Record_addr_extern& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddressExt::cell_unpack_addr_extern(Ref<vm::Cell> cell_ref, int& len, Ref<td::BitString>& external_address) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_addr_extern(cs, len, external_address) && cs.empty_ext();
}

bool MsgAddressExt::pack(vm::CellBuilder& cb, const MsgAddressExt::Record_addr_none& data) const {
  return cb.store_long_bool(0, 2);
}

bool MsgAddressExt::pack_addr_none(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 2);
}

bool MsgAddressExt::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddressExt::Record_addr_none& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressExt::cell_pack_addr_none(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_addr_none(cb) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressExt::pack(vm::CellBuilder& cb, const MsgAddressExt::Record_addr_extern& data) const {
  return cb.store_long_bool(1, 2)
      && cb.store_ulong_rchk_bool(data.len, 9)
      && cb.append_bitstring_chk(data.external_address, data.len);
}

bool MsgAddressExt::pack_addr_extern(vm::CellBuilder& cb, int len, Ref<td::BitString> external_address) const {
  return cb.store_long_bool(1, 2)
      && cb.store_ulong_rchk_bool(len, 9)
      && cb.append_bitstring_chk(external_address, len);
}

bool MsgAddressExt::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddressExt::Record_addr_extern& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressExt::cell_pack_addr_extern(Ref<vm::Cell>& cell_ref, int len, Ref<td::BitString> external_address) const {
  vm::CellBuilder cb;
  return pack_addr_extern(cb, len, std::move(external_address)) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressExt::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_none:
    return cs.advance(2)
        && pp.cons("addr_none");
  case addr_extern: {
    int len;
    return cs.fetch_ulong(2) == 1
        && pp.open("addr_extern")
        && cs.fetch_uint_to(9, len)
        && pp.field_int(len, "len")
        && pp.fetch_bits_field(cs, len, "external_address")
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for MsgAddressExt");
}

const MsgAddressExt t_MsgAddressExt;

//
// code for type `Anycast`
//

int Anycast::check_tag(const vm::CellSlice& cs) const {
  return anycast_info;
}

bool Anycast::skip(vm::CellSlice& cs) const {
  int depth;
  return cs.fetch_uint_leq(30, depth)
      && 1 <= depth
      && cs.advance(depth);
}

bool Anycast::validate_skip(vm::CellSlice& cs, bool weak) const {
  int depth;
  return cs.fetch_uint_leq(30, depth)
      && 1 <= depth
      && cs.advance(depth);
}

bool Anycast::unpack(vm::CellSlice& cs, Anycast::Record& data) const {
  return cs.fetch_uint_leq(30, data.depth)
      && 1 <= data.depth
      && cs.fetch_bitstring_to(data.depth, data.rewrite_pfx);
}

bool Anycast::unpack_anycast_info(vm::CellSlice& cs, int& depth, Ref<td::BitString>& rewrite_pfx) const {
  return cs.fetch_uint_leq(30, depth)
      && 1 <= depth
      && cs.fetch_bitstring_to(depth, rewrite_pfx);
}

bool Anycast::cell_unpack(Ref<vm::Cell> cell_ref, Anycast::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Anycast::cell_unpack_anycast_info(Ref<vm::Cell> cell_ref, int& depth, Ref<td::BitString>& rewrite_pfx) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_anycast_info(cs, depth, rewrite_pfx) && cs.empty_ext();
}

bool Anycast::pack(vm::CellBuilder& cb, const Anycast::Record& data) const {
  return cb.store_uint_leq(30, data.depth)
      && 1 <= data.depth
      && cb.append_bitstring_chk(data.rewrite_pfx, data.depth);
}

bool Anycast::pack_anycast_info(vm::CellBuilder& cb, int depth, Ref<td::BitString> rewrite_pfx) const {
  return cb.store_uint_leq(30, depth)
      && 1 <= depth
      && cb.append_bitstring_chk(rewrite_pfx, depth);
}

bool Anycast::cell_pack(Ref<vm::Cell>& cell_ref, const Anycast::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Anycast::cell_pack_anycast_info(Ref<vm::Cell>& cell_ref, int depth, Ref<td::BitString> rewrite_pfx) const {
  vm::CellBuilder cb;
  return pack_anycast_info(cb, depth, std::move(rewrite_pfx)) && std::move(cb).finalize_to(cell_ref);
}

bool Anycast::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int depth;
  return pp.open("anycast_info")
      && cs.fetch_uint_leq(30, depth)
      && pp.field_int(depth, "depth")
      && 1 <= depth
      && pp.fetch_bits_field(cs, depth, "rewrite_pfx")
      && pp.close();
}

const Anycast t_Anycast;

//
// code for type `MsgAddressInt`
//
constexpr unsigned char MsgAddressInt::cons_tag[2];

int MsgAddressInt::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_std:
    return cs.have(2) ? addr_std : -1;
  case addr_var:
    return cs.have(2) ? addr_var : -1;
  }
  return -1;
}

bool MsgAddressInt::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_std:
    return cs.advance(2)
        && t_Maybe_Anycast.skip(cs)
        && cs.advance(264);
  case addr_var: {
    int addr_len;
    return cs.advance(2)
        && t_Maybe_Anycast.skip(cs)
        && cs.fetch_uint_to(9, addr_len)
        && cs.advance(32)
        && cs.advance(addr_len);
    }
  }
  return false;
}

bool MsgAddressInt::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case addr_std:
    return cs.advance(2)
        && t_Maybe_Anycast.validate_skip(cs, weak)
        && cs.advance(264);
  case addr_var: {
    int addr_len;
    return cs.advance(2)
        && t_Maybe_Anycast.validate_skip(cs, weak)
        && cs.fetch_uint_to(9, addr_len)
        && cs.advance(32)
        && cs.advance(addr_len);
    }
  }
  return false;
}

bool MsgAddressInt::unpack(vm::CellSlice& cs, MsgAddressInt::Record_addr_std& data) const {
  return cs.fetch_ulong(2) == 2
      && t_Maybe_Anycast.fetch_to(cs, data.anycast)
      && cs.fetch_int_to(8, data.workchain_id)
      && cs.fetch_bits_to(data.address.bits(), 256);
}

bool MsgAddressInt::unpack_addr_std(vm::CellSlice& cs, Ref<CellSlice>& anycast, int& workchain_id, td::BitArray<256>& address) const {
  return cs.fetch_ulong(2) == 2
      && t_Maybe_Anycast.fetch_to(cs, anycast)
      && cs.fetch_int_to(8, workchain_id)
      && cs.fetch_bits_to(address.bits(), 256);
}

bool MsgAddressInt::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddressInt::Record_addr_std& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddressInt::cell_unpack_addr_std(Ref<vm::Cell> cell_ref, Ref<CellSlice>& anycast, int& workchain_id, td::BitArray<256>& address) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_addr_std(cs, anycast, workchain_id, address) && cs.empty_ext();
}

bool MsgAddressInt::unpack(vm::CellSlice& cs, MsgAddressInt::Record_addr_var& data) const {
  return cs.fetch_ulong(2) == 3
      && t_Maybe_Anycast.fetch_to(cs, data.anycast)
      && cs.fetch_uint_to(9, data.addr_len)
      && cs.fetch_int_to(32, data.workchain_id)
      && cs.fetch_bitstring_to(data.addr_len, data.address);
}

bool MsgAddressInt::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddressInt::Record_addr_var& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddressInt::pack(vm::CellBuilder& cb, const MsgAddressInt::Record_addr_std& data) const {
  return cb.store_long_bool(2, 2)
      && t_Maybe_Anycast.store_from(cb, data.anycast)
      && cb.store_long_rchk_bool(data.workchain_id, 8)
      && cb.store_bits_bool(data.address.cbits(), 256);
}

bool MsgAddressInt::pack_addr_std(vm::CellBuilder& cb, Ref<CellSlice> anycast, int workchain_id, td::BitArray<256> address) const {
  return cb.store_long_bool(2, 2)
      && t_Maybe_Anycast.store_from(cb, anycast)
      && cb.store_long_rchk_bool(workchain_id, 8)
      && cb.store_bits_bool(address.cbits(), 256);
}

bool MsgAddressInt::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddressInt::Record_addr_std& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressInt::cell_pack_addr_std(Ref<vm::Cell>& cell_ref, Ref<CellSlice> anycast, int workchain_id, td::BitArray<256> address) const {
  vm::CellBuilder cb;
  return pack_addr_std(cb, std::move(anycast), workchain_id, address) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressInt::pack(vm::CellBuilder& cb, const MsgAddressInt::Record_addr_var& data) const {
  return cb.store_long_bool(3, 2)
      && t_Maybe_Anycast.store_from(cb, data.anycast)
      && cb.store_ulong_rchk_bool(data.addr_len, 9)
      && cb.store_long_rchk_bool(data.workchain_id, 32)
      && cb.append_bitstring_chk(data.address, data.addr_len);
}

bool MsgAddressInt::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddressInt::Record_addr_var& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddressInt::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case addr_std:
    return cs.advance(2)
        && pp.open("addr_std")
        && pp.field("anycast")
        && t_Maybe_Anycast.print_skip(pp, cs)
        && pp.fetch_int_field(cs, 8, "workchain_id")
        && pp.fetch_bits_field(cs, 256, "address")
        && pp.close();
  case addr_var: {
    int addr_len;
    return cs.advance(2)
        && pp.open("addr_var")
        && pp.field("anycast")
        && t_Maybe_Anycast.print_skip(pp, cs)
        && cs.fetch_uint_to(9, addr_len)
        && pp.field_int(addr_len, "addr_len")
        && pp.fetch_int_field(cs, 32, "workchain_id")
        && pp.fetch_bits_field(cs, addr_len, "address")
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for MsgAddressInt");
}

const MsgAddressInt t_MsgAddressInt;

//
// code for type `MsgAddress`
//

int MsgAddress::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return cons1;
  case cons2:
    return cons2;
  }
  return -1;
}

bool MsgAddress::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return t_MsgAddressInt.skip(cs);
  case cons2:
    return t_MsgAddressExt.skip(cs);
  }
  return false;
}

bool MsgAddress::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case cons1:
    return t_MsgAddressInt.validate_skip(cs, weak);
  case cons2:
    return t_MsgAddressExt.validate_skip(cs, weak);
  }
  return false;
}

bool MsgAddress::unpack(vm::CellSlice& cs, MsgAddress::Record_cons1& data) const {
  return t_MsgAddressInt.fetch_to(cs, data.x);
}

bool MsgAddress::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_MsgAddressInt.fetch_to(cs, x);
}

bool MsgAddress::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddress::Record_cons1& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddress::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool MsgAddress::unpack(vm::CellSlice& cs, MsgAddress::Record_cons2& data) const {
  return t_MsgAddressExt.fetch_to(cs, data.x);
}

bool MsgAddress::unpack_cons2(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_MsgAddressExt.fetch_to(cs, x);
}

bool MsgAddress::cell_unpack(Ref<vm::Cell> cell_ref, MsgAddress::Record_cons2& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgAddress::cell_unpack_cons2(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons2(cs, x) && cs.empty_ext();
}

bool MsgAddress::pack(vm::CellBuilder& cb, const MsgAddress::Record_cons1& data) const {
  return t_MsgAddressInt.store_from(cb, data.x);
}

bool MsgAddress::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_MsgAddressInt.store_from(cb, x);
}

bool MsgAddress::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddress::Record_cons1& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddress::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddress::pack(vm::CellBuilder& cb, const MsgAddress::Record_cons2& data) const {
  return t_MsgAddressExt.store_from(cb, data.x);
}

bool MsgAddress::pack_cons2(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_MsgAddressExt.store_from(cb, x);
}

bool MsgAddress::cell_pack(Ref<vm::Cell>& cell_ref, const MsgAddress::Record_cons2& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddress::cell_pack_cons2(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons2(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool MsgAddress::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return pp.open()
        && pp.field()
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.close();
  case cons2:
    return pp.open()
        && pp.field()
        && t_MsgAddressExt.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for MsgAddress");
}

const MsgAddress t_MsgAddress;

//
// code for type `VarUInteger`
//

int VarUInteger::check_tag(const vm::CellSlice& cs) const {
  return var_uint;
}

bool VarUInteger::skip(vm::CellSlice& cs) const {
  int len;
  return cs.fetch_uint_less(m_, len)
      && cs.advance(8 * len);
}

bool VarUInteger::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len;
  return cs.fetch_uint_less(m_, len)
      && cs.advance(8 * len);
}

bool VarUInteger::unpack(vm::CellSlice& cs, VarUInteger::Record& data) const {
  return (data.n = m_) >= 0
      && cs.fetch_uint_less(m_, data.len)
      && cs.fetch_uint256_to(8 * data.len, data.value);
}

bool VarUInteger::unpack_var_uint(vm::CellSlice& cs, int& n, int& len, RefInt256& value) const {
  return (n = m_) >= 0
      && cs.fetch_uint_less(m_, len)
      && cs.fetch_uint256_to(8 * len, value);
}

bool VarUInteger::cell_unpack(Ref<vm::Cell> cell_ref, VarUInteger::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarUInteger::cell_unpack_var_uint(Ref<vm::Cell> cell_ref, int& n, int& len, RefInt256& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_var_uint(cs, n, len, value) && cs.empty_ext();
}

bool VarUInteger::pack(vm::CellBuilder& cb, const VarUInteger::Record& data) const {
  return cb.store_uint_less(m_, data.len)
      && cb.store_int256_bool(data.value, 8 * data.len, false);
}

bool VarUInteger::pack_var_uint(vm::CellBuilder& cb, int len, RefInt256 value) const {
  return cb.store_uint_less(m_, len)
      && cb.store_int256_bool(value, 8 * len, false);
}

bool VarUInteger::cell_pack(Ref<vm::Cell>& cell_ref, const VarUInteger::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarUInteger::cell_pack_var_uint(Ref<vm::Cell>& cell_ref, int len, RefInt256 value) const {
  vm::CellBuilder cb;
  return pack_var_uint(cb, len, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool VarUInteger::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int len;
  return pp.open("var_uint")
      && cs.fetch_uint_less(m_, len)
      && pp.field_int(len, "len")
      && pp.fetch_uint256_field(cs, 8 * len, "value")
      && pp.close();
}


//
// code for type `VarInteger`
//

int VarInteger::check_tag(const vm::CellSlice& cs) const {
  return var_int;
}

bool VarInteger::skip(vm::CellSlice& cs) const {
  int len;
  return cs.fetch_uint_less(m_, len)
      && cs.advance(8 * len);
}

bool VarInteger::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len;
  return cs.fetch_uint_less(m_, len)
      && cs.advance(8 * len);
}

bool VarInteger::unpack(vm::CellSlice& cs, VarInteger::Record& data) const {
  return (data.n = m_) >= 0
      && cs.fetch_uint_less(m_, data.len)
      && cs.fetch_int256_to(8 * data.len, data.value);
}

bool VarInteger::unpack_var_int(vm::CellSlice& cs, int& n, int& len, RefInt256& value) const {
  return (n = m_) >= 0
      && cs.fetch_uint_less(m_, len)
      && cs.fetch_int256_to(8 * len, value);
}

bool VarInteger::cell_unpack(Ref<vm::Cell> cell_ref, VarInteger::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool VarInteger::cell_unpack_var_int(Ref<vm::Cell> cell_ref, int& n, int& len, RefInt256& value) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_var_int(cs, n, len, value) && cs.empty_ext();
}

bool VarInteger::pack(vm::CellBuilder& cb, const VarInteger::Record& data) const {
  return cb.store_uint_less(m_, data.len)
      && cb.store_int256_bool(data.value, 8 * data.len);
}

bool VarInteger::pack_var_int(vm::CellBuilder& cb, int len, RefInt256 value) const {
  return cb.store_uint_less(m_, len)
      && cb.store_int256_bool(value, 8 * len);
}

bool VarInteger::cell_pack(Ref<vm::Cell>& cell_ref, const VarInteger::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool VarInteger::cell_pack_var_int(Ref<vm::Cell>& cell_ref, int len, RefInt256 value) const {
  vm::CellBuilder cb;
  return pack_var_int(cb, len, std::move(value)) && std::move(cb).finalize_to(cell_ref);
}

bool VarInteger::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int len;
  return pp.open("var_int")
      && cs.fetch_uint_less(m_, len)
      && pp.field_int(len, "len")
      && pp.fetch_int256_field(cs, 8 * len, "value")
      && pp.close();
}


//
// code for type `Grams`
//

int Grams::check_tag(const vm::CellSlice& cs) const {
  return nanograms;
}

bool Grams::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_16.skip(cs);
}

bool Grams::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_16.validate_skip(cs, weak);
}

bool Grams::unpack(vm::CellSlice& cs, Grams::Record& data) const {
  return t_VarUInteger_16.fetch_to(cs, data.amount);
}

bool Grams::unpack_nanograms(vm::CellSlice& cs, Ref<CellSlice>& amount) const {
  return t_VarUInteger_16.fetch_to(cs, amount);
}

bool Grams::cell_unpack(Ref<vm::Cell> cell_ref, Grams::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Grams::cell_unpack_nanograms(Ref<vm::Cell> cell_ref, Ref<CellSlice>& amount) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_nanograms(cs, amount) && cs.empty_ext();
}

bool Grams::pack(vm::CellBuilder& cb, const Grams::Record& data) const {
  return t_VarUInteger_16.store_from(cb, data.amount);
}

bool Grams::pack_nanograms(vm::CellBuilder& cb, Ref<CellSlice> amount) const {
  return t_VarUInteger_16.store_from(cb, amount);
}

bool Grams::cell_pack(Ref<vm::Cell>& cell_ref, const Grams::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Grams::cell_pack_nanograms(Ref<vm::Cell>& cell_ref, Ref<CellSlice> amount) const {
  vm::CellBuilder cb;
  return pack_nanograms(cb, std::move(amount)) && std::move(cb).finalize_to(cell_ref);
}

bool Grams::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("nanograms")
      && pp.field("amount")
      && t_VarUInteger_16.print_skip(pp, cs)
      && pp.close();
}

const Grams t_Grams;

//
// code for type `ExtraCurrencyCollection`
//

int ExtraCurrencyCollection::check_tag(const vm::CellSlice& cs) const {
  return extra_currencies;
}

bool ExtraCurrencyCollection::skip(vm::CellSlice& cs) const {
  return t_HashmapE_32_VarUInteger_32.skip(cs);
}

bool ExtraCurrencyCollection::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapE_32_VarUInteger_32.validate_skip(cs, weak);
}

bool ExtraCurrencyCollection::unpack(vm::CellSlice& cs, ExtraCurrencyCollection::Record& data) const {
  return t_HashmapE_32_VarUInteger_32.fetch_to(cs, data.dict);
}

bool ExtraCurrencyCollection::unpack_extra_currencies(vm::CellSlice& cs, Ref<CellSlice>& dict) const {
  return t_HashmapE_32_VarUInteger_32.fetch_to(cs, dict);
}

bool ExtraCurrencyCollection::cell_unpack(Ref<vm::Cell> cell_ref, ExtraCurrencyCollection::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ExtraCurrencyCollection::cell_unpack_extra_currencies(Ref<vm::Cell> cell_ref, Ref<CellSlice>& dict) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_extra_currencies(cs, dict) && cs.empty_ext();
}

bool ExtraCurrencyCollection::pack(vm::CellBuilder& cb, const ExtraCurrencyCollection::Record& data) const {
  return t_HashmapE_32_VarUInteger_32.store_from(cb, data.dict);
}

bool ExtraCurrencyCollection::pack_extra_currencies(vm::CellBuilder& cb, Ref<CellSlice> dict) const {
  return t_HashmapE_32_VarUInteger_32.store_from(cb, dict);
}

bool ExtraCurrencyCollection::cell_pack(Ref<vm::Cell>& cell_ref, const ExtraCurrencyCollection::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ExtraCurrencyCollection::cell_pack_extra_currencies(Ref<vm::Cell>& cell_ref, Ref<CellSlice> dict) const {
  vm::CellBuilder cb;
  return pack_extra_currencies(cb, std::move(dict)) && std::move(cb).finalize_to(cell_ref);
}

bool ExtraCurrencyCollection::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("extra_currencies")
      && pp.field("dict")
      && t_HashmapE_32_VarUInteger_32.print_skip(pp, cs)
      && pp.close();
}

const ExtraCurrencyCollection t_ExtraCurrencyCollection;

//
// code for type `CurrencyCollection`
//

int CurrencyCollection::check_tag(const vm::CellSlice& cs) const {
  return currencies;
}

bool CurrencyCollection::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs)
      && t_ExtraCurrencyCollection.skip(cs);
}

bool CurrencyCollection::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak)
      && t_ExtraCurrencyCollection.validate_skip(cs, weak);
}

bool CurrencyCollection::unpack(vm::CellSlice& cs, CurrencyCollection::Record& data) const {
  return t_Grams.fetch_to(cs, data.grams)
      && t_ExtraCurrencyCollection.fetch_to(cs, data.other);
}

bool CurrencyCollection::unpack_currencies(vm::CellSlice& cs, Ref<CellSlice>& grams, Ref<CellSlice>& other) const {
  return t_Grams.fetch_to(cs, grams)
      && t_ExtraCurrencyCollection.fetch_to(cs, other);
}

bool CurrencyCollection::cell_unpack(Ref<vm::Cell> cell_ref, CurrencyCollection::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CurrencyCollection::cell_unpack_currencies(Ref<vm::Cell> cell_ref, Ref<CellSlice>& grams, Ref<CellSlice>& other) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_currencies(cs, grams, other) && cs.empty_ext();
}

bool CurrencyCollection::pack(vm::CellBuilder& cb, const CurrencyCollection::Record& data) const {
  return t_Grams.store_from(cb, data.grams)
      && t_ExtraCurrencyCollection.store_from(cb, data.other);
}

bool CurrencyCollection::pack_currencies(vm::CellBuilder& cb, Ref<CellSlice> grams, Ref<CellSlice> other) const {
  return t_Grams.store_from(cb, grams)
      && t_ExtraCurrencyCollection.store_from(cb, other);
}

bool CurrencyCollection::cell_pack(Ref<vm::Cell>& cell_ref, const CurrencyCollection::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CurrencyCollection::cell_pack_currencies(Ref<vm::Cell>& cell_ref, Ref<CellSlice> grams, Ref<CellSlice> other) const {
  vm::CellBuilder cb;
  return pack_currencies(cb, std::move(grams), std::move(other)) && std::move(cb).finalize_to(cell_ref);
}

bool CurrencyCollection::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("currencies")
      && pp.field("grams")
      && t_Grams.print_skip(pp, cs)
      && pp.field("other")
      && t_ExtraCurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const CurrencyCollection t_CurrencyCollection;

//
// code for type `CommonMsgInfo`
//
constexpr char CommonMsgInfo::cons_len[3];
constexpr unsigned char CommonMsgInfo::cons_tag[3];

int CommonMsgInfo::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.have(1) ? int_msg_info : -1;
  case ext_in_msg_info:
    return cs.have(2) ? ext_in_msg_info : -1;
  case ext_out_msg_info:
    return cs.have(2) ? ext_out_msg_info : -1;
  }
  return -1;
}

bool CommonMsgInfo::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(4)
        && t_MsgAddressInt.skip(cs)
        && t_MsgAddressInt.skip(cs)
        && t_CurrencyCollection.skip(cs)
        && t_Grams.skip(cs)
        && t_Grams.skip(cs)
        && cs.advance(96);
  case ext_in_msg_info:
    return cs.advance(2)
        && t_MsgAddressExt.skip(cs)
        && t_MsgAddressInt.skip(cs)
        && t_Grams.skip(cs);
  case ext_out_msg_info:
    return cs.advance(2)
        && t_MsgAddressInt.skip(cs)
        && t_MsgAddressExt.skip(cs)
        && cs.advance(96);
  }
  return false;
}

bool CommonMsgInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(4)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_CurrencyCollection.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && cs.advance(96);
  case ext_in_msg_info:
    return cs.advance(2)
        && t_MsgAddressExt.validate_skip(cs, weak)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  case ext_out_msg_info:
    return cs.advance(2)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_MsgAddressExt.validate_skip(cs, weak)
        && cs.advance(96);
  }
  return false;
}

bool CommonMsgInfo::unpack(vm::CellSlice& cs, CommonMsgInfo::Record_int_msg_info& data) const {
  return cs.fetch_ulong(1) == 0
      && cs.fetch_bool_to(data.ihr_disabled)
      && cs.fetch_bool_to(data.bounce)
      && cs.fetch_bool_to(data.bounced)
      && t_MsgAddressInt.fetch_to(cs, data.src)
      && t_MsgAddressInt.fetch_to(cs, data.dest)
      && t_CurrencyCollection.fetch_to(cs, data.value)
      && t_Grams.fetch_to(cs, data.ihr_fee)
      && t_Grams.fetch_to(cs, data.fwd_fee)
      && cs.fetch_uint_to(64, data.created_lt)
      && cs.fetch_uint_to(32, data.created_at);
}

bool CommonMsgInfo::cell_unpack(Ref<vm::Cell> cell_ref, CommonMsgInfo::Record_int_msg_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CommonMsgInfo::unpack(vm::CellSlice& cs, CommonMsgInfo::Record_ext_in_msg_info& data) const {
  return cs.fetch_ulong(2) == 2
      && t_MsgAddressExt.fetch_to(cs, data.src)
      && t_MsgAddressInt.fetch_to(cs, data.dest)
      && t_Grams.fetch_to(cs, data.import_fee);
}

bool CommonMsgInfo::unpack_ext_in_msg_info(vm::CellSlice& cs, Ref<CellSlice>& src, Ref<CellSlice>& dest, Ref<CellSlice>& import_fee) const {
  return cs.fetch_ulong(2) == 2
      && t_MsgAddressExt.fetch_to(cs, src)
      && t_MsgAddressInt.fetch_to(cs, dest)
      && t_Grams.fetch_to(cs, import_fee);
}

bool CommonMsgInfo::cell_unpack(Ref<vm::Cell> cell_ref, CommonMsgInfo::Record_ext_in_msg_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CommonMsgInfo::cell_unpack_ext_in_msg_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& src, Ref<CellSlice>& dest, Ref<CellSlice>& import_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ext_in_msg_info(cs, src, dest, import_fee) && cs.empty_ext();
}

bool CommonMsgInfo::unpack(vm::CellSlice& cs, CommonMsgInfo::Record_ext_out_msg_info& data) const {
  return cs.fetch_ulong(2) == 3
      && t_MsgAddressInt.fetch_to(cs, data.src)
      && t_MsgAddressExt.fetch_to(cs, data.dest)
      && cs.fetch_uint_to(64, data.created_lt)
      && cs.fetch_uint_to(32, data.created_at);
}

bool CommonMsgInfo::cell_unpack(Ref<vm::Cell> cell_ref, CommonMsgInfo::Record_ext_out_msg_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CommonMsgInfo::pack(vm::CellBuilder& cb, const CommonMsgInfo::Record_int_msg_info& data) const {
  return cb.store_long_bool(0, 1)
      && cb.store_ulong_rchk_bool(data.ihr_disabled, 1)
      && cb.store_ulong_rchk_bool(data.bounce, 1)
      && cb.store_ulong_rchk_bool(data.bounced, 1)
      && t_MsgAddressInt.store_from(cb, data.src)
      && t_MsgAddressInt.store_from(cb, data.dest)
      && t_CurrencyCollection.store_from(cb, data.value)
      && t_Grams.store_from(cb, data.ihr_fee)
      && t_Grams.store_from(cb, data.fwd_fee)
      && cb.store_ulong_rchk_bool(data.created_lt, 64)
      && cb.store_ulong_rchk_bool(data.created_at, 32);
}

bool CommonMsgInfo::cell_pack(Ref<vm::Cell>& cell_ref, const CommonMsgInfo::Record_int_msg_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfo::pack(vm::CellBuilder& cb, const CommonMsgInfo::Record_ext_in_msg_info& data) const {
  return cb.store_long_bool(2, 2)
      && t_MsgAddressExt.store_from(cb, data.src)
      && t_MsgAddressInt.store_from(cb, data.dest)
      && t_Grams.store_from(cb, data.import_fee);
}

bool CommonMsgInfo::pack_ext_in_msg_info(vm::CellBuilder& cb, Ref<CellSlice> src, Ref<CellSlice> dest, Ref<CellSlice> import_fee) const {
  return cb.store_long_bool(2, 2)
      && t_MsgAddressExt.store_from(cb, src)
      && t_MsgAddressInt.store_from(cb, dest)
      && t_Grams.store_from(cb, import_fee);
}

bool CommonMsgInfo::cell_pack(Ref<vm::Cell>& cell_ref, const CommonMsgInfo::Record_ext_in_msg_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfo::cell_pack_ext_in_msg_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> src, Ref<CellSlice> dest, Ref<CellSlice> import_fee) const {
  vm::CellBuilder cb;
  return pack_ext_in_msg_info(cb, std::move(src), std::move(dest), std::move(import_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfo::pack(vm::CellBuilder& cb, const CommonMsgInfo::Record_ext_out_msg_info& data) const {
  return cb.store_long_bool(3, 2)
      && t_MsgAddressInt.store_from(cb, data.src)
      && t_MsgAddressExt.store_from(cb, data.dest)
      && cb.store_ulong_rchk_bool(data.created_lt, 64)
      && cb.store_ulong_rchk_bool(data.created_at, 32);
}

bool CommonMsgInfo::cell_pack(Ref<vm::Cell>& cell_ref, const CommonMsgInfo::Record_ext_out_msg_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(1)
        && pp.open("int_msg_info")
        && pp.fetch_uint_field(cs, 1, "ihr_disabled")
        && pp.fetch_uint_field(cs, 1, "bounce")
        && pp.fetch_uint_field(cs, 1, "bounced")
        && pp.field("src")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("dest")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("value")
        && t_CurrencyCollection.print_skip(pp, cs)
        && pp.field("ihr_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "created_lt")
        && pp.fetch_uint_field(cs, 32, "created_at")
        && pp.close();
  case ext_in_msg_info:
    return cs.advance(2)
        && pp.open("ext_in_msg_info")
        && pp.field("src")
        && t_MsgAddressExt.print_skip(pp, cs)
        && pp.field("dest")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("import_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case ext_out_msg_info:
    return cs.advance(2)
        && pp.open("ext_out_msg_info")
        && pp.field("src")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("dest")
        && t_MsgAddressExt.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "created_lt")
        && pp.fetch_uint_field(cs, 32, "created_at")
        && pp.close();
  }
  return pp.fail("unknown constructor for CommonMsgInfo");
}

const CommonMsgInfo t_CommonMsgInfo;

//
// code for type `CommonMsgInfoRelaxed`
//
constexpr char CommonMsgInfoRelaxed::cons_len[2];
constexpr unsigned char CommonMsgInfoRelaxed::cons_tag[2];

int CommonMsgInfoRelaxed::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.have(1) ? int_msg_info : -1;
  case ext_out_msg_info:
    return cs.prefetch_ulong(2) == 3 ? ext_out_msg_info : -1;
  }
  return -1;
}

bool CommonMsgInfoRelaxed::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(4)
        && t_MsgAddress.skip(cs)
        && t_MsgAddressInt.skip(cs)
        && t_CurrencyCollection.skip(cs)
        && t_Grams.skip(cs)
        && t_Grams.skip(cs)
        && cs.advance(96);
  case ext_out_msg_info:
    return cs.advance(2)
        && t_MsgAddress.skip(cs)
        && t_MsgAddressExt.skip(cs)
        && cs.advance(96);
  }
  return false;
}

bool CommonMsgInfoRelaxed::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(4)
        && t_MsgAddress.validate_skip(cs, weak)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_CurrencyCollection.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && cs.advance(96);
  case ext_out_msg_info:
    return cs.fetch_ulong(2) == 3
        && t_MsgAddress.validate_skip(cs, weak)
        && t_MsgAddressExt.validate_skip(cs, weak)
        && cs.advance(96);
  }
  return false;
}

bool CommonMsgInfoRelaxed::unpack(vm::CellSlice& cs, CommonMsgInfoRelaxed::Record_int_msg_info& data) const {
  return cs.fetch_ulong(1) == 0
      && cs.fetch_bool_to(data.ihr_disabled)
      && cs.fetch_bool_to(data.bounce)
      && cs.fetch_bool_to(data.bounced)
      && t_MsgAddress.fetch_to(cs, data.src)
      && t_MsgAddressInt.fetch_to(cs, data.dest)
      && t_CurrencyCollection.fetch_to(cs, data.value)
      && t_Grams.fetch_to(cs, data.ihr_fee)
      && t_Grams.fetch_to(cs, data.fwd_fee)
      && cs.fetch_uint_to(64, data.created_lt)
      && cs.fetch_uint_to(32, data.created_at);
}

bool CommonMsgInfoRelaxed::cell_unpack(Ref<vm::Cell> cell_ref, CommonMsgInfoRelaxed::Record_int_msg_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CommonMsgInfoRelaxed::unpack(vm::CellSlice& cs, CommonMsgInfoRelaxed::Record_ext_out_msg_info& data) const {
  return cs.fetch_ulong(2) == 3
      && t_MsgAddress.fetch_to(cs, data.src)
      && t_MsgAddressExt.fetch_to(cs, data.dest)
      && cs.fetch_uint_to(64, data.created_lt)
      && cs.fetch_uint_to(32, data.created_at);
}

bool CommonMsgInfoRelaxed::cell_unpack(Ref<vm::Cell> cell_ref, CommonMsgInfoRelaxed::Record_ext_out_msg_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CommonMsgInfoRelaxed::pack(vm::CellBuilder& cb, const CommonMsgInfoRelaxed::Record_int_msg_info& data) const {
  return cb.store_long_bool(0, 1)
      && cb.store_ulong_rchk_bool(data.ihr_disabled, 1)
      && cb.store_ulong_rchk_bool(data.bounce, 1)
      && cb.store_ulong_rchk_bool(data.bounced, 1)
      && t_MsgAddress.store_from(cb, data.src)
      && t_MsgAddressInt.store_from(cb, data.dest)
      && t_CurrencyCollection.store_from(cb, data.value)
      && t_Grams.store_from(cb, data.ihr_fee)
      && t_Grams.store_from(cb, data.fwd_fee)
      && cb.store_ulong_rchk_bool(data.created_lt, 64)
      && cb.store_ulong_rchk_bool(data.created_at, 32);
}

bool CommonMsgInfoRelaxed::cell_pack(Ref<vm::Cell>& cell_ref, const CommonMsgInfoRelaxed::Record_int_msg_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfoRelaxed::pack(vm::CellBuilder& cb, const CommonMsgInfoRelaxed::Record_ext_out_msg_info& data) const {
  return cb.store_long_bool(3, 2)
      && t_MsgAddress.store_from(cb, data.src)
      && t_MsgAddressExt.store_from(cb, data.dest)
      && cb.store_ulong_rchk_bool(data.created_lt, 64)
      && cb.store_ulong_rchk_bool(data.created_at, 32);
}

bool CommonMsgInfoRelaxed::cell_pack(Ref<vm::Cell>& cell_ref, const CommonMsgInfoRelaxed::Record_ext_out_msg_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CommonMsgInfoRelaxed::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case int_msg_info:
    return cs.advance(1)
        && pp.open("int_msg_info")
        && pp.fetch_uint_field(cs, 1, "ihr_disabled")
        && pp.fetch_uint_field(cs, 1, "bounce")
        && pp.fetch_uint_field(cs, 1, "bounced")
        && pp.field("src")
        && t_MsgAddress.print_skip(pp, cs)
        && pp.field("dest")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("value")
        && t_CurrencyCollection.print_skip(pp, cs)
        && pp.field("ihr_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "created_lt")
        && pp.fetch_uint_field(cs, 32, "created_at")
        && pp.close();
  case ext_out_msg_info:
    return cs.fetch_ulong(2) == 3
        && pp.open("ext_out_msg_info")
        && pp.field("src")
        && t_MsgAddress.print_skip(pp, cs)
        && pp.field("dest")
        && t_MsgAddressExt.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "created_lt")
        && pp.fetch_uint_field(cs, 32, "created_at")
        && pp.close();
  }
  return pp.fail("unknown constructor for CommonMsgInfoRelaxed");
}

const CommonMsgInfoRelaxed t_CommonMsgInfoRelaxed;

//
// code for type `TickTock`
//

int TickTock::check_tag(const vm::CellSlice& cs) const {
  return tick_tock;
}

bool TickTock::unpack(vm::CellSlice& cs, TickTock::Record& data) const {
  return cs.fetch_bool_to(data.tick)
      && cs.fetch_bool_to(data.tock);
}

bool TickTock::unpack_tick_tock(vm::CellSlice& cs, bool& tick, bool& tock) const {
  return cs.fetch_bool_to(tick)
      && cs.fetch_bool_to(tock);
}

bool TickTock::cell_unpack(Ref<vm::Cell> cell_ref, TickTock::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TickTock::cell_unpack_tick_tock(Ref<vm::Cell> cell_ref, bool& tick, bool& tock) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tick_tock(cs, tick, tock) && cs.empty_ext();
}

bool TickTock::pack(vm::CellBuilder& cb, const TickTock::Record& data) const {
  return cb.store_ulong_rchk_bool(data.tick, 1)
      && cb.store_ulong_rchk_bool(data.tock, 1);
}

bool TickTock::pack_tick_tock(vm::CellBuilder& cb, bool tick, bool tock) const {
  return cb.store_ulong_rchk_bool(tick, 1)
      && cb.store_ulong_rchk_bool(tock, 1);
}

bool TickTock::cell_pack(Ref<vm::Cell>& cell_ref, const TickTock::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TickTock::cell_pack_tick_tock(Ref<vm::Cell>& cell_ref, bool tick, bool tock) const {
  vm::CellBuilder cb;
  return pack_tick_tock(cb, tick, tock) && std::move(cb).finalize_to(cell_ref);
}

bool TickTock::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("tick_tock")
      && pp.fetch_uint_field(cs, 1, "tick")
      && pp.fetch_uint_field(cs, 1, "tock")
      && pp.close();
}

const TickTock t_TickTock;

//
// code for type `StateInit`
//

int StateInit::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool StateInit::skip(vm::CellSlice& cs) const {
  return t_Maybe_natwidth_5.skip(cs)
      && t_Maybe_TickTock.skip(cs)
      && t_Maybe_Ref_Cell.skip(cs)
      && t_Maybe_Ref_Cell.skip(cs)
      && t_HashmapE_256_SimpleLib.skip(cs);
}

bool StateInit::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Maybe_natwidth_5.validate_skip(cs, weak)
      && t_Maybe_TickTock.validate_skip(cs, weak)
      && t_Maybe_Ref_Cell.validate_skip(cs, weak)
      && t_Maybe_Ref_Cell.validate_skip(cs, weak)
      && t_HashmapE_256_SimpleLib.validate_skip(cs, weak);
}

bool StateInit::unpack(vm::CellSlice& cs, StateInit::Record& data) const {
  return t_Maybe_natwidth_5.fetch_to(cs, data.split_depth)
      && t_Maybe_TickTock.fetch_to(cs, data.special)
      && t_Maybe_Ref_Cell.fetch_to(cs, data.code)
      && t_Maybe_Ref_Cell.fetch_to(cs, data.data)
      && t_HashmapE_256_SimpleLib.fetch_to(cs, data.library);
}

bool StateInit::cell_unpack(Ref<vm::Cell> cell_ref, StateInit::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool StateInit::pack(vm::CellBuilder& cb, const StateInit::Record& data) const {
  return t_Maybe_natwidth_5.store_from(cb, data.split_depth)
      && t_Maybe_TickTock.store_from(cb, data.special)
      && t_Maybe_Ref_Cell.store_from(cb, data.code)
      && t_Maybe_Ref_Cell.store_from(cb, data.data)
      && t_HashmapE_256_SimpleLib.store_from(cb, data.library);
}

bool StateInit::cell_pack(Ref<vm::Cell>& cell_ref, const StateInit::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool StateInit::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("split_depth")
      && t_Maybe_natwidth_5.print_skip(pp, cs)
      && pp.field("special")
      && t_Maybe_TickTock.print_skip(pp, cs)
      && pp.field("code")
      && t_Maybe_Ref_Cell.print_skip(pp, cs)
      && pp.field("data")
      && t_Maybe_Ref_Cell.print_skip(pp, cs)
      && pp.field("library")
      && t_HashmapE_256_SimpleLib.print_skip(pp, cs)
      && pp.close();
}

const StateInit t_StateInit;

//
// code for type `SimpleLib`
//

int SimpleLib::check_tag(const vm::CellSlice& cs) const {
  return simple_lib;
}

bool SimpleLib::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance_ext(0x10001);
}

bool SimpleLib::unpack(vm::CellSlice& cs, SimpleLib::Record& data) const {
  return cs.fetch_bool_to(data.public1)
      && cs.fetch_ref_to(data.root);
}

bool SimpleLib::unpack_simple_lib(vm::CellSlice& cs, bool& public1, Ref<Cell>& root) const {
  return cs.fetch_bool_to(public1)
      && cs.fetch_ref_to(root);
}

bool SimpleLib::cell_unpack(Ref<vm::Cell> cell_ref, SimpleLib::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool SimpleLib::cell_unpack_simple_lib(Ref<vm::Cell> cell_ref, bool& public1, Ref<Cell>& root) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_simple_lib(cs, public1, root) && cs.empty_ext();
}

bool SimpleLib::pack(vm::CellBuilder& cb, const SimpleLib::Record& data) const {
  return cb.store_ulong_rchk_bool(data.public1, 1)
      && cb.store_ref_bool(data.root);
}

bool SimpleLib::pack_simple_lib(vm::CellBuilder& cb, bool public1, Ref<Cell> root) const {
  return cb.store_ulong_rchk_bool(public1, 1)
      && cb.store_ref_bool(root);
}

bool SimpleLib::cell_pack(Ref<vm::Cell>& cell_ref, const SimpleLib::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool SimpleLib::cell_pack_simple_lib(Ref<vm::Cell>& cell_ref, bool public1, Ref<Cell> root) const {
  vm::CellBuilder cb;
  return pack_simple_lib(cb, public1, std::move(root)) && std::move(cb).finalize_to(cell_ref);
}

bool SimpleLib::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("simple_lib")
      && pp.fetch_uint_field(cs, 1, "public")
      && pp.field("root")
      && t_Anything.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const SimpleLib t_SimpleLib;

//
// code for type `Message`
//

int Message::check_tag(const vm::CellSlice& cs) const {
  return message;
}

bool Message::skip(vm::CellSlice& cs) const {
  return t_CommonMsgInfo.skip(cs)
      && t_Maybe_Either_StateInit_Ref_StateInit.skip(cs)
      && Either{X_, RefT{X_}}.skip(cs);
}

bool Message::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CommonMsgInfo.validate_skip(cs, weak)
      && t_Maybe_Either_StateInit_Ref_StateInit.validate_skip(cs, weak)
      && Either{X_, RefT{X_}}.validate_skip(cs, weak);
}

bool Message::unpack(vm::CellSlice& cs, Message::Record& data) const {
  return t_CommonMsgInfo.fetch_to(cs, data.info)
      && t_Maybe_Either_StateInit_Ref_StateInit.fetch_to(cs, data.init)
      && Either{X_, RefT{X_}}.fetch_to(cs, data.body);
}

bool Message::unpack_message(vm::CellSlice& cs, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const {
  return t_CommonMsgInfo.fetch_to(cs, info)
      && t_Maybe_Either_StateInit_Ref_StateInit.fetch_to(cs, init)
      && Either{X_, RefT{X_}}.fetch_to(cs, body);
}

bool Message::cell_unpack(Ref<vm::Cell> cell_ref, Message::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Message::cell_unpack_message(Ref<vm::Cell> cell_ref, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_message(cs, info, init, body) && cs.empty_ext();
}

bool Message::pack(vm::CellBuilder& cb, const Message::Record& data) const {
  return t_CommonMsgInfo.store_from(cb, data.info)
      && t_Maybe_Either_StateInit_Ref_StateInit.store_from(cb, data.init)
      && Either{X_, RefT{X_}}.store_from(cb, data.body);
}

bool Message::pack_message(vm::CellBuilder& cb, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const {
  return t_CommonMsgInfo.store_from(cb, info)
      && t_Maybe_Either_StateInit_Ref_StateInit.store_from(cb, init)
      && Either{X_, RefT{X_}}.store_from(cb, body);
}

bool Message::cell_pack(Ref<vm::Cell>& cell_ref, const Message::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Message::cell_pack_message(Ref<vm::Cell>& cell_ref, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const {
  vm::CellBuilder cb;
  return pack_message(cb, std::move(info), std::move(init), std::move(body)) && std::move(cb).finalize_to(cell_ref);
}

bool Message::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("message")
      && pp.field("info")
      && t_CommonMsgInfo.print_skip(pp, cs)
      && pp.field("init")
      && t_Maybe_Either_StateInit_Ref_StateInit.print_skip(pp, cs)
      && pp.field("body")
      && Either{X_, RefT{X_}}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `MessageRelaxed`
//

int MessageRelaxed::check_tag(const vm::CellSlice& cs) const {
  return message;
}

bool MessageRelaxed::skip(vm::CellSlice& cs) const {
  return t_CommonMsgInfoRelaxed.skip(cs)
      && t_Maybe_Either_StateInit_Ref_StateInit.skip(cs)
      && Either{X_, RefT{X_}}.skip(cs);
}

bool MessageRelaxed::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CommonMsgInfoRelaxed.validate_skip(cs, weak)
      && t_Maybe_Either_StateInit_Ref_StateInit.validate_skip(cs, weak)
      && Either{X_, RefT{X_}}.validate_skip(cs, weak);
}

bool MessageRelaxed::unpack(vm::CellSlice& cs, MessageRelaxed::Record& data) const {
  return t_CommonMsgInfoRelaxed.fetch_to(cs, data.info)
      && t_Maybe_Either_StateInit_Ref_StateInit.fetch_to(cs, data.init)
      && Either{X_, RefT{X_}}.fetch_to(cs, data.body);
}

bool MessageRelaxed::unpack_message(vm::CellSlice& cs, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const {
  return t_CommonMsgInfoRelaxed.fetch_to(cs, info)
      && t_Maybe_Either_StateInit_Ref_StateInit.fetch_to(cs, init)
      && Either{X_, RefT{X_}}.fetch_to(cs, body);
}

bool MessageRelaxed::cell_unpack(Ref<vm::Cell> cell_ref, MessageRelaxed::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MessageRelaxed::cell_unpack_message(Ref<vm::Cell> cell_ref, Ref<CellSlice>& info, Ref<CellSlice>& init, Ref<CellSlice>& body) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_message(cs, info, init, body) && cs.empty_ext();
}

bool MessageRelaxed::pack(vm::CellBuilder& cb, const MessageRelaxed::Record& data) const {
  return t_CommonMsgInfoRelaxed.store_from(cb, data.info)
      && t_Maybe_Either_StateInit_Ref_StateInit.store_from(cb, data.init)
      && Either{X_, RefT{X_}}.store_from(cb, data.body);
}

bool MessageRelaxed::pack_message(vm::CellBuilder& cb, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const {
  return t_CommonMsgInfoRelaxed.store_from(cb, info)
      && t_Maybe_Either_StateInit_Ref_StateInit.store_from(cb, init)
      && Either{X_, RefT{X_}}.store_from(cb, body);
}

bool MessageRelaxed::cell_pack(Ref<vm::Cell>& cell_ref, const MessageRelaxed::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MessageRelaxed::cell_pack_message(Ref<vm::Cell>& cell_ref, Ref<CellSlice> info, Ref<CellSlice> init, Ref<CellSlice> body) const {
  vm::CellBuilder cb;
  return pack_message(cb, std::move(info), std::move(init), std::move(body)) && std::move(cb).finalize_to(cell_ref);
}

bool MessageRelaxed::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("message")
      && pp.field("info")
      && t_CommonMsgInfoRelaxed.print_skip(pp, cs)
      && pp.field("init")
      && t_Maybe_Either_StateInit_Ref_StateInit.print_skip(pp, cs)
      && pp.field("body")
      && Either{X_, RefT{X_}}.print_skip(pp, cs)
      && pp.close();
}


//
// code for type `IntermediateAddress`
//
constexpr char IntermediateAddress::cons_len[3];
constexpr unsigned char IntermediateAddress::cons_tag[3];

int IntermediateAddress::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case interm_addr_regular:
    return cs.have(1) ? interm_addr_regular : -1;
  case interm_addr_simple:
    return cs.have(2) ? interm_addr_simple : -1;
  case interm_addr_ext:
    return cs.have(2) ? interm_addr_ext : -1;
  }
  return -1;
}

bool IntermediateAddress::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case interm_addr_regular:
    return cs.advance(8);
  case interm_addr_simple:
    return cs.advance(74);
  case interm_addr_ext:
    return cs.advance(98);
  }
  return false;
}

bool IntermediateAddress::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case interm_addr_regular: {
    int use_dest_bits;
    return cs.advance(1)
        && cs.fetch_uint_leq(96, use_dest_bits);
    }
  case interm_addr_simple:
    return cs.advance(74);
  case interm_addr_ext:
    return cs.advance(98);
  }
  return false;
}

bool IntermediateAddress::unpack(vm::CellSlice& cs, IntermediateAddress::Record_interm_addr_regular& data) const {
  return cs.fetch_ulong(1) == 0
      && cs.fetch_uint_leq(96, data.use_dest_bits);
}

bool IntermediateAddress::unpack_interm_addr_regular(vm::CellSlice& cs, int& use_dest_bits) const {
  return cs.fetch_ulong(1) == 0
      && cs.fetch_uint_leq(96, use_dest_bits);
}

bool IntermediateAddress::cell_unpack(Ref<vm::Cell> cell_ref, IntermediateAddress::Record_interm_addr_regular& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool IntermediateAddress::cell_unpack_interm_addr_regular(Ref<vm::Cell> cell_ref, int& use_dest_bits) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_interm_addr_regular(cs, use_dest_bits) && cs.empty_ext();
}

bool IntermediateAddress::unpack(vm::CellSlice& cs, IntermediateAddress::Record_interm_addr_simple& data) const {
  return cs.fetch_ulong(2) == 2
      && cs.fetch_int_to(8, data.workchain_id)
      && cs.fetch_uint_to(64, data.addr_pfx);
}

bool IntermediateAddress::unpack_interm_addr_simple(vm::CellSlice& cs, int& workchain_id, unsigned long long& addr_pfx) const {
  return cs.fetch_ulong(2) == 2
      && cs.fetch_int_to(8, workchain_id)
      && cs.fetch_uint_to(64, addr_pfx);
}

bool IntermediateAddress::cell_unpack(Ref<vm::Cell> cell_ref, IntermediateAddress::Record_interm_addr_simple& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool IntermediateAddress::cell_unpack_interm_addr_simple(Ref<vm::Cell> cell_ref, int& workchain_id, unsigned long long& addr_pfx) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_interm_addr_simple(cs, workchain_id, addr_pfx) && cs.empty_ext();
}

bool IntermediateAddress::unpack(vm::CellSlice& cs, IntermediateAddress::Record_interm_addr_ext& data) const {
  return cs.fetch_ulong(2) == 3
      && cs.fetch_int_to(32, data.workchain_id)
      && cs.fetch_uint_to(64, data.addr_pfx);
}

bool IntermediateAddress::unpack_interm_addr_ext(vm::CellSlice& cs, int& workchain_id, unsigned long long& addr_pfx) const {
  return cs.fetch_ulong(2) == 3
      && cs.fetch_int_to(32, workchain_id)
      && cs.fetch_uint_to(64, addr_pfx);
}

bool IntermediateAddress::cell_unpack(Ref<vm::Cell> cell_ref, IntermediateAddress::Record_interm_addr_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool IntermediateAddress::cell_unpack_interm_addr_ext(Ref<vm::Cell> cell_ref, int& workchain_id, unsigned long long& addr_pfx) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_interm_addr_ext(cs, workchain_id, addr_pfx) && cs.empty_ext();
}

bool IntermediateAddress::pack(vm::CellBuilder& cb, const IntermediateAddress::Record_interm_addr_regular& data) const {
  return cb.store_long_bool(0, 1)
      && cb.store_uint_leq(96, data.use_dest_bits);
}

bool IntermediateAddress::pack_interm_addr_regular(vm::CellBuilder& cb, int use_dest_bits) const {
  return cb.store_long_bool(0, 1)
      && cb.store_uint_leq(96, use_dest_bits);
}

bool IntermediateAddress::cell_pack(Ref<vm::Cell>& cell_ref, const IntermediateAddress::Record_interm_addr_regular& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::cell_pack_interm_addr_regular(Ref<vm::Cell>& cell_ref, int use_dest_bits) const {
  vm::CellBuilder cb;
  return pack_interm_addr_regular(cb, use_dest_bits) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::pack(vm::CellBuilder& cb, const IntermediateAddress::Record_interm_addr_simple& data) const {
  return cb.store_long_bool(2, 2)
      && cb.store_long_rchk_bool(data.workchain_id, 8)
      && cb.store_ulong_rchk_bool(data.addr_pfx, 64);
}

bool IntermediateAddress::pack_interm_addr_simple(vm::CellBuilder& cb, int workchain_id, unsigned long long addr_pfx) const {
  return cb.store_long_bool(2, 2)
      && cb.store_long_rchk_bool(workchain_id, 8)
      && cb.store_ulong_rchk_bool(addr_pfx, 64);
}

bool IntermediateAddress::cell_pack(Ref<vm::Cell>& cell_ref, const IntermediateAddress::Record_interm_addr_simple& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::cell_pack_interm_addr_simple(Ref<vm::Cell>& cell_ref, int workchain_id, unsigned long long addr_pfx) const {
  vm::CellBuilder cb;
  return pack_interm_addr_simple(cb, workchain_id, addr_pfx) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::pack(vm::CellBuilder& cb, const IntermediateAddress::Record_interm_addr_ext& data) const {
  return cb.store_long_bool(3, 2)
      && cb.store_long_rchk_bool(data.workchain_id, 32)
      && cb.store_ulong_rchk_bool(data.addr_pfx, 64);
}

bool IntermediateAddress::pack_interm_addr_ext(vm::CellBuilder& cb, int workchain_id, unsigned long long addr_pfx) const {
  return cb.store_long_bool(3, 2)
      && cb.store_long_rchk_bool(workchain_id, 32)
      && cb.store_ulong_rchk_bool(addr_pfx, 64);
}

bool IntermediateAddress::cell_pack(Ref<vm::Cell>& cell_ref, const IntermediateAddress::Record_interm_addr_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::cell_pack_interm_addr_ext(Ref<vm::Cell>& cell_ref, int workchain_id, unsigned long long addr_pfx) const {
  vm::CellBuilder cb;
  return pack_interm_addr_ext(cb, workchain_id, addr_pfx) && std::move(cb).finalize_to(cell_ref);
}

bool IntermediateAddress::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case interm_addr_regular: {
    int use_dest_bits;
    return cs.advance(1)
        && pp.open("interm_addr_regular")
        && cs.fetch_uint_leq(96, use_dest_bits)
        && pp.field_int(use_dest_bits, "use_dest_bits")
        && pp.close();
    }
  case interm_addr_simple:
    return cs.advance(2)
        && pp.open("interm_addr_simple")
        && pp.fetch_int_field(cs, 8, "workchain_id")
        && pp.fetch_uint_field(cs, 64, "addr_pfx")
        && pp.close();
  case interm_addr_ext:
    return cs.advance(2)
        && pp.open("interm_addr_ext")
        && pp.fetch_int_field(cs, 32, "workchain_id")
        && pp.fetch_uint_field(cs, 64, "addr_pfx")
        && pp.close();
  }
  return pp.fail("unknown constructor for IntermediateAddress");
}

const IntermediateAddress t_IntermediateAddress;

//
// code for type `MsgEnvelope`
//
constexpr unsigned char MsgEnvelope::cons_tag[1];

int MsgEnvelope::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 4 ? msg_envelope : -1;
}

bool MsgEnvelope::skip(vm::CellSlice& cs) const {
  return cs.advance(4)
      && t_IntermediateAddress.skip(cs)
      && t_IntermediateAddress.skip(cs)
      && t_Grams.skip(cs)
      && cs.advance_refs(1);
}

bool MsgEnvelope::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 4
      && t_IntermediateAddress.validate_skip(cs, weak)
      && t_IntermediateAddress.validate_skip(cs, weak)
      && t_Grams.validate_skip(cs, weak)
      && t_Message_Any.validate_skip_ref(cs, weak);
}

bool MsgEnvelope::unpack(vm::CellSlice& cs, MsgEnvelope::Record& data) const {
  return cs.fetch_ulong(4) == 4
      && t_IntermediateAddress.fetch_to(cs, data.cur_addr)
      && t_IntermediateAddress.fetch_to(cs, data.next_addr)
      && t_Grams.fetch_to(cs, data.fwd_fee_remaining)
      && cs.fetch_ref_to(data.msg);
}

bool MsgEnvelope::cell_unpack(Ref<vm::Cell> cell_ref, MsgEnvelope::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgEnvelope::pack(vm::CellBuilder& cb, const MsgEnvelope::Record& data) const {
  return cb.store_long_bool(4, 4)
      && t_IntermediateAddress.store_from(cb, data.cur_addr)
      && t_IntermediateAddress.store_from(cb, data.next_addr)
      && t_Grams.store_from(cb, data.fwd_fee_remaining)
      && cb.store_ref_bool(data.msg);
}

bool MsgEnvelope::cell_pack(Ref<vm::Cell>& cell_ref, const MsgEnvelope::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgEnvelope::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 4
      && pp.open("msg_envelope")
      && pp.field("cur_addr")
      && t_IntermediateAddress.print_skip(pp, cs)
      && pp.field("next_addr")
      && t_IntermediateAddress.print_skip(pp, cs)
      && pp.field("fwd_fee_remaining")
      && t_Grams.print_skip(pp, cs)
      && pp.field("msg")
      && t_Message_Any.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const MsgEnvelope t_MsgEnvelope;

//
// code for type `InMsg`
//
constexpr unsigned char InMsg::cons_tag[7];

int InMsg::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_import_ext:
    return cs.prefetch_ulong(3) == 0 ? msg_import_ext : -1;
  case msg_import_ihr:
    return cs.have(3) ? msg_import_ihr : -1;
  case msg_import_imm:
    return cs.have(3) ? msg_import_imm : -1;
  case msg_import_fin:
    return cs.have(3) ? msg_import_fin : -1;
  case msg_import_tr:
    return cs.have(3) ? msg_import_tr : -1;
  case msg_discard_fin:
    return cs.have(3) ? msg_discard_fin : -1;
  case msg_discard_tr:
    return cs.have(3) ? msg_discard_tr : -1;
  }
  return -1;
}

bool InMsg::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_import_ext:
    return cs.advance_ext(0x20003);
  case msg_import_ihr:
    return cs.advance_ext(0x20003)
        && t_Grams.skip(cs)
        && cs.advance_refs(1);
  case msg_import_imm:
    return cs.advance_ext(0x20003)
        && t_Grams.skip(cs);
  case msg_import_fin:
    return cs.advance_ext(0x20003)
        && t_Grams.skip(cs);
  case msg_import_tr:
    return cs.advance_ext(0x20003)
        && t_Grams.skip(cs);
  case msg_discard_fin:
    return cs.advance_ext(0x10043)
        && t_Grams.skip(cs);
  case msg_discard_tr:
    return cs.advance_ext(0x10043)
        && t_Grams.skip(cs)
        && cs.advance_refs(1);
  }
  return false;
}

bool InMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case msg_import_ext:
    return cs.fetch_ulong(3) == 0
        && t_Message_Any.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak);
  case msg_import_ihr:
    return cs.advance(3)
        && t_Message_Any.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && cs.advance_refs(1);
  case msg_import_imm:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  case msg_import_fin:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  case msg_import_tr:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  case msg_discard_fin:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && cs.advance(64)
        && t_Grams.validate_skip(cs, weak);
  case msg_discard_tr:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && cs.advance(64)
        && t_Grams.validate_skip(cs, weak)
        && cs.advance_refs(1);
  }
  return false;
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_import_ext& data) const {
  return cs.fetch_ulong(3) == 0
      && cs.fetch_ref_to(data.msg)
      && cs.fetch_ref_to(data.transaction);
}

bool InMsg::unpack_msg_import_ext(vm::CellSlice& cs, Ref<Cell>& msg, Ref<Cell>& transaction) const {
  return cs.fetch_ulong(3) == 0
      && cs.fetch_ref_to(msg)
      && cs.fetch_ref_to(transaction);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_import_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::cell_unpack_msg_import_ext(Ref<vm::Cell> cell_ref, Ref<Cell>& msg, Ref<Cell>& transaction) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_import_ext(cs, msg, transaction) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_import_ihr& data) const {
  return cs.fetch_ulong(3) == 2
      && cs.fetch_ref_to(data.msg)
      && cs.fetch_ref_to(data.transaction)
      && t_Grams.fetch_to(cs, data.ihr_fee)
      && cs.fetch_ref_to(data.proof_created);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_import_ihr& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_import_imm& data) const {
  return cs.fetch_ulong(3) == 3
      && cs.fetch_ref_to(data.in_msg)
      && cs.fetch_ref_to(data.transaction)
      && t_Grams.fetch_to(cs, data.fwd_fee);
}

bool InMsg::unpack_msg_import_imm(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const {
  return cs.fetch_ulong(3) == 3
      && cs.fetch_ref_to(in_msg)
      && cs.fetch_ref_to(transaction)
      && t_Grams.fetch_to(cs, fwd_fee);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_import_imm& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::cell_unpack_msg_import_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_import_imm(cs, in_msg, transaction, fwd_fee) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_import_fin& data) const {
  return cs.fetch_ulong(3) == 4
      && cs.fetch_ref_to(data.in_msg)
      && cs.fetch_ref_to(data.transaction)
      && t_Grams.fetch_to(cs, data.fwd_fee);
}

bool InMsg::unpack_msg_import_fin(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const {
  return cs.fetch_ulong(3) == 4
      && cs.fetch_ref_to(in_msg)
      && cs.fetch_ref_to(transaction)
      && t_Grams.fetch_to(cs, fwd_fee);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_import_fin& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::cell_unpack_msg_import_fin(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& transaction, Ref<CellSlice>& fwd_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_import_fin(cs, in_msg, transaction, fwd_fee) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_import_tr& data) const {
  return cs.fetch_ulong(3) == 5
      && cs.fetch_ref_to(data.in_msg)
      && cs.fetch_ref_to(data.out_msg)
      && t_Grams.fetch_to(cs, data.transit_fee);
}

bool InMsg::unpack_msg_import_tr(vm::CellSlice& cs, Ref<Cell>& in_msg, Ref<Cell>& out_msg, Ref<CellSlice>& transit_fee) const {
  return cs.fetch_ulong(3) == 5
      && cs.fetch_ref_to(in_msg)
      && cs.fetch_ref_to(out_msg)
      && t_Grams.fetch_to(cs, transit_fee);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_import_tr& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::cell_unpack_msg_import_tr(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, Ref<Cell>& out_msg, Ref<CellSlice>& transit_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_import_tr(cs, in_msg, out_msg, transit_fee) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_discard_fin& data) const {
  return cs.fetch_ulong(3) == 6
      && cs.fetch_ref_to(data.in_msg)
      && cs.fetch_uint_to(64, data.transaction_id)
      && t_Grams.fetch_to(cs, data.fwd_fee);
}

bool InMsg::unpack_msg_discard_fin(vm::CellSlice& cs, Ref<Cell>& in_msg, unsigned long long& transaction_id, Ref<CellSlice>& fwd_fee) const {
  return cs.fetch_ulong(3) == 6
      && cs.fetch_ref_to(in_msg)
      && cs.fetch_uint_to(64, transaction_id)
      && t_Grams.fetch_to(cs, fwd_fee);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_discard_fin& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::cell_unpack_msg_discard_fin(Ref<vm::Cell> cell_ref, Ref<Cell>& in_msg, unsigned long long& transaction_id, Ref<CellSlice>& fwd_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_discard_fin(cs, in_msg, transaction_id, fwd_fee) && cs.empty_ext();
}

bool InMsg::unpack(vm::CellSlice& cs, InMsg::Record_msg_discard_tr& data) const {
  return cs.fetch_ulong(3) == 7
      && cs.fetch_ref_to(data.in_msg)
      && cs.fetch_uint_to(64, data.transaction_id)
      && t_Grams.fetch_to(cs, data.fwd_fee)
      && cs.fetch_ref_to(data.proof_delivered);
}

bool InMsg::cell_unpack(Ref<vm::Cell> cell_ref, InMsg::Record_msg_discard_tr& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_import_ext& data) const {
  return cb.store_long_bool(0, 3)
      && cb.store_ref_bool(data.msg)
      && cb.store_ref_bool(data.transaction);
}

bool InMsg::pack_msg_import_ext(vm::CellBuilder& cb, Ref<Cell> msg, Ref<Cell> transaction) const {
  return cb.store_long_bool(0, 3)
      && cb.store_ref_bool(msg)
      && cb.store_ref_bool(transaction);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_import_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::cell_pack_msg_import_ext(Ref<vm::Cell>& cell_ref, Ref<Cell> msg, Ref<Cell> transaction) const {
  vm::CellBuilder cb;
  return pack_msg_import_ext(cb, std::move(msg), std::move(transaction)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_import_ihr& data) const {
  return cb.store_long_bool(2, 3)
      && cb.store_ref_bool(data.msg)
      && cb.store_ref_bool(data.transaction)
      && t_Grams.store_from(cb, data.ihr_fee)
      && cb.store_ref_bool(data.proof_created);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_import_ihr& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_import_imm& data) const {
  return cb.store_long_bool(3, 3)
      && cb.store_ref_bool(data.in_msg)
      && cb.store_ref_bool(data.transaction)
      && t_Grams.store_from(cb, data.fwd_fee);
}

bool InMsg::pack_msg_import_imm(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const {
  return cb.store_long_bool(3, 3)
      && cb.store_ref_bool(in_msg)
      && cb.store_ref_bool(transaction)
      && t_Grams.store_from(cb, fwd_fee);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_import_imm& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::cell_pack_msg_import_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const {
  vm::CellBuilder cb;
  return pack_msg_import_imm(cb, std::move(in_msg), std::move(transaction), std::move(fwd_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_import_fin& data) const {
  return cb.store_long_bool(4, 3)
      && cb.store_ref_bool(data.in_msg)
      && cb.store_ref_bool(data.transaction)
      && t_Grams.store_from(cb, data.fwd_fee);
}

bool InMsg::pack_msg_import_fin(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const {
  return cb.store_long_bool(4, 3)
      && cb.store_ref_bool(in_msg)
      && cb.store_ref_bool(transaction)
      && t_Grams.store_from(cb, fwd_fee);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_import_fin& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::cell_pack_msg_import_fin(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> transaction, Ref<CellSlice> fwd_fee) const {
  vm::CellBuilder cb;
  return pack_msg_import_fin(cb, std::move(in_msg), std::move(transaction), std::move(fwd_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_import_tr& data) const {
  return cb.store_long_bool(5, 3)
      && cb.store_ref_bool(data.in_msg)
      && cb.store_ref_bool(data.out_msg)
      && t_Grams.store_from(cb, data.transit_fee);
}

bool InMsg::pack_msg_import_tr(vm::CellBuilder& cb, Ref<Cell> in_msg, Ref<Cell> out_msg, Ref<CellSlice> transit_fee) const {
  return cb.store_long_bool(5, 3)
      && cb.store_ref_bool(in_msg)
      && cb.store_ref_bool(out_msg)
      && t_Grams.store_from(cb, transit_fee);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_import_tr& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::cell_pack_msg_import_tr(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, Ref<Cell> out_msg, Ref<CellSlice> transit_fee) const {
  vm::CellBuilder cb;
  return pack_msg_import_tr(cb, std::move(in_msg), std::move(out_msg), std::move(transit_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_discard_fin& data) const {
  return cb.store_long_bool(6, 3)
      && cb.store_ref_bool(data.in_msg)
      && cb.store_ulong_rchk_bool(data.transaction_id, 64)
      && t_Grams.store_from(cb, data.fwd_fee);
}

bool InMsg::pack_msg_discard_fin(vm::CellBuilder& cb, Ref<Cell> in_msg, unsigned long long transaction_id, Ref<CellSlice> fwd_fee) const {
  return cb.store_long_bool(6, 3)
      && cb.store_ref_bool(in_msg)
      && cb.store_ulong_rchk_bool(transaction_id, 64)
      && t_Grams.store_from(cb, fwd_fee);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_discard_fin& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::cell_pack_msg_discard_fin(Ref<vm::Cell>& cell_ref, Ref<Cell> in_msg, unsigned long long transaction_id, Ref<CellSlice> fwd_fee) const {
  vm::CellBuilder cb;
  return pack_msg_discard_fin(cb, std::move(in_msg), transaction_id, std::move(fwd_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::pack(vm::CellBuilder& cb, const InMsg::Record_msg_discard_tr& data) const {
  return cb.store_long_bool(7, 3)
      && cb.store_ref_bool(data.in_msg)
      && cb.store_ulong_rchk_bool(data.transaction_id, 64)
      && t_Grams.store_from(cb, data.fwd_fee)
      && cb.store_ref_bool(data.proof_delivered);
}

bool InMsg::cell_pack(Ref<vm::Cell>& cell_ref, const InMsg::Record_msg_discard_tr& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsg::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_import_ext:
    return cs.fetch_ulong(3) == 0
        && pp.open("msg_import_ext")
        && pp.field("msg")
        && t_Message_Any.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_import_ihr:
    return cs.advance(3)
        && pp.open("msg_import_ihr")
        && pp.field("msg")
        && t_Message_Any.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.field("ihr_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.field("proof_created")
        && t_Anything.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_import_imm:
    return cs.advance(3)
        && pp.open("msg_import_imm")
        && pp.field("in_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case msg_import_fin:
    return cs.advance(3)
        && pp.open("msg_import_fin")
        && pp.field("in_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case msg_import_tr:
    return cs.advance(3)
        && pp.open("msg_import_tr")
        && pp.field("in_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("transit_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case msg_discard_fin:
    return cs.advance(3)
        && pp.open("msg_discard_fin")
        && pp.field("in_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.fetch_uint_field(cs, 64, "transaction_id")
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case msg_discard_tr:
    return cs.advance(3)
        && pp.open("msg_discard_tr")
        && pp.field("in_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.fetch_uint_field(cs, 64, "transaction_id")
        && pp.field("fwd_fee")
        && t_Grams.print_skip(pp, cs)
        && pp.field("proof_delivered")
        && t_Anything.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for InMsg");
}

const InMsg t_InMsg;

//
// code for type `ImportFees`
//

int ImportFees::check_tag(const vm::CellSlice& cs) const {
  return import_fees;
}

bool ImportFees::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool ImportFees::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ImportFees::unpack(vm::CellSlice& cs, ImportFees::Record& data) const {
  return t_Grams.fetch_to(cs, data.fees_collected)
      && t_CurrencyCollection.fetch_to(cs, data.value_imported);
}

bool ImportFees::unpack_import_fees(vm::CellSlice& cs, Ref<CellSlice>& fees_collected, Ref<CellSlice>& value_imported) const {
  return t_Grams.fetch_to(cs, fees_collected)
      && t_CurrencyCollection.fetch_to(cs, value_imported);
}

bool ImportFees::cell_unpack(Ref<vm::Cell> cell_ref, ImportFees::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ImportFees::cell_unpack_import_fees(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fees_collected, Ref<CellSlice>& value_imported) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_import_fees(cs, fees_collected, value_imported) && cs.empty_ext();
}

bool ImportFees::pack(vm::CellBuilder& cb, const ImportFees::Record& data) const {
  return t_Grams.store_from(cb, data.fees_collected)
      && t_CurrencyCollection.store_from(cb, data.value_imported);
}

bool ImportFees::pack_import_fees(vm::CellBuilder& cb, Ref<CellSlice> fees_collected, Ref<CellSlice> value_imported) const {
  return t_Grams.store_from(cb, fees_collected)
      && t_CurrencyCollection.store_from(cb, value_imported);
}

bool ImportFees::cell_pack(Ref<vm::Cell>& cell_ref, const ImportFees::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ImportFees::cell_pack_import_fees(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fees_collected, Ref<CellSlice> value_imported) const {
  vm::CellBuilder cb;
  return pack_import_fees(cb, std::move(fees_collected), std::move(value_imported)) && std::move(cb).finalize_to(cell_ref);
}

bool ImportFees::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("import_fees")
      && pp.field("fees_collected")
      && t_Grams.print_skip(pp, cs)
      && pp.field("value_imported")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ImportFees t_ImportFees;

//
// code for type `InMsgDescr`
//

int InMsgDescr::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool InMsgDescr::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_256_InMsg_ImportFees.skip(cs);
}

bool InMsgDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_256_InMsg_ImportFees.validate_skip(cs, weak);
}

bool InMsgDescr::unpack(vm::CellSlice& cs, InMsgDescr::Record& data) const {
  return t_HashmapAugE_256_InMsg_ImportFees.fetch_to(cs, data.x);
}

bool InMsgDescr::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_256_InMsg_ImportFees.fetch_to(cs, x);
}

bool InMsgDescr::cell_unpack(Ref<vm::Cell> cell_ref, InMsgDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool InMsgDescr::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool InMsgDescr::pack(vm::CellBuilder& cb, const InMsgDescr::Record& data) const {
  return t_HashmapAugE_256_InMsg_ImportFees.store_from(cb, data.x);
}

bool InMsgDescr::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_256_InMsg_ImportFees.store_from(cb, x);
}

bool InMsgDescr::cell_pack(Ref<vm::Cell>& cell_ref, const InMsgDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool InMsgDescr::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool InMsgDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_256_InMsg_ImportFees.print_skip(pp, cs)
      && pp.close();
}

const InMsgDescr t_InMsgDescr;

//
// code for type `OutMsg`
//
constexpr unsigned char OutMsg::cons_tag[7];

int OutMsg::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_export_ext:
    return cs.have(3) ? msg_export_ext : -1;
  case msg_export_imm:
    return cs.have(3) ? msg_export_imm : -1;
  case msg_export_new:
    return cs.have(3) ? msg_export_new : -1;
  case msg_export_tr:
    return cs.have(3) ? msg_export_tr : -1;
  case msg_export_deq:
    return cs.have(3) ? msg_export_deq : -1;
  case msg_export_tr_req:
    return cs.have(3) ? msg_export_tr_req : -1;
  case msg_export_deq_imm:
    return cs.prefetch_ulong(3) == 4 ? msg_export_deq_imm : -1;
  }
  return -1;
}

bool OutMsg::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_export_ext:
    return cs.advance_ext(0x20003);
  case msg_export_imm:
    return cs.advance_ext(0x30003);
  case msg_export_new:
    return cs.advance_ext(0x20003);
  case msg_export_tr:
    return cs.advance_ext(0x20003);
  case msg_export_deq:
    return cs.advance_ext(0x10043);
  case msg_export_tr_req:
    return cs.advance_ext(0x20003);
  case msg_export_deq_imm:
    return cs.advance_ext(0x20003);
  }
  return false;
}

bool OutMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case msg_export_ext:
    return cs.advance(3)
        && t_Message_Any.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak);
  case msg_export_imm:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak)
        && t_InMsg.validate_skip_ref(cs, weak);
  case msg_export_new:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_Transaction.validate_skip_ref(cs, weak);
  case msg_export_tr:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_InMsg.validate_skip_ref(cs, weak);
  case msg_export_deq:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && cs.advance(64);
  case msg_export_tr_req:
    return cs.advance(3)
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_InMsg.validate_skip_ref(cs, weak);
  case msg_export_deq_imm:
    return cs.fetch_ulong(3) == 4
        && t_MsgEnvelope.validate_skip_ref(cs, weak)
        && t_InMsg.validate_skip_ref(cs, weak);
  }
  return false;
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_ext& data) const {
  return cs.fetch_ulong(3) == 0
      && cs.fetch_ref_to(data.msg)
      && cs.fetch_ref_to(data.transaction);
}

bool OutMsg::unpack_msg_export_ext(vm::CellSlice& cs, Ref<Cell>& msg, Ref<Cell>& transaction) const {
  return cs.fetch_ulong(3) == 0
      && cs.fetch_ref_to(msg)
      && cs.fetch_ref_to(transaction);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_ext(Ref<vm::Cell> cell_ref, Ref<Cell>& msg, Ref<Cell>& transaction) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_ext(cs, msg, transaction) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_imm& data) const {
  return cs.fetch_ulong(3) == 2
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_ref_to(data.transaction)
      && cs.fetch_ref_to(data.reimport);
}

bool OutMsg::unpack_msg_export_imm(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& transaction, Ref<Cell>& reimport) const {
  return cs.fetch_ulong(3) == 2
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_ref_to(transaction)
      && cs.fetch_ref_to(reimport);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_imm& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& transaction, Ref<Cell>& reimport) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_imm(cs, out_msg, transaction, reimport) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_new& data) const {
  return cs.fetch_ulong(3) == 1
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_ref_to(data.transaction);
}

bool OutMsg::unpack_msg_export_new(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& transaction) const {
  return cs.fetch_ulong(3) == 1
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_ref_to(transaction);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_new& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_new(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& transaction) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_new(cs, out_msg, transaction) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_tr& data) const {
  return cs.fetch_ulong(3) == 3
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_ref_to(data.imported);
}

bool OutMsg::unpack_msg_export_tr(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& imported) const {
  return cs.fetch_ulong(3) == 3
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_ref_to(imported);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_tr& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_tr(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& imported) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_tr(cs, out_msg, imported) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_deq& data) const {
  return cs.fetch_ulong(3) == 6
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_uint_to(64, data.import_block_lt);
}

bool OutMsg::unpack_msg_export_deq(vm::CellSlice& cs, Ref<Cell>& out_msg, unsigned long long& import_block_lt) const {
  return cs.fetch_ulong(3) == 6
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_uint_to(64, import_block_lt);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_deq& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_deq(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, unsigned long long& import_block_lt) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_deq(cs, out_msg, import_block_lt) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_tr_req& data) const {
  return cs.fetch_ulong(3) == 7
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_ref_to(data.imported);
}

bool OutMsg::unpack_msg_export_tr_req(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& imported) const {
  return cs.fetch_ulong(3) == 7
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_ref_to(imported);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_tr_req& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_tr_req(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& imported) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_tr_req(cs, out_msg, imported) && cs.empty_ext();
}

bool OutMsg::unpack(vm::CellSlice& cs, OutMsg::Record_msg_export_deq_imm& data) const {
  return cs.fetch_ulong(3) == 4
      && cs.fetch_ref_to(data.out_msg)
      && cs.fetch_ref_to(data.reimport);
}

bool OutMsg::unpack_msg_export_deq_imm(vm::CellSlice& cs, Ref<Cell>& out_msg, Ref<Cell>& reimport) const {
  return cs.fetch_ulong(3) == 4
      && cs.fetch_ref_to(out_msg)
      && cs.fetch_ref_to(reimport);
}

bool OutMsg::cell_unpack(Ref<vm::Cell> cell_ref, OutMsg::Record_msg_export_deq_imm& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsg::cell_unpack_msg_export_deq_imm(Ref<vm::Cell> cell_ref, Ref<Cell>& out_msg, Ref<Cell>& reimport) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_msg_export_deq_imm(cs, out_msg, reimport) && cs.empty_ext();
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_ext& data) const {
  return cb.store_long_bool(0, 3)
      && cb.store_ref_bool(data.msg)
      && cb.store_ref_bool(data.transaction);
}

bool OutMsg::pack_msg_export_ext(vm::CellBuilder& cb, Ref<Cell> msg, Ref<Cell> transaction) const {
  return cb.store_long_bool(0, 3)
      && cb.store_ref_bool(msg)
      && cb.store_ref_bool(transaction);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_ext(Ref<vm::Cell>& cell_ref, Ref<Cell> msg, Ref<Cell> transaction) const {
  vm::CellBuilder cb;
  return pack_msg_export_ext(cb, std::move(msg), std::move(transaction)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_imm& data) const {
  return cb.store_long_bool(2, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ref_bool(data.transaction)
      && cb.store_ref_bool(data.reimport);
}

bool OutMsg::pack_msg_export_imm(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> transaction, Ref<Cell> reimport) const {
  return cb.store_long_bool(2, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ref_bool(transaction)
      && cb.store_ref_bool(reimport);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_imm& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> transaction, Ref<Cell> reimport) const {
  vm::CellBuilder cb;
  return pack_msg_export_imm(cb, std::move(out_msg), std::move(transaction), std::move(reimport)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_new& data) const {
  return cb.store_long_bool(1, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ref_bool(data.transaction);
}

bool OutMsg::pack_msg_export_new(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> transaction) const {
  return cb.store_long_bool(1, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ref_bool(transaction);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_new& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_new(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> transaction) const {
  vm::CellBuilder cb;
  return pack_msg_export_new(cb, std::move(out_msg), std::move(transaction)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_tr& data) const {
  return cb.store_long_bool(3, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ref_bool(data.imported);
}

bool OutMsg::pack_msg_export_tr(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> imported) const {
  return cb.store_long_bool(3, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ref_bool(imported);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_tr& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_tr(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> imported) const {
  vm::CellBuilder cb;
  return pack_msg_export_tr(cb, std::move(out_msg), std::move(imported)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_deq& data) const {
  return cb.store_long_bool(6, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ulong_rchk_bool(data.import_block_lt, 64);
}

bool OutMsg::pack_msg_export_deq(vm::CellBuilder& cb, Ref<Cell> out_msg, unsigned long long import_block_lt) const {
  return cb.store_long_bool(6, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ulong_rchk_bool(import_block_lt, 64);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_deq& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_deq(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, unsigned long long import_block_lt) const {
  vm::CellBuilder cb;
  return pack_msg_export_deq(cb, std::move(out_msg), import_block_lt) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_tr_req& data) const {
  return cb.store_long_bool(7, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ref_bool(data.imported);
}

bool OutMsg::pack_msg_export_tr_req(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> imported) const {
  return cb.store_long_bool(7, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ref_bool(imported);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_tr_req& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_tr_req(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> imported) const {
  vm::CellBuilder cb;
  return pack_msg_export_tr_req(cb, std::move(out_msg), std::move(imported)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::pack(vm::CellBuilder& cb, const OutMsg::Record_msg_export_deq_imm& data) const {
  return cb.store_long_bool(4, 3)
      && cb.store_ref_bool(data.out_msg)
      && cb.store_ref_bool(data.reimport);
}

bool OutMsg::pack_msg_export_deq_imm(vm::CellBuilder& cb, Ref<Cell> out_msg, Ref<Cell> reimport) const {
  return cb.store_long_bool(4, 3)
      && cb.store_ref_bool(out_msg)
      && cb.store_ref_bool(reimport);
}

bool OutMsg::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsg::Record_msg_export_deq_imm& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::cell_pack_msg_export_deq_imm(Ref<vm::Cell>& cell_ref, Ref<Cell> out_msg, Ref<Cell> reimport) const {
  vm::CellBuilder cb;
  return pack_msg_export_deq_imm(cb, std::move(out_msg), std::move(reimport)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsg::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case msg_export_ext:
    return cs.advance(3)
        && pp.open("msg_export_ext")
        && pp.field("msg")
        && t_Message_Any.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_export_imm:
    return cs.advance(3)
        && pp.open("msg_export_imm")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.field("reimport")
        && t_InMsg.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_export_new:
    return cs.advance(3)
        && pp.open("msg_export_new")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_export_tr:
    return cs.advance(3)
        && pp.open("msg_export_tr")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("imported")
        && t_InMsg.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_export_deq:
    return cs.advance(3)
        && pp.open("msg_export_deq")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.fetch_uint_field(cs, 64, "import_block_lt")
        && pp.close();
  case msg_export_tr_req:
    return cs.advance(3)
        && pp.open("msg_export_tr_req")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("imported")
        && t_InMsg.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case msg_export_deq_imm:
    return cs.fetch_ulong(3) == 4
        && pp.open("msg_export_deq_imm")
        && pp.field("out_msg")
        && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
        && pp.field("reimport")
        && t_InMsg.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for OutMsg");
}

const OutMsg t_OutMsg;

//
// code for type `EnqueuedMsg`
//

int EnqueuedMsg::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool EnqueuedMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(64)
      && t_MsgEnvelope.validate_skip_ref(cs, weak);
}

bool EnqueuedMsg::unpack(vm::CellSlice& cs, EnqueuedMsg::Record& data) const {
  return cs.fetch_uint_to(64, data.enqueued_lt)
      && cs.fetch_ref_to(data.out_msg);
}

bool EnqueuedMsg::unpack_cons1(vm::CellSlice& cs, unsigned long long& enqueued_lt, Ref<Cell>& out_msg) const {
  return cs.fetch_uint_to(64, enqueued_lt)
      && cs.fetch_ref_to(out_msg);
}

bool EnqueuedMsg::cell_unpack(Ref<vm::Cell> cell_ref, EnqueuedMsg::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool EnqueuedMsg::cell_unpack_cons1(Ref<vm::Cell> cell_ref, unsigned long long& enqueued_lt, Ref<Cell>& out_msg) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, enqueued_lt, out_msg) && cs.empty_ext();
}

bool EnqueuedMsg::pack(vm::CellBuilder& cb, const EnqueuedMsg::Record& data) const {
  return cb.store_ulong_rchk_bool(data.enqueued_lt, 64)
      && cb.store_ref_bool(data.out_msg);
}

bool EnqueuedMsg::pack_cons1(vm::CellBuilder& cb, unsigned long long enqueued_lt, Ref<Cell> out_msg) const {
  return cb.store_ulong_rchk_bool(enqueued_lt, 64)
      && cb.store_ref_bool(out_msg);
}

bool EnqueuedMsg::cell_pack(Ref<vm::Cell>& cell_ref, const EnqueuedMsg::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool EnqueuedMsg::cell_pack_cons1(Ref<vm::Cell>& cell_ref, unsigned long long enqueued_lt, Ref<Cell> out_msg) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, enqueued_lt, std::move(out_msg)) && std::move(cb).finalize_to(cell_ref);
}

bool EnqueuedMsg::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.fetch_uint_field(cs, 64, "enqueued_lt")
      && pp.field("out_msg")
      && t_MsgEnvelope.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const EnqueuedMsg t_EnqueuedMsg;

//
// code for type `OutMsgDescr`
//

int OutMsgDescr::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool OutMsgDescr::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.skip(cs);
}

bool OutMsgDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.validate_skip(cs, weak);
}

bool OutMsgDescr::unpack(vm::CellSlice& cs, OutMsgDescr::Record& data) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.fetch_to(cs, data.x);
}

bool OutMsgDescr::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.fetch_to(cs, x);
}

bool OutMsgDescr::cell_unpack(Ref<vm::Cell> cell_ref, OutMsgDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsgDescr::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool OutMsgDescr::pack(vm::CellBuilder& cb, const OutMsgDescr::Record& data) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.store_from(cb, data.x);
}

bool OutMsgDescr::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_256_OutMsg_CurrencyCollection.store_from(cb, x);
}

bool OutMsgDescr::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsgDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgDescr::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_256_OutMsg_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const OutMsgDescr t_OutMsgDescr;

//
// code for type `OutMsgQueue`
//

int OutMsgQueue::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool OutMsgQueue::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.skip(cs);
}

bool OutMsgQueue::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.validate_skip(cs, weak);
}

bool OutMsgQueue::unpack(vm::CellSlice& cs, OutMsgQueue::Record& data) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.fetch_to(cs, data.x);
}

bool OutMsgQueue::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.fetch_to(cs, x);
}

bool OutMsgQueue::cell_unpack(Ref<vm::Cell> cell_ref, OutMsgQueue::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsgQueue::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool OutMsgQueue::pack(vm::CellBuilder& cb, const OutMsgQueue::Record& data) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.store_from(cb, data.x);
}

bool OutMsgQueue::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_352_EnqueuedMsg_uint64.store_from(cb, x);
}

bool OutMsgQueue::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsgQueue::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgQueue::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgQueue::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_352_EnqueuedMsg_uint64.print_skip(pp, cs)
      && pp.close();
}

const OutMsgQueue t_OutMsgQueue;

//
// code for type `ProcessedUpto`
//

int ProcessedUpto::check_tag(const vm::CellSlice& cs) const {
  return processed_upto;
}

bool ProcessedUpto::unpack(vm::CellSlice& cs, ProcessedUpto::Record& data) const {
  return cs.fetch_uint_to(64, data.last_msg_lt)
      && cs.fetch_bits_to(data.last_msg_hash.bits(), 256);
}

bool ProcessedUpto::unpack_processed_upto(vm::CellSlice& cs, unsigned long long& last_msg_lt, td::BitArray<256>& last_msg_hash) const {
  return cs.fetch_uint_to(64, last_msg_lt)
      && cs.fetch_bits_to(last_msg_hash.bits(), 256);
}

bool ProcessedUpto::cell_unpack(Ref<vm::Cell> cell_ref, ProcessedUpto::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ProcessedUpto::cell_unpack_processed_upto(Ref<vm::Cell> cell_ref, unsigned long long& last_msg_lt, td::BitArray<256>& last_msg_hash) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_processed_upto(cs, last_msg_lt, last_msg_hash) && cs.empty_ext();
}

bool ProcessedUpto::pack(vm::CellBuilder& cb, const ProcessedUpto::Record& data) const {
  return cb.store_ulong_rchk_bool(data.last_msg_lt, 64)
      && cb.store_bits_bool(data.last_msg_hash.cbits(), 256);
}

bool ProcessedUpto::pack_processed_upto(vm::CellBuilder& cb, unsigned long long last_msg_lt, td::BitArray<256> last_msg_hash) const {
  return cb.store_ulong_rchk_bool(last_msg_lt, 64)
      && cb.store_bits_bool(last_msg_hash.cbits(), 256);
}

bool ProcessedUpto::cell_pack(Ref<vm::Cell>& cell_ref, const ProcessedUpto::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ProcessedUpto::cell_pack_processed_upto(Ref<vm::Cell>& cell_ref, unsigned long long last_msg_lt, td::BitArray<256> last_msg_hash) const {
  vm::CellBuilder cb;
  return pack_processed_upto(cb, last_msg_lt, last_msg_hash) && std::move(cb).finalize_to(cell_ref);
}

bool ProcessedUpto::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("processed_upto")
      && pp.fetch_uint_field(cs, 64, "last_msg_lt")
      && pp.fetch_bits_field(cs, 256, "last_msg_hash")
      && pp.close();
}

const ProcessedUpto t_ProcessedUpto;

//
// code for type `ProcessedInfo`
//

int ProcessedInfo::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ProcessedInfo::skip(vm::CellSlice& cs) const {
  return t_HashmapE_96_ProcessedUpto.skip(cs);
}

bool ProcessedInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapE_96_ProcessedUpto.validate_skip(cs, weak);
}

bool ProcessedInfo::unpack(vm::CellSlice& cs, ProcessedInfo::Record& data) const {
  return t_HashmapE_96_ProcessedUpto.fetch_to(cs, data.x);
}

bool ProcessedInfo::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapE_96_ProcessedUpto.fetch_to(cs, x);
}

bool ProcessedInfo::cell_unpack(Ref<vm::Cell> cell_ref, ProcessedInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ProcessedInfo::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ProcessedInfo::pack(vm::CellBuilder& cb, const ProcessedInfo::Record& data) const {
  return t_HashmapE_96_ProcessedUpto.store_from(cb, data.x);
}

bool ProcessedInfo::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapE_96_ProcessedUpto.store_from(cb, x);
}

bool ProcessedInfo::cell_pack(Ref<vm::Cell>& cell_ref, const ProcessedInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ProcessedInfo::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ProcessedInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapE_96_ProcessedUpto.print_skip(pp, cs)
      && pp.close();
}

const ProcessedInfo t_ProcessedInfo;

//
// code for type `IhrPendingSince`
//

int IhrPendingSince::check_tag(const vm::CellSlice& cs) const {
  return ihr_pending;
}

bool IhrPendingSince::unpack(vm::CellSlice& cs, IhrPendingSince::Record& data) const {
  return cs.fetch_uint_to(64, data.import_lt);
}

bool IhrPendingSince::unpack_ihr_pending(vm::CellSlice& cs, unsigned long long& import_lt) const {
  return cs.fetch_uint_to(64, import_lt);
}

bool IhrPendingSince::cell_unpack(Ref<vm::Cell> cell_ref, IhrPendingSince::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool IhrPendingSince::cell_unpack_ihr_pending(Ref<vm::Cell> cell_ref, unsigned long long& import_lt) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ihr_pending(cs, import_lt) && cs.empty_ext();
}

bool IhrPendingSince::pack(vm::CellBuilder& cb, const IhrPendingSince::Record& data) const {
  return cb.store_ulong_rchk_bool(data.import_lt, 64);
}

bool IhrPendingSince::pack_ihr_pending(vm::CellBuilder& cb, unsigned long long import_lt) const {
  return cb.store_ulong_rchk_bool(import_lt, 64);
}

bool IhrPendingSince::cell_pack(Ref<vm::Cell>& cell_ref, const IhrPendingSince::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool IhrPendingSince::cell_pack_ihr_pending(Ref<vm::Cell>& cell_ref, unsigned long long import_lt) const {
  vm::CellBuilder cb;
  return pack_ihr_pending(cb, import_lt) && std::move(cb).finalize_to(cell_ref);
}

bool IhrPendingSince::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("ihr_pending")
      && pp.fetch_uint_field(cs, 64, "import_lt")
      && pp.close();
}

const IhrPendingSince t_IhrPendingSince;

//
// code for type `IhrPendingInfo`
//

int IhrPendingInfo::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool IhrPendingInfo::skip(vm::CellSlice& cs) const {
  return t_HashmapE_320_IhrPendingSince.skip(cs);
}

bool IhrPendingInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapE_320_IhrPendingSince.validate_skip(cs, weak);
}

bool IhrPendingInfo::unpack(vm::CellSlice& cs, IhrPendingInfo::Record& data) const {
  return t_HashmapE_320_IhrPendingSince.fetch_to(cs, data.x);
}

bool IhrPendingInfo::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapE_320_IhrPendingSince.fetch_to(cs, x);
}

bool IhrPendingInfo::cell_unpack(Ref<vm::Cell> cell_ref, IhrPendingInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool IhrPendingInfo::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool IhrPendingInfo::pack(vm::CellBuilder& cb, const IhrPendingInfo::Record& data) const {
  return t_HashmapE_320_IhrPendingSince.store_from(cb, data.x);
}

bool IhrPendingInfo::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapE_320_IhrPendingSince.store_from(cb, x);
}

bool IhrPendingInfo::cell_pack(Ref<vm::Cell>& cell_ref, const IhrPendingInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool IhrPendingInfo::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool IhrPendingInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapE_320_IhrPendingSince.print_skip(pp, cs)
      && pp.close();
}

const IhrPendingInfo t_IhrPendingInfo;

//
// code for type `OutMsgQueueInfo`
//

int OutMsgQueueInfo::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool OutMsgQueueInfo::skip(vm::CellSlice& cs) const {
  return t_OutMsgQueue.skip(cs)
      && t_ProcessedInfo.skip(cs)
      && t_IhrPendingInfo.skip(cs);
}

bool OutMsgQueueInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_OutMsgQueue.validate_skip(cs, weak)
      && t_ProcessedInfo.validate_skip(cs, weak)
      && t_IhrPendingInfo.validate_skip(cs, weak);
}

bool OutMsgQueueInfo::unpack(vm::CellSlice& cs, OutMsgQueueInfo::Record& data) const {
  return t_OutMsgQueue.fetch_to(cs, data.out_queue)
      && t_ProcessedInfo.fetch_to(cs, data.proc_info)
      && t_IhrPendingInfo.fetch_to(cs, data.ihr_pending);
}

bool OutMsgQueueInfo::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& out_queue, Ref<CellSlice>& proc_info, Ref<CellSlice>& ihr_pending) const {
  return t_OutMsgQueue.fetch_to(cs, out_queue)
      && t_ProcessedInfo.fetch_to(cs, proc_info)
      && t_IhrPendingInfo.fetch_to(cs, ihr_pending);
}

bool OutMsgQueueInfo::cell_unpack(Ref<vm::Cell> cell_ref, OutMsgQueueInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutMsgQueueInfo::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& out_queue, Ref<CellSlice>& proc_info, Ref<CellSlice>& ihr_pending) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, out_queue, proc_info, ihr_pending) && cs.empty_ext();
}

bool OutMsgQueueInfo::pack(vm::CellBuilder& cb, const OutMsgQueueInfo::Record& data) const {
  return t_OutMsgQueue.store_from(cb, data.out_queue)
      && t_ProcessedInfo.store_from(cb, data.proc_info)
      && t_IhrPendingInfo.store_from(cb, data.ihr_pending);
}

bool OutMsgQueueInfo::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> out_queue, Ref<CellSlice> proc_info, Ref<CellSlice> ihr_pending) const {
  return t_OutMsgQueue.store_from(cb, out_queue)
      && t_ProcessedInfo.store_from(cb, proc_info)
      && t_IhrPendingInfo.store_from(cb, ihr_pending);
}

bool OutMsgQueueInfo::cell_pack(Ref<vm::Cell>& cell_ref, const OutMsgQueueInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgQueueInfo::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> out_queue, Ref<CellSlice> proc_info, Ref<CellSlice> ihr_pending) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(out_queue), std::move(proc_info), std::move(ihr_pending)) && std::move(cb).finalize_to(cell_ref);
}

bool OutMsgQueueInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("out_queue")
      && t_OutMsgQueue.print_skip(pp, cs)
      && pp.field("proc_info")
      && t_ProcessedInfo.print_skip(pp, cs)
      && pp.field("ihr_pending")
      && t_IhrPendingInfo.print_skip(pp, cs)
      && pp.close();
}

const OutMsgQueueInfo t_OutMsgQueueInfo;

//
// code for type `StorageUsed`
//

int StorageUsed::check_tag(const vm::CellSlice& cs) const {
  return storage_used;
}

bool StorageUsed::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)
      && t_VarUInteger_7.skip(cs)
      && t_VarUInteger_7.skip(cs);
}

bool StorageUsed::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)
      && t_VarUInteger_7.validate_skip(cs, weak)
      && t_VarUInteger_7.validate_skip(cs, weak);
}

bool StorageUsed::unpack(vm::CellSlice& cs, StorageUsed::Record& data) const {
  return t_VarUInteger_7.fetch_to(cs, data.cells)
      && t_VarUInteger_7.fetch_to(cs, data.bits)
      && t_VarUInteger_7.fetch_to(cs, data.public_cells);
}

bool StorageUsed::unpack_storage_used(vm::CellSlice& cs, Ref<CellSlice>& cells, Ref<CellSlice>& bits, Ref<CellSlice>& public_cells) const {
  return t_VarUInteger_7.fetch_to(cs, cells)
      && t_VarUInteger_7.fetch_to(cs, bits)
      && t_VarUInteger_7.fetch_to(cs, public_cells);
}

bool StorageUsed::cell_unpack(Ref<vm::Cell> cell_ref, StorageUsed::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool StorageUsed::cell_unpack_storage_used(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cells, Ref<CellSlice>& bits, Ref<CellSlice>& public_cells) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_storage_used(cs, cells, bits, public_cells) && cs.empty_ext();
}

bool StorageUsed::pack(vm::CellBuilder& cb, const StorageUsed::Record& data) const {
  return t_VarUInteger_7.store_from(cb, data.cells)
      && t_VarUInteger_7.store_from(cb, data.bits)
      && t_VarUInteger_7.store_from(cb, data.public_cells);
}

bool StorageUsed::pack_storage_used(vm::CellBuilder& cb, Ref<CellSlice> cells, Ref<CellSlice> bits, Ref<CellSlice> public_cells) const {
  return t_VarUInteger_7.store_from(cb, cells)
      && t_VarUInteger_7.store_from(cb, bits)
      && t_VarUInteger_7.store_from(cb, public_cells);
}

bool StorageUsed::cell_pack(Ref<vm::Cell>& cell_ref, const StorageUsed::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool StorageUsed::cell_pack_storage_used(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cells, Ref<CellSlice> bits, Ref<CellSlice> public_cells) const {
  vm::CellBuilder cb;
  return pack_storage_used(cb, std::move(cells), std::move(bits), std::move(public_cells)) && std::move(cb).finalize_to(cell_ref);
}

bool StorageUsed::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("storage_used")
      && pp.field("cells")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.field("bits")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.field("public_cells")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.close();
}

const StorageUsed t_StorageUsed;

//
// code for type `StorageUsedShort`
//

int StorageUsedShort::check_tag(const vm::CellSlice& cs) const {
  return storage_used_short;
}

bool StorageUsedShort::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)
      && t_VarUInteger_7.skip(cs);
}

bool StorageUsedShort::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)
      && t_VarUInteger_7.validate_skip(cs, weak);
}

bool StorageUsedShort::unpack(vm::CellSlice& cs, StorageUsedShort::Record& data) const {
  return t_VarUInteger_7.fetch_to(cs, data.cells)
      && t_VarUInteger_7.fetch_to(cs, data.bits);
}

bool StorageUsedShort::unpack_storage_used_short(vm::CellSlice& cs, Ref<CellSlice>& cells, Ref<CellSlice>& bits) const {
  return t_VarUInteger_7.fetch_to(cs, cells)
      && t_VarUInteger_7.fetch_to(cs, bits);
}

bool StorageUsedShort::cell_unpack(Ref<vm::Cell> cell_ref, StorageUsedShort::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool StorageUsedShort::cell_unpack_storage_used_short(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cells, Ref<CellSlice>& bits) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_storage_used_short(cs, cells, bits) && cs.empty_ext();
}

bool StorageUsedShort::pack(vm::CellBuilder& cb, const StorageUsedShort::Record& data) const {
  return t_VarUInteger_7.store_from(cb, data.cells)
      && t_VarUInteger_7.store_from(cb, data.bits);
}

bool StorageUsedShort::pack_storage_used_short(vm::CellBuilder& cb, Ref<CellSlice> cells, Ref<CellSlice> bits) const {
  return t_VarUInteger_7.store_from(cb, cells)
      && t_VarUInteger_7.store_from(cb, bits);
}

bool StorageUsedShort::cell_pack(Ref<vm::Cell>& cell_ref, const StorageUsedShort::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool StorageUsedShort::cell_pack_storage_used_short(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cells, Ref<CellSlice> bits) const {
  vm::CellBuilder cb;
  return pack_storage_used_short(cb, std::move(cells), std::move(bits)) && std::move(cb).finalize_to(cell_ref);
}

bool StorageUsedShort::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("storage_used_short")
      && pp.field("cells")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.field("bits")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.close();
}

const StorageUsedShort t_StorageUsedShort;

//
// code for type `StorageInfo`
//

int StorageInfo::check_tag(const vm::CellSlice& cs) const {
  return storage_info;
}

bool StorageInfo::skip(vm::CellSlice& cs) const {
  return t_StorageUsed.skip(cs)
      && cs.advance(32)
      && t_Maybe_Grams.skip(cs);
}

bool StorageInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_StorageUsed.validate_skip(cs, weak)
      && cs.advance(32)
      && t_Maybe_Grams.validate_skip(cs, weak);
}

bool StorageInfo::unpack(vm::CellSlice& cs, StorageInfo::Record& data) const {
  return t_StorageUsed.fetch_to(cs, data.used)
      && cs.fetch_uint_to(32, data.last_paid)
      && t_Maybe_Grams.fetch_to(cs, data.due_payment);
}

bool StorageInfo::unpack_storage_info(vm::CellSlice& cs, Ref<CellSlice>& used, unsigned& last_paid, Ref<CellSlice>& due_payment) const {
  return t_StorageUsed.fetch_to(cs, used)
      && cs.fetch_uint_to(32, last_paid)
      && t_Maybe_Grams.fetch_to(cs, due_payment);
}

bool StorageInfo::cell_unpack(Ref<vm::Cell> cell_ref, StorageInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool StorageInfo::cell_unpack_storage_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& used, unsigned& last_paid, Ref<CellSlice>& due_payment) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_storage_info(cs, used, last_paid, due_payment) && cs.empty_ext();
}

bool StorageInfo::pack(vm::CellBuilder& cb, const StorageInfo::Record& data) const {
  return t_StorageUsed.store_from(cb, data.used)
      && cb.store_ulong_rchk_bool(data.last_paid, 32)
      && t_Maybe_Grams.store_from(cb, data.due_payment);
}

bool StorageInfo::pack_storage_info(vm::CellBuilder& cb, Ref<CellSlice> used, unsigned last_paid, Ref<CellSlice> due_payment) const {
  return t_StorageUsed.store_from(cb, used)
      && cb.store_ulong_rchk_bool(last_paid, 32)
      && t_Maybe_Grams.store_from(cb, due_payment);
}

bool StorageInfo::cell_pack(Ref<vm::Cell>& cell_ref, const StorageInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool StorageInfo::cell_pack_storage_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> used, unsigned last_paid, Ref<CellSlice> due_payment) const {
  vm::CellBuilder cb;
  return pack_storage_info(cb, std::move(used), last_paid, std::move(due_payment)) && std::move(cb).finalize_to(cell_ref);
}

bool StorageInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("storage_info")
      && pp.field("used")
      && t_StorageUsed.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "last_paid")
      && pp.field("due_payment")
      && t_Maybe_Grams.print_skip(pp, cs)
      && pp.close();
}

const StorageInfo t_StorageInfo;

//
// code for type `Account`
//

int Account::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_none:
    return cs.have(1) ? account_none : -1;
  case account:
    return cs.have(1) ? account : -1;
  }
  return -1;
}

bool Account::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_none:
    return cs.advance(1);
  case account:
    return cs.advance(1)
        && t_MsgAddressInt.skip(cs)
        && t_StorageInfo.skip(cs)
        && t_AccountStorage.skip(cs);
  }
  return false;
}

bool Account::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case account_none:
    return cs.advance(1);
  case account:
    return cs.advance(1)
        && t_MsgAddressInt.validate_skip(cs, weak)
        && t_StorageInfo.validate_skip(cs, weak)
        && t_AccountStorage.validate_skip(cs, weak);
  }
  return false;
}

bool Account::unpack(vm::CellSlice& cs, Account::Record_account_none& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool Account::unpack_account_none(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool Account::cell_unpack(Ref<vm::Cell> cell_ref, Account::Record_account_none& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Account::cell_unpack_account_none(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_none(cs) && cs.empty_ext();
}

bool Account::unpack(vm::CellSlice& cs, Account::Record_account& data) const {
  return cs.fetch_ulong(1) == 1
      && t_MsgAddressInt.fetch_to(cs, data.addr)
      && t_StorageInfo.fetch_to(cs, data.storage_stat)
      && t_AccountStorage.fetch_to(cs, data.storage);
}

bool Account::unpack_account(vm::CellSlice& cs, Ref<CellSlice>& addr, Ref<CellSlice>& storage_stat, Ref<CellSlice>& storage) const {
  return cs.fetch_ulong(1) == 1
      && t_MsgAddressInt.fetch_to(cs, addr)
      && t_StorageInfo.fetch_to(cs, storage_stat)
      && t_AccountStorage.fetch_to(cs, storage);
}

bool Account::cell_unpack(Ref<vm::Cell> cell_ref, Account::Record_account& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Account::cell_unpack_account(Ref<vm::Cell> cell_ref, Ref<CellSlice>& addr, Ref<CellSlice>& storage_stat, Ref<CellSlice>& storage) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account(cs, addr, storage_stat, storage) && cs.empty_ext();
}

bool Account::pack(vm::CellBuilder& cb, const Account::Record_account_none& data) const {
  return cb.store_long_bool(0, 1);
}

bool Account::pack_account_none(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool Account::cell_pack(Ref<vm::Cell>& cell_ref, const Account::Record_account_none& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Account::cell_pack_account_none(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_account_none(cb) && std::move(cb).finalize_to(cell_ref);
}

bool Account::pack(vm::CellBuilder& cb, const Account::Record_account& data) const {
  return cb.store_long_bool(1, 1)
      && t_MsgAddressInt.store_from(cb, data.addr)
      && t_StorageInfo.store_from(cb, data.storage_stat)
      && t_AccountStorage.store_from(cb, data.storage);
}

bool Account::pack_account(vm::CellBuilder& cb, Ref<CellSlice> addr, Ref<CellSlice> storage_stat, Ref<CellSlice> storage) const {
  return cb.store_long_bool(1, 1)
      && t_MsgAddressInt.store_from(cb, addr)
      && t_StorageInfo.store_from(cb, storage_stat)
      && t_AccountStorage.store_from(cb, storage);
}

bool Account::cell_pack(Ref<vm::Cell>& cell_ref, const Account::Record_account& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Account::cell_pack_account(Ref<vm::Cell>& cell_ref, Ref<CellSlice> addr, Ref<CellSlice> storage_stat, Ref<CellSlice> storage) const {
  vm::CellBuilder cb;
  return pack_account(cb, std::move(addr), std::move(storage_stat), std::move(storage)) && std::move(cb).finalize_to(cell_ref);
}

bool Account::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_none:
    return cs.advance(1)
        && pp.cons("account_none");
  case account:
    return cs.advance(1)
        && pp.open("account")
        && pp.field("addr")
        && t_MsgAddressInt.print_skip(pp, cs)
        && pp.field("storage_stat")
        && t_StorageInfo.print_skip(pp, cs)
        && pp.field("storage")
        && t_AccountStorage.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for Account");
}

const Account t_Account;

//
// code for type `AccountStorage`
//

int AccountStorage::check_tag(const vm::CellSlice& cs) const {
  return account_storage;
}

bool AccountStorage::skip(vm::CellSlice& cs) const {
  return cs.advance(64)
      && t_CurrencyCollection.skip(cs)
      && t_AccountState.skip(cs);
}

bool AccountStorage::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(64)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_AccountState.validate_skip(cs, weak);
}

bool AccountStorage::unpack(vm::CellSlice& cs, AccountStorage::Record& data) const {
  return cs.fetch_uint_to(64, data.last_trans_lt)
      && t_CurrencyCollection.fetch_to(cs, data.balance)
      && t_AccountState.fetch_to(cs, data.state);
}

bool AccountStorage::unpack_account_storage(vm::CellSlice& cs, unsigned long long& last_trans_lt, Ref<CellSlice>& balance, Ref<CellSlice>& state) const {
  return cs.fetch_uint_to(64, last_trans_lt)
      && t_CurrencyCollection.fetch_to(cs, balance)
      && t_AccountState.fetch_to(cs, state);
}

bool AccountStorage::cell_unpack(Ref<vm::Cell> cell_ref, AccountStorage::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountStorage::cell_unpack_account_storage(Ref<vm::Cell> cell_ref, unsigned long long& last_trans_lt, Ref<CellSlice>& balance, Ref<CellSlice>& state) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_storage(cs, last_trans_lt, balance, state) && cs.empty_ext();
}

bool AccountStorage::pack(vm::CellBuilder& cb, const AccountStorage::Record& data) const {
  return cb.store_ulong_rchk_bool(data.last_trans_lt, 64)
      && t_CurrencyCollection.store_from(cb, data.balance)
      && t_AccountState.store_from(cb, data.state);
}

bool AccountStorage::pack_account_storage(vm::CellBuilder& cb, unsigned long long last_trans_lt, Ref<CellSlice> balance, Ref<CellSlice> state) const {
  return cb.store_ulong_rchk_bool(last_trans_lt, 64)
      && t_CurrencyCollection.store_from(cb, balance)
      && t_AccountState.store_from(cb, state);
}

bool AccountStorage::cell_pack(Ref<vm::Cell>& cell_ref, const AccountStorage::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStorage::cell_pack_account_storage(Ref<vm::Cell>& cell_ref, unsigned long long last_trans_lt, Ref<CellSlice> balance, Ref<CellSlice> state) const {
  vm::CellBuilder cb;
  return pack_account_storage(cb, last_trans_lt, std::move(balance), std::move(state)) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStorage::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("account_storage")
      && pp.fetch_uint_field(cs, 64, "last_trans_lt")
      && pp.field("balance")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("state")
      && t_AccountState.print_skip(pp, cs)
      && pp.close();
}

const AccountStorage t_AccountStorage;

//
// code for type `AccountState`
//
constexpr char AccountState::cons_len[3];
constexpr unsigned char AccountState::cons_tag[3];

int AccountState::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_uninit:
    return cs.have(2) ? account_uninit : -1;
  case account_active:
    return cs.have(1) ? account_active : -1;
  case account_frozen:
    return cs.have(2) ? account_frozen : -1;
  }
  return -1;
}

bool AccountState::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_uninit:
    return cs.advance(2);
  case account_active:
    return cs.advance(1)
        && t_StateInit.skip(cs);
  case account_frozen:
    return cs.advance(258);
  }
  return false;
}

bool AccountState::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case account_uninit:
    return cs.advance(2);
  case account_active:
    return cs.advance(1)
        && t_StateInit.validate_skip(cs, weak);
  case account_frozen:
    return cs.advance(258);
  }
  return false;
}

bool AccountState::unpack(vm::CellSlice& cs, AccountState::Record_account_uninit& data) const {
  return cs.fetch_ulong(2) == 0;
}

bool AccountState::unpack_account_uninit(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0;
}

bool AccountState::cell_unpack(Ref<vm::Cell> cell_ref, AccountState::Record_account_uninit& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountState::cell_unpack_account_uninit(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_uninit(cs) && cs.empty_ext();
}

bool AccountState::unpack(vm::CellSlice& cs, AccountState::Record_account_active& data) const {
  return cs.fetch_ulong(1) == 1
      && t_StateInit.fetch_to(cs, data.x);
}

bool AccountState::unpack_account_active(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_ulong(1) == 1
      && t_StateInit.fetch_to(cs, x);
}

bool AccountState::cell_unpack(Ref<vm::Cell> cell_ref, AccountState::Record_account_active& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountState::cell_unpack_account_active(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_active(cs, x) && cs.empty_ext();
}

bool AccountState::unpack(vm::CellSlice& cs, AccountState::Record_account_frozen& data) const {
  return cs.fetch_ulong(2) == 1
      && cs.fetch_bits_to(data.state_hash.bits(), 256);
}

bool AccountState::unpack_account_frozen(vm::CellSlice& cs, td::BitArray<256>& state_hash) const {
  return cs.fetch_ulong(2) == 1
      && cs.fetch_bits_to(state_hash.bits(), 256);
}

bool AccountState::cell_unpack(Ref<vm::Cell> cell_ref, AccountState::Record_account_frozen& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountState::cell_unpack_account_frozen(Ref<vm::Cell> cell_ref, td::BitArray<256>& state_hash) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_frozen(cs, state_hash) && cs.empty_ext();
}

bool AccountState::pack(vm::CellBuilder& cb, const AccountState::Record_account_uninit& data) const {
  return cb.store_long_bool(0, 2);
}

bool AccountState::pack_account_uninit(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 2);
}

bool AccountState::cell_pack(Ref<vm::Cell>& cell_ref, const AccountState::Record_account_uninit& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::cell_pack_account_uninit(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_account_uninit(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::pack(vm::CellBuilder& cb, const AccountState::Record_account_active& data) const {
  return cb.store_long_bool(1, 1)
      && t_StateInit.store_from(cb, data.x);
}

bool AccountState::pack_account_active(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.store_long_bool(1, 1)
      && t_StateInit.store_from(cb, x);
}

bool AccountState::cell_pack(Ref<vm::Cell>& cell_ref, const AccountState::Record_account_active& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::cell_pack_account_active(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_account_active(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::pack(vm::CellBuilder& cb, const AccountState::Record_account_frozen& data) const {
  return cb.store_long_bool(1, 2)
      && cb.store_bits_bool(data.state_hash.cbits(), 256);
}

bool AccountState::pack_account_frozen(vm::CellBuilder& cb, td::BitArray<256> state_hash) const {
  return cb.store_long_bool(1, 2)
      && cb.store_bits_bool(state_hash.cbits(), 256);
}

bool AccountState::cell_pack(Ref<vm::Cell>& cell_ref, const AccountState::Record_account_frozen& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::cell_pack_account_frozen(Ref<vm::Cell>& cell_ref, td::BitArray<256> state_hash) const {
  vm::CellBuilder cb;
  return pack_account_frozen(cb, state_hash) && std::move(cb).finalize_to(cell_ref);
}

bool AccountState::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case account_uninit:
    return cs.advance(2)
        && pp.cons("account_uninit");
  case account_active:
    return cs.advance(1)
        && pp.open("account_active")
        && pp.field()
        && t_StateInit.print_skip(pp, cs)
        && pp.close();
  case account_frozen:
    return cs.advance(2)
        && pp.open("account_frozen")
        && pp.fetch_bits_field(cs, 256, "state_hash")
        && pp.close();
  }
  return pp.fail("unknown constructor for AccountState");
}

const AccountState t_AccountState;

//
// code for type `AccountStatus`
//

int AccountStatus::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case acc_state_uninit:
    return cs.have(2) ? acc_state_uninit : -1;
  case acc_state_frozen:
    return cs.have(2) ? acc_state_frozen : -1;
  case acc_state_active:
    return cs.have(2) ? acc_state_active : -1;
  case acc_state_nonexist:
    return cs.have(2) ? acc_state_nonexist : -1;
  }
  return -1;
}

bool AccountStatus::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  value = (char)cs.fetch_ulong(2);
  return value >= 0;
}

bool AccountStatus::store_enum_from(vm::CellBuilder& cb, int value) const {
  return cb.store_long_rchk_bool(value, 2);
}

bool AccountStatus::unpack(vm::CellSlice& cs, AccountStatus::Record_acc_state_uninit& data) const {
  return cs.fetch_ulong(2) == 0;
}

bool AccountStatus::unpack_acc_state_uninit(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0;
}

bool AccountStatus::cell_unpack(Ref<vm::Cell> cell_ref, AccountStatus::Record_acc_state_uninit& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountStatus::cell_unpack_acc_state_uninit(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acc_state_uninit(cs) && cs.empty_ext();
}

bool AccountStatus::unpack(vm::CellSlice& cs, AccountStatus::Record_acc_state_frozen& data) const {
  return cs.fetch_ulong(2) == 1;
}

bool AccountStatus::unpack_acc_state_frozen(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 1;
}

bool AccountStatus::cell_unpack(Ref<vm::Cell> cell_ref, AccountStatus::Record_acc_state_frozen& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountStatus::cell_unpack_acc_state_frozen(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acc_state_frozen(cs) && cs.empty_ext();
}

bool AccountStatus::unpack(vm::CellSlice& cs, AccountStatus::Record_acc_state_active& data) const {
  return cs.fetch_ulong(2) == 2;
}

bool AccountStatus::unpack_acc_state_active(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 2;
}

bool AccountStatus::cell_unpack(Ref<vm::Cell> cell_ref, AccountStatus::Record_acc_state_active& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountStatus::cell_unpack_acc_state_active(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acc_state_active(cs) && cs.empty_ext();
}

bool AccountStatus::unpack(vm::CellSlice& cs, AccountStatus::Record_acc_state_nonexist& data) const {
  return cs.fetch_ulong(2) == 3;
}

bool AccountStatus::unpack_acc_state_nonexist(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 3;
}

bool AccountStatus::cell_unpack(Ref<vm::Cell> cell_ref, AccountStatus::Record_acc_state_nonexist& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountStatus::cell_unpack_acc_state_nonexist(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acc_state_nonexist(cs) && cs.empty_ext();
}

bool AccountStatus::pack(vm::CellBuilder& cb, const AccountStatus::Record_acc_state_uninit& data) const {
  return cb.store_long_bool(0, 2);
}

bool AccountStatus::pack_acc_state_uninit(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 2);
}

bool AccountStatus::cell_pack(Ref<vm::Cell>& cell_ref, const AccountStatus::Record_acc_state_uninit& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::cell_pack_acc_state_uninit(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acc_state_uninit(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::pack(vm::CellBuilder& cb, const AccountStatus::Record_acc_state_frozen& data) const {
  return cb.store_long_bool(1, 2);
}

bool AccountStatus::pack_acc_state_frozen(vm::CellBuilder& cb) const {
  return cb.store_long_bool(1, 2);
}

bool AccountStatus::cell_pack(Ref<vm::Cell>& cell_ref, const AccountStatus::Record_acc_state_frozen& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::cell_pack_acc_state_frozen(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acc_state_frozen(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::pack(vm::CellBuilder& cb, const AccountStatus::Record_acc_state_active& data) const {
  return cb.store_long_bool(2, 2);
}

bool AccountStatus::pack_acc_state_active(vm::CellBuilder& cb) const {
  return cb.store_long_bool(2, 2);
}

bool AccountStatus::cell_pack(Ref<vm::Cell>& cell_ref, const AccountStatus::Record_acc_state_active& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::cell_pack_acc_state_active(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acc_state_active(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::pack(vm::CellBuilder& cb, const AccountStatus::Record_acc_state_nonexist& data) const {
  return cb.store_long_bool(3, 2);
}

bool AccountStatus::pack_acc_state_nonexist(vm::CellBuilder& cb) const {
  return cb.store_long_bool(3, 2);
}

bool AccountStatus::cell_pack(Ref<vm::Cell>& cell_ref, const AccountStatus::Record_acc_state_nonexist& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::cell_pack_acc_state_nonexist(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acc_state_nonexist(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccountStatus::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case acc_state_uninit:
    return cs.advance(2)
        && pp.cons("acc_state_uninit");
  case acc_state_frozen:
    return cs.advance(2)
        && pp.cons("acc_state_frozen");
  case acc_state_active:
    return cs.advance(2)
        && pp.cons("acc_state_active");
  case acc_state_nonexist:
    return cs.advance(2)
        && pp.cons("acc_state_nonexist");
  }
  return pp.fail("unknown constructor for AccountStatus");
}

const AccountStatus t_AccountStatus;

//
// code for type `ShardAccount`
//

int ShardAccount::check_tag(const vm::CellSlice& cs) const {
  return account_descr;
}

bool ShardAccount::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Account.validate_skip_ref(cs, weak)
      && cs.advance(320);
}

bool ShardAccount::unpack(vm::CellSlice& cs, ShardAccount::Record& data) const {
  return cs.fetch_ref_to(data.account)
      && cs.fetch_bits_to(data.last_trans_hash.bits(), 256)
      && cs.fetch_uint_to(64, data.last_trans_lt);
}

bool ShardAccount::unpack_account_descr(vm::CellSlice& cs, Ref<Cell>& account, td::BitArray<256>& last_trans_hash, unsigned long long& last_trans_lt) const {
  return cs.fetch_ref_to(account)
      && cs.fetch_bits_to(last_trans_hash.bits(), 256)
      && cs.fetch_uint_to(64, last_trans_lt);
}

bool ShardAccount::cell_unpack(Ref<vm::Cell> cell_ref, ShardAccount::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardAccount::cell_unpack_account_descr(Ref<vm::Cell> cell_ref, Ref<Cell>& account, td::BitArray<256>& last_trans_hash, unsigned long long& last_trans_lt) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_account_descr(cs, account, last_trans_hash, last_trans_lt) && cs.empty_ext();
}

bool ShardAccount::pack(vm::CellBuilder& cb, const ShardAccount::Record& data) const {
  return cb.store_ref_bool(data.account)
      && cb.store_bits_bool(data.last_trans_hash.cbits(), 256)
      && cb.store_ulong_rchk_bool(data.last_trans_lt, 64);
}

bool ShardAccount::pack_account_descr(vm::CellBuilder& cb, Ref<Cell> account, td::BitArray<256> last_trans_hash, unsigned long long last_trans_lt) const {
  return cb.store_ref_bool(account)
      && cb.store_bits_bool(last_trans_hash.cbits(), 256)
      && cb.store_ulong_rchk_bool(last_trans_lt, 64);
}

bool ShardAccount::cell_pack(Ref<vm::Cell>& cell_ref, const ShardAccount::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccount::cell_pack_account_descr(Ref<vm::Cell>& cell_ref, Ref<Cell> account, td::BitArray<256> last_trans_hash, unsigned long long last_trans_lt) const {
  vm::CellBuilder cb;
  return pack_account_descr(cb, std::move(account), last_trans_hash, last_trans_lt) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccount::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("account_descr")
      && pp.field("account")
      && t_Account.print_ref(pp, cs.fetch_ref())
      && pp.fetch_bits_field(cs, 256, "last_trans_hash")
      && pp.fetch_uint_field(cs, 64, "last_trans_lt")
      && pp.close();
}

const ShardAccount t_ShardAccount;

//
// code for type `DepthBalanceInfo`
//

int DepthBalanceInfo::check_tag(const vm::CellSlice& cs) const {
  return depth_balance;
}

bool DepthBalanceInfo::skip(vm::CellSlice& cs) const {
  return cs.advance(5)
      && t_CurrencyCollection.skip(cs);
}

bool DepthBalanceInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  int split_depth;
  return cs.fetch_uint_leq(30, split_depth)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool DepthBalanceInfo::unpack(vm::CellSlice& cs, DepthBalanceInfo::Record& data) const {
  return cs.fetch_uint_leq(30, data.split_depth)
      && t_CurrencyCollection.fetch_to(cs, data.balance);
}

bool DepthBalanceInfo::unpack_depth_balance(vm::CellSlice& cs, int& split_depth, Ref<CellSlice>& balance) const {
  return cs.fetch_uint_leq(30, split_depth)
      && t_CurrencyCollection.fetch_to(cs, balance);
}

bool DepthBalanceInfo::cell_unpack(Ref<vm::Cell> cell_ref, DepthBalanceInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool DepthBalanceInfo::cell_unpack_depth_balance(Ref<vm::Cell> cell_ref, int& split_depth, Ref<CellSlice>& balance) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_depth_balance(cs, split_depth, balance) && cs.empty_ext();
}

bool DepthBalanceInfo::pack(vm::CellBuilder& cb, const DepthBalanceInfo::Record& data) const {
  return cb.store_uint_leq(30, data.split_depth)
      && t_CurrencyCollection.store_from(cb, data.balance);
}

bool DepthBalanceInfo::pack_depth_balance(vm::CellBuilder& cb, int split_depth, Ref<CellSlice> balance) const {
  return cb.store_uint_leq(30, split_depth)
      && t_CurrencyCollection.store_from(cb, balance);
}

bool DepthBalanceInfo::cell_pack(Ref<vm::Cell>& cell_ref, const DepthBalanceInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool DepthBalanceInfo::cell_pack_depth_balance(Ref<vm::Cell>& cell_ref, int split_depth, Ref<CellSlice> balance) const {
  vm::CellBuilder cb;
  return pack_depth_balance(cb, split_depth, std::move(balance)) && std::move(cb).finalize_to(cell_ref);
}

bool DepthBalanceInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int split_depth;
  return pp.open("depth_balance")
      && cs.fetch_uint_leq(30, split_depth)
      && pp.field_int(split_depth, "split_depth")
      && pp.field("balance")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const DepthBalanceInfo t_DepthBalanceInfo;

//
// code for type `ShardAccounts`
//

int ShardAccounts::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardAccounts::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.skip(cs);
}

bool ShardAccounts::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.validate_skip(cs, weak);
}

bool ShardAccounts::unpack(vm::CellSlice& cs, ShardAccounts::Record& data) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.fetch_to(cs, data.x);
}

bool ShardAccounts::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.fetch_to(cs, x);
}

bool ShardAccounts::cell_unpack(Ref<vm::Cell> cell_ref, ShardAccounts::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardAccounts::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ShardAccounts::pack(vm::CellBuilder& cb, const ShardAccounts::Record& data) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.store_from(cb, data.x);
}

bool ShardAccounts::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.store_from(cb, x);
}

bool ShardAccounts::cell_pack(Ref<vm::Cell>& cell_ref, const ShardAccounts::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccounts::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccounts::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_256_ShardAccount_DepthBalanceInfo.print_skip(pp, cs)
      && pp.close();
}

const ShardAccounts t_ShardAccounts;

//
// code for auxiliary type `Transaction_aux`
//

int Transaction_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool Transaction_aux::skip(vm::CellSlice& cs) const {
  return t_Maybe_Ref_Message_Any.skip(cs)
      && t_HashmapE_15_Ref_Message_Any.skip(cs);
}

bool Transaction_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Maybe_Ref_Message_Any.validate_skip(cs, weak)
      && t_HashmapE_15_Ref_Message_Any.validate_skip(cs, weak);
}

bool Transaction_aux::unpack(vm::CellSlice& cs, Transaction_aux::Record& data) const {
  return t_Maybe_Ref_Message_Any.fetch_to(cs, data.in_msg)
      && t_HashmapE_15_Ref_Message_Any.fetch_to(cs, data.out_msgs);
}

bool Transaction_aux::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& in_msg, Ref<CellSlice>& out_msgs) const {
  return t_Maybe_Ref_Message_Any.fetch_to(cs, in_msg)
      && t_HashmapE_15_Ref_Message_Any.fetch_to(cs, out_msgs);
}

bool Transaction_aux::cell_unpack(Ref<vm::Cell> cell_ref, Transaction_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Transaction_aux::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& in_msg, Ref<CellSlice>& out_msgs) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, in_msg, out_msgs) && cs.empty_ext();
}

bool Transaction_aux::pack(vm::CellBuilder& cb, const Transaction_aux::Record& data) const {
  return t_Maybe_Ref_Message_Any.store_from(cb, data.in_msg)
      && t_HashmapE_15_Ref_Message_Any.store_from(cb, data.out_msgs);
}

bool Transaction_aux::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> in_msg, Ref<CellSlice> out_msgs) const {
  return t_Maybe_Ref_Message_Any.store_from(cb, in_msg)
      && t_HashmapE_15_Ref_Message_Any.store_from(cb, out_msgs);
}

bool Transaction_aux::cell_pack(Ref<vm::Cell>& cell_ref, const Transaction_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Transaction_aux::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> in_msg, Ref<CellSlice> out_msgs) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(in_msg), std::move(out_msgs)) && std::move(cb).finalize_to(cell_ref);
}

bool Transaction_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("in_msg")
      && t_Maybe_Ref_Message_Any.print_skip(pp, cs)
      && pp.field("out_msgs")
      && t_HashmapE_15_Ref_Message_Any.print_skip(pp, cs)
      && pp.close();
}

const Transaction_aux t_Transaction_aux;

//
// code for type `Transaction`
//
constexpr unsigned char Transaction::cons_tag[1];

int Transaction::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 7 ? transaction : -1;
}

bool Transaction::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x102b7)
      && t_CurrencyCollection.skip(cs)
      && cs.advance_refs(2);
}

bool Transaction::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 7
      && cs.advance(691)
      && t_Transaction_aux.validate_skip_ref(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_HASH_UPDATE_Account.validate_skip_ref(cs, weak)
      && t_TransactionDescr.validate_skip_ref(cs, weak);
}

bool Transaction::unpack(vm::CellSlice& cs, Transaction::Record& data) const {
  return cs.fetch_ulong(4) == 7
      && cs.fetch_bits_to(data.account_addr.bits(), 256)
      && cs.fetch_uint_to(64, data.lt)
      && cs.fetch_bits_to(data.prev_trans_hash.bits(), 256)
      && cs.fetch_uint_to(64, data.prev_trans_lt)
      && cs.fetch_uint_to(32, data.now)
      && cs.fetch_uint_to(15, data.outmsg_cnt)
      && t_AccountStatus.fetch_enum_to(cs, data.orig_status)
      && t_AccountStatus.fetch_enum_to(cs, data.end_status)
      && t_Transaction_aux.cell_unpack(cs.fetch_ref(), data.r1)
      && t_CurrencyCollection.fetch_to(cs, data.total_fees)
      && cs.fetch_ref_to(data.state_update)
      && cs.fetch_ref_to(data.description);
}

bool Transaction::cell_unpack(Ref<vm::Cell> cell_ref, Transaction::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Transaction::pack(vm::CellBuilder& cb, const Transaction::Record& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(7, 4)
      && cb.store_bits_bool(data.account_addr.cbits(), 256)
      && cb.store_ulong_rchk_bool(data.lt, 64)
      && cb.store_bits_bool(data.prev_trans_hash.cbits(), 256)
      && cb.store_ulong_rchk_bool(data.prev_trans_lt, 64)
      && cb.store_ulong_rchk_bool(data.now, 32)
      && cb.store_ulong_rchk_bool(data.outmsg_cnt, 15)
      && t_AccountStatus.store_enum_from(cb, data.orig_status)
      && t_AccountStatus.store_enum_from(cb, data.end_status)
      && t_Transaction_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell))
      && t_CurrencyCollection.store_from(cb, data.total_fees)
      && cb.store_ref_bool(data.state_update)
      && cb.store_ref_bool(data.description);
}

bool Transaction::cell_pack(Ref<vm::Cell>& cell_ref, const Transaction::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Transaction::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 7
      && pp.open("transaction")
      && pp.fetch_bits_field(cs, 256, "account_addr")
      && pp.fetch_uint_field(cs, 64, "lt")
      && pp.fetch_bits_field(cs, 256, "prev_trans_hash")
      && pp.fetch_uint_field(cs, 64, "prev_trans_lt")
      && pp.fetch_uint_field(cs, 32, "now")
      && pp.fetch_uint_field(cs, 15, "outmsg_cnt")
      && pp.field("orig_status")
      && t_AccountStatus.print_skip(pp, cs)
      && pp.field("end_status")
      && t_AccountStatus.print_skip(pp, cs)
      && pp.field()
      && t_Transaction_aux.print_ref(pp, cs.fetch_ref())
      && pp.field("total_fees")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("state_update")
      && t_HASH_UPDATE_Account.print_ref(pp, cs.fetch_ref())
      && pp.field("description")
      && t_TransactionDescr.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const Transaction t_Transaction;

//
// code for type `MERKLE_UPDATE`
//
constexpr unsigned char MERKLE_UPDATE::cons_tag[1];

int MERKLE_UPDATE::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 2 ? _merkle_update : -1;
}

bool MERKLE_UPDATE::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 2
      && cs.advance(512)
      && X_.validate_skip_ref(cs, weak)
      && X_.validate_skip_ref(cs, weak);
}

bool MERKLE_UPDATE::unpack(vm::CellSlice& cs, MERKLE_UPDATE::Record& data) const {
  return cs.fetch_ulong(8) == 2
      && cs.fetch_bits_to(data.old_hash.bits(), 256)
      && cs.fetch_bits_to(data.new_hash.bits(), 256)
      && cs.fetch_ref_to(data.old)
      && cs.fetch_ref_to(data.new1);
}

bool MERKLE_UPDATE::cell_unpack(Ref<vm::Cell> cell_ref, MERKLE_UPDATE::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MERKLE_UPDATE::pack(vm::CellBuilder& cb, const MERKLE_UPDATE::Record& data) const {
  return cb.store_long_bool(2, 8)
      && cb.store_bits_bool(data.old_hash.cbits(), 256)
      && cb.store_bits_bool(data.new_hash.cbits(), 256)
      && cb.store_ref_bool(data.old)
      && cb.store_ref_bool(data.new1);
}

bool MERKLE_UPDATE::cell_pack(Ref<vm::Cell>& cell_ref, const MERKLE_UPDATE::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MERKLE_UPDATE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 2
      && pp.open("!merkle_update")
      && pp.fetch_bits_field(cs, 256, "old_hash")
      && pp.fetch_bits_field(cs, 256, "new_hash")
      && pp.field("old")
      && X_.print_ref(pp, cs.fetch_ref())
      && pp.field("new")
      && X_.print_ref(pp, cs.fetch_ref())
      && pp.close();
}


//
// code for type `HASH_UPDATE`
//
constexpr unsigned char HASH_UPDATE::cons_tag[1];

int HASH_UPDATE::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0x72 ? update_hashes : -1;
}

bool HASH_UPDATE::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0x72
      && cs.advance(512);
}

bool HASH_UPDATE::unpack(vm::CellSlice& cs, HASH_UPDATE::Record& data) const {
  return cs.fetch_ulong(8) == 0x72
      && cs.fetch_bits_to(data.old_hash.bits(), 256)
      && cs.fetch_bits_to(data.new_hash.bits(), 256);
}

bool HASH_UPDATE::unpack_update_hashes(vm::CellSlice& cs, td::BitArray<256>& old_hash, td::BitArray<256>& new_hash) const {
  return cs.fetch_ulong(8) == 0x72
      && cs.fetch_bits_to(old_hash.bits(), 256)
      && cs.fetch_bits_to(new_hash.bits(), 256);
}

bool HASH_UPDATE::cell_unpack(Ref<vm::Cell> cell_ref, HASH_UPDATE::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool HASH_UPDATE::cell_unpack_update_hashes(Ref<vm::Cell> cell_ref, td::BitArray<256>& old_hash, td::BitArray<256>& new_hash) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_update_hashes(cs, old_hash, new_hash) && cs.empty_ext();
}

bool HASH_UPDATE::pack(vm::CellBuilder& cb, const HASH_UPDATE::Record& data) const {
  return cb.store_long_bool(0x72, 8)
      && cb.store_bits_bool(data.old_hash.cbits(), 256)
      && cb.store_bits_bool(data.new_hash.cbits(), 256);
}

bool HASH_UPDATE::pack_update_hashes(vm::CellBuilder& cb, td::BitArray<256> old_hash, td::BitArray<256> new_hash) const {
  return cb.store_long_bool(0x72, 8)
      && cb.store_bits_bool(old_hash.cbits(), 256)
      && cb.store_bits_bool(new_hash.cbits(), 256);
}

bool HASH_UPDATE::cell_pack(Ref<vm::Cell>& cell_ref, const HASH_UPDATE::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool HASH_UPDATE::cell_pack_update_hashes(Ref<vm::Cell>& cell_ref, td::BitArray<256> old_hash, td::BitArray<256> new_hash) const {
  vm::CellBuilder cb;
  return pack_update_hashes(cb, old_hash, new_hash) && std::move(cb).finalize_to(cell_ref);
}

bool HASH_UPDATE::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0x72
      && pp.open("update_hashes")
      && pp.fetch_bits_field(cs, 256, "old_hash")
      && pp.fetch_bits_field(cs, 256, "new_hash")
      && pp.close();
}


//
// code for type `AccountBlock`
//
constexpr unsigned char AccountBlock::cons_tag[1];

int AccountBlock::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 5 ? acc_trans : -1;
}

bool AccountBlock::skip(vm::CellSlice& cs) const {
  return cs.advance(260)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.skip(cs)
      && cs.advance_refs(1);
}

bool AccountBlock::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 5
      && cs.advance(256)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.validate_skip(cs, weak)
      && t_HASH_UPDATE_Account.validate_skip_ref(cs, weak);
}

bool AccountBlock::unpack(vm::CellSlice& cs, AccountBlock::Record& data) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_bits_to(data.account_addr.bits(), 256)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.fetch_to(cs, data.transactions)
      && cs.fetch_ref_to(data.state_update);
}

bool AccountBlock::unpack_acc_trans(vm::CellSlice& cs, td::BitArray<256>& account_addr, Ref<CellSlice>& transactions, Ref<Cell>& state_update) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_bits_to(account_addr.bits(), 256)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.fetch_to(cs, transactions)
      && cs.fetch_ref_to(state_update);
}

bool AccountBlock::cell_unpack(Ref<vm::Cell> cell_ref, AccountBlock::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccountBlock::cell_unpack_acc_trans(Ref<vm::Cell> cell_ref, td::BitArray<256>& account_addr, Ref<CellSlice>& transactions, Ref<Cell>& state_update) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acc_trans(cs, account_addr, transactions, state_update) && cs.empty_ext();
}

bool AccountBlock::pack(vm::CellBuilder& cb, const AccountBlock::Record& data) const {
  return cb.store_long_bool(5, 4)
      && cb.store_bits_bool(data.account_addr.cbits(), 256)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.store_from(cb, data.transactions)
      && cb.store_ref_bool(data.state_update);
}

bool AccountBlock::pack_acc_trans(vm::CellBuilder& cb, td::BitArray<256> account_addr, Ref<CellSlice> transactions, Ref<Cell> state_update) const {
  return cb.store_long_bool(5, 4)
      && cb.store_bits_bool(account_addr.cbits(), 256)
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.store_from(cb, transactions)
      && cb.store_ref_bool(state_update);
}

bool AccountBlock::cell_pack(Ref<vm::Cell>& cell_ref, const AccountBlock::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccountBlock::cell_pack_acc_trans(Ref<vm::Cell>& cell_ref, td::BitArray<256> account_addr, Ref<CellSlice> transactions, Ref<Cell> state_update) const {
  vm::CellBuilder cb;
  return pack_acc_trans(cb, account_addr, std::move(transactions), std::move(state_update)) && std::move(cb).finalize_to(cell_ref);
}

bool AccountBlock::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 5
      && pp.open("acc_trans")
      && pp.fetch_bits_field(cs, 256, "account_addr")
      && pp.field("transactions")
      && t_HashmapAug_64_Ref_Transaction_CurrencyCollection.print_skip(pp, cs)
      && pp.field("state_update")
      && t_HASH_UPDATE_Account.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const AccountBlock t_AccountBlock;

//
// code for type `ShardAccountBlocks`
//

int ShardAccountBlocks::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardAccountBlocks::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.skip(cs);
}

bool ShardAccountBlocks::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.validate_skip(cs, weak);
}

bool ShardAccountBlocks::unpack(vm::CellSlice& cs, ShardAccountBlocks::Record& data) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.fetch_to(cs, data.x);
}

bool ShardAccountBlocks::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.fetch_to(cs, x);
}

bool ShardAccountBlocks::cell_unpack(Ref<vm::Cell> cell_ref, ShardAccountBlocks::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardAccountBlocks::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ShardAccountBlocks::pack(vm::CellBuilder& cb, const ShardAccountBlocks::Record& data) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.store_from(cb, data.x);
}

bool ShardAccountBlocks::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_256_AccountBlock_CurrencyCollection.store_from(cb, x);
}

bool ShardAccountBlocks::cell_pack(Ref<vm::Cell>& cell_ref, const ShardAccountBlocks::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccountBlocks::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardAccountBlocks::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_256_AccountBlock_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ShardAccountBlocks t_ShardAccountBlocks;

//
// code for type `TrStoragePhase`
//

int TrStoragePhase::check_tag(const vm::CellSlice& cs) const {
  return tr_phase_storage;
}

bool TrStoragePhase::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs)
      && t_Maybe_Grams.skip(cs)
      && t_AccStatusChange.skip(cs);
}

bool TrStoragePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak)
      && t_Maybe_Grams.validate_skip(cs, weak)
      && t_AccStatusChange.validate_skip(cs, weak);
}

bool TrStoragePhase::unpack(vm::CellSlice& cs, TrStoragePhase::Record& data) const {
  return t_Grams.fetch_to(cs, data.storage_fees_collected)
      && t_Maybe_Grams.fetch_to(cs, data.storage_fees_due)
      && t_AccStatusChange.fetch_enum_to(cs, data.status_change);
}

bool TrStoragePhase::unpack_tr_phase_storage(vm::CellSlice& cs, Ref<CellSlice>& storage_fees_collected, Ref<CellSlice>& storage_fees_due, char& status_change) const {
  return t_Grams.fetch_to(cs, storage_fees_collected)
      && t_Maybe_Grams.fetch_to(cs, storage_fees_due)
      && t_AccStatusChange.fetch_enum_to(cs, status_change);
}

bool TrStoragePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrStoragePhase::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrStoragePhase::cell_unpack_tr_phase_storage(Ref<vm::Cell> cell_ref, Ref<CellSlice>& storage_fees_collected, Ref<CellSlice>& storage_fees_due, char& status_change) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_storage(cs, storage_fees_collected, storage_fees_due, status_change) && cs.empty_ext();
}

bool TrStoragePhase::pack(vm::CellBuilder& cb, const TrStoragePhase::Record& data) const {
  return t_Grams.store_from(cb, data.storage_fees_collected)
      && t_Maybe_Grams.store_from(cb, data.storage_fees_due)
      && t_AccStatusChange.store_enum_from(cb, data.status_change);
}

bool TrStoragePhase::pack_tr_phase_storage(vm::CellBuilder& cb, Ref<CellSlice> storage_fees_collected, Ref<CellSlice> storage_fees_due, char status_change) const {
  return t_Grams.store_from(cb, storage_fees_collected)
      && t_Maybe_Grams.store_from(cb, storage_fees_due)
      && t_AccStatusChange.store_enum_from(cb, status_change);
}

bool TrStoragePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrStoragePhase::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrStoragePhase::cell_pack_tr_phase_storage(Ref<vm::Cell>& cell_ref, Ref<CellSlice> storage_fees_collected, Ref<CellSlice> storage_fees_due, char status_change) const {
  vm::CellBuilder cb;
  return pack_tr_phase_storage(cb, std::move(storage_fees_collected), std::move(storage_fees_due), status_change) && std::move(cb).finalize_to(cell_ref);
}

bool TrStoragePhase::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("tr_phase_storage")
      && pp.field("storage_fees_collected")
      && t_Grams.print_skip(pp, cs)
      && pp.field("storage_fees_due")
      && t_Maybe_Grams.print_skip(pp, cs)
      && pp.field("status_change")
      && t_AccStatusChange.print_skip(pp, cs)
      && pp.close();
}

const TrStoragePhase t_TrStoragePhase;

//
// code for type `AccStatusChange`
//
constexpr char AccStatusChange::cons_len[3];
constexpr unsigned char AccStatusChange::cons_tag[3];

int AccStatusChange::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case acst_unchanged:
    return cs.have(1) ? acst_unchanged : -1;
  case acst_frozen:
    return cs.have(2) ? acst_frozen : -1;
  case acst_deleted:
    return cs.have(2) ? acst_deleted : -1;
  }
  return -1;
}

bool AccStatusChange::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case acst_unchanged:
    return cs.advance(1);
  case acst_frozen:
    return cs.advance(2);
  case acst_deleted:
    return cs.advance(2);
  }
  return false;
}

bool AccStatusChange::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case acst_unchanged:
    return cs.advance(1);
  case acst_frozen:
    return cs.advance(2);
  case acst_deleted:
    return cs.advance(2);
  }
  return false;
}

bool AccStatusChange::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  int t = get_tag(cs);
  value = (char)t;
  return t >= 0 && cs.advance(cons_len[t]);
}

bool AccStatusChange::store_enum_from(vm::CellBuilder& cb, int value) const {
  return (unsigned)value < 3 && cb.store_long_bool(cons_tag[value], cons_len[value]);
}

bool AccStatusChange::unpack(vm::CellSlice& cs, AccStatusChange::Record_acst_unchanged& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool AccStatusChange::unpack_acst_unchanged(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool AccStatusChange::cell_unpack(Ref<vm::Cell> cell_ref, AccStatusChange::Record_acst_unchanged& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccStatusChange::cell_unpack_acst_unchanged(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acst_unchanged(cs) && cs.empty_ext();
}

bool AccStatusChange::unpack(vm::CellSlice& cs, AccStatusChange::Record_acst_frozen& data) const {
  return cs.fetch_ulong(2) == 2;
}

bool AccStatusChange::unpack_acst_frozen(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 2;
}

bool AccStatusChange::cell_unpack(Ref<vm::Cell> cell_ref, AccStatusChange::Record_acst_frozen& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccStatusChange::cell_unpack_acst_frozen(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acst_frozen(cs) && cs.empty_ext();
}

bool AccStatusChange::unpack(vm::CellSlice& cs, AccStatusChange::Record_acst_deleted& data) const {
  return cs.fetch_ulong(2) == 3;
}

bool AccStatusChange::unpack_acst_deleted(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 3;
}

bool AccStatusChange::cell_unpack(Ref<vm::Cell> cell_ref, AccStatusChange::Record_acst_deleted& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool AccStatusChange::cell_unpack_acst_deleted(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_acst_deleted(cs) && cs.empty_ext();
}

bool AccStatusChange::pack(vm::CellBuilder& cb, const AccStatusChange::Record_acst_unchanged& data) const {
  return cb.store_long_bool(0, 1);
}

bool AccStatusChange::pack_acst_unchanged(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool AccStatusChange::cell_pack(Ref<vm::Cell>& cell_ref, const AccStatusChange::Record_acst_unchanged& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::cell_pack_acst_unchanged(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acst_unchanged(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::pack(vm::CellBuilder& cb, const AccStatusChange::Record_acst_frozen& data) const {
  return cb.store_long_bool(2, 2);
}

bool AccStatusChange::pack_acst_frozen(vm::CellBuilder& cb) const {
  return cb.store_long_bool(2, 2);
}

bool AccStatusChange::cell_pack(Ref<vm::Cell>& cell_ref, const AccStatusChange::Record_acst_frozen& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::cell_pack_acst_frozen(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acst_frozen(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::pack(vm::CellBuilder& cb, const AccStatusChange::Record_acst_deleted& data) const {
  return cb.store_long_bool(3, 2);
}

bool AccStatusChange::pack_acst_deleted(vm::CellBuilder& cb) const {
  return cb.store_long_bool(3, 2);
}

bool AccStatusChange::cell_pack(Ref<vm::Cell>& cell_ref, const AccStatusChange::Record_acst_deleted& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::cell_pack_acst_deleted(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_acst_deleted(cb) && std::move(cb).finalize_to(cell_ref);
}

bool AccStatusChange::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case acst_unchanged:
    return cs.advance(1)
        && pp.cons("acst_unchanged");
  case acst_frozen:
    return cs.advance(2)
        && pp.cons("acst_frozen");
  case acst_deleted:
    return cs.advance(2)
        && pp.cons("acst_deleted");
  }
  return pp.fail("unknown constructor for AccStatusChange");
}

const AccStatusChange t_AccStatusChange;

//
// code for type `TrCreditPhase`
//

int TrCreditPhase::check_tag(const vm::CellSlice& cs) const {
  return tr_phase_credit;
}

bool TrCreditPhase::skip(vm::CellSlice& cs) const {
  return t_Maybe_Grams.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool TrCreditPhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Maybe_Grams.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool TrCreditPhase::unpack(vm::CellSlice& cs, TrCreditPhase::Record& data) const {
  return t_Maybe_Grams.fetch_to(cs, data.due_fees_collected)
      && t_CurrencyCollection.fetch_to(cs, data.credit);
}

bool TrCreditPhase::unpack_tr_phase_credit(vm::CellSlice& cs, Ref<CellSlice>& due_fees_collected, Ref<CellSlice>& credit) const {
  return t_Maybe_Grams.fetch_to(cs, due_fees_collected)
      && t_CurrencyCollection.fetch_to(cs, credit);
}

bool TrCreditPhase::cell_unpack(Ref<vm::Cell> cell_ref, TrCreditPhase::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrCreditPhase::cell_unpack_tr_phase_credit(Ref<vm::Cell> cell_ref, Ref<CellSlice>& due_fees_collected, Ref<CellSlice>& credit) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_credit(cs, due_fees_collected, credit) && cs.empty_ext();
}

bool TrCreditPhase::pack(vm::CellBuilder& cb, const TrCreditPhase::Record& data) const {
  return t_Maybe_Grams.store_from(cb, data.due_fees_collected)
      && t_CurrencyCollection.store_from(cb, data.credit);
}

bool TrCreditPhase::pack_tr_phase_credit(vm::CellBuilder& cb, Ref<CellSlice> due_fees_collected, Ref<CellSlice> credit) const {
  return t_Maybe_Grams.store_from(cb, due_fees_collected)
      && t_CurrencyCollection.store_from(cb, credit);
}

bool TrCreditPhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrCreditPhase::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrCreditPhase::cell_pack_tr_phase_credit(Ref<vm::Cell>& cell_ref, Ref<CellSlice> due_fees_collected, Ref<CellSlice> credit) const {
  vm::CellBuilder cb;
  return pack_tr_phase_credit(cb, std::move(due_fees_collected), std::move(credit)) && std::move(cb).finalize_to(cell_ref);
}

bool TrCreditPhase::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("tr_phase_credit")
      && pp.field("due_fees_collected")
      && t_Maybe_Grams.print_skip(pp, cs)
      && pp.field("credit")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const TrCreditPhase t_TrCreditPhase;

//
// code for auxiliary type `TrComputePhase_aux`
//

int TrComputePhase_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool TrComputePhase_aux::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)
      && t_VarUInteger_7.skip(cs)
      && t_Maybe_VarUInteger_3.skip(cs)
      && cs.advance(40)
      && t_Maybe_int32.skip(cs)
      && cs.advance(544);
}

bool TrComputePhase_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)
      && t_VarUInteger_7.validate_skip(cs, weak)
      && t_Maybe_VarUInteger_3.validate_skip(cs, weak)
      && cs.advance(40)
      && t_Maybe_int32.validate_skip(cs, weak)
      && cs.advance(544);
}

bool TrComputePhase_aux::unpack(vm::CellSlice& cs, TrComputePhase_aux::Record& data) const {
  return t_VarUInteger_7.fetch_to(cs, data.gas_used)
      && t_VarUInteger_7.fetch_to(cs, data.gas_limit)
      && t_Maybe_VarUInteger_3.fetch_to(cs, data.gas_credit)
      && cs.fetch_int_to(8, data.mode)
      && cs.fetch_int_to(32, data.exit_code)
      && t_Maybe_int32.fetch_to(cs, data.exit_arg)
      && cs.fetch_uint_to(32, data.vm_steps)
      && cs.fetch_bits_to(data.vm_init_state_hash.bits(), 256)
      && cs.fetch_bits_to(data.vm_final_state_hash.bits(), 256);
}

bool TrComputePhase_aux::cell_unpack(Ref<vm::Cell> cell_ref, TrComputePhase_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrComputePhase_aux::pack(vm::CellBuilder& cb, const TrComputePhase_aux::Record& data) const {
  return t_VarUInteger_7.store_from(cb, data.gas_used)
      && t_VarUInteger_7.store_from(cb, data.gas_limit)
      && t_Maybe_VarUInteger_3.store_from(cb, data.gas_credit)
      && cb.store_long_rchk_bool(data.mode, 8)
      && cb.store_long_rchk_bool(data.exit_code, 32)
      && t_Maybe_int32.store_from(cb, data.exit_arg)
      && cb.store_ulong_rchk_bool(data.vm_steps, 32)
      && cb.store_bits_bool(data.vm_init_state_hash.cbits(), 256)
      && cb.store_bits_bool(data.vm_final_state_hash.cbits(), 256);
}

bool TrComputePhase_aux::cell_pack(Ref<vm::Cell>& cell_ref, const TrComputePhase_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrComputePhase_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("gas_used")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.field("gas_limit")
      && t_VarUInteger_7.print_skip(pp, cs)
      && pp.field("gas_credit")
      && t_Maybe_VarUInteger_3.print_skip(pp, cs)
      && pp.fetch_int_field(cs, 8, "mode")
      && pp.fetch_int_field(cs, 32, "exit_code")
      && pp.field("exit_arg")
      && t_Maybe_int32.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "vm_steps")
      && pp.fetch_bits_field(cs, 256, "vm_init_state_hash")
      && pp.fetch_bits_field(cs, 256, "vm_final_state_hash")
      && pp.close();
}

const TrComputePhase_aux t_TrComputePhase_aux;

//
// code for type `TrComputePhase`
//

int TrComputePhase::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_compute_skipped:
    return cs.have(1) ? tr_phase_compute_skipped : -1;
  case tr_phase_compute_vm:
    return cs.have(1) ? tr_phase_compute_vm : -1;
  }
  return -1;
}

bool TrComputePhase::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_compute_skipped:
    return cs.advance(3);
  case tr_phase_compute_vm:
    return cs.advance(4)
        && t_Grams.skip(cs)
        && cs.advance_refs(1);
  }
  return false;
}

bool TrComputePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case tr_phase_compute_skipped:
    return cs.advance(1)
        && t_ComputeSkipReason.validate_skip(cs, weak);
  case tr_phase_compute_vm:
    return cs.advance(4)
        && t_Grams.validate_skip(cs, weak)
        && t_TrComputePhase_aux.validate_skip_ref(cs, weak);
  }
  return false;
}

bool TrComputePhase::unpack(vm::CellSlice& cs, TrComputePhase::Record_tr_phase_compute_skipped& data) const {
  return cs.fetch_ulong(1) == 0
      && t_ComputeSkipReason.fetch_enum_to(cs, data.reason);
}

bool TrComputePhase::unpack_tr_phase_compute_skipped(vm::CellSlice& cs, char& reason) const {
  return cs.fetch_ulong(1) == 0
      && t_ComputeSkipReason.fetch_enum_to(cs, reason);
}

bool TrComputePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrComputePhase::Record_tr_phase_compute_skipped& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrComputePhase::cell_unpack_tr_phase_compute_skipped(Ref<vm::Cell> cell_ref, char& reason) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_compute_skipped(cs, reason) && cs.empty_ext();
}

bool TrComputePhase::unpack(vm::CellSlice& cs, TrComputePhase::Record_tr_phase_compute_vm& data) const {
  return cs.fetch_ulong(1) == 1
      && cs.fetch_bool_to(data.success)
      && cs.fetch_bool_to(data.msg_state_used)
      && cs.fetch_bool_to(data.account_activated)
      && t_Grams.fetch_to(cs, data.gas_fees)
      && t_TrComputePhase_aux.cell_unpack(cs.fetch_ref(), data.r1);
}

bool TrComputePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrComputePhase::Record_tr_phase_compute_vm& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrComputePhase::pack(vm::CellBuilder& cb, const TrComputePhase::Record_tr_phase_compute_skipped& data) const {
  return cb.store_long_bool(0, 1)
      && t_ComputeSkipReason.store_enum_from(cb, data.reason);
}

bool TrComputePhase::pack_tr_phase_compute_skipped(vm::CellBuilder& cb, char reason) const {
  return cb.store_long_bool(0, 1)
      && t_ComputeSkipReason.store_enum_from(cb, reason);
}

bool TrComputePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrComputePhase::Record_tr_phase_compute_skipped& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrComputePhase::cell_pack_tr_phase_compute_skipped(Ref<vm::Cell>& cell_ref, char reason) const {
  vm::CellBuilder cb;
  return pack_tr_phase_compute_skipped(cb, reason) && std::move(cb).finalize_to(cell_ref);
}

bool TrComputePhase::pack(vm::CellBuilder& cb, const TrComputePhase::Record_tr_phase_compute_vm& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(1, 1)
      && cb.store_ulong_rchk_bool(data.success, 1)
      && cb.store_ulong_rchk_bool(data.msg_state_used, 1)
      && cb.store_ulong_rchk_bool(data.account_activated, 1)
      && t_Grams.store_from(cb, data.gas_fees)
      && t_TrComputePhase_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell));
}

bool TrComputePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrComputePhase::Record_tr_phase_compute_vm& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrComputePhase::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_compute_skipped:
    return cs.advance(1)
        && pp.open("tr_phase_compute_skipped")
        && pp.field("reason")
        && t_ComputeSkipReason.print_skip(pp, cs)
        && pp.close();
  case tr_phase_compute_vm:
    return cs.advance(1)
        && pp.open("tr_phase_compute_vm")
        && pp.fetch_uint_field(cs, 1, "success")
        && pp.fetch_uint_field(cs, 1, "msg_state_used")
        && pp.fetch_uint_field(cs, 1, "account_activated")
        && pp.field("gas_fees")
        && t_Grams.print_skip(pp, cs)
        && pp.field()
        && t_TrComputePhase_aux.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for TrComputePhase");
}

const TrComputePhase t_TrComputePhase;

//
// code for type `ComputeSkipReason`
//

int ComputeSkipReason::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cskip_no_state:
    return cs.have(2) ? cskip_no_state : -1;
  case cskip_bad_state:
    return cs.have(2) ? cskip_bad_state : -1;
  case cskip_no_gas:
    return cs.prefetch_ulong(2) == 2 ? cskip_no_gas : -1;
  }
  return -1;
}

bool ComputeSkipReason::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case cskip_no_state:
    return cs.advance(2);
  case cskip_bad_state:
    return cs.advance(2);
  case cskip_no_gas:
    return cs.fetch_ulong(2) == 2;
  }
  return false;
}

bool ComputeSkipReason::fetch_enum_to(vm::CellSlice& cs, char& value) const {
  int t = get_tag(cs);
  value = (char)t;
  return t >= 0 && cs.fetch_ulong(2) == (unsigned)t;
}

bool ComputeSkipReason::store_enum_from(vm::CellBuilder& cb, int value) const {
  return cb.store_uint_less(3, value);
}

bool ComputeSkipReason::unpack(vm::CellSlice& cs, ComputeSkipReason::Record_cskip_no_state& data) const {
  return cs.fetch_ulong(2) == 0;
}

bool ComputeSkipReason::unpack_cskip_no_state(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0;
}

bool ComputeSkipReason::cell_unpack(Ref<vm::Cell> cell_ref, ComputeSkipReason::Record_cskip_no_state& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ComputeSkipReason::cell_unpack_cskip_no_state(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cskip_no_state(cs) && cs.empty_ext();
}

bool ComputeSkipReason::unpack(vm::CellSlice& cs, ComputeSkipReason::Record_cskip_bad_state& data) const {
  return cs.fetch_ulong(2) == 1;
}

bool ComputeSkipReason::unpack_cskip_bad_state(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 1;
}

bool ComputeSkipReason::cell_unpack(Ref<vm::Cell> cell_ref, ComputeSkipReason::Record_cskip_bad_state& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ComputeSkipReason::cell_unpack_cskip_bad_state(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cskip_bad_state(cs) && cs.empty_ext();
}

bool ComputeSkipReason::unpack(vm::CellSlice& cs, ComputeSkipReason::Record_cskip_no_gas& data) const {
  return cs.fetch_ulong(2) == 2;
}

bool ComputeSkipReason::unpack_cskip_no_gas(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 2;
}

bool ComputeSkipReason::cell_unpack(Ref<vm::Cell> cell_ref, ComputeSkipReason::Record_cskip_no_gas& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ComputeSkipReason::cell_unpack_cskip_no_gas(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cskip_no_gas(cs) && cs.empty_ext();
}

bool ComputeSkipReason::pack(vm::CellBuilder& cb, const ComputeSkipReason::Record_cskip_no_state& data) const {
  return cb.store_long_bool(0, 2);
}

bool ComputeSkipReason::pack_cskip_no_state(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 2);
}

bool ComputeSkipReason::cell_pack(Ref<vm::Cell>& cell_ref, const ComputeSkipReason::Record_cskip_no_state& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::cell_pack_cskip_no_state(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_cskip_no_state(cb) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::pack(vm::CellBuilder& cb, const ComputeSkipReason::Record_cskip_bad_state& data) const {
  return cb.store_long_bool(1, 2);
}

bool ComputeSkipReason::pack_cskip_bad_state(vm::CellBuilder& cb) const {
  return cb.store_long_bool(1, 2);
}

bool ComputeSkipReason::cell_pack(Ref<vm::Cell>& cell_ref, const ComputeSkipReason::Record_cskip_bad_state& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::cell_pack_cskip_bad_state(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_cskip_bad_state(cb) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::pack(vm::CellBuilder& cb, const ComputeSkipReason::Record_cskip_no_gas& data) const {
  return cb.store_long_bool(2, 2);
}

bool ComputeSkipReason::pack_cskip_no_gas(vm::CellBuilder& cb) const {
  return cb.store_long_bool(2, 2);
}

bool ComputeSkipReason::cell_pack(Ref<vm::Cell>& cell_ref, const ComputeSkipReason::Record_cskip_no_gas& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::cell_pack_cskip_no_gas(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_cskip_no_gas(cb) && std::move(cb).finalize_to(cell_ref);
}

bool ComputeSkipReason::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cskip_no_state:
    return cs.advance(2)
        && pp.cons("cskip_no_state");
  case cskip_bad_state:
    return cs.advance(2)
        && pp.cons("cskip_bad_state");
  case cskip_no_gas:
    return cs.fetch_ulong(2) == 2
        && pp.cons("cskip_no_gas");
  }
  return pp.fail("unknown constructor for ComputeSkipReason");
}

const ComputeSkipReason t_ComputeSkipReason;

//
// code for type `TrActionPhase`
//

int TrActionPhase::check_tag(const vm::CellSlice& cs) const {
  return tr_phase_action;
}

bool TrActionPhase::skip(vm::CellSlice& cs) const {
  return cs.advance(3)
      && t_AccStatusChange.skip(cs)
      && t_Maybe_Grams.skip(cs)
      && t_Maybe_Grams.skip(cs)
      && cs.advance(32)
      && t_Maybe_int32.skip(cs)
      && cs.advance(320)
      && t_StorageUsedShort.skip(cs);
}

bool TrActionPhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(3)
      && t_AccStatusChange.validate_skip(cs, weak)
      && t_Maybe_Grams.validate_skip(cs, weak)
      && t_Maybe_Grams.validate_skip(cs, weak)
      && cs.advance(32)
      && t_Maybe_int32.validate_skip(cs, weak)
      && cs.advance(320)
      && t_StorageUsedShort.validate_skip(cs, weak);
}

bool TrActionPhase::unpack(vm::CellSlice& cs, TrActionPhase::Record& data) const {
  return cs.fetch_bool_to(data.success)
      && cs.fetch_bool_to(data.valid)
      && cs.fetch_bool_to(data.no_funds)
      && t_AccStatusChange.fetch_enum_to(cs, data.status_change)
      && t_Maybe_Grams.fetch_to(cs, data.total_fwd_fees)
      && t_Maybe_Grams.fetch_to(cs, data.total_action_fees)
      && cs.fetch_int_to(32, data.result_code)
      && t_Maybe_int32.fetch_to(cs, data.result_arg)
      && cs.fetch_uint_to(16, data.tot_actions)
      && cs.fetch_uint_to(16, data.spec_actions)
      && cs.fetch_uint_to(16, data.skipped_actions)
      && cs.fetch_uint_to(16, data.msgs_created)
      && cs.fetch_bits_to(data.action_list_hash.bits(), 256)
      && t_StorageUsedShort.fetch_to(cs, data.tot_msg_size);
}

bool TrActionPhase::cell_unpack(Ref<vm::Cell> cell_ref, TrActionPhase::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrActionPhase::pack(vm::CellBuilder& cb, const TrActionPhase::Record& data) const {
  return cb.store_ulong_rchk_bool(data.success, 1)
      && cb.store_ulong_rchk_bool(data.valid, 1)
      && cb.store_ulong_rchk_bool(data.no_funds, 1)
      && t_AccStatusChange.store_enum_from(cb, data.status_change)
      && t_Maybe_Grams.store_from(cb, data.total_fwd_fees)
      && t_Maybe_Grams.store_from(cb, data.total_action_fees)
      && cb.store_long_rchk_bool(data.result_code, 32)
      && t_Maybe_int32.store_from(cb, data.result_arg)
      && cb.store_ulong_rchk_bool(data.tot_actions, 16)
      && cb.store_ulong_rchk_bool(data.spec_actions, 16)
      && cb.store_ulong_rchk_bool(data.skipped_actions, 16)
      && cb.store_ulong_rchk_bool(data.msgs_created, 16)
      && cb.store_bits_bool(data.action_list_hash.cbits(), 256)
      && t_StorageUsedShort.store_from(cb, data.tot_msg_size);
}

bool TrActionPhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrActionPhase::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrActionPhase::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("tr_phase_action")
      && pp.fetch_uint_field(cs, 1, "success")
      && pp.fetch_uint_field(cs, 1, "valid")
      && pp.fetch_uint_field(cs, 1, "no_funds")
      && pp.field("status_change")
      && t_AccStatusChange.print_skip(pp, cs)
      && pp.field("total_fwd_fees")
      && t_Maybe_Grams.print_skip(pp, cs)
      && pp.field("total_action_fees")
      && t_Maybe_Grams.print_skip(pp, cs)
      && pp.fetch_int_field(cs, 32, "result_code")
      && pp.field("result_arg")
      && t_Maybe_int32.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 16, "tot_actions")
      && pp.fetch_uint_field(cs, 16, "spec_actions")
      && pp.fetch_uint_field(cs, 16, "skipped_actions")
      && pp.fetch_uint_field(cs, 16, "msgs_created")
      && pp.fetch_bits_field(cs, 256, "action_list_hash")
      && pp.field("tot_msg_size")
      && t_StorageUsedShort.print_skip(pp, cs)
      && pp.close();
}

const TrActionPhase t_TrActionPhase;

//
// code for type `TrBouncePhase`
//
constexpr char TrBouncePhase::cons_len[3];
constexpr unsigned char TrBouncePhase::cons_tag[3];

int TrBouncePhase::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_bounce_negfunds:
    return cs.have(2) ? tr_phase_bounce_negfunds : -1;
  case tr_phase_bounce_nofunds:
    return cs.have(2) ? tr_phase_bounce_nofunds : -1;
  case tr_phase_bounce_ok:
    return cs.have(1) ? tr_phase_bounce_ok : -1;
  }
  return -1;
}

bool TrBouncePhase::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_bounce_negfunds:
    return cs.advance(2);
  case tr_phase_bounce_nofunds:
    return cs.advance(2)
        && t_StorageUsedShort.skip(cs)
        && t_Grams.skip(cs);
  case tr_phase_bounce_ok:
    return cs.advance(1)
        && t_StorageUsedShort.skip(cs)
        && t_Grams.skip(cs)
        && t_Grams.skip(cs);
  }
  return false;
}

bool TrBouncePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case tr_phase_bounce_negfunds:
    return cs.advance(2);
  case tr_phase_bounce_nofunds:
    return cs.advance(2)
        && t_StorageUsedShort.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  case tr_phase_bounce_ok:
    return cs.advance(1)
        && t_StorageUsedShort.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak);
  }
  return false;
}

bool TrBouncePhase::unpack(vm::CellSlice& cs, TrBouncePhase::Record_tr_phase_bounce_negfunds& data) const {
  return cs.fetch_ulong(2) == 0;
}

bool TrBouncePhase::unpack_tr_phase_bounce_negfunds(vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0;
}

bool TrBouncePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrBouncePhase::Record_tr_phase_bounce_negfunds& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrBouncePhase::cell_unpack_tr_phase_bounce_negfunds(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_bounce_negfunds(cs) && cs.empty_ext();
}

bool TrBouncePhase::unpack(vm::CellSlice& cs, TrBouncePhase::Record_tr_phase_bounce_nofunds& data) const {
  return cs.fetch_ulong(2) == 1
      && t_StorageUsedShort.fetch_to(cs, data.msg_size)
      && t_Grams.fetch_to(cs, data.req_fwd_fees);
}

bool TrBouncePhase::unpack_tr_phase_bounce_nofunds(vm::CellSlice& cs, Ref<CellSlice>& msg_size, Ref<CellSlice>& req_fwd_fees) const {
  return cs.fetch_ulong(2) == 1
      && t_StorageUsedShort.fetch_to(cs, msg_size)
      && t_Grams.fetch_to(cs, req_fwd_fees);
}

bool TrBouncePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrBouncePhase::Record_tr_phase_bounce_nofunds& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrBouncePhase::cell_unpack_tr_phase_bounce_nofunds(Ref<vm::Cell> cell_ref, Ref<CellSlice>& msg_size, Ref<CellSlice>& req_fwd_fees) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_bounce_nofunds(cs, msg_size, req_fwd_fees) && cs.empty_ext();
}

bool TrBouncePhase::unpack(vm::CellSlice& cs, TrBouncePhase::Record_tr_phase_bounce_ok& data) const {
  return cs.fetch_ulong(1) == 1
      && t_StorageUsedShort.fetch_to(cs, data.msg_size)
      && t_Grams.fetch_to(cs, data.msg_fees)
      && t_Grams.fetch_to(cs, data.fwd_fees);
}

bool TrBouncePhase::unpack_tr_phase_bounce_ok(vm::CellSlice& cs, Ref<CellSlice>& msg_size, Ref<CellSlice>& msg_fees, Ref<CellSlice>& fwd_fees) const {
  return cs.fetch_ulong(1) == 1
      && t_StorageUsedShort.fetch_to(cs, msg_size)
      && t_Grams.fetch_to(cs, msg_fees)
      && t_Grams.fetch_to(cs, fwd_fees);
}

bool TrBouncePhase::cell_unpack(Ref<vm::Cell> cell_ref, TrBouncePhase::Record_tr_phase_bounce_ok& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TrBouncePhase::cell_unpack_tr_phase_bounce_ok(Ref<vm::Cell> cell_ref, Ref<CellSlice>& msg_size, Ref<CellSlice>& msg_fees, Ref<CellSlice>& fwd_fees) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_tr_phase_bounce_ok(cs, msg_size, msg_fees, fwd_fees) && cs.empty_ext();
}

bool TrBouncePhase::pack(vm::CellBuilder& cb, const TrBouncePhase::Record_tr_phase_bounce_negfunds& data) const {
  return cb.store_long_bool(0, 2);
}

bool TrBouncePhase::pack_tr_phase_bounce_negfunds(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 2);
}

bool TrBouncePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrBouncePhase::Record_tr_phase_bounce_negfunds& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::cell_pack_tr_phase_bounce_negfunds(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_tr_phase_bounce_negfunds(cb) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::pack(vm::CellBuilder& cb, const TrBouncePhase::Record_tr_phase_bounce_nofunds& data) const {
  return cb.store_long_bool(1, 2)
      && t_StorageUsedShort.store_from(cb, data.msg_size)
      && t_Grams.store_from(cb, data.req_fwd_fees);
}

bool TrBouncePhase::pack_tr_phase_bounce_nofunds(vm::CellBuilder& cb, Ref<CellSlice> msg_size, Ref<CellSlice> req_fwd_fees) const {
  return cb.store_long_bool(1, 2)
      && t_StorageUsedShort.store_from(cb, msg_size)
      && t_Grams.store_from(cb, req_fwd_fees);
}

bool TrBouncePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrBouncePhase::Record_tr_phase_bounce_nofunds& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::cell_pack_tr_phase_bounce_nofunds(Ref<vm::Cell>& cell_ref, Ref<CellSlice> msg_size, Ref<CellSlice> req_fwd_fees) const {
  vm::CellBuilder cb;
  return pack_tr_phase_bounce_nofunds(cb, std::move(msg_size), std::move(req_fwd_fees)) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::pack(vm::CellBuilder& cb, const TrBouncePhase::Record_tr_phase_bounce_ok& data) const {
  return cb.store_long_bool(1, 1)
      && t_StorageUsedShort.store_from(cb, data.msg_size)
      && t_Grams.store_from(cb, data.msg_fees)
      && t_Grams.store_from(cb, data.fwd_fees);
}

bool TrBouncePhase::pack_tr_phase_bounce_ok(vm::CellBuilder& cb, Ref<CellSlice> msg_size, Ref<CellSlice> msg_fees, Ref<CellSlice> fwd_fees) const {
  return cb.store_long_bool(1, 1)
      && t_StorageUsedShort.store_from(cb, msg_size)
      && t_Grams.store_from(cb, msg_fees)
      && t_Grams.store_from(cb, fwd_fees);
}

bool TrBouncePhase::cell_pack(Ref<vm::Cell>& cell_ref, const TrBouncePhase::Record_tr_phase_bounce_ok& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::cell_pack_tr_phase_bounce_ok(Ref<vm::Cell>& cell_ref, Ref<CellSlice> msg_size, Ref<CellSlice> msg_fees, Ref<CellSlice> fwd_fees) const {
  vm::CellBuilder cb;
  return pack_tr_phase_bounce_ok(cb, std::move(msg_size), std::move(msg_fees), std::move(fwd_fees)) && std::move(cb).finalize_to(cell_ref);
}

bool TrBouncePhase::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case tr_phase_bounce_negfunds:
    return cs.advance(2)
        && pp.cons("tr_phase_bounce_negfunds");
  case tr_phase_bounce_nofunds:
    return cs.advance(2)
        && pp.open("tr_phase_bounce_nofunds")
        && pp.field("msg_size")
        && t_StorageUsedShort.print_skip(pp, cs)
        && pp.field("req_fwd_fees")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  case tr_phase_bounce_ok:
    return cs.advance(1)
        && pp.open("tr_phase_bounce_ok")
        && pp.field("msg_size")
        && t_StorageUsedShort.print_skip(pp, cs)
        && pp.field("msg_fees")
        && t_Grams.print_skip(pp, cs)
        && pp.field("fwd_fees")
        && t_Grams.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for TrBouncePhase");
}

const TrBouncePhase t_TrBouncePhase;

//
// code for type `SplitMergeInfo`
//

int SplitMergeInfo::check_tag(const vm::CellSlice& cs) const {
  return split_merge_info;
}

bool SplitMergeInfo::unpack(vm::CellSlice& cs, SplitMergeInfo::Record& data) const {
  return cs.fetch_uint_to(6, data.cur_shard_pfx_len)
      && cs.fetch_uint_to(6, data.acc_split_depth)
      && cs.fetch_bits_to(data.this_addr.bits(), 256)
      && cs.fetch_bits_to(data.sibling_addr.bits(), 256);
}

bool SplitMergeInfo::cell_unpack(Ref<vm::Cell> cell_ref, SplitMergeInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool SplitMergeInfo::pack(vm::CellBuilder& cb, const SplitMergeInfo::Record& data) const {
  return cb.store_ulong_rchk_bool(data.cur_shard_pfx_len, 6)
      && cb.store_ulong_rchk_bool(data.acc_split_depth, 6)
      && cb.store_bits_bool(data.this_addr.cbits(), 256)
      && cb.store_bits_bool(data.sibling_addr.cbits(), 256);
}

bool SplitMergeInfo::cell_pack(Ref<vm::Cell>& cell_ref, const SplitMergeInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool SplitMergeInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int cur_shard_pfx_len, acc_split_depth;
  return pp.open("split_merge_info")
      && cs.fetch_uint_to(6, cur_shard_pfx_len)
      && pp.field_int(cur_shard_pfx_len, "cur_shard_pfx_len")
      && cs.fetch_uint_to(6, acc_split_depth)
      && pp.field_int(acc_split_depth, "acc_split_depth")
      && pp.fetch_bits_field(cs, 256, "this_addr")
      && pp.fetch_bits_field(cs, 256, "sibling_addr")
      && pp.close();
}

const SplitMergeInfo t_SplitMergeInfo;

//
// code for type `TransactionDescr`
//
constexpr char TransactionDescr::cons_len[7];
constexpr unsigned char TransactionDescr::cons_tag[7];

int TransactionDescr::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case trans_ord:
    return cs.have(4) ? trans_ord : -1;
  case trans_storage:
    return cs.have(4) ? trans_storage : -1;
  case trans_tick_tock:
    return cs.have(3) ? trans_tick_tock : -1;
  case trans_split_prepare:
    return cs.have(4) ? trans_split_prepare : -1;
  case trans_split_install:
    return cs.have(4) ? trans_split_install : -1;
  case trans_merge_prepare:
    return cs.have(4) ? trans_merge_prepare : -1;
  case trans_merge_install:
    return cs.prefetch_ulong(4) == 7 ? trans_merge_install : -1;
  }
  return -1;
}

bool TransactionDescr::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case trans_ord:
    return cs.advance(5)
        && t_Maybe_TrStoragePhase.skip(cs)
        && t_Maybe_TrCreditPhase.skip(cs)
        && t_TrComputePhase.skip(cs)
        && t_Maybe_Ref_TrActionPhase.skip(cs)
        && cs.advance(1)
        && t_Maybe_TrBouncePhase.skip(cs)
        && cs.advance(1);
  case trans_storage:
    return cs.advance(4)
        && t_TrStoragePhase.skip(cs);
  case trans_tick_tock:
    return cs.advance(4)
        && t_TrStoragePhase.skip(cs)
        && t_TrComputePhase.skip(cs)
        && t_Maybe_Ref_TrActionPhase.skip(cs)
        && cs.advance(2);
  case trans_split_prepare:
    return cs.advance(528)
        && t_Maybe_TrStoragePhase.skip(cs)
        && t_TrComputePhase.skip(cs)
        && t_Maybe_Ref_TrActionPhase.skip(cs)
        && cs.advance(2);
  case trans_split_install:
    return cs.advance_ext(0x10211);
  case trans_merge_prepare:
    return cs.advance(528)
        && t_TrStoragePhase.skip(cs)
        && cs.advance(1);
  case trans_merge_install:
    return cs.advance_ext(0x10210)
        && t_Maybe_TrStoragePhase.skip(cs)
        && t_Maybe_TrCreditPhase.skip(cs)
        && t_TrComputePhase.skip(cs)
        && t_Maybe_Ref_TrActionPhase.skip(cs)
        && cs.advance(2);
  }
  return false;
}

bool TransactionDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case trans_ord:
    return cs.advance(5)
        && t_Maybe_TrStoragePhase.validate_skip(cs, weak)
        && t_Maybe_TrCreditPhase.validate_skip(cs, weak)
        && t_TrComputePhase.validate_skip(cs, weak)
        && t_Maybe_Ref_TrActionPhase.validate_skip(cs, weak)
        && cs.advance(1)
        && t_Maybe_TrBouncePhase.validate_skip(cs, weak)
        && cs.advance(1);
  case trans_storage:
    return cs.advance(4)
        && t_TrStoragePhase.validate_skip(cs, weak);
  case trans_tick_tock:
    return cs.advance(4)
        && t_TrStoragePhase.validate_skip(cs, weak)
        && t_TrComputePhase.validate_skip(cs, weak)
        && t_Maybe_Ref_TrActionPhase.validate_skip(cs, weak)
        && cs.advance(2);
  case trans_split_prepare:
    return cs.advance(528)
        && t_Maybe_TrStoragePhase.validate_skip(cs, weak)
        && t_TrComputePhase.validate_skip(cs, weak)
        && t_Maybe_Ref_TrActionPhase.validate_skip(cs, weak)
        && cs.advance(2);
  case trans_split_install:
    return cs.advance(528)
        && t_Transaction.validate_skip_ref(cs, weak)
        && cs.advance(1);
  case trans_merge_prepare:
    return cs.advance(528)
        && t_TrStoragePhase.validate_skip(cs, weak)
        && cs.advance(1);
  case trans_merge_install:
    return cs.fetch_ulong(4) == 7
        && cs.advance(524)
        && t_Transaction.validate_skip_ref(cs, weak)
        && t_Maybe_TrStoragePhase.validate_skip(cs, weak)
        && t_Maybe_TrCreditPhase.validate_skip(cs, weak)
        && t_TrComputePhase.validate_skip(cs, weak)
        && t_Maybe_Ref_TrActionPhase.validate_skip(cs, weak)
        && cs.advance(2);
  }
  return false;
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_ord& data) const {
  return cs.fetch_ulong(4) == 0
      && cs.fetch_bool_to(data.credit_first)
      && t_Maybe_TrStoragePhase.fetch_to(cs, data.storage_ph)
      && t_Maybe_TrCreditPhase.fetch_to(cs, data.credit_ph)
      && t_TrComputePhase.fetch_to(cs, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.fetch_to(cs, data.action)
      && cs.fetch_bool_to(data.aborted)
      && t_Maybe_TrBouncePhase.fetch_to(cs, data.bounce)
      && cs.fetch_bool_to(data.destroyed);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_ord& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_storage& data) const {
  return cs.fetch_ulong(4) == 1
      && t_TrStoragePhase.fetch_to(cs, data.storage_ph);
}

bool TransactionDescr::unpack_trans_storage(vm::CellSlice& cs, Ref<CellSlice>& storage_ph) const {
  return cs.fetch_ulong(4) == 1
      && t_TrStoragePhase.fetch_to(cs, storage_ph);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_storage& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::cell_unpack_trans_storage(Ref<vm::Cell> cell_ref, Ref<CellSlice>& storage_ph) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_trans_storage(cs, storage_ph) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_tick_tock& data) const {
  return cs.fetch_ulong(3) == 1
      && cs.fetch_bool_to(data.is_tock)
      && t_TrStoragePhase.fetch_to(cs, data.storage_ph)
      && t_TrComputePhase.fetch_to(cs, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.fetch_to(cs, data.action)
      && cs.fetch_bool_to(data.aborted)
      && cs.fetch_bool_to(data.destroyed);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_tick_tock& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_split_prepare& data) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_subslice_to(524, data.split_info)
      && t_Maybe_TrStoragePhase.fetch_to(cs, data.storage_ph)
      && t_TrComputePhase.fetch_to(cs, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.fetch_to(cs, data.action)
      && cs.fetch_bool_to(data.aborted)
      && cs.fetch_bool_to(data.destroyed);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_split_prepare& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_split_install& data) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_subslice_to(524, data.split_info)
      && cs.fetch_ref_to(data.prepare_transaction)
      && cs.fetch_bool_to(data.installed);
}

bool TransactionDescr::unpack_trans_split_install(vm::CellSlice& cs, Ref<CellSlice>& split_info, Ref<Cell>& prepare_transaction, bool& installed) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_subslice_to(524, split_info)
      && cs.fetch_ref_to(prepare_transaction)
      && cs.fetch_bool_to(installed);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_split_install& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::cell_unpack_trans_split_install(Ref<vm::Cell> cell_ref, Ref<CellSlice>& split_info, Ref<Cell>& prepare_transaction, bool& installed) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_trans_split_install(cs, split_info, prepare_transaction, installed) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_merge_prepare& data) const {
  return cs.fetch_ulong(4) == 6
      && cs.fetch_subslice_to(524, data.split_info)
      && t_TrStoragePhase.fetch_to(cs, data.storage_ph)
      && cs.fetch_bool_to(data.aborted);
}

bool TransactionDescr::unpack_trans_merge_prepare(vm::CellSlice& cs, Ref<CellSlice>& split_info, Ref<CellSlice>& storage_ph, bool& aborted) const {
  return cs.fetch_ulong(4) == 6
      && cs.fetch_subslice_to(524, split_info)
      && t_TrStoragePhase.fetch_to(cs, storage_ph)
      && cs.fetch_bool_to(aborted);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_merge_prepare& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::cell_unpack_trans_merge_prepare(Ref<vm::Cell> cell_ref, Ref<CellSlice>& split_info, Ref<CellSlice>& storage_ph, bool& aborted) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_trans_merge_prepare(cs, split_info, storage_ph, aborted) && cs.empty_ext();
}

bool TransactionDescr::unpack(vm::CellSlice& cs, TransactionDescr::Record_trans_merge_install& data) const {
  return cs.fetch_ulong(4) == 7
      && cs.fetch_subslice_to(524, data.split_info)
      && cs.fetch_ref_to(data.prepare_transaction)
      && t_Maybe_TrStoragePhase.fetch_to(cs, data.storage_ph)
      && t_Maybe_TrCreditPhase.fetch_to(cs, data.credit_ph)
      && t_TrComputePhase.fetch_to(cs, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.fetch_to(cs, data.action)
      && cs.fetch_bool_to(data.aborted)
      && cs.fetch_bool_to(data.destroyed);
}

bool TransactionDescr::cell_unpack(Ref<vm::Cell> cell_ref, TransactionDescr::Record_trans_merge_install& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_ord& data) const {
  return cb.store_long_bool(0, 4)
      && cb.store_ulong_rchk_bool(data.credit_first, 1)
      && t_Maybe_TrStoragePhase.store_from(cb, data.storage_ph)
      && t_Maybe_TrCreditPhase.store_from(cb, data.credit_ph)
      && t_TrComputePhase.store_from(cb, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.store_from(cb, data.action)
      && cb.store_ulong_rchk_bool(data.aborted, 1)
      && t_Maybe_TrBouncePhase.store_from(cb, data.bounce)
      && cb.store_ulong_rchk_bool(data.destroyed, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_ord& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_storage& data) const {
  return cb.store_long_bool(1, 4)
      && t_TrStoragePhase.store_from(cb, data.storage_ph);
}

bool TransactionDescr::pack_trans_storage(vm::CellBuilder& cb, Ref<CellSlice> storage_ph) const {
  return cb.store_long_bool(1, 4)
      && t_TrStoragePhase.store_from(cb, storage_ph);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_storage& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::cell_pack_trans_storage(Ref<vm::Cell>& cell_ref, Ref<CellSlice> storage_ph) const {
  vm::CellBuilder cb;
  return pack_trans_storage(cb, std::move(storage_ph)) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_tick_tock& data) const {
  return cb.store_long_bool(1, 3)
      && cb.store_ulong_rchk_bool(data.is_tock, 1)
      && t_TrStoragePhase.store_from(cb, data.storage_ph)
      && t_TrComputePhase.store_from(cb, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.store_from(cb, data.action)
      && cb.store_ulong_rchk_bool(data.aborted, 1)
      && cb.store_ulong_rchk_bool(data.destroyed, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_tick_tock& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_split_prepare& data) const {
  return cb.store_long_bool(4, 4)
      && cb.append_cellslice_chk(data.split_info, 524)
      && t_Maybe_TrStoragePhase.store_from(cb, data.storage_ph)
      && t_TrComputePhase.store_from(cb, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.store_from(cb, data.action)
      && cb.store_ulong_rchk_bool(data.aborted, 1)
      && cb.store_ulong_rchk_bool(data.destroyed, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_split_prepare& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_split_install& data) const {
  return cb.store_long_bool(5, 4)
      && cb.append_cellslice_chk(data.split_info, 524)
      && cb.store_ref_bool(data.prepare_transaction)
      && cb.store_ulong_rchk_bool(data.installed, 1);
}

bool TransactionDescr::pack_trans_split_install(vm::CellBuilder& cb, Ref<CellSlice> split_info, Ref<Cell> prepare_transaction, bool installed) const {
  return cb.store_long_bool(5, 4)
      && cb.append_cellslice_chk(split_info, 524)
      && cb.store_ref_bool(prepare_transaction)
      && cb.store_ulong_rchk_bool(installed, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_split_install& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::cell_pack_trans_split_install(Ref<vm::Cell>& cell_ref, Ref<CellSlice> split_info, Ref<Cell> prepare_transaction, bool installed) const {
  vm::CellBuilder cb;
  return pack_trans_split_install(cb, std::move(split_info), std::move(prepare_transaction), installed) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_merge_prepare& data) const {
  return cb.store_long_bool(6, 4)
      && cb.append_cellslice_chk(data.split_info, 524)
      && t_TrStoragePhase.store_from(cb, data.storage_ph)
      && cb.store_ulong_rchk_bool(data.aborted, 1);
}

bool TransactionDescr::pack_trans_merge_prepare(vm::CellBuilder& cb, Ref<CellSlice> split_info, Ref<CellSlice> storage_ph, bool aborted) const {
  return cb.store_long_bool(6, 4)
      && cb.append_cellslice_chk(split_info, 524)
      && t_TrStoragePhase.store_from(cb, storage_ph)
      && cb.store_ulong_rchk_bool(aborted, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_merge_prepare& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::cell_pack_trans_merge_prepare(Ref<vm::Cell>& cell_ref, Ref<CellSlice> split_info, Ref<CellSlice> storage_ph, bool aborted) const {
  vm::CellBuilder cb;
  return pack_trans_merge_prepare(cb, std::move(split_info), std::move(storage_ph), aborted) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::pack(vm::CellBuilder& cb, const TransactionDescr::Record_trans_merge_install& data) const {
  return cb.store_long_bool(7, 4)
      && cb.append_cellslice_chk(data.split_info, 524)
      && cb.store_ref_bool(data.prepare_transaction)
      && t_Maybe_TrStoragePhase.store_from(cb, data.storage_ph)
      && t_Maybe_TrCreditPhase.store_from(cb, data.credit_ph)
      && t_TrComputePhase.store_from(cb, data.compute_ph)
      && t_Maybe_Ref_TrActionPhase.store_from(cb, data.action)
      && cb.store_ulong_rchk_bool(data.aborted, 1)
      && cb.store_ulong_rchk_bool(data.destroyed, 1);
}

bool TransactionDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TransactionDescr::Record_trans_merge_install& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TransactionDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case trans_ord:
    return cs.advance(4)
        && pp.open("trans_ord")
        && pp.fetch_uint_field(cs, 1, "credit_first")
        && pp.field("storage_ph")
        && t_Maybe_TrStoragePhase.print_skip(pp, cs)
        && pp.field("credit_ph")
        && t_Maybe_TrCreditPhase.print_skip(pp, cs)
        && pp.field("compute_ph")
        && t_TrComputePhase.print_skip(pp, cs)
        && pp.field("action")
        && t_Maybe_Ref_TrActionPhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "aborted")
        && pp.field("bounce")
        && t_Maybe_TrBouncePhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "destroyed")
        && pp.close();
  case trans_storage:
    return cs.advance(4)
        && pp.open("trans_storage")
        && pp.field("storage_ph")
        && t_TrStoragePhase.print_skip(pp, cs)
        && pp.close();
  case trans_tick_tock:
    return cs.advance(3)
        && pp.open("trans_tick_tock")
        && pp.fetch_uint_field(cs, 1, "is_tock")
        && pp.field("storage_ph")
        && t_TrStoragePhase.print_skip(pp, cs)
        && pp.field("compute_ph")
        && t_TrComputePhase.print_skip(pp, cs)
        && pp.field("action")
        && t_Maybe_Ref_TrActionPhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "aborted")
        && pp.fetch_uint_field(cs, 1, "destroyed")
        && pp.close();
  case trans_split_prepare:
    return cs.advance(4)
        && pp.open("trans_split_prepare")
        && pp.field("split_info")
        && t_SplitMergeInfo.print_skip(pp, cs)
        && pp.field("storage_ph")
        && t_Maybe_TrStoragePhase.print_skip(pp, cs)
        && pp.field("compute_ph")
        && t_TrComputePhase.print_skip(pp, cs)
        && pp.field("action")
        && t_Maybe_Ref_TrActionPhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "aborted")
        && pp.fetch_uint_field(cs, 1, "destroyed")
        && pp.close();
  case trans_split_install:
    return cs.advance(4)
        && pp.open("trans_split_install")
        && pp.field("split_info")
        && t_SplitMergeInfo.print_skip(pp, cs)
        && pp.field("prepare_transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.fetch_uint_field(cs, 1, "installed")
        && pp.close();
  case trans_merge_prepare:
    return cs.advance(4)
        && pp.open("trans_merge_prepare")
        && pp.field("split_info")
        && t_SplitMergeInfo.print_skip(pp, cs)
        && pp.field("storage_ph")
        && t_TrStoragePhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "aborted")
        && pp.close();
  case trans_merge_install:
    return cs.fetch_ulong(4) == 7
        && pp.open("trans_merge_install")
        && pp.field("split_info")
        && t_SplitMergeInfo.print_skip(pp, cs)
        && pp.field("prepare_transaction")
        && t_Transaction.print_ref(pp, cs.fetch_ref())
        && pp.field("storage_ph")
        && t_Maybe_TrStoragePhase.print_skip(pp, cs)
        && pp.field("credit_ph")
        && t_Maybe_TrCreditPhase.print_skip(pp, cs)
        && pp.field("compute_ph")
        && t_TrComputePhase.print_skip(pp, cs)
        && pp.field("action")
        && t_Maybe_Ref_TrActionPhase.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 1, "aborted")
        && pp.fetch_uint_field(cs, 1, "destroyed")
        && pp.close();
  }
  return pp.fail("unknown constructor for TransactionDescr");
}

const TransactionDescr t_TransactionDescr;

//
// code for type `SmartContractInfo`
//
constexpr unsigned SmartContractInfo::cons_tag[1];

int SmartContractInfo::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x76ef1ea ? smc_info : -1;
}

bool SmartContractInfo::skip(vm::CellSlice& cs) const {
  return cs.advance(480)
      && t_CurrencyCollection.skip(cs)
      && t_MsgAddressInt.skip(cs);
}

bool SmartContractInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x76ef1ea
      && cs.advance(448)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_MsgAddressInt.validate_skip(cs, weak);
}

bool SmartContractInfo::unpack(vm::CellSlice& cs, SmartContractInfo::Record& data) const {
  return cs.fetch_ulong(32) == 0x76ef1ea
      && cs.fetch_uint_to(16, data.actions)
      && cs.fetch_uint_to(16, data.msgs_sent)
      && cs.fetch_uint_to(32, data.unixtime)
      && cs.fetch_uint_to(64, data.block_lt)
      && cs.fetch_uint_to(64, data.trans_lt)
      && cs.fetch_bits_to(data.rand_seed.bits(), 256)
      && t_CurrencyCollection.fetch_to(cs, data.balance_remaining)
      && t_MsgAddressInt.fetch_to(cs, data.myself);
}

bool SmartContractInfo::cell_unpack(Ref<vm::Cell> cell_ref, SmartContractInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool SmartContractInfo::pack(vm::CellBuilder& cb, const SmartContractInfo::Record& data) const {
  return cb.store_long_bool(0x76ef1ea, 32)
      && cb.store_ulong_rchk_bool(data.actions, 16)
      && cb.store_ulong_rchk_bool(data.msgs_sent, 16)
      && cb.store_ulong_rchk_bool(data.unixtime, 32)
      && cb.store_ulong_rchk_bool(data.block_lt, 64)
      && cb.store_ulong_rchk_bool(data.trans_lt, 64)
      && cb.store_bits_bool(data.rand_seed.cbits(), 256)
      && t_CurrencyCollection.store_from(cb, data.balance_remaining)
      && t_MsgAddressInt.store_from(cb, data.myself);
}

bool SmartContractInfo::cell_pack(Ref<vm::Cell>& cell_ref, const SmartContractInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool SmartContractInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0x76ef1ea
      && pp.open("smc_info")
      && pp.fetch_uint_field(cs, 16, "actions")
      && pp.fetch_uint_field(cs, 16, "msgs_sent")
      && pp.fetch_uint_field(cs, 32, "unixtime")
      && pp.fetch_uint_field(cs, 64, "block_lt")
      && pp.fetch_uint_field(cs, 64, "trans_lt")
      && pp.fetch_bits_field(cs, 256, "rand_seed")
      && pp.field("balance_remaining")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("myself")
      && t_MsgAddressInt.print_skip(pp, cs)
      && pp.close();
}

const SmartContractInfo t_SmartContractInfo;

//
// code for type `OutList`
//

int OutList::get_tag(const vm::CellSlice& cs) const {
  // distinguish by parameter `m_` using 1 2 2 2
  return m_ ? out_list : out_list_empty;
}

int OutList::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case out_list_empty:
    return out_list_empty;
  case out_list:
    return out_list;
  }
  return -1;
}

bool OutList::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case out_list_empty:
    return m_ == 0;
  case out_list: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_refs(1)
        && t_OutAction.skip(cs);
    }
  }
  return false;
}

bool OutList::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case out_list_empty:
    return m_ == 0;
  case out_list: {
    int n;
    return add_r1(n, 1, m_)
        && OutList{n}.validate_skip_ref(cs, weak)
        && t_OutAction.validate_skip(cs, weak);
    }
  }
  return false;
}

bool OutList::unpack(vm::CellSlice& cs, OutList::Record_out_list_empty& data) const {
  return m_ == 0;
}

bool OutList::unpack_out_list_empty(vm::CellSlice& cs) const {
  return m_ == 0;
}

bool OutList::cell_unpack(Ref<vm::Cell> cell_ref, OutList::Record_out_list_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutList::cell_unpack_out_list_empty(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_out_list_empty(cs) && cs.empty_ext();
}

bool OutList::unpack(vm::CellSlice& cs, OutList::Record_out_list& data) const {
  return add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.prev)
      && t_OutAction.fetch_to(cs, data.action);
}

bool OutList::unpack_out_list(vm::CellSlice& cs, int& n, Ref<Cell>& prev, Ref<CellSlice>& action) const {
  return add_r1(n, 1, m_)
      && cs.fetch_ref_to(prev)
      && t_OutAction.fetch_to(cs, action);
}

bool OutList::cell_unpack(Ref<vm::Cell> cell_ref, OutList::Record_out_list& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutList::cell_unpack_out_list(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& prev, Ref<CellSlice>& action) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_out_list(cs, n, prev, action) && cs.empty_ext();
}

bool OutList::pack(vm::CellBuilder& cb, const OutList::Record_out_list_empty& data) const {
  return m_ == 0;
}

bool OutList::pack_out_list_empty(vm::CellBuilder& cb) const {
  return m_ == 0;
}

bool OutList::cell_pack(Ref<vm::Cell>& cell_ref, const OutList::Record_out_list_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutList::cell_pack_out_list_empty(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_out_list_empty(cb) && std::move(cb).finalize_to(cell_ref);
}

bool OutList::pack(vm::CellBuilder& cb, const OutList::Record_out_list& data) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(data.prev)
      && t_OutAction.store_from(cb, data.action);
}

bool OutList::pack_out_list(vm::CellBuilder& cb, Ref<Cell> prev, Ref<CellSlice> action) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(prev)
      && t_OutAction.store_from(cb, action);
}

bool OutList::cell_pack(Ref<vm::Cell>& cell_ref, const OutList::Record_out_list& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutList::cell_pack_out_list(Ref<vm::Cell>& cell_ref, Ref<Cell> prev, Ref<CellSlice> action) const {
  vm::CellBuilder cb;
  return pack_out_list(cb, std::move(prev), std::move(action)) && std::move(cb).finalize_to(cell_ref);
}

bool OutList::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case out_list_empty:
    return pp.cons("out_list_empty")
        && m_ == 0;
  case out_list: {
    int n;
    return pp.open("out_list")
        && add_r1(n, 1, m_)
        && pp.field("prev")
        && OutList{n}.print_ref(pp, cs.fetch_ref())
        && pp.field("action")
        && t_OutAction.print_skip(pp, cs)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for OutList");
}


//
// code for type `OutAction`
//
constexpr unsigned OutAction::cons_tag[3];

int OutAction::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case action_send_msg:
    return cs.prefetch_ulong(32) == 0xec3c86d ? action_send_msg : -1;
  case action_set_code:
    return cs.prefetch_ulong(32) == 0xad4de08eU ? action_set_code : -1;
  case action_reserve_currency:
    return cs.prefetch_ulong(32) == 0x36e6b809 ? action_reserve_currency : -1;
  }
  return -1;
}

bool OutAction::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case action_send_msg:
    return cs.advance_ext(0x10028);
  case action_set_code:
    return cs.advance_ext(0x10020);
  case action_reserve_currency:
    return cs.advance(40)
        && t_CurrencyCollection.skip(cs);
  }
  return false;
}

bool OutAction::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case action_send_msg:
    return cs.fetch_ulong(32) == 0xec3c86d
        && cs.advance(8)
        && t_MessageRelaxed_Any.validate_skip_ref(cs, weak);
  case action_set_code:
    return cs.fetch_ulong(32) == 0xad4de08eU
        && cs.advance_refs(1);
  case action_reserve_currency:
    return cs.fetch_ulong(32) == 0x36e6b809
        && cs.advance(8)
        && t_CurrencyCollection.validate_skip(cs, weak);
  }
  return false;
}

bool OutAction::unpack(vm::CellSlice& cs, OutAction::Record_action_send_msg& data) const {
  return cs.fetch_ulong(32) == 0xec3c86d
      && cs.fetch_uint_to(8, data.mode)
      && cs.fetch_ref_to(data.out_msg);
}

bool OutAction::unpack_action_send_msg(vm::CellSlice& cs, int& mode, Ref<Cell>& out_msg) const {
  return cs.fetch_ulong(32) == 0xec3c86d
      && cs.fetch_uint_to(8, mode)
      && cs.fetch_ref_to(out_msg);
}

bool OutAction::cell_unpack(Ref<vm::Cell> cell_ref, OutAction::Record_action_send_msg& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutAction::cell_unpack_action_send_msg(Ref<vm::Cell> cell_ref, int& mode, Ref<Cell>& out_msg) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_action_send_msg(cs, mode, out_msg) && cs.empty_ext();
}

bool OutAction::unpack(vm::CellSlice& cs, OutAction::Record_action_set_code& data) const {
  return cs.fetch_ulong(32) == 0xad4de08eU
      && cs.fetch_ref_to(data.new_code);
}

bool OutAction::unpack_action_set_code(vm::CellSlice& cs, Ref<Cell>& new_code) const {
  return cs.fetch_ulong(32) == 0xad4de08eU
      && cs.fetch_ref_to(new_code);
}

bool OutAction::cell_unpack(Ref<vm::Cell> cell_ref, OutAction::Record_action_set_code& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutAction::cell_unpack_action_set_code(Ref<vm::Cell> cell_ref, Ref<Cell>& new_code) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_action_set_code(cs, new_code) && cs.empty_ext();
}

bool OutAction::unpack(vm::CellSlice& cs, OutAction::Record_action_reserve_currency& data) const {
  return cs.fetch_ulong(32) == 0x36e6b809
      && cs.fetch_uint_to(8, data.mode)
      && t_CurrencyCollection.fetch_to(cs, data.currency);
}

bool OutAction::unpack_action_reserve_currency(vm::CellSlice& cs, int& mode, Ref<CellSlice>& currency) const {
  return cs.fetch_ulong(32) == 0x36e6b809
      && cs.fetch_uint_to(8, mode)
      && t_CurrencyCollection.fetch_to(cs, currency);
}

bool OutAction::cell_unpack(Ref<vm::Cell> cell_ref, OutAction::Record_action_reserve_currency& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutAction::cell_unpack_action_reserve_currency(Ref<vm::Cell> cell_ref, int& mode, Ref<CellSlice>& currency) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_action_reserve_currency(cs, mode, currency) && cs.empty_ext();
}

bool OutAction::pack(vm::CellBuilder& cb, const OutAction::Record_action_send_msg& data) const {
  return cb.store_long_bool(0xec3c86d, 32)
      && cb.store_ulong_rchk_bool(data.mode, 8)
      && cb.store_ref_bool(data.out_msg);
}

bool OutAction::pack_action_send_msg(vm::CellBuilder& cb, int mode, Ref<Cell> out_msg) const {
  return cb.store_long_bool(0xec3c86d, 32)
      && cb.store_ulong_rchk_bool(mode, 8)
      && cb.store_ref_bool(out_msg);
}

bool OutAction::cell_pack(Ref<vm::Cell>& cell_ref, const OutAction::Record_action_send_msg& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::cell_pack_action_send_msg(Ref<vm::Cell>& cell_ref, int mode, Ref<Cell> out_msg) const {
  vm::CellBuilder cb;
  return pack_action_send_msg(cb, mode, std::move(out_msg)) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::pack(vm::CellBuilder& cb, const OutAction::Record_action_set_code& data) const {
  return cb.store_long_bool(0xad4de08eU, 32)
      && cb.store_ref_bool(data.new_code);
}

bool OutAction::pack_action_set_code(vm::CellBuilder& cb, Ref<Cell> new_code) const {
  return cb.store_long_bool(0xad4de08eU, 32)
      && cb.store_ref_bool(new_code);
}

bool OutAction::cell_pack(Ref<vm::Cell>& cell_ref, const OutAction::Record_action_set_code& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::cell_pack_action_set_code(Ref<vm::Cell>& cell_ref, Ref<Cell> new_code) const {
  vm::CellBuilder cb;
  return pack_action_set_code(cb, std::move(new_code)) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::pack(vm::CellBuilder& cb, const OutAction::Record_action_reserve_currency& data) const {
  return cb.store_long_bool(0x36e6b809, 32)
      && cb.store_ulong_rchk_bool(data.mode, 8)
      && t_CurrencyCollection.store_from(cb, data.currency);
}

bool OutAction::pack_action_reserve_currency(vm::CellBuilder& cb, int mode, Ref<CellSlice> currency) const {
  return cb.store_long_bool(0x36e6b809, 32)
      && cb.store_ulong_rchk_bool(mode, 8)
      && t_CurrencyCollection.store_from(cb, currency);
}

bool OutAction::cell_pack(Ref<vm::Cell>& cell_ref, const OutAction::Record_action_reserve_currency& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::cell_pack_action_reserve_currency(Ref<vm::Cell>& cell_ref, int mode, Ref<CellSlice> currency) const {
  vm::CellBuilder cb;
  return pack_action_reserve_currency(cb, mode, std::move(currency)) && std::move(cb).finalize_to(cell_ref);
}

bool OutAction::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case action_send_msg: {
    int mode;
    return cs.fetch_ulong(32) == 0xec3c86d
        && pp.open("action_send_msg")
        && cs.fetch_uint_to(8, mode)
        && pp.field_int(mode, "mode")
        && pp.field("out_msg")
        && t_MessageRelaxed_Any.print_ref(pp, cs.fetch_ref())
        && pp.close();
    }
  case action_set_code:
    return cs.fetch_ulong(32) == 0xad4de08eU
        && pp.open("action_set_code")
        && pp.field("new_code")
        && t_Anything.print_ref(pp, cs.fetch_ref())
        && pp.close();
  case action_reserve_currency: {
    int mode;
    return cs.fetch_ulong(32) == 0x36e6b809
        && pp.open("action_reserve_currency")
        && cs.fetch_uint_to(8, mode)
        && pp.field_int(mode, "mode")
        && pp.field("currency")
        && t_CurrencyCollection.print_skip(pp, cs)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for OutAction");
}

const OutAction t_OutAction;

//
// code for type `OutListNode`
//

int OutListNode::check_tag(const vm::CellSlice& cs) const {
  return out_list_node;
}

bool OutListNode::skip(vm::CellSlice& cs) const {
  return cs.advance_refs(1)
      && t_OutAction.skip(cs);
}

bool OutListNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance_refs(1)
      && t_OutAction.validate_skip(cs, weak);
}

bool OutListNode::unpack(vm::CellSlice& cs, OutListNode::Record& data) const {
  return cs.fetch_ref_to(data.prev)
      && t_OutAction.fetch_to(cs, data.action);
}

bool OutListNode::unpack_out_list_node(vm::CellSlice& cs, Ref<Cell>& prev, Ref<CellSlice>& action) const {
  return cs.fetch_ref_to(prev)
      && t_OutAction.fetch_to(cs, action);
}

bool OutListNode::cell_unpack(Ref<vm::Cell> cell_ref, OutListNode::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OutListNode::cell_unpack_out_list_node(Ref<vm::Cell> cell_ref, Ref<Cell>& prev, Ref<CellSlice>& action) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_out_list_node(cs, prev, action) && cs.empty_ext();
}

bool OutListNode::pack(vm::CellBuilder& cb, const OutListNode::Record& data) const {
  return cb.store_ref_bool(data.prev)
      && t_OutAction.store_from(cb, data.action);
}

bool OutListNode::pack_out_list_node(vm::CellBuilder& cb, Ref<Cell> prev, Ref<CellSlice> action) const {
  return cb.store_ref_bool(prev)
      && t_OutAction.store_from(cb, action);
}

bool OutListNode::cell_pack(Ref<vm::Cell>& cell_ref, const OutListNode::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OutListNode::cell_pack_out_list_node(Ref<vm::Cell>& cell_ref, Ref<Cell> prev, Ref<CellSlice> action) const {
  vm::CellBuilder cb;
  return pack_out_list_node(cb, std::move(prev), std::move(action)) && std::move(cb).finalize_to(cell_ref);
}

bool OutListNode::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("out_list_node")
      && pp.field("prev")
      && t_Anything.print_ref(pp, cs.fetch_ref())
      && pp.field("action")
      && t_OutAction.print_skip(pp, cs)
      && pp.close();
}

const OutListNode t_OutListNode;

//
// code for type `ShardIdent`
//

int ShardIdent::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(2) == 0 ? shard_ident : -1;
}

bool ShardIdent::validate_skip(vm::CellSlice& cs, bool weak) const {
  int shard_pfx_bits;
  return cs.fetch_ulong(2) == 0
      && cs.fetch_uint_leq(60, shard_pfx_bits)
      && cs.advance(96);
}

bool ShardIdent::unpack(vm::CellSlice& cs, ShardIdent::Record& data) const {
  return cs.fetch_ulong(2) == 0
      && cs.fetch_uint_leq(60, data.shard_pfx_bits)
      && cs.fetch_int_to(32, data.workchain_id)
      && cs.fetch_uint_to(64, data.shard_prefix);
}

bool ShardIdent::unpack_shard_ident(vm::CellSlice& cs, int& shard_pfx_bits, int& workchain_id, unsigned long long& shard_prefix) const {
  return cs.fetch_ulong(2) == 0
      && cs.fetch_uint_leq(60, shard_pfx_bits)
      && cs.fetch_int_to(32, workchain_id)
      && cs.fetch_uint_to(64, shard_prefix);
}

bool ShardIdent::cell_unpack(Ref<vm::Cell> cell_ref, ShardIdent::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardIdent::cell_unpack_shard_ident(Ref<vm::Cell> cell_ref, int& shard_pfx_bits, int& workchain_id, unsigned long long& shard_prefix) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_shard_ident(cs, shard_pfx_bits, workchain_id, shard_prefix) && cs.empty_ext();
}

bool ShardIdent::pack(vm::CellBuilder& cb, const ShardIdent::Record& data) const {
  return cb.store_long_bool(0, 2)
      && cb.store_uint_leq(60, data.shard_pfx_bits)
      && cb.store_long_rchk_bool(data.workchain_id, 32)
      && cb.store_ulong_rchk_bool(data.shard_prefix, 64);
}

bool ShardIdent::pack_shard_ident(vm::CellBuilder& cb, int shard_pfx_bits, int workchain_id, unsigned long long shard_prefix) const {
  return cb.store_long_bool(0, 2)
      && cb.store_uint_leq(60, shard_pfx_bits)
      && cb.store_long_rchk_bool(workchain_id, 32)
      && cb.store_ulong_rchk_bool(shard_prefix, 64);
}

bool ShardIdent::cell_pack(Ref<vm::Cell>& cell_ref, const ShardIdent::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardIdent::cell_pack_shard_ident(Ref<vm::Cell>& cell_ref, int shard_pfx_bits, int workchain_id, unsigned long long shard_prefix) const {
  vm::CellBuilder cb;
  return pack_shard_ident(cb, shard_pfx_bits, workchain_id, shard_prefix) && std::move(cb).finalize_to(cell_ref);
}

bool ShardIdent::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int shard_pfx_bits;
  return cs.fetch_ulong(2) == 0
      && pp.open("shard_ident")
      && cs.fetch_uint_leq(60, shard_pfx_bits)
      && pp.field_int(shard_pfx_bits, "shard_pfx_bits")
      && pp.fetch_int_field(cs, 32, "workchain_id")
      && pp.fetch_uint_field(cs, 64, "shard_prefix")
      && pp.close();
}

const ShardIdent t_ShardIdent;

//
// code for type `ExtBlkRef`
//

int ExtBlkRef::check_tag(const vm::CellSlice& cs) const {
  return ext_blk_ref;
}

bool ExtBlkRef::unpack(vm::CellSlice& cs, ExtBlkRef::Record& data) const {
  return cs.fetch_uint_to(64, data.end_lt)
      && cs.fetch_uint_to(32, data.seq_no)
      && cs.fetch_bits_to(data.root_hash.bits(), 256)
      && cs.fetch_bits_to(data.file_hash.bits(), 256);
}

bool ExtBlkRef::cell_unpack(Ref<vm::Cell> cell_ref, ExtBlkRef::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ExtBlkRef::pack(vm::CellBuilder& cb, const ExtBlkRef::Record& data) const {
  return cb.store_ulong_rchk_bool(data.end_lt, 64)
      && cb.store_ulong_rchk_bool(data.seq_no, 32)
      && cb.store_bits_bool(data.root_hash.cbits(), 256)
      && cb.store_bits_bool(data.file_hash.cbits(), 256);
}

bool ExtBlkRef::cell_pack(Ref<vm::Cell>& cell_ref, const ExtBlkRef::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ExtBlkRef::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("ext_blk_ref")
      && pp.fetch_uint_field(cs, 64, "end_lt")
      && pp.fetch_uint_field(cs, 32, "seq_no")
      && pp.fetch_bits_field(cs, 256, "root_hash")
      && pp.fetch_bits_field(cs, 256, "file_hash")
      && pp.close();
}

const ExtBlkRef t_ExtBlkRef;

//
// code for type `BlockIdExt`
//

int BlockIdExt::check_tag(const vm::CellSlice& cs) const {
  return block_id_ext;
}

bool BlockIdExt::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_ShardIdent.validate_skip(cs, weak)
      && cs.advance(544);
}

bool BlockIdExt::unpack(vm::CellSlice& cs, BlockIdExt::Record& data) const {
  return cs.fetch_subslice_to(104, data.shard_id)
      && cs.fetch_uint_to(32, data.seq_no)
      && cs.fetch_bits_to(data.root_hash.bits(), 256)
      && cs.fetch_bits_to(data.file_hash.bits(), 256);
}

bool BlockIdExt::cell_unpack(Ref<vm::Cell> cell_ref, BlockIdExt::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockIdExt::pack(vm::CellBuilder& cb, const BlockIdExt::Record& data) const {
  return cb.append_cellslice_chk(data.shard_id, 104)
      && cb.store_ulong_rchk_bool(data.seq_no, 32)
      && cb.store_bits_bool(data.root_hash.cbits(), 256)
      && cb.store_bits_bool(data.file_hash.cbits(), 256);
}

bool BlockIdExt::cell_pack(Ref<vm::Cell>& cell_ref, const BlockIdExt::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockIdExt::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("block_id_ext")
      && pp.field("shard_id")
      && t_ShardIdent.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "seq_no")
      && pp.fetch_bits_field(cs, 256, "root_hash")
      && pp.fetch_bits_field(cs, 256, "file_hash")
      && pp.close();
}

const BlockIdExt t_BlockIdExt;

//
// code for type `BlkMasterInfo`
//

int BlkMasterInfo::check_tag(const vm::CellSlice& cs) const {
  return master_info;
}

bool BlkMasterInfo::unpack(vm::CellSlice& cs, BlkMasterInfo::Record& data) const {
  return cs.fetch_subslice_to(608, data.master);
}

bool BlkMasterInfo::unpack_master_info(vm::CellSlice& cs, Ref<CellSlice>& master) const {
  return cs.fetch_subslice_to(608, master);
}

bool BlkMasterInfo::cell_unpack(Ref<vm::Cell> cell_ref, BlkMasterInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlkMasterInfo::cell_unpack_master_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& master) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_master_info(cs, master) && cs.empty_ext();
}

bool BlkMasterInfo::pack(vm::CellBuilder& cb, const BlkMasterInfo::Record& data) const {
  return cb.append_cellslice_chk(data.master, 608);
}

bool BlkMasterInfo::pack_master_info(vm::CellBuilder& cb, Ref<CellSlice> master) const {
  return cb.append_cellslice_chk(master, 608);
}

bool BlkMasterInfo::cell_pack(Ref<vm::Cell>& cell_ref, const BlkMasterInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlkMasterInfo::cell_pack_master_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> master) const {
  vm::CellBuilder cb;
  return pack_master_info(cb, std::move(master)) && std::move(cb).finalize_to(cell_ref);
}

bool BlkMasterInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("master_info")
      && pp.field("master")
      && t_ExtBlkRef.print_skip(pp, cs)
      && pp.close();
}

const BlkMasterInfo t_BlkMasterInfo;

//
// code for auxiliary type `ShardStateUnsplit_aux`
//

int ShardStateUnsplit_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardStateUnsplit_aux::skip(vm::CellSlice& cs) const {
  return cs.advance(128)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_HashmapE_256_LibDescr.skip(cs)
      && t_Maybe_BlkMasterInfo.skip(cs);
}

bool ShardStateUnsplit_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(128)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_HashmapE_256_LibDescr.validate_skip(cs, weak)
      && t_Maybe_BlkMasterInfo.validate_skip(cs, weak);
}

bool ShardStateUnsplit_aux::unpack(vm::CellSlice& cs, ShardStateUnsplit_aux::Record& data) const {
  return cs.fetch_uint_to(64, data.overload_history)
      && cs.fetch_uint_to(64, data.underload_history)
      && t_CurrencyCollection.fetch_to(cs, data.total_balance)
      && t_CurrencyCollection.fetch_to(cs, data.total_validator_fees)
      && t_HashmapE_256_LibDescr.fetch_to(cs, data.libraries)
      && t_Maybe_BlkMasterInfo.fetch_to(cs, data.master_ref);
}

bool ShardStateUnsplit_aux::cell_unpack(Ref<vm::Cell> cell_ref, ShardStateUnsplit_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardStateUnsplit_aux::pack(vm::CellBuilder& cb, const ShardStateUnsplit_aux::Record& data) const {
  return cb.store_ulong_rchk_bool(data.overload_history, 64)
      && cb.store_ulong_rchk_bool(data.underload_history, 64)
      && t_CurrencyCollection.store_from(cb, data.total_balance)
      && t_CurrencyCollection.store_from(cb, data.total_validator_fees)
      && t_HashmapE_256_LibDescr.store_from(cb, data.libraries)
      && t_Maybe_BlkMasterInfo.store_from(cb, data.master_ref);
}

bool ShardStateUnsplit_aux::cell_pack(Ref<vm::Cell>& cell_ref, const ShardStateUnsplit_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardStateUnsplit_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.fetch_uint_field(cs, 64, "overload_history")
      && pp.fetch_uint_field(cs, 64, "underload_history")
      && pp.field("total_balance")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("total_validator_fees")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("libraries")
      && t_HashmapE_256_LibDescr.print_skip(pp, cs)
      && pp.field("master_ref")
      && t_Maybe_BlkMasterInfo.print_skip(pp, cs)
      && pp.close();
}

const ShardStateUnsplit_aux t_ShardStateUnsplit_aux;

//
// code for type `ShardStateUnsplit`
//
constexpr unsigned ShardStateUnsplit::cons_tag[1];

int ShardStateUnsplit::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x9023afe2U ? shard_state : -1;
}

bool ShardStateUnsplit::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x30169)
      && t_Maybe_Ref_McStateExtra.skip(cs);
}

bool ShardStateUnsplit::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x9023afe2U
      && cs.advance(32)
      && t_ShardIdent.validate_skip(cs, weak)
      && cs.advance(192)
      && t_OutMsgQueueInfo.validate_skip_ref(cs, weak)
      && cs.advance(1)
      && t_ShardAccounts.validate_skip_ref(cs, weak)
      && t_ShardStateUnsplit_aux.validate_skip_ref(cs, weak)
      && t_Maybe_Ref_McStateExtra.validate_skip(cs, weak);
}

bool ShardStateUnsplit::unpack(vm::CellSlice& cs, ShardStateUnsplit::Record& data) const {
  return cs.fetch_ulong(32) == 0x9023afe2U
      && cs.fetch_int_to(32, data.global_id)
      && cs.fetch_subslice_to(104, data.shard_id)
      && cs.fetch_uint_to(32, data.seq_no)
      && cs.fetch_uint_to(32, data.vert_seq_no)
      && cs.fetch_uint_to(32, data.gen_utime)
      && cs.fetch_uint_to(64, data.gen_lt)
      && cs.fetch_uint_to(32, data.min_ref_mc_seqno)
      && cs.fetch_ref_to(data.out_msg_queue_info)
      && cs.fetch_bool_to(data.before_split)
      && cs.fetch_ref_to(data.accounts)
      && t_ShardStateUnsplit_aux.cell_unpack(cs.fetch_ref(), data.r1)
      && t_Maybe_Ref_McStateExtra.fetch_to(cs, data.custom);
}

bool ShardStateUnsplit::cell_unpack(Ref<vm::Cell> cell_ref, ShardStateUnsplit::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardStateUnsplit::pack(vm::CellBuilder& cb, const ShardStateUnsplit::Record& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(0x9023afe2U, 32)
      && cb.store_long_rchk_bool(data.global_id, 32)
      && cb.append_cellslice_chk(data.shard_id, 104)
      && cb.store_ulong_rchk_bool(data.seq_no, 32)
      && cb.store_ulong_rchk_bool(data.vert_seq_no, 32)
      && cb.store_ulong_rchk_bool(data.gen_utime, 32)
      && cb.store_ulong_rchk_bool(data.gen_lt, 64)
      && cb.store_ulong_rchk_bool(data.min_ref_mc_seqno, 32)
      && cb.store_ref_bool(data.out_msg_queue_info)
      && cb.store_ulong_rchk_bool(data.before_split, 1)
      && cb.store_ref_bool(data.accounts)
      && t_ShardStateUnsplit_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell))
      && t_Maybe_Ref_McStateExtra.store_from(cb, data.custom);
}

bool ShardStateUnsplit::cell_pack(Ref<vm::Cell>& cell_ref, const ShardStateUnsplit::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardStateUnsplit::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int vert_seq_no, before_split;
  return cs.fetch_ulong(32) == 0x9023afe2U
      && pp.open("shard_state")
      && pp.fetch_int_field(cs, 32, "global_id")
      && pp.field("shard_id")
      && t_ShardIdent.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "seq_no")
      && cs.fetch_uint_to(32, vert_seq_no)
      && pp.field_int(vert_seq_no, "vert_seq_no")
      && pp.fetch_uint_field(cs, 32, "gen_utime")
      && pp.fetch_uint_field(cs, 64, "gen_lt")
      && pp.fetch_uint_field(cs, 32, "min_ref_mc_seqno")
      && pp.field("out_msg_queue_info")
      && t_OutMsgQueueInfo.print_ref(pp, cs.fetch_ref())
      && cs.fetch_bool_to(before_split)
      && pp.field_int(before_split, "before_split")
      && pp.field("accounts")
      && t_ShardAccounts.print_ref(pp, cs.fetch_ref())
      && pp.field()
      && t_ShardStateUnsplit_aux.print_ref(pp, cs.fetch_ref())
      && pp.field("custom")
      && t_Maybe_Ref_McStateExtra.print_skip(pp, cs)
      && pp.close();
}

const ShardStateUnsplit t_ShardStateUnsplit;

//
// code for type `ShardState`
//
constexpr char ShardState::cons_len[2];
constexpr unsigned ShardState::cons_tag[2];

int ShardState::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return cons1;
  case split_state:
    return cs.prefetch_ulong(32) == 0x5f327da5 ? split_state : -1;
  }
  return -1;
}

bool ShardState::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return t_ShardStateUnsplit.skip(cs);
  case split_state:
    return cs.advance_ext(0x20020);
  }
  return false;
}

bool ShardState::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case cons1:
    return t_ShardStateUnsplit.validate_skip(cs, weak);
  case split_state:
    return cs.fetch_ulong(32) == 0x5f327da5
        && t_ShardStateUnsplit.validate_skip_ref(cs, weak)
        && t_ShardStateUnsplit.validate_skip_ref(cs, weak);
  }
  return false;
}

bool ShardState::unpack(vm::CellSlice& cs, ShardState::Record_cons1& data) const {
  return t_ShardStateUnsplit.fetch_to(cs, data.x);
}

bool ShardState::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_ShardStateUnsplit.fetch_to(cs, x);
}

bool ShardState::cell_unpack(Ref<vm::Cell> cell_ref, ShardState::Record_cons1& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardState::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ShardState::unpack(vm::CellSlice& cs, ShardState::Record_split_state& data) const {
  return cs.fetch_ulong(32) == 0x5f327da5
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right);
}

bool ShardState::unpack_split_state(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right) const {
  return cs.fetch_ulong(32) == 0x5f327da5
      && cs.fetch_ref_to(left)
      && cs.fetch_ref_to(right);
}

bool ShardState::cell_unpack(Ref<vm::Cell> cell_ref, ShardState::Record_split_state& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardState::cell_unpack_split_state(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_split_state(cs, left, right) && cs.empty_ext();
}

bool ShardState::pack(vm::CellBuilder& cb, const ShardState::Record_cons1& data) const {
  return t_ShardStateUnsplit.store_from(cb, data.x);
}

bool ShardState::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_ShardStateUnsplit.store_from(cb, x);
}

bool ShardState::cell_pack(Ref<vm::Cell>& cell_ref, const ShardState::Record_cons1& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardState::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardState::pack(vm::CellBuilder& cb, const ShardState::Record_split_state& data) const {
  return cb.store_long_bool(0x5f327da5, 32)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right);
}

bool ShardState::pack_split_state(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const {
  return cb.store_long_bool(0x5f327da5, 32)
      && cb.store_ref_bool(left)
      && cb.store_ref_bool(right);
}

bool ShardState::cell_pack(Ref<vm::Cell>& cell_ref, const ShardState::Record_split_state& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardState::cell_pack_split_state(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const {
  vm::CellBuilder cb;
  return pack_split_state(cb, std::move(left), std::move(right)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardState::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return pp.open()
        && pp.field()
        && t_ShardStateUnsplit.print_skip(pp, cs)
        && pp.close();
  case split_state:
    return cs.fetch_ulong(32) == 0x5f327da5
        && pp.open("split_state")
        && pp.field("left")
        && t_ShardStateUnsplit.print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && t_ShardStateUnsplit.print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for ShardState");
}

const ShardState t_ShardState;

//
// code for type `LibDescr`
//

int LibDescr::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(2) == 0 ? shared_lib_descr : -1;
}

bool LibDescr::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x10002)
      && t_Hashmap_256_True.skip(cs);
}

bool LibDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(2) == 0
      && cs.advance_refs(1)
      && t_Hashmap_256_True.validate_skip(cs, weak);
}

bool LibDescr::unpack(vm::CellSlice& cs, LibDescr::Record& data) const {
  return cs.fetch_ulong(2) == 0
      && cs.fetch_ref_to(data.lib)
      && t_Hashmap_256_True.fetch_to(cs, data.publishers);
}

bool LibDescr::unpack_shared_lib_descr(vm::CellSlice& cs, Ref<Cell>& lib, Ref<CellSlice>& publishers) const {
  return cs.fetch_ulong(2) == 0
      && cs.fetch_ref_to(lib)
      && t_Hashmap_256_True.fetch_to(cs, publishers);
}

bool LibDescr::cell_unpack(Ref<vm::Cell> cell_ref, LibDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool LibDescr::cell_unpack_shared_lib_descr(Ref<vm::Cell> cell_ref, Ref<Cell>& lib, Ref<CellSlice>& publishers) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_shared_lib_descr(cs, lib, publishers) && cs.empty_ext();
}

bool LibDescr::pack(vm::CellBuilder& cb, const LibDescr::Record& data) const {
  return cb.store_long_bool(0, 2)
      && cb.store_ref_bool(data.lib)
      && t_Hashmap_256_True.store_from(cb, data.publishers);
}

bool LibDescr::pack_shared_lib_descr(vm::CellBuilder& cb, Ref<Cell> lib, Ref<CellSlice> publishers) const {
  return cb.store_long_bool(0, 2)
      && cb.store_ref_bool(lib)
      && t_Hashmap_256_True.store_from(cb, publishers);
}

bool LibDescr::cell_pack(Ref<vm::Cell>& cell_ref, const LibDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool LibDescr::cell_pack_shared_lib_descr(Ref<vm::Cell>& cell_ref, Ref<Cell> lib, Ref<CellSlice> publishers) const {
  vm::CellBuilder cb;
  return pack_shared_lib_descr(cb, std::move(lib), std::move(publishers)) && std::move(cb).finalize_to(cell_ref);
}

bool LibDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(2) == 0
      && pp.open("shared_lib_descr")
      && pp.field("lib")
      && t_Anything.print_ref(pp, cs.fetch_ref())
      && pp.field("publishers")
      && t_Hashmap_256_True.print_skip(pp, cs)
      && pp.close();
}

const LibDescr t_LibDescr;

//
// code for type `BlockInfo`
//
constexpr unsigned BlockInfo::cons_tag[1];

int BlockInfo::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x9bc7a987U ? block_info : -1;
}

bool BlockInfo::skip(vm::CellSlice& cs) const {
  int not_master, after_merge, vert_seqno_incr, seq_no, vert_seq_no, prev_seq_no;
  return cs.advance(64)
      && cs.fetch_bool_to(not_master)
      && cs.fetch_bool_to(after_merge)
      && cs.advance(5)
      && cs.fetch_bool_to(vert_seqno_incr)
      && cs.advance(8)
      && cs.fetch_uint_to(32, seq_no)
      && cs.fetch_uint_to(32, vert_seq_no)
      && vert_seqno_incr <= vert_seq_no
      && add_r1(prev_seq_no, 1, seq_no)
      && cs.advance(392)
      && (!not_master || cs.advance_refs(1))
      && cs.advance_refs(1)
      && (!vert_seqno_incr || cs.advance_refs(1));
}

bool BlockInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  int not_master, after_merge, vert_seqno_incr, seq_no, vert_seq_no, prev_seq_no;
  return cs.fetch_ulong(32) == 0x9bc7a987U
      && cs.advance(32)
      && cs.fetch_bool_to(not_master)
      && cs.fetch_bool_to(after_merge)
      && cs.advance(5)
      && cs.fetch_bool_to(vert_seqno_incr)
      && cs.advance(8)
      && cs.fetch_uint_to(32, seq_no)
      && cs.fetch_uint_to(32, vert_seq_no)
      && vert_seqno_incr <= vert_seq_no
      && add_r1(prev_seq_no, 1, seq_no)
      && t_ShardIdent.validate_skip(cs, weak)
      && cs.advance(288)
      && (!not_master || t_BlkMasterInfo.validate_skip_ref(cs, weak))
      && BlkPrevInfo{after_merge}.validate_skip_ref(cs, weak)
      && (!vert_seqno_incr || t_BlkPrevInfo_0.validate_skip_ref(cs, weak));
}

bool BlockInfo::unpack(vm::CellSlice& cs, BlockInfo::Record& data) const {
  int prev_seq_no;
  return cs.fetch_ulong(32) == 0x9bc7a987U
      && cs.fetch_uint_to(32, data.version)
      && cs.fetch_bool_to(data.not_master)
      && cs.fetch_bool_to(data.after_merge)
      && cs.fetch_bool_to(data.before_split)
      && cs.fetch_bool_to(data.after_split)
      && cs.fetch_bool_to(data.want_split)
      && cs.fetch_bool_to(data.want_merge)
      && cs.fetch_bool_to(data.key_block)
      && cs.fetch_bool_to(data.vert_seqno_incr)
      && cs.fetch_uint_to(8, data.flags)
      && cs.fetch_uint_to(32, data.seq_no)
      && cs.fetch_uint_to(32, data.vert_seq_no)
      && data.vert_seqno_incr <= data.vert_seq_no
      && add_r1(prev_seq_no, 1, data.seq_no)
      && cs.fetch_subslice_to(104, data.shard)
      && cs.fetch_uint_to(32, data.gen_utime)
      && cs.fetch_uint_to(64, data.start_lt)
      && cs.fetch_uint_to(64, data.end_lt)
      && cs.fetch_uint_to(32, data.gen_validator_list_hash_short)
      && cs.fetch_uint_to(32, data.gen_catchain_seqno)
      && cs.fetch_uint_to(32, data.min_ref_mc_seqno)
      && cs.fetch_uint_to(32, data.prev_key_block_seqno)
      && (!data.not_master || cs.fetch_ref_to(data.master_ref))
      && cs.fetch_ref_to(data.prev_ref)
      && (!data.vert_seqno_incr || cs.fetch_ref_to(data.prev_vert_ref));
}

bool BlockInfo::cell_unpack(Ref<vm::Cell> cell_ref, BlockInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockInfo::pack(vm::CellBuilder& cb, const BlockInfo::Record& data) const {
  int prev_seq_no;
  return cb.store_long_bool(0x9bc7a987U, 32)
      && cb.store_ulong_rchk_bool(data.version, 32)
      && cb.store_ulong_rchk_bool(data.not_master, 1)
      && cb.store_ulong_rchk_bool(data.after_merge, 1)
      && cb.store_ulong_rchk_bool(data.before_split, 1)
      && cb.store_ulong_rchk_bool(data.after_split, 1)
      && cb.store_ulong_rchk_bool(data.want_split, 1)
      && cb.store_ulong_rchk_bool(data.want_merge, 1)
      && cb.store_ulong_rchk_bool(data.key_block, 1)
      && cb.store_ulong_rchk_bool(data.vert_seqno_incr, 1)
      && cb.store_ulong_rchk_bool(data.flags, 8)
      && cb.store_ulong_rchk_bool(data.seq_no, 32)
      && cb.store_ulong_rchk_bool(data.vert_seq_no, 32)
      && data.vert_seqno_incr <= data.vert_seq_no
      && add_r1(prev_seq_no, 1, data.seq_no)
      && cb.append_cellslice_chk(data.shard, 104)
      && cb.store_ulong_rchk_bool(data.gen_utime, 32)
      && cb.store_ulong_rchk_bool(data.start_lt, 64)
      && cb.store_ulong_rchk_bool(data.end_lt, 64)
      && cb.store_ulong_rchk_bool(data.gen_validator_list_hash_short, 32)
      && cb.store_ulong_rchk_bool(data.gen_catchain_seqno, 32)
      && cb.store_ulong_rchk_bool(data.min_ref_mc_seqno, 32)
      && cb.store_ulong_rchk_bool(data.prev_key_block_seqno, 32)
      && (!data.not_master || cb.store_ref_bool(data.master_ref))
      && cb.store_ref_bool(data.prev_ref)
      && (!data.vert_seqno_incr || cb.store_ref_bool(data.prev_vert_ref));
}

bool BlockInfo::cell_pack(Ref<vm::Cell>& cell_ref, const BlockInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int not_master, after_merge, before_split, after_split, vert_seqno_incr, flags, seq_no, vert_seq_no, prev_seq_no;
  return cs.fetch_ulong(32) == 0x9bc7a987U
      && pp.open("block_info")
      && pp.fetch_uint_field(cs, 32, "version")
      && cs.fetch_bool_to(not_master)
      && pp.field_int(not_master, "not_master")
      && cs.fetch_bool_to(after_merge)
      && pp.field_int(after_merge, "after_merge")
      && cs.fetch_bool_to(before_split)
      && pp.field_int(before_split, "before_split")
      && cs.fetch_bool_to(after_split)
      && pp.field_int(after_split, "after_split")
      && pp.fetch_uint_field(cs, 1, "want_split")
      && pp.fetch_uint_field(cs, 1, "want_merge")
      && pp.fetch_uint_field(cs, 1, "key_block")
      && cs.fetch_bool_to(vert_seqno_incr)
      && pp.field_int(vert_seqno_incr, "vert_seqno_incr")
      && cs.fetch_uint_to(8, flags)
      && pp.field_int(flags, "flags")
      && cs.fetch_uint_to(32, seq_no)
      && pp.field_int(seq_no, "seq_no")
      && cs.fetch_uint_to(32, vert_seq_no)
      && pp.field_int(vert_seq_no, "vert_seq_no")
      && vert_seqno_incr <= vert_seq_no
      && add_r1(prev_seq_no, 1, seq_no)
      && pp.field("shard")
      && t_ShardIdent.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "gen_utime")
      && pp.fetch_uint_field(cs, 64, "start_lt")
      && pp.fetch_uint_field(cs, 64, "end_lt")
      && pp.fetch_uint_field(cs, 32, "gen_validator_list_hash_short")
      && pp.fetch_uint_field(cs, 32, "gen_catchain_seqno")
      && pp.fetch_uint_field(cs, 32, "min_ref_mc_seqno")
      && pp.fetch_uint_field(cs, 32, "prev_key_block_seqno")
      && (!not_master || (pp.field("master_ref") && t_BlkMasterInfo.print_ref(pp, cs.fetch_ref())))
      && pp.field("prev_ref")
      && BlkPrevInfo{after_merge}.print_ref(pp, cs.fetch_ref())
      && (!vert_seqno_incr || (pp.field("prev_vert_ref") && t_BlkPrevInfo_0.print_ref(pp, cs.fetch_ref())))
      && pp.close();
}

const BlockInfo t_BlockInfo;

//
// code for type `BlkPrevInfo`
//

int BlkPrevInfo::get_tag(const vm::CellSlice& cs) const {
  switch (m_) {
  case 0:
    return prev_blk_info;
  case 1:
    return prev_blks_info;
  default:
    return -1;
  }
}

int BlkPrevInfo::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case prev_blk_info:
    return prev_blk_info;
  case prev_blks_info:
    return prev_blks_info;
  }
  return -1;
}

bool BlkPrevInfo::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case prev_blk_info:
    return cs.advance(608)
        && m_ == 0;
  case prev_blks_info:
    return cs.advance_refs(2)
        && m_ == 1;
  }
  return false;
}

bool BlkPrevInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case prev_blk_info:
    return cs.advance(608)
        && m_ == 0;
  case prev_blks_info:
    return t_ExtBlkRef.validate_skip_ref(cs, weak)
        && t_ExtBlkRef.validate_skip_ref(cs, weak)
        && m_ == 1;
  }
  return false;
}

bool BlkPrevInfo::unpack(vm::CellSlice& cs, BlkPrevInfo::Record_prev_blk_info& data) const {
  return cs.fetch_subslice_to(608, data.prev)
      && m_ == 0;
}

bool BlkPrevInfo::unpack_prev_blk_info(vm::CellSlice& cs, Ref<CellSlice>& prev) const {
  return cs.fetch_subslice_to(608, prev)
      && m_ == 0;
}

bool BlkPrevInfo::cell_unpack(Ref<vm::Cell> cell_ref, BlkPrevInfo::Record_prev_blk_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlkPrevInfo::cell_unpack_prev_blk_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_prev_blk_info(cs, prev) && cs.empty_ext();
}

bool BlkPrevInfo::unpack(vm::CellSlice& cs, BlkPrevInfo::Record_prev_blks_info& data) const {
  return cs.fetch_ref_to(data.prev1)
      && cs.fetch_ref_to(data.prev2)
      && m_ == 1;
}

bool BlkPrevInfo::unpack_prev_blks_info(vm::CellSlice& cs, Ref<Cell>& prev1, Ref<Cell>& prev2) const {
  return cs.fetch_ref_to(prev1)
      && cs.fetch_ref_to(prev2)
      && m_ == 1;
}

bool BlkPrevInfo::cell_unpack(Ref<vm::Cell> cell_ref, BlkPrevInfo::Record_prev_blks_info& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlkPrevInfo::cell_unpack_prev_blks_info(Ref<vm::Cell> cell_ref, Ref<Cell>& prev1, Ref<Cell>& prev2) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_prev_blks_info(cs, prev1, prev2) && cs.empty_ext();
}

bool BlkPrevInfo::pack(vm::CellBuilder& cb, const BlkPrevInfo::Record_prev_blk_info& data) const {
  return cb.append_cellslice_chk(data.prev, 608)
      && m_ == 0;
}

bool BlkPrevInfo::pack_prev_blk_info(vm::CellBuilder& cb, Ref<CellSlice> prev) const {
  return cb.append_cellslice_chk(prev, 608)
      && m_ == 0;
}

bool BlkPrevInfo::cell_pack(Ref<vm::Cell>& cell_ref, const BlkPrevInfo::Record_prev_blk_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlkPrevInfo::cell_pack_prev_blk_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev) const {
  vm::CellBuilder cb;
  return pack_prev_blk_info(cb, std::move(prev)) && std::move(cb).finalize_to(cell_ref);
}

bool BlkPrevInfo::pack(vm::CellBuilder& cb, const BlkPrevInfo::Record_prev_blks_info& data) const {
  return cb.store_ref_bool(data.prev1)
      && cb.store_ref_bool(data.prev2)
      && m_ == 1;
}

bool BlkPrevInfo::pack_prev_blks_info(vm::CellBuilder& cb, Ref<Cell> prev1, Ref<Cell> prev2) const {
  return cb.store_ref_bool(prev1)
      && cb.store_ref_bool(prev2)
      && m_ == 1;
}

bool BlkPrevInfo::cell_pack(Ref<vm::Cell>& cell_ref, const BlkPrevInfo::Record_prev_blks_info& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlkPrevInfo::cell_pack_prev_blks_info(Ref<vm::Cell>& cell_ref, Ref<Cell> prev1, Ref<Cell> prev2) const {
  vm::CellBuilder cb;
  return pack_prev_blks_info(cb, std::move(prev1), std::move(prev2)) && std::move(cb).finalize_to(cell_ref);
}

bool BlkPrevInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case prev_blk_info:
    return pp.open("prev_blk_info")
        && pp.field("prev")
        && t_ExtBlkRef.print_skip(pp, cs)
        && m_ == 0
        && pp.close();
  case prev_blks_info:
    return pp.open("prev_blks_info")
        && pp.field("prev1")
        && t_ExtBlkRef.print_ref(pp, cs.fetch_ref())
        && pp.field("prev2")
        && t_ExtBlkRef.print_ref(pp, cs.fetch_ref())
        && m_ == 1
        && pp.close();
  }
  return pp.fail("unknown constructor for BlkPrevInfo");
}


//
// code for type `Block`
//
constexpr unsigned Block::cons_tag[1];

int Block::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x11ef55aa ? block : -1;
}

bool Block::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x11ef55aa
      && cs.advance(32)
      && t_BlockInfo.validate_skip_ref(cs, weak)
      && t_ValueFlow.validate_skip_ref(cs, weak)
      && t_MERKLE_UPDATE_ShardState.validate_skip_ref(cs, weak)
      && t_BlockExtra.validate_skip_ref(cs, weak);
}

bool Block::unpack(vm::CellSlice& cs, Block::Record& data) const {
  return cs.fetch_ulong(32) == 0x11ef55aa
      && cs.fetch_int_to(32, data.global_id)
      && cs.fetch_ref_to(data.info)
      && cs.fetch_ref_to(data.value_flow)
      && cs.fetch_ref_to(data.state_update)
      && cs.fetch_ref_to(data.extra);
}

bool Block::cell_unpack(Ref<vm::Cell> cell_ref, Block::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Block::pack(vm::CellBuilder& cb, const Block::Record& data) const {
  return cb.store_long_bool(0x11ef55aa, 32)
      && cb.store_long_rchk_bool(data.global_id, 32)
      && cb.store_ref_bool(data.info)
      && cb.store_ref_bool(data.value_flow)
      && cb.store_ref_bool(data.state_update)
      && cb.store_ref_bool(data.extra);
}

bool Block::cell_pack(Ref<vm::Cell>& cell_ref, const Block::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Block::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0x11ef55aa
      && pp.open("block")
      && pp.fetch_int_field(cs, 32, "global_id")
      && pp.field("info")
      && t_BlockInfo.print_ref(pp, cs.fetch_ref())
      && pp.field("value_flow")
      && t_ValueFlow.print_ref(pp, cs.fetch_ref())
      && pp.field("state_update")
      && t_MERKLE_UPDATE_ShardState.print_ref(pp, cs.fetch_ref())
      && pp.field("extra")
      && t_BlockExtra.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const Block t_Block;

//
// code for type `BlockExtra`
//
constexpr unsigned BlockExtra::cons_tag[1];

int BlockExtra::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x4a33f6fd ? block_extra : -1;
}

bool BlockExtra::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x30220)
      && t_Maybe_Ref_McBlockExtra.skip(cs);
}

bool BlockExtra::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x4a33f6fd
      && t_InMsgDescr.validate_skip_ref(cs, weak)
      && t_OutMsgDescr.validate_skip_ref(cs, weak)
      && t_ShardAccountBlocks.validate_skip_ref(cs, weak)
      && cs.advance(512)
      && t_Maybe_Ref_McBlockExtra.validate_skip(cs, weak);
}

bool BlockExtra::unpack(vm::CellSlice& cs, BlockExtra::Record& data) const {
  return cs.fetch_ulong(32) == 0x4a33f6fd
      && cs.fetch_ref_to(data.in_msg_descr)
      && cs.fetch_ref_to(data.out_msg_descr)
      && cs.fetch_ref_to(data.account_blocks)
      && cs.fetch_bits_to(data.rand_seed.bits(), 256)
      && cs.fetch_bits_to(data.created_by.bits(), 256)
      && t_Maybe_Ref_McBlockExtra.fetch_to(cs, data.custom);
}

bool BlockExtra::cell_unpack(Ref<vm::Cell> cell_ref, BlockExtra::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockExtra::pack(vm::CellBuilder& cb, const BlockExtra::Record& data) const {
  return cb.store_long_bool(0x4a33f6fd, 32)
      && cb.store_ref_bool(data.in_msg_descr)
      && cb.store_ref_bool(data.out_msg_descr)
      && cb.store_ref_bool(data.account_blocks)
      && cb.store_bits_bool(data.rand_seed.cbits(), 256)
      && cb.store_bits_bool(data.created_by.cbits(), 256)
      && t_Maybe_Ref_McBlockExtra.store_from(cb, data.custom);
}

bool BlockExtra::cell_pack(Ref<vm::Cell>& cell_ref, const BlockExtra::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockExtra::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0x4a33f6fd
      && pp.open("block_extra")
      && pp.field("in_msg_descr")
      && t_InMsgDescr.print_ref(pp, cs.fetch_ref())
      && pp.field("out_msg_descr")
      && t_OutMsgDescr.print_ref(pp, cs.fetch_ref())
      && pp.field("account_blocks")
      && t_ShardAccountBlocks.print_ref(pp, cs.fetch_ref())
      && pp.fetch_bits_field(cs, 256, "rand_seed")
      && pp.fetch_bits_field(cs, 256, "created_by")
      && pp.field("custom")
      && t_Maybe_Ref_McBlockExtra.print_skip(pp, cs)
      && pp.close();
}

const BlockExtra t_BlockExtra;

//
// code for auxiliary type `ValueFlow_aux`
//

int ValueFlow_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ValueFlow_aux::skip(vm::CellSlice& cs) const {
  return t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool ValueFlow_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ValueFlow_aux::unpack(vm::CellSlice& cs, ValueFlow_aux::Record& data) const {
  return t_CurrencyCollection.fetch_to(cs, data.from_prev_blk)
      && t_CurrencyCollection.fetch_to(cs, data.to_next_blk)
      && t_CurrencyCollection.fetch_to(cs, data.imported)
      && t_CurrencyCollection.fetch_to(cs, data.exported);
}

bool ValueFlow_aux::cell_unpack(Ref<vm::Cell> cell_ref, ValueFlow_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValueFlow_aux::pack(vm::CellBuilder& cb, const ValueFlow_aux::Record& data) const {
  return t_CurrencyCollection.store_from(cb, data.from_prev_blk)
      && t_CurrencyCollection.store_from(cb, data.to_next_blk)
      && t_CurrencyCollection.store_from(cb, data.imported)
      && t_CurrencyCollection.store_from(cb, data.exported);
}

bool ValueFlow_aux::cell_pack(Ref<vm::Cell>& cell_ref, const ValueFlow_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValueFlow_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("from_prev_blk")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("to_next_blk")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("imported")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("exported")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ValueFlow_aux t_ValueFlow_aux;

//
// code for auxiliary type `ValueFlow_aux1`
//

int ValueFlow_aux1::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ValueFlow_aux1::skip(vm::CellSlice& cs) const {
  return t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool ValueFlow_aux1::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ValueFlow_aux1::unpack(vm::CellSlice& cs, ValueFlow_aux1::Record& data) const {
  return t_CurrencyCollection.fetch_to(cs, data.fees_imported)
      && t_CurrencyCollection.fetch_to(cs, data.recovered)
      && t_CurrencyCollection.fetch_to(cs, data.created)
      && t_CurrencyCollection.fetch_to(cs, data.minted);
}

bool ValueFlow_aux1::cell_unpack(Ref<vm::Cell> cell_ref, ValueFlow_aux1::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValueFlow_aux1::pack(vm::CellBuilder& cb, const ValueFlow_aux1::Record& data) const {
  return t_CurrencyCollection.store_from(cb, data.fees_imported)
      && t_CurrencyCollection.store_from(cb, data.recovered)
      && t_CurrencyCollection.store_from(cb, data.created)
      && t_CurrencyCollection.store_from(cb, data.minted);
}

bool ValueFlow_aux1::cell_pack(Ref<vm::Cell>& cell_ref, const ValueFlow_aux1::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValueFlow_aux1::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("fees_imported")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("recovered")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("created")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("minted")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ValueFlow_aux1 t_ValueFlow_aux1;

//
// code for type `ValueFlow`
//
constexpr unsigned ValueFlow::cons_tag[1];

int ValueFlow::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0xb8e48dfbU ? value_flow : -1;
}

bool ValueFlow::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x10020)
      && t_CurrencyCollection.skip(cs)
      && cs.advance_refs(1);
}

bool ValueFlow::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0xb8e48dfbU
      && t_ValueFlow_aux.validate_skip_ref(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_ValueFlow_aux1.validate_skip_ref(cs, weak);
}

bool ValueFlow::unpack(vm::CellSlice& cs, ValueFlow::Record& data) const {
  return cs.fetch_ulong(32) == 0xb8e48dfbU
      && t_ValueFlow_aux.cell_unpack(cs.fetch_ref(), data.r1)
      && t_CurrencyCollection.fetch_to(cs, data.fees_collected)
      && t_ValueFlow_aux1.cell_unpack(cs.fetch_ref(), data.r2);
}

bool ValueFlow::cell_unpack(Ref<vm::Cell> cell_ref, ValueFlow::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValueFlow::pack(vm::CellBuilder& cb, const ValueFlow::Record& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(0xb8e48dfbU, 32)
      && t_ValueFlow_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell))
      && t_CurrencyCollection.store_from(cb, data.fees_collected)
      && t_ValueFlow_aux1.cell_pack(tmp_cell, data.r2)
      && cb.store_ref_bool(std::move(tmp_cell));
}

bool ValueFlow::cell_pack(Ref<vm::Cell>& cell_ref, const ValueFlow::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValueFlow::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0xb8e48dfbU
      && pp.open("value_flow")
      && pp.field()
      && t_ValueFlow_aux.print_ref(pp, cs.fetch_ref())
      && pp.field("fees_collected")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field()
      && t_ValueFlow_aux1.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const ValueFlow t_ValueFlow;

//
// code for type `BinTree`
//

int BinTree::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bt_leaf:
    return cs.have(1) ? bt_leaf : -1;
  case bt_fork:
    return cs.have(1) ? bt_fork : -1;
  }
  return -1;
}

bool BinTree::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bt_leaf:
    return cs.advance(1)
        && X_.skip(cs);
  case bt_fork:
    return cs.advance_ext(0x20001);
  }
  return false;
}

bool BinTree::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case bt_leaf:
    return cs.advance(1)
        && X_.validate_skip(cs, weak);
  case bt_fork:
    return cs.advance(1)
        && validate_skip_ref(cs, weak)
        && validate_skip_ref(cs, weak);
  }
  return false;
}

bool BinTree::unpack(vm::CellSlice& cs, BinTree::Record_bt_leaf& data) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, data.leaf);
}

bool BinTree::unpack_bt_leaf(vm::CellSlice& cs, Ref<CellSlice>& leaf) const {
  return cs.fetch_ulong(1) == 0
      && X_.fetch_to(cs, leaf);
}

bool BinTree::cell_unpack(Ref<vm::Cell> cell_ref, BinTree::Record_bt_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BinTree::cell_unpack_bt_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& leaf) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bt_leaf(cs, leaf) && cs.empty_ext();
}

bool BinTree::unpack(vm::CellSlice& cs, BinTree::Record_bt_fork& data) const {
  return cs.fetch_ulong(1) == 1
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right);
}

bool BinTree::unpack_bt_fork(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right) const {
  return cs.fetch_ulong(1) == 1
      && cs.fetch_ref_to(left)
      && cs.fetch_ref_to(right);
}

bool BinTree::cell_unpack(Ref<vm::Cell> cell_ref, BinTree::Record_bt_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BinTree::cell_unpack_bt_fork(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bt_fork(cs, left, right) && cs.empty_ext();
}

bool BinTree::pack(vm::CellBuilder& cb, const BinTree::Record_bt_leaf& data) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, data.leaf);
}

bool BinTree::pack_bt_leaf(vm::CellBuilder& cb, Ref<CellSlice> leaf) const {
  return cb.store_long_bool(0, 1)
      && X_.store_from(cb, leaf);
}

bool BinTree::cell_pack(Ref<vm::Cell>& cell_ref, const BinTree::Record_bt_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BinTree::cell_pack_bt_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> leaf) const {
  vm::CellBuilder cb;
  return pack_bt_leaf(cb, std::move(leaf)) && std::move(cb).finalize_to(cell_ref);
}

bool BinTree::pack(vm::CellBuilder& cb, const BinTree::Record_bt_fork& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right);
}

bool BinTree::pack_bt_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(left)
      && cb.store_ref_bool(right);
}

bool BinTree::cell_pack(Ref<vm::Cell>& cell_ref, const BinTree::Record_bt_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BinTree::cell_pack_bt_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right) const {
  vm::CellBuilder cb;
  return pack_bt_fork(cb, std::move(left), std::move(right)) && std::move(cb).finalize_to(cell_ref);
}

bool BinTree::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bt_leaf:
    return cs.advance(1)
        && pp.open("bt_leaf")
        && pp.field("leaf")
        && X_.print_skip(pp, cs)
        && pp.close();
  case bt_fork:
    return cs.advance(1)
        && pp.open("bt_fork")
        && pp.field("left")
        && print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && print_ref(pp, cs.fetch_ref())
        && pp.close();
  }
  return pp.fail("unknown constructor for BinTree");
}


//
// code for type `FutureSplitMerge`
//
constexpr char FutureSplitMerge::cons_len[3];
constexpr unsigned char FutureSplitMerge::cons_tag[3];

int FutureSplitMerge::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case fsm_none:
    return cs.have(1) ? fsm_none : -1;
  case fsm_split:
    return cs.have(2) ? fsm_split : -1;
  case fsm_merge:
    return cs.have(2) ? fsm_merge : -1;
  }
  return -1;
}

bool FutureSplitMerge::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case fsm_none:
    return cs.advance(1);
  case fsm_split:
    return cs.advance(66);
  case fsm_merge:
    return cs.advance(66);
  }
  return false;
}

bool FutureSplitMerge::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case fsm_none:
    return cs.advance(1);
  case fsm_split:
    return cs.advance(66);
  case fsm_merge:
    return cs.advance(66);
  }
  return false;
}

bool FutureSplitMerge::unpack(vm::CellSlice& cs, FutureSplitMerge::Record_fsm_none& data) const {
  return cs.fetch_ulong(1) == 0;
}

bool FutureSplitMerge::unpack_fsm_none(vm::CellSlice& cs) const {
  return cs.fetch_ulong(1) == 0;
}

bool FutureSplitMerge::cell_unpack(Ref<vm::Cell> cell_ref, FutureSplitMerge::Record_fsm_none& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool FutureSplitMerge::cell_unpack_fsm_none(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_fsm_none(cs) && cs.empty_ext();
}

bool FutureSplitMerge::unpack(vm::CellSlice& cs, FutureSplitMerge::Record_fsm_split& data) const {
  return cs.fetch_ulong(2) == 2
      && cs.fetch_uint_to(32, data.split_utime)
      && cs.fetch_uint_to(32, data.interval);
}

bool FutureSplitMerge::unpack_fsm_split(vm::CellSlice& cs, unsigned& split_utime, unsigned& interval) const {
  return cs.fetch_ulong(2) == 2
      && cs.fetch_uint_to(32, split_utime)
      && cs.fetch_uint_to(32, interval);
}

bool FutureSplitMerge::cell_unpack(Ref<vm::Cell> cell_ref, FutureSplitMerge::Record_fsm_split& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool FutureSplitMerge::cell_unpack_fsm_split(Ref<vm::Cell> cell_ref, unsigned& split_utime, unsigned& interval) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_fsm_split(cs, split_utime, interval) && cs.empty_ext();
}

bool FutureSplitMerge::unpack(vm::CellSlice& cs, FutureSplitMerge::Record_fsm_merge& data) const {
  return cs.fetch_ulong(2) == 3
      && cs.fetch_uint_to(32, data.merge_utime)
      && cs.fetch_uint_to(32, data.interval);
}

bool FutureSplitMerge::unpack_fsm_merge(vm::CellSlice& cs, unsigned& merge_utime, unsigned& interval) const {
  return cs.fetch_ulong(2) == 3
      && cs.fetch_uint_to(32, merge_utime)
      && cs.fetch_uint_to(32, interval);
}

bool FutureSplitMerge::cell_unpack(Ref<vm::Cell> cell_ref, FutureSplitMerge::Record_fsm_merge& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool FutureSplitMerge::cell_unpack_fsm_merge(Ref<vm::Cell> cell_ref, unsigned& merge_utime, unsigned& interval) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_fsm_merge(cs, merge_utime, interval) && cs.empty_ext();
}

bool FutureSplitMerge::pack(vm::CellBuilder& cb, const FutureSplitMerge::Record_fsm_none& data) const {
  return cb.store_long_bool(0, 1);
}

bool FutureSplitMerge::pack_fsm_none(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 1);
}

bool FutureSplitMerge::cell_pack(Ref<vm::Cell>& cell_ref, const FutureSplitMerge::Record_fsm_none& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::cell_pack_fsm_none(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_fsm_none(cb) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::pack(vm::CellBuilder& cb, const FutureSplitMerge::Record_fsm_split& data) const {
  return cb.store_long_bool(2, 2)
      && cb.store_ulong_rchk_bool(data.split_utime, 32)
      && cb.store_ulong_rchk_bool(data.interval, 32);
}

bool FutureSplitMerge::pack_fsm_split(vm::CellBuilder& cb, unsigned split_utime, unsigned interval) const {
  return cb.store_long_bool(2, 2)
      && cb.store_ulong_rchk_bool(split_utime, 32)
      && cb.store_ulong_rchk_bool(interval, 32);
}

bool FutureSplitMerge::cell_pack(Ref<vm::Cell>& cell_ref, const FutureSplitMerge::Record_fsm_split& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::cell_pack_fsm_split(Ref<vm::Cell>& cell_ref, unsigned split_utime, unsigned interval) const {
  vm::CellBuilder cb;
  return pack_fsm_split(cb, split_utime, interval) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::pack(vm::CellBuilder& cb, const FutureSplitMerge::Record_fsm_merge& data) const {
  return cb.store_long_bool(3, 2)
      && cb.store_ulong_rchk_bool(data.merge_utime, 32)
      && cb.store_ulong_rchk_bool(data.interval, 32);
}

bool FutureSplitMerge::pack_fsm_merge(vm::CellBuilder& cb, unsigned merge_utime, unsigned interval) const {
  return cb.store_long_bool(3, 2)
      && cb.store_ulong_rchk_bool(merge_utime, 32)
      && cb.store_ulong_rchk_bool(interval, 32);
}

bool FutureSplitMerge::cell_pack(Ref<vm::Cell>& cell_ref, const FutureSplitMerge::Record_fsm_merge& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::cell_pack_fsm_merge(Ref<vm::Cell>& cell_ref, unsigned merge_utime, unsigned interval) const {
  vm::CellBuilder cb;
  return pack_fsm_merge(cb, merge_utime, interval) && std::move(cb).finalize_to(cell_ref);
}

bool FutureSplitMerge::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case fsm_none:
    return cs.advance(1)
        && pp.cons("fsm_none");
  case fsm_split:
    return cs.advance(2)
        && pp.open("fsm_split")
        && pp.fetch_uint_field(cs, 32, "split_utime")
        && pp.fetch_uint_field(cs, 32, "interval")
        && pp.close();
  case fsm_merge:
    return cs.advance(2)
        && pp.open("fsm_merge")
        && pp.fetch_uint_field(cs, 32, "merge_utime")
        && pp.fetch_uint_field(cs, 32, "interval")
        && pp.close();
  }
  return pp.fail("unknown constructor for FutureSplitMerge");
}

const FutureSplitMerge t_FutureSplitMerge;

//
// code for type `ShardDescr`
//
constexpr unsigned char ShardDescr::cons_tag[1];

int ShardDescr::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 11 ? shard_descr : -1;
}

bool ShardDescr::skip(vm::CellSlice& cs) const {
  int flags;
  return cs.advance(713)
      && cs.fetch_uint_to(3, flags)
      && flags == 0
      && cs.advance(160)
      && t_FutureSplitMerge.skip(cs)
      && t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool ShardDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  int flags;
  return cs.fetch_ulong(4) == 11
      && cs.advance(709)
      && cs.fetch_uint_to(3, flags)
      && flags == 0
      && cs.advance(160)
      && t_FutureSplitMerge.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ShardDescr::unpack(vm::CellSlice& cs, ShardDescr::Record& data) const {
  return cs.fetch_ulong(4) == 11
      && cs.fetch_uint_to(32, data.seq_no)
      && cs.fetch_uint_to(32, data.reg_mc_seqno)
      && cs.fetch_uint_to(64, data.start_lt)
      && cs.fetch_uint_to(64, data.end_lt)
      && cs.fetch_bits_to(data.root_hash.bits(), 256)
      && cs.fetch_bits_to(data.file_hash.bits(), 256)
      && cs.fetch_bool_to(data.before_split)
      && cs.fetch_bool_to(data.before_merge)
      && cs.fetch_bool_to(data.want_split)
      && cs.fetch_bool_to(data.want_merge)
      && cs.fetch_bool_to(data.nx_cc_updated)
      && cs.fetch_uint_to(3, data.flags)
      && data.flags == 0
      && cs.fetch_uint_to(32, data.next_catchain_seqno)
      && cs.fetch_uint_to(64, data.next_validator_shard)
      && cs.fetch_uint_to(32, data.min_ref_mc_seqno)
      && cs.fetch_uint_to(32, data.gen_utime)
      && t_FutureSplitMerge.fetch_to(cs, data.split_merge_at)
      && t_CurrencyCollection.fetch_to(cs, data.fees_collected)
      && t_CurrencyCollection.fetch_to(cs, data.funds_created);
}

bool ShardDescr::cell_unpack(Ref<vm::Cell> cell_ref, ShardDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardDescr::pack(vm::CellBuilder& cb, const ShardDescr::Record& data) const {
  return cb.store_long_bool(11, 4)
      && cb.store_ulong_rchk_bool(data.seq_no, 32)
      && cb.store_ulong_rchk_bool(data.reg_mc_seqno, 32)
      && cb.store_ulong_rchk_bool(data.start_lt, 64)
      && cb.store_ulong_rchk_bool(data.end_lt, 64)
      && cb.store_bits_bool(data.root_hash.cbits(), 256)
      && cb.store_bits_bool(data.file_hash.cbits(), 256)
      && cb.store_ulong_rchk_bool(data.before_split, 1)
      && cb.store_ulong_rchk_bool(data.before_merge, 1)
      && cb.store_ulong_rchk_bool(data.want_split, 1)
      && cb.store_ulong_rchk_bool(data.want_merge, 1)
      && cb.store_ulong_rchk_bool(data.nx_cc_updated, 1)
      && cb.store_ulong_rchk_bool(data.flags, 3)
      && data.flags == 0
      && cb.store_ulong_rchk_bool(data.next_catchain_seqno, 32)
      && cb.store_ulong_rchk_bool(data.next_validator_shard, 64)
      && cb.store_ulong_rchk_bool(data.min_ref_mc_seqno, 32)
      && cb.store_ulong_rchk_bool(data.gen_utime, 32)
      && t_FutureSplitMerge.store_from(cb, data.split_merge_at)
      && t_CurrencyCollection.store_from(cb, data.fees_collected)
      && t_CurrencyCollection.store_from(cb, data.funds_created);
}

bool ShardDescr::cell_pack(Ref<vm::Cell>& cell_ref, const ShardDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int flags;
  return cs.fetch_ulong(4) == 11
      && pp.open("shard_descr")
      && pp.fetch_uint_field(cs, 32, "seq_no")
      && pp.fetch_uint_field(cs, 32, "reg_mc_seqno")
      && pp.fetch_uint_field(cs, 64, "start_lt")
      && pp.fetch_uint_field(cs, 64, "end_lt")
      && pp.fetch_bits_field(cs, 256, "root_hash")
      && pp.fetch_bits_field(cs, 256, "file_hash")
      && pp.fetch_uint_field(cs, 1, "before_split")
      && pp.fetch_uint_field(cs, 1, "before_merge")
      && pp.fetch_uint_field(cs, 1, "want_split")
      && pp.fetch_uint_field(cs, 1, "want_merge")
      && pp.fetch_uint_field(cs, 1, "nx_cc_updated")
      && cs.fetch_uint_to(3, flags)
      && pp.field_int(flags, "flags")
      && flags == 0
      && pp.fetch_uint_field(cs, 32, "next_catchain_seqno")
      && pp.fetch_uint_field(cs, 64, "next_validator_shard")
      && pp.fetch_uint_field(cs, 32, "min_ref_mc_seqno")
      && pp.fetch_uint_field(cs, 32, "gen_utime")
      && pp.field("split_merge_at")
      && t_FutureSplitMerge.print_skip(pp, cs)
      && pp.field("fees_collected")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("funds_created")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ShardDescr t_ShardDescr;

//
// code for type `ShardHashes`
//

int ShardHashes::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardHashes::skip(vm::CellSlice& cs) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.skip(cs);
}

bool ShardHashes::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.validate_skip(cs, weak);
}

bool ShardHashes::unpack(vm::CellSlice& cs, ShardHashes::Record& data) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.fetch_to(cs, data.x);
}

bool ShardHashes::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.fetch_to(cs, x);
}

bool ShardHashes::cell_unpack(Ref<vm::Cell> cell_ref, ShardHashes::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardHashes::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ShardHashes::pack(vm::CellBuilder& cb, const ShardHashes::Record& data) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.store_from(cb, data.x);
}

bool ShardHashes::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapE_32_Ref_BinTree_ShardDescr.store_from(cb, x);
}

bool ShardHashes::cell_pack(Ref<vm::Cell>& cell_ref, const ShardHashes::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardHashes::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardHashes::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapE_32_Ref_BinTree_ShardDescr.print_skip(pp, cs)
      && pp.close();
}

const ShardHashes t_ShardHashes;

//
// code for type `BinTreeAug`
//

int BinTreeAug::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bta_leaf:
    return cs.have(1) ? bta_leaf : -1;
  case bta_fork:
    return cs.have(1) ? bta_fork : -1;
  }
  return -1;
}

bool BinTreeAug::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bta_leaf:
    return cs.advance(1)
        && Y_.skip(cs)
        && X_.skip(cs);
  case bta_fork:
    return cs.advance_ext(0x20001)
        && Y_.skip(cs);
  }
  return false;
}

bool BinTreeAug::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case bta_leaf:
    return cs.advance(1)
        && Y_.validate_skip(cs, weak)
        && X_.validate_skip(cs, weak);
  case bta_fork:
    return cs.advance(1)
        && validate_skip_ref(cs, weak)
        && validate_skip_ref(cs, weak)
        && Y_.validate_skip(cs, weak);
  }
  return false;
}

bool BinTreeAug::unpack(vm::CellSlice& cs, BinTreeAug::Record_bta_leaf& data) const {
  return cs.fetch_ulong(1) == 0
      && Y_.fetch_to(cs, data.extra)
      && X_.fetch_to(cs, data.leaf);
}

bool BinTreeAug::unpack_bta_leaf(vm::CellSlice& cs, Ref<CellSlice>& extra, Ref<CellSlice>& leaf) const {
  return cs.fetch_ulong(1) == 0
      && Y_.fetch_to(cs, extra)
      && X_.fetch_to(cs, leaf);
}

bool BinTreeAug::cell_unpack(Ref<vm::Cell> cell_ref, BinTreeAug::Record_bta_leaf& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BinTreeAug::cell_unpack_bta_leaf(Ref<vm::Cell> cell_ref, Ref<CellSlice>& extra, Ref<CellSlice>& leaf) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bta_leaf(cs, extra, leaf) && cs.empty_ext();
}

bool BinTreeAug::unpack(vm::CellSlice& cs, BinTreeAug::Record_bta_fork& data) const {
  return cs.fetch_ulong(1) == 1
      && cs.fetch_ref_to(data.left)
      && cs.fetch_ref_to(data.right)
      && Y_.fetch_to(cs, data.extra);
}

bool BinTreeAug::unpack_bta_fork(vm::CellSlice& cs, Ref<Cell>& left, Ref<Cell>& right, Ref<CellSlice>& extra) const {
  return cs.fetch_ulong(1) == 1
      && cs.fetch_ref_to(left)
      && cs.fetch_ref_to(right)
      && Y_.fetch_to(cs, extra);
}

bool BinTreeAug::cell_unpack(Ref<vm::Cell> cell_ref, BinTreeAug::Record_bta_fork& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BinTreeAug::cell_unpack_bta_fork(Ref<vm::Cell> cell_ref, Ref<Cell>& left, Ref<Cell>& right, Ref<CellSlice>& extra) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_bta_fork(cs, left, right, extra) && cs.empty_ext();
}

bool BinTreeAug::pack(vm::CellBuilder& cb, const BinTreeAug::Record_bta_leaf& data) const {
  return cb.store_long_bool(0, 1)
      && Y_.store_from(cb, data.extra)
      && X_.store_from(cb, data.leaf);
}

bool BinTreeAug::pack_bta_leaf(vm::CellBuilder& cb, Ref<CellSlice> extra, Ref<CellSlice> leaf) const {
  return cb.store_long_bool(0, 1)
      && Y_.store_from(cb, extra)
      && X_.store_from(cb, leaf);
}

bool BinTreeAug::cell_pack(Ref<vm::Cell>& cell_ref, const BinTreeAug::Record_bta_leaf& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BinTreeAug::cell_pack_bta_leaf(Ref<vm::Cell>& cell_ref, Ref<CellSlice> extra, Ref<CellSlice> leaf) const {
  vm::CellBuilder cb;
  return pack_bta_leaf(cb, std::move(extra), std::move(leaf)) && std::move(cb).finalize_to(cell_ref);
}

bool BinTreeAug::pack(vm::CellBuilder& cb, const BinTreeAug::Record_bta_fork& data) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(data.left)
      && cb.store_ref_bool(data.right)
      && Y_.store_from(cb, data.extra);
}

bool BinTreeAug::pack_bta_fork(vm::CellBuilder& cb, Ref<Cell> left, Ref<Cell> right, Ref<CellSlice> extra) const {
  return cb.store_long_bool(1, 1)
      && cb.store_ref_bool(left)
      && cb.store_ref_bool(right)
      && Y_.store_from(cb, extra);
}

bool BinTreeAug::cell_pack(Ref<vm::Cell>& cell_ref, const BinTreeAug::Record_bta_fork& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BinTreeAug::cell_pack_bta_fork(Ref<vm::Cell>& cell_ref, Ref<Cell> left, Ref<Cell> right, Ref<CellSlice> extra) const {
  vm::CellBuilder cb;
  return pack_bta_fork(cb, std::move(left), std::move(right), std::move(extra)) && std::move(cb).finalize_to(cell_ref);
}

bool BinTreeAug::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case bta_leaf:
    return cs.advance(1)
        && pp.open("bta_leaf")
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.field("leaf")
        && X_.print_skip(pp, cs)
        && pp.close();
  case bta_fork:
    return cs.advance(1)
        && pp.open("bta_fork")
        && pp.field("left")
        && print_ref(pp, cs.fetch_ref())
        && pp.field("right")
        && print_ref(pp, cs.fetch_ref())
        && pp.field("extra")
        && Y_.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for BinTreeAug");
}


//
// code for type `ShardFeeCreated`
//

int ShardFeeCreated::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardFeeCreated::skip(vm::CellSlice& cs) const {
  return t_CurrencyCollection.skip(cs)
      && t_CurrencyCollection.skip(cs);
}

bool ShardFeeCreated::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CurrencyCollection.validate_skip(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ShardFeeCreated::unpack(vm::CellSlice& cs, ShardFeeCreated::Record& data) const {
  return t_CurrencyCollection.fetch_to(cs, data.fees)
      && t_CurrencyCollection.fetch_to(cs, data.create);
}

bool ShardFeeCreated::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& fees, Ref<CellSlice>& create) const {
  return t_CurrencyCollection.fetch_to(cs, fees)
      && t_CurrencyCollection.fetch_to(cs, create);
}

bool ShardFeeCreated::cell_unpack(Ref<vm::Cell> cell_ref, ShardFeeCreated::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardFeeCreated::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fees, Ref<CellSlice>& create) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, fees, create) && cs.empty_ext();
}

bool ShardFeeCreated::pack(vm::CellBuilder& cb, const ShardFeeCreated::Record& data) const {
  return t_CurrencyCollection.store_from(cb, data.fees)
      && t_CurrencyCollection.store_from(cb, data.create);
}

bool ShardFeeCreated::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> fees, Ref<CellSlice> create) const {
  return t_CurrencyCollection.store_from(cb, fees)
      && t_CurrencyCollection.store_from(cb, create);
}

bool ShardFeeCreated::cell_pack(Ref<vm::Cell>& cell_ref, const ShardFeeCreated::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardFeeCreated::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fees, Ref<CellSlice> create) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(fees), std::move(create)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardFeeCreated::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("fees")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.field("create")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const ShardFeeCreated t_ShardFeeCreated;

//
// code for type `ShardFees`
//

int ShardFees::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ShardFees::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.skip(cs);
}

bool ShardFees::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.validate_skip(cs, weak);
}

bool ShardFees::unpack(vm::CellSlice& cs, ShardFees::Record& data) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.fetch_to(cs, data.x);
}

bool ShardFees::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.fetch_to(cs, x);
}

bool ShardFees::cell_unpack(Ref<vm::Cell> cell_ref, ShardFees::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ShardFees::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool ShardFees::pack(vm::CellBuilder& cb, const ShardFees::Record& data) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.store_from(cb, data.x);
}

bool ShardFees::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.store_from(cb, x);
}

bool ShardFees::cell_pack(Ref<vm::Cell>& cell_ref, const ShardFees::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ShardFees::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ShardFees::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated.print_skip(pp, cs)
      && pp.close();
}

const ShardFees t_ShardFees;

//
// code for type `ConfigParams`
//

int ConfigParams::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool ConfigParams::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(256)
      && t_Hashmap_32_Ref_Cell.validate_skip_ref(cs, weak);
}

bool ConfigParams::unpack(vm::CellSlice& cs, ConfigParams::Record& data) const {
  return cs.fetch_bits_to(data.config_addr.bits(), 256)
      && cs.fetch_ref_to(data.config);
}

bool ConfigParams::unpack_cons1(vm::CellSlice& cs, td::BitArray<256>& config_addr, Ref<Cell>& config) const {
  return cs.fetch_bits_to(config_addr.bits(), 256)
      && cs.fetch_ref_to(config);
}

bool ConfigParams::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParams::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParams::cell_unpack_cons1(Ref<vm::Cell> cell_ref, td::BitArray<256>& config_addr, Ref<Cell>& config) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, config_addr, config) && cs.empty_ext();
}

bool ConfigParams::pack(vm::CellBuilder& cb, const ConfigParams::Record& data) const {
  return cb.store_bits_bool(data.config_addr.cbits(), 256)
      && cb.store_ref_bool(data.config);
}

bool ConfigParams::pack_cons1(vm::CellBuilder& cb, td::BitArray<256> config_addr, Ref<Cell> config) const {
  return cb.store_bits_bool(config_addr.cbits(), 256)
      && cb.store_ref_bool(config);
}

bool ConfigParams::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParams::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParams::cell_pack_cons1(Ref<vm::Cell>& cell_ref, td::BitArray<256> config_addr, Ref<Cell> config) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, config_addr, std::move(config)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParams::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.fetch_bits_field(cs, 256, "config_addr")
      && pp.field("config")
      && t_Hashmap_32_Ref_Cell.print_ref(pp, cs.fetch_ref())
      && pp.close();
}

const ConfigParams t_ConfigParams;

//
// code for type `ValidatorInfo`
//

int ValidatorInfo::check_tag(const vm::CellSlice& cs) const {
  return validator_info;
}

bool ValidatorInfo::unpack(vm::CellSlice& cs, ValidatorInfo::Record& data) const {
  return cs.fetch_uint_to(32, data.validator_list_hash_short)
      && cs.fetch_uint_to(32, data.catchain_seqno)
      && cs.fetch_bool_to(data.nx_cc_updated);
}

bool ValidatorInfo::unpack_validator_info(vm::CellSlice& cs, unsigned& validator_list_hash_short, unsigned& catchain_seqno, bool& nx_cc_updated) const {
  return cs.fetch_uint_to(32, validator_list_hash_short)
      && cs.fetch_uint_to(32, catchain_seqno)
      && cs.fetch_bool_to(nx_cc_updated);
}

bool ValidatorInfo::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorInfo::cell_unpack_validator_info(Ref<vm::Cell> cell_ref, unsigned& validator_list_hash_short, unsigned& catchain_seqno, bool& nx_cc_updated) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_validator_info(cs, validator_list_hash_short, catchain_seqno, nx_cc_updated) && cs.empty_ext();
}

bool ValidatorInfo::pack(vm::CellBuilder& cb, const ValidatorInfo::Record& data) const {
  return cb.store_ulong_rchk_bool(data.validator_list_hash_short, 32)
      && cb.store_ulong_rchk_bool(data.catchain_seqno, 32)
      && cb.store_ulong_rchk_bool(data.nx_cc_updated, 1);
}

bool ValidatorInfo::pack_validator_info(vm::CellBuilder& cb, unsigned validator_list_hash_short, unsigned catchain_seqno, bool nx_cc_updated) const {
  return cb.store_ulong_rchk_bool(validator_list_hash_short, 32)
      && cb.store_ulong_rchk_bool(catchain_seqno, 32)
      && cb.store_ulong_rchk_bool(nx_cc_updated, 1);
}

bool ValidatorInfo::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorInfo::cell_pack_validator_info(Ref<vm::Cell>& cell_ref, unsigned validator_list_hash_short, unsigned catchain_seqno, bool nx_cc_updated) const {
  vm::CellBuilder cb;
  return pack_validator_info(cb, validator_list_hash_short, catchain_seqno, nx_cc_updated) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("validator_info")
      && pp.fetch_uint_field(cs, 32, "validator_list_hash_short")
      && pp.fetch_uint_field(cs, 32, "catchain_seqno")
      && pp.fetch_uint_field(cs, 1, "nx_cc_updated")
      && pp.close();
}

const ValidatorInfo t_ValidatorInfo;

//
// code for type `ValidatorBaseInfo`
//

int ValidatorBaseInfo::check_tag(const vm::CellSlice& cs) const {
  return validator_base_info;
}

bool ValidatorBaseInfo::unpack(vm::CellSlice& cs, ValidatorBaseInfo::Record& data) const {
  return cs.fetch_uint_to(32, data.validator_list_hash_short)
      && cs.fetch_uint_to(32, data.catchain_seqno);
}

bool ValidatorBaseInfo::unpack_validator_base_info(vm::CellSlice& cs, unsigned& validator_list_hash_short, unsigned& catchain_seqno) const {
  return cs.fetch_uint_to(32, validator_list_hash_short)
      && cs.fetch_uint_to(32, catchain_seqno);
}

bool ValidatorBaseInfo::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorBaseInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorBaseInfo::cell_unpack_validator_base_info(Ref<vm::Cell> cell_ref, unsigned& validator_list_hash_short, unsigned& catchain_seqno) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_validator_base_info(cs, validator_list_hash_short, catchain_seqno) && cs.empty_ext();
}

bool ValidatorBaseInfo::pack(vm::CellBuilder& cb, const ValidatorBaseInfo::Record& data) const {
  return cb.store_ulong_rchk_bool(data.validator_list_hash_short, 32)
      && cb.store_ulong_rchk_bool(data.catchain_seqno, 32);
}

bool ValidatorBaseInfo::pack_validator_base_info(vm::CellBuilder& cb, unsigned validator_list_hash_short, unsigned catchain_seqno) const {
  return cb.store_ulong_rchk_bool(validator_list_hash_short, 32)
      && cb.store_ulong_rchk_bool(catchain_seqno, 32);
}

bool ValidatorBaseInfo::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorBaseInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorBaseInfo::cell_pack_validator_base_info(Ref<vm::Cell>& cell_ref, unsigned validator_list_hash_short, unsigned catchain_seqno) const {
  vm::CellBuilder cb;
  return pack_validator_base_info(cb, validator_list_hash_short, catchain_seqno) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorBaseInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("validator_base_info")
      && pp.fetch_uint_field(cs, 32, "validator_list_hash_short")
      && pp.fetch_uint_field(cs, 32, "catchain_seqno")
      && pp.close();
}

const ValidatorBaseInfo t_ValidatorBaseInfo;

//
// code for type `KeyMaxLt`
//

int KeyMaxLt::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool KeyMaxLt::unpack(vm::CellSlice& cs, KeyMaxLt::Record& data) const {
  return cs.fetch_bool_to(data.key)
      && cs.fetch_uint_to(64, data.max_end_lt);
}

bool KeyMaxLt::unpack_cons1(vm::CellSlice& cs, bool& key, unsigned long long& max_end_lt) const {
  return cs.fetch_bool_to(key)
      && cs.fetch_uint_to(64, max_end_lt);
}

bool KeyMaxLt::cell_unpack(Ref<vm::Cell> cell_ref, KeyMaxLt::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool KeyMaxLt::cell_unpack_cons1(Ref<vm::Cell> cell_ref, bool& key, unsigned long long& max_end_lt) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, key, max_end_lt) && cs.empty_ext();
}

bool KeyMaxLt::pack(vm::CellBuilder& cb, const KeyMaxLt::Record& data) const {
  return cb.store_ulong_rchk_bool(data.key, 1)
      && cb.store_ulong_rchk_bool(data.max_end_lt, 64);
}

bool KeyMaxLt::pack_cons1(vm::CellBuilder& cb, bool key, unsigned long long max_end_lt) const {
  return cb.store_ulong_rchk_bool(key, 1)
      && cb.store_ulong_rchk_bool(max_end_lt, 64);
}

bool KeyMaxLt::cell_pack(Ref<vm::Cell>& cell_ref, const KeyMaxLt::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool KeyMaxLt::cell_pack_cons1(Ref<vm::Cell>& cell_ref, bool key, unsigned long long max_end_lt) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, key, max_end_lt) && std::move(cb).finalize_to(cell_ref);
}

bool KeyMaxLt::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.fetch_uint_field(cs, 1, "key")
      && pp.fetch_uint_field(cs, 64, "max_end_lt")
      && pp.close();
}

const KeyMaxLt t_KeyMaxLt;

//
// code for type `KeyExtBlkRef`
//

int KeyExtBlkRef::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool KeyExtBlkRef::unpack(vm::CellSlice& cs, KeyExtBlkRef::Record& data) const {
  return cs.fetch_bool_to(data.key)
      && cs.fetch_subslice_to(608, data.blk_ref);
}

bool KeyExtBlkRef::unpack_cons1(vm::CellSlice& cs, bool& key, Ref<CellSlice>& blk_ref) const {
  return cs.fetch_bool_to(key)
      && cs.fetch_subslice_to(608, blk_ref);
}

bool KeyExtBlkRef::cell_unpack(Ref<vm::Cell> cell_ref, KeyExtBlkRef::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool KeyExtBlkRef::cell_unpack_cons1(Ref<vm::Cell> cell_ref, bool& key, Ref<CellSlice>& blk_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, key, blk_ref) && cs.empty_ext();
}

bool KeyExtBlkRef::pack(vm::CellBuilder& cb, const KeyExtBlkRef::Record& data) const {
  return cb.store_ulong_rchk_bool(data.key, 1)
      && cb.append_cellslice_chk(data.blk_ref, 608);
}

bool KeyExtBlkRef::pack_cons1(vm::CellBuilder& cb, bool key, Ref<CellSlice> blk_ref) const {
  return cb.store_ulong_rchk_bool(key, 1)
      && cb.append_cellslice_chk(blk_ref, 608);
}

bool KeyExtBlkRef::cell_pack(Ref<vm::Cell>& cell_ref, const KeyExtBlkRef::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool KeyExtBlkRef::cell_pack_cons1(Ref<vm::Cell>& cell_ref, bool key, Ref<CellSlice> blk_ref) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, key, std::move(blk_ref)) && std::move(cb).finalize_to(cell_ref);
}

bool KeyExtBlkRef::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.fetch_uint_field(cs, 1, "key")
      && pp.field("blk_ref")
      && t_ExtBlkRef.print_skip(pp, cs)
      && pp.close();
}

const KeyExtBlkRef t_KeyExtBlkRef;

//
// code for type `OldMcBlocksInfo`
//

int OldMcBlocksInfo::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool OldMcBlocksInfo::skip(vm::CellSlice& cs) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.skip(cs);
}

bool OldMcBlocksInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.validate_skip(cs, weak);
}

bool OldMcBlocksInfo::unpack(vm::CellSlice& cs, OldMcBlocksInfo::Record& data) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.fetch_to(cs, data.x);
}

bool OldMcBlocksInfo::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.fetch_to(cs, x);
}

bool OldMcBlocksInfo::cell_unpack(Ref<vm::Cell> cell_ref, OldMcBlocksInfo::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool OldMcBlocksInfo::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool OldMcBlocksInfo::pack(vm::CellBuilder& cb, const OldMcBlocksInfo::Record& data) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.store_from(cb, data.x);
}

bool OldMcBlocksInfo::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.store_from(cb, x);
}

bool OldMcBlocksInfo::cell_pack(Ref<vm::Cell>& cell_ref, const OldMcBlocksInfo::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool OldMcBlocksInfo::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool OldMcBlocksInfo::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field()
      && t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt.print_skip(pp, cs)
      && pp.close();
}

const OldMcBlocksInfo t_OldMcBlocksInfo;

//
// code for type `Counters`
//

int Counters::check_tag(const vm::CellSlice& cs) const {
  return counters;
}

bool Counters::unpack(vm::CellSlice& cs, Counters::Record& data) const {
  return cs.fetch_uint_to(32, data.last_updated)
      && cs.fetch_uint_to(64, data.total)
      && cs.fetch_uint_to(64, data.cnt2048)
      && cs.fetch_uint_to(64, data.cnt65536);
}

bool Counters::cell_unpack(Ref<vm::Cell> cell_ref, Counters::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Counters::pack(vm::CellBuilder& cb, const Counters::Record& data) const {
  return cb.store_ulong_rchk_bool(data.last_updated, 32)
      && cb.store_ulong_rchk_bool(data.total, 64)
      && cb.store_ulong_rchk_bool(data.cnt2048, 64)
      && cb.store_ulong_rchk_bool(data.cnt65536, 64);
}

bool Counters::cell_pack(Ref<vm::Cell>& cell_ref, const Counters::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Counters::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("counters")
      && pp.fetch_uint_field(cs, 32, "last_updated")
      && pp.fetch_uint_field(cs, 64, "total")
      && pp.fetch_uint_field(cs, 64, "cnt2048")
      && pp.fetch_uint_field(cs, 64, "cnt65536")
      && pp.close();
}

const Counters t_Counters;

//
// code for type `CreatorStats`
//
constexpr unsigned char CreatorStats::cons_tag[1];

int CreatorStats::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 4 ? creator_info : -1;
}

bool CreatorStats::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 4
      && cs.advance(448);
}

bool CreatorStats::unpack(vm::CellSlice& cs, CreatorStats::Record& data) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_subslice_to(224, data.mc_blocks)
      && cs.fetch_subslice_to(224, data.shard_blocks);
}

bool CreatorStats::unpack_creator_info(vm::CellSlice& cs, Ref<CellSlice>& mc_blocks, Ref<CellSlice>& shard_blocks) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_subslice_to(224, mc_blocks)
      && cs.fetch_subslice_to(224, shard_blocks);
}

bool CreatorStats::cell_unpack(Ref<vm::Cell> cell_ref, CreatorStats::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CreatorStats::cell_unpack_creator_info(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mc_blocks, Ref<CellSlice>& shard_blocks) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_creator_info(cs, mc_blocks, shard_blocks) && cs.empty_ext();
}

bool CreatorStats::pack(vm::CellBuilder& cb, const CreatorStats::Record& data) const {
  return cb.store_long_bool(4, 4)
      && cb.append_cellslice_chk(data.mc_blocks, 224)
      && cb.append_cellslice_chk(data.shard_blocks, 224);
}

bool CreatorStats::pack_creator_info(vm::CellBuilder& cb, Ref<CellSlice> mc_blocks, Ref<CellSlice> shard_blocks) const {
  return cb.store_long_bool(4, 4)
      && cb.append_cellslice_chk(mc_blocks, 224)
      && cb.append_cellslice_chk(shard_blocks, 224);
}

bool CreatorStats::cell_pack(Ref<vm::Cell>& cell_ref, const CreatorStats::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CreatorStats::cell_pack_creator_info(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mc_blocks, Ref<CellSlice> shard_blocks) const {
  vm::CellBuilder cb;
  return pack_creator_info(cb, std::move(mc_blocks), std::move(shard_blocks)) && std::move(cb).finalize_to(cell_ref);
}

bool CreatorStats::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 4
      && pp.open("creator_info")
      && pp.field("mc_blocks")
      && t_Counters.print_skip(pp, cs)
      && pp.field("shard_blocks")
      && t_Counters.print_skip(pp, cs)
      && pp.close();
}

const CreatorStats t_CreatorStats;

//
// code for type `BlockCreateStats`
//
constexpr unsigned char BlockCreateStats::cons_tag[1];

int BlockCreateStats::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 23 ? block_create_stats : -1;
}

bool BlockCreateStats::skip(vm::CellSlice& cs) const {
  return cs.advance(8)
      && t_HashmapE_256_CreatorStats.skip(cs);
}

bool BlockCreateStats::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 23
      && t_HashmapE_256_CreatorStats.validate_skip(cs, weak);
}

bool BlockCreateStats::unpack(vm::CellSlice& cs, BlockCreateStats::Record& data) const {
  return cs.fetch_ulong(8) == 23
      && t_HashmapE_256_CreatorStats.fetch_to(cs, data.counters);
}

bool BlockCreateStats::unpack_block_create_stats(vm::CellSlice& cs, Ref<CellSlice>& counters) const {
  return cs.fetch_ulong(8) == 23
      && t_HashmapE_256_CreatorStats.fetch_to(cs, counters);
}

bool BlockCreateStats::cell_unpack(Ref<vm::Cell> cell_ref, BlockCreateStats::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockCreateStats::cell_unpack_block_create_stats(Ref<vm::Cell> cell_ref, Ref<CellSlice>& counters) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_create_stats(cs, counters) && cs.empty_ext();
}

bool BlockCreateStats::pack(vm::CellBuilder& cb, const BlockCreateStats::Record& data) const {
  return cb.store_long_bool(23, 8)
      && t_HashmapE_256_CreatorStats.store_from(cb, data.counters);
}

bool BlockCreateStats::pack_block_create_stats(vm::CellBuilder& cb, Ref<CellSlice> counters) const {
  return cb.store_long_bool(23, 8)
      && t_HashmapE_256_CreatorStats.store_from(cb, counters);
}

bool BlockCreateStats::cell_pack(Ref<vm::Cell>& cell_ref, const BlockCreateStats::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockCreateStats::cell_pack_block_create_stats(Ref<vm::Cell>& cell_ref, Ref<CellSlice> counters) const {
  vm::CellBuilder cb;
  return pack_block_create_stats(cb, std::move(counters)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockCreateStats::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 23
      && pp.open("block_create_stats")
      && pp.field("counters")
      && t_HashmapE_256_CreatorStats.print_skip(pp, cs)
      && pp.close();
}

const BlockCreateStats t_BlockCreateStats;

//
// code for auxiliary type `McStateExtra_aux`
//

int McStateExtra_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool McStateExtra_aux::skip(vm::CellSlice& cs) const {
  int flags;
  return cs.fetch_uint_to(16, flags)
      && flags <= 1
      && cs.advance(65)
      && t_OldMcBlocksInfo.skip(cs)
      && cs.advance(1)
      && t_Maybe_ExtBlkRef.skip(cs)
      && (!(flags & 1) || t_BlockCreateStats.skip(cs));
}

bool McStateExtra_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  int flags;
  return cs.fetch_uint_to(16, flags)
      && flags <= 1
      && cs.advance(65)
      && t_OldMcBlocksInfo.validate_skip(cs, weak)
      && cs.advance(1)
      && t_Maybe_ExtBlkRef.validate_skip(cs, weak)
      && (!(flags & 1) || t_BlockCreateStats.validate_skip(cs, weak));
}

bool McStateExtra_aux::unpack(vm::CellSlice& cs, McStateExtra_aux::Record& data) const {
  return cs.fetch_uint_to(16, data.flags)
      && data.flags <= 1
      && cs.fetch_subslice_to(65, data.validator_info)
      && t_OldMcBlocksInfo.fetch_to(cs, data.prev_blocks)
      && cs.fetch_bool_to(data.after_key_block)
      && t_Maybe_ExtBlkRef.fetch_to(cs, data.last_key_block)
      && (!(data.flags & 1) || t_BlockCreateStats.fetch_to(cs, data.block_create_stats));
}

bool McStateExtra_aux::cell_unpack(Ref<vm::Cell> cell_ref, McStateExtra_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool McStateExtra_aux::pack(vm::CellBuilder& cb, const McStateExtra_aux::Record& data) const {
  return cb.store_ulong_rchk_bool(data.flags, 16)
      && data.flags <= 1
      && cb.append_cellslice_chk(data.validator_info, 65)
      && t_OldMcBlocksInfo.store_from(cb, data.prev_blocks)
      && cb.store_ulong_rchk_bool(data.after_key_block, 1)
      && t_Maybe_ExtBlkRef.store_from(cb, data.last_key_block)
      && (!(data.flags & 1) || t_BlockCreateStats.store_from(cb, data.block_create_stats));
}

bool McStateExtra_aux::cell_pack(Ref<vm::Cell>& cell_ref, const McStateExtra_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool McStateExtra_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int flags;
  return pp.open()
      && cs.fetch_uint_to(16, flags)
      && pp.field_int(flags, "flags")
      && flags <= 1
      && pp.field("validator_info")
      && t_ValidatorInfo.print_skip(pp, cs)
      && pp.field("prev_blocks")
      && t_OldMcBlocksInfo.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 1, "after_key_block")
      && pp.field("last_key_block")
      && t_Maybe_ExtBlkRef.print_skip(pp, cs)
      && (!(flags & 1) || (pp.field("block_create_stats") && t_BlockCreateStats.print_skip(pp, cs)))
      && pp.close();
}

const McStateExtra_aux t_McStateExtra_aux;

//
// code for type `McStateExtra`
//
constexpr unsigned short McStateExtra::cons_tag[1];

int McStateExtra::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(16) == 0xcc26 ? masterchain_state_extra : -1;
}

bool McStateExtra::skip(vm::CellSlice& cs) const {
  return cs.advance(16)
      && t_ShardHashes.skip(cs)
      && cs.advance_ext(0x20100)
      && t_CurrencyCollection.skip(cs);
}

bool McStateExtra::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(16) == 0xcc26
      && t_ShardHashes.validate_skip(cs, weak)
      && t_ConfigParams.validate_skip(cs, weak)
      && t_McStateExtra_aux.validate_skip_ref(cs, weak)
      && t_CurrencyCollection.validate_skip(cs, weak);
}

bool McStateExtra::unpack(vm::CellSlice& cs, McStateExtra::Record& data) const {
  return cs.fetch_ulong(16) == 0xcc26
      && t_ShardHashes.fetch_to(cs, data.shard_hashes)
      && cs.fetch_subslice_ext_to(0x10100, data.config)
      && t_McStateExtra_aux.cell_unpack(cs.fetch_ref(), data.r1)
      && t_CurrencyCollection.fetch_to(cs, data.global_balance);
}

bool McStateExtra::cell_unpack(Ref<vm::Cell> cell_ref, McStateExtra::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool McStateExtra::pack(vm::CellBuilder& cb, const McStateExtra::Record& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(0xcc26, 16)
      && t_ShardHashes.store_from(cb, data.shard_hashes)
      && cb.append_cellslice_chk(data.config, 0x10100)
      && t_McStateExtra_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell))
      && t_CurrencyCollection.store_from(cb, data.global_balance);
}

bool McStateExtra::cell_pack(Ref<vm::Cell>& cell_ref, const McStateExtra::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool McStateExtra::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(16) == 0xcc26
      && pp.open("masterchain_state_extra")
      && pp.field("shard_hashes")
      && t_ShardHashes.print_skip(pp, cs)
      && pp.field("config")
      && t_ConfigParams.print_skip(pp, cs)
      && pp.field()
      && t_McStateExtra_aux.print_ref(pp, cs.fetch_ref())
      && pp.field("global_balance")
      && t_CurrencyCollection.print_skip(pp, cs)
      && pp.close();
}

const McStateExtra t_McStateExtra;

//
// code for type `SigPubKey`
//
constexpr unsigned SigPubKey::cons_tag[1];

int SigPubKey::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x8e81278aU ? ed25519_pubkey : -1;
}

bool SigPubKey::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x8e81278aU
      && cs.advance(256);
}

bool SigPubKey::unpack(vm::CellSlice& cs, SigPubKey::Record& data) const {
  return cs.fetch_ulong(32) == 0x8e81278aU
      && cs.fetch_bits_to(data.pubkey.bits(), 256);
}

bool SigPubKey::unpack_ed25519_pubkey(vm::CellSlice& cs, td::BitArray<256>& pubkey) const {
  return cs.fetch_ulong(32) == 0x8e81278aU
      && cs.fetch_bits_to(pubkey.bits(), 256);
}

bool SigPubKey::cell_unpack(Ref<vm::Cell> cell_ref, SigPubKey::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool SigPubKey::cell_unpack_ed25519_pubkey(Ref<vm::Cell> cell_ref, td::BitArray<256>& pubkey) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ed25519_pubkey(cs, pubkey) && cs.empty_ext();
}

bool SigPubKey::pack(vm::CellBuilder& cb, const SigPubKey::Record& data) const {
  return cb.store_long_bool(0x8e81278aU, 32)
      && cb.store_bits_bool(data.pubkey.cbits(), 256);
}

bool SigPubKey::pack_ed25519_pubkey(vm::CellBuilder& cb, td::BitArray<256> pubkey) const {
  return cb.store_long_bool(0x8e81278aU, 32)
      && cb.store_bits_bool(pubkey.cbits(), 256);
}

bool SigPubKey::cell_pack(Ref<vm::Cell>& cell_ref, const SigPubKey::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool SigPubKey::cell_pack_ed25519_pubkey(Ref<vm::Cell>& cell_ref, td::BitArray<256> pubkey) const {
  vm::CellBuilder cb;
  return pack_ed25519_pubkey(cb, pubkey) && std::move(cb).finalize_to(cell_ref);
}

bool SigPubKey::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0x8e81278aU
      && pp.open("ed25519_pubkey")
      && pp.fetch_bits_field(cs, 256, "pubkey")
      && pp.close();
}

const SigPubKey t_SigPubKey;

//
// code for type `CryptoSignatureSimple`
//
constexpr unsigned char CryptoSignatureSimple::cons_tag[1];

int CryptoSignatureSimple::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 5 ? ed25519_signature : -1;
}

bool CryptoSignatureSimple::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 5
      && cs.advance(512);
}

bool CryptoSignatureSimple::unpack(vm::CellSlice& cs, CryptoSignatureSimple::Record& data) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_bits_to(data.R.bits(), 256)
      && cs.fetch_bits_to(data.s.bits(), 256);
}

bool CryptoSignatureSimple::unpack_ed25519_signature(vm::CellSlice& cs, td::BitArray<256>& R, td::BitArray<256>& s) const {
  return cs.fetch_ulong(4) == 5
      && cs.fetch_bits_to(R.bits(), 256)
      && cs.fetch_bits_to(s.bits(), 256);
}

bool CryptoSignatureSimple::cell_unpack(Ref<vm::Cell> cell_ref, CryptoSignatureSimple::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CryptoSignatureSimple::cell_unpack_ed25519_signature(Ref<vm::Cell> cell_ref, td::BitArray<256>& R, td::BitArray<256>& s) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_ed25519_signature(cs, R, s) && cs.empty_ext();
}

bool CryptoSignatureSimple::pack(vm::CellBuilder& cb, const CryptoSignatureSimple::Record& data) const {
  return cb.store_long_bool(5, 4)
      && cb.store_bits_bool(data.R.cbits(), 256)
      && cb.store_bits_bool(data.s.cbits(), 256);
}

bool CryptoSignatureSimple::pack_ed25519_signature(vm::CellBuilder& cb, td::BitArray<256> R, td::BitArray<256> s) const {
  return cb.store_long_bool(5, 4)
      && cb.store_bits_bool(R.cbits(), 256)
      && cb.store_bits_bool(s.cbits(), 256);
}

bool CryptoSignatureSimple::cell_pack(Ref<vm::Cell>& cell_ref, const CryptoSignatureSimple::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignatureSimple::cell_pack_ed25519_signature(Ref<vm::Cell>& cell_ref, td::BitArray<256> R, td::BitArray<256> s) const {
  vm::CellBuilder cb;
  return pack_ed25519_signature(cb, R, s) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignatureSimple::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 5
      && pp.open("ed25519_signature")
      && pp.fetch_bits_field(cs, 256, "R")
      && pp.fetch_bits_field(cs, 256, "s")
      && pp.close();
}

const CryptoSignatureSimple t_CryptoSignatureSimple;

//
// code for type `CryptoSignaturePair`
//

int CryptoSignaturePair::check_tag(const vm::CellSlice& cs) const {
  return sig_pair;
}

bool CryptoSignaturePair::skip(vm::CellSlice& cs) const {
  return cs.advance(256)
      && t_CryptoSignature.skip(cs);
}

bool CryptoSignaturePair::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(256)
      && t_CryptoSignature.validate_skip(cs, weak);
}

bool CryptoSignaturePair::unpack(vm::CellSlice& cs, CryptoSignaturePair::Record& data) const {
  return cs.fetch_bits_to(data.node_id_short.bits(), 256)
      && t_CryptoSignature.fetch_to(cs, data.sign);
}

bool CryptoSignaturePair::unpack_sig_pair(vm::CellSlice& cs, td::BitArray<256>& node_id_short, Ref<CellSlice>& sign) const {
  return cs.fetch_bits_to(node_id_short.bits(), 256)
      && t_CryptoSignature.fetch_to(cs, sign);
}

bool CryptoSignaturePair::cell_unpack(Ref<vm::Cell> cell_ref, CryptoSignaturePair::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CryptoSignaturePair::cell_unpack_sig_pair(Ref<vm::Cell> cell_ref, td::BitArray<256>& node_id_short, Ref<CellSlice>& sign) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_sig_pair(cs, node_id_short, sign) && cs.empty_ext();
}

bool CryptoSignaturePair::pack(vm::CellBuilder& cb, const CryptoSignaturePair::Record& data) const {
  return cb.store_bits_bool(data.node_id_short.cbits(), 256)
      && t_CryptoSignature.store_from(cb, data.sign);
}

bool CryptoSignaturePair::pack_sig_pair(vm::CellBuilder& cb, td::BitArray<256> node_id_short, Ref<CellSlice> sign) const {
  return cb.store_bits_bool(node_id_short.cbits(), 256)
      && t_CryptoSignature.store_from(cb, sign);
}

bool CryptoSignaturePair::cell_pack(Ref<vm::Cell>& cell_ref, const CryptoSignaturePair::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignaturePair::cell_pack_sig_pair(Ref<vm::Cell>& cell_ref, td::BitArray<256> node_id_short, Ref<CellSlice> sign) const {
  vm::CellBuilder cb;
  return pack_sig_pair(cb, node_id_short, std::move(sign)) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignaturePair::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("sig_pair")
      && pp.fetch_bits_field(cs, 256, "node_id_short")
      && pp.field("sign")
      && t_CryptoSignature.print_skip(pp, cs)
      && pp.close();
}

const CryptoSignaturePair t_CryptoSignaturePair;

//
// code for type `Certificate`
//
constexpr unsigned char Certificate::cons_tag[1];

int Certificate::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 4 ? certificate : -1;
}

bool Certificate::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 4
      && t_SigPubKey.validate_skip(cs, weak)
      && cs.advance(64);
}

bool Certificate::unpack(vm::CellSlice& cs, Certificate::Record& data) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_subslice_to(288, data.temp_key)
      && cs.fetch_uint_to(32, data.valid_since)
      && cs.fetch_uint_to(32, data.valid_until);
}

bool Certificate::unpack_certificate(vm::CellSlice& cs, Ref<CellSlice>& temp_key, unsigned& valid_since, unsigned& valid_until) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_subslice_to(288, temp_key)
      && cs.fetch_uint_to(32, valid_since)
      && cs.fetch_uint_to(32, valid_until);
}

bool Certificate::cell_unpack(Ref<vm::Cell> cell_ref, Certificate::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool Certificate::cell_unpack_certificate(Ref<vm::Cell> cell_ref, Ref<CellSlice>& temp_key, unsigned& valid_since, unsigned& valid_until) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_certificate(cs, temp_key, valid_since, valid_until) && cs.empty_ext();
}

bool Certificate::pack(vm::CellBuilder& cb, const Certificate::Record& data) const {
  return cb.store_long_bool(4, 4)
      && cb.append_cellslice_chk(data.temp_key, 288)
      && cb.store_ulong_rchk_bool(data.valid_since, 32)
      && cb.store_ulong_rchk_bool(data.valid_until, 32);
}

bool Certificate::pack_certificate(vm::CellBuilder& cb, Ref<CellSlice> temp_key, unsigned valid_since, unsigned valid_until) const {
  return cb.store_long_bool(4, 4)
      && cb.append_cellslice_chk(temp_key, 288)
      && cb.store_ulong_rchk_bool(valid_since, 32)
      && cb.store_ulong_rchk_bool(valid_until, 32);
}

bool Certificate::cell_pack(Ref<vm::Cell>& cell_ref, const Certificate::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool Certificate::cell_pack_certificate(Ref<vm::Cell>& cell_ref, Ref<CellSlice> temp_key, unsigned valid_since, unsigned valid_until) const {
  vm::CellBuilder cb;
  return pack_certificate(cb, std::move(temp_key), valid_since, valid_until) && std::move(cb).finalize_to(cell_ref);
}

bool Certificate::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 4
      && pp.open("certificate")
      && pp.field("temp_key")
      && t_SigPubKey.print_skip(pp, cs)
      && pp.fetch_uint_field(cs, 32, "valid_since")
      && pp.fetch_uint_field(cs, 32, "valid_until")
      && pp.close();
}

const Certificate t_Certificate;

//
// code for type `CertificateEnv`
//
constexpr unsigned CertificateEnv::cons_tag[1];

int CertificateEnv::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(28) == 0xa419b7d ? certificate_env : -1;
}

bool CertificateEnv::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(28) == 0xa419b7d
      && t_Certificate.validate_skip(cs, weak);
}

bool CertificateEnv::unpack(vm::CellSlice& cs, CertificateEnv::Record& data) const {
  return cs.fetch_ulong(28) == 0xa419b7d
      && cs.fetch_subslice_to(356, data.certificate);
}

bool CertificateEnv::unpack_certificate_env(vm::CellSlice& cs, Ref<CellSlice>& certificate) const {
  return cs.fetch_ulong(28) == 0xa419b7d
      && cs.fetch_subslice_to(356, certificate);
}

bool CertificateEnv::cell_unpack(Ref<vm::Cell> cell_ref, CertificateEnv::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CertificateEnv::cell_unpack_certificate_env(Ref<vm::Cell> cell_ref, Ref<CellSlice>& certificate) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_certificate_env(cs, certificate) && cs.empty_ext();
}

bool CertificateEnv::pack(vm::CellBuilder& cb, const CertificateEnv::Record& data) const {
  return cb.store_long_bool(0xa419b7d, 28)
      && cb.append_cellslice_chk(data.certificate, 356);
}

bool CertificateEnv::pack_certificate_env(vm::CellBuilder& cb, Ref<CellSlice> certificate) const {
  return cb.store_long_bool(0xa419b7d, 28)
      && cb.append_cellslice_chk(certificate, 356);
}

bool CertificateEnv::cell_pack(Ref<vm::Cell>& cell_ref, const CertificateEnv::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CertificateEnv::cell_pack_certificate_env(Ref<vm::Cell>& cell_ref, Ref<CellSlice> certificate) const {
  vm::CellBuilder cb;
  return pack_certificate_env(cb, std::move(certificate)) && std::move(cb).finalize_to(cell_ref);
}

bool CertificateEnv::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(28) == 0xa419b7d
      && pp.open("certificate_env")
      && pp.field("certificate")
      && t_Certificate.print_skip(pp, cs)
      && pp.close();
}

const CertificateEnv t_CertificateEnv;

//
// code for type `SignedCertificate`
//

int SignedCertificate::check_tag(const vm::CellSlice& cs) const {
  return signed_certificate;
}

bool SignedCertificate::skip(vm::CellSlice& cs) const {
  return cs.advance(356)
      && t_CryptoSignature.skip(cs);
}

bool SignedCertificate::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Certificate.validate_skip(cs, weak)
      && t_CryptoSignature.validate_skip(cs, weak);
}

bool SignedCertificate::unpack(vm::CellSlice& cs, SignedCertificate::Record& data) const {
  return cs.fetch_subslice_to(356, data.certificate)
      && t_CryptoSignature.fetch_to(cs, data.certificate_signature);
}

bool SignedCertificate::unpack_signed_certificate(vm::CellSlice& cs, Ref<CellSlice>& certificate, Ref<CellSlice>& certificate_signature) const {
  return cs.fetch_subslice_to(356, certificate)
      && t_CryptoSignature.fetch_to(cs, certificate_signature);
}

bool SignedCertificate::cell_unpack(Ref<vm::Cell> cell_ref, SignedCertificate::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool SignedCertificate::cell_unpack_signed_certificate(Ref<vm::Cell> cell_ref, Ref<CellSlice>& certificate, Ref<CellSlice>& certificate_signature) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_signed_certificate(cs, certificate, certificate_signature) && cs.empty_ext();
}

bool SignedCertificate::pack(vm::CellBuilder& cb, const SignedCertificate::Record& data) const {
  return cb.append_cellslice_chk(data.certificate, 356)
      && t_CryptoSignature.store_from(cb, data.certificate_signature);
}

bool SignedCertificate::pack_signed_certificate(vm::CellBuilder& cb, Ref<CellSlice> certificate, Ref<CellSlice> certificate_signature) const {
  return cb.append_cellslice_chk(certificate, 356)
      && t_CryptoSignature.store_from(cb, certificate_signature);
}

bool SignedCertificate::cell_pack(Ref<vm::Cell>& cell_ref, const SignedCertificate::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool SignedCertificate::cell_pack_signed_certificate(Ref<vm::Cell>& cell_ref, Ref<CellSlice> certificate, Ref<CellSlice> certificate_signature) const {
  vm::CellBuilder cb;
  return pack_signed_certificate(cb, std::move(certificate), std::move(certificate_signature)) && std::move(cb).finalize_to(cell_ref);
}

bool SignedCertificate::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("signed_certificate")
      && pp.field("certificate")
      && t_Certificate.print_skip(pp, cs)
      && pp.field("certificate_signature")
      && t_CryptoSignature.print_skip(pp, cs)
      && pp.close();
}

const SignedCertificate t_SignedCertificate;

//
// code for type `CryptoSignature`
//
constexpr char CryptoSignature::cons_len[2];
constexpr unsigned char CryptoSignature::cons_tag[2];

int CryptoSignature::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return cons1;
  case chained_signature:
    return cs.prefetch_ulong(4) == 15 ? chained_signature : -1;
  }
  return -1;
}

bool CryptoSignature::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return cs.advance(516);
  case chained_signature:
    return cs.advance_ext(0x10208);
  }
  return false;
}

bool CryptoSignature::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case cons1:
    return t_CryptoSignatureSimple.validate_skip(cs, weak);
  case chained_signature:
    return cs.fetch_ulong(4) == 15
        && t_SignedCertificate.validate_skip_ref(cs, weak)
        && t_CryptoSignatureSimple.validate_skip(cs, weak);
  }
  return false;
}

bool CryptoSignature::unpack(vm::CellSlice& cs, CryptoSignature::Record_cons1& data) const {
  return cs.fetch_subslice_to(516, data.x);
}

bool CryptoSignature::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(516, x);
}

bool CryptoSignature::cell_unpack(Ref<vm::Cell> cell_ref, CryptoSignature::Record_cons1& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CryptoSignature::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, x) && cs.empty_ext();
}

bool CryptoSignature::unpack(vm::CellSlice& cs, CryptoSignature::Record_chained_signature& data) const {
  return cs.fetch_ulong(4) == 15
      && cs.fetch_ref_to(data.signed_cert)
      && cs.fetch_subslice_to(516, data.temp_key_signature);
}

bool CryptoSignature::unpack_chained_signature(vm::CellSlice& cs, Ref<Cell>& signed_cert, Ref<CellSlice>& temp_key_signature) const {
  return cs.fetch_ulong(4) == 15
      && cs.fetch_ref_to(signed_cert)
      && cs.fetch_subslice_to(516, temp_key_signature);
}

bool CryptoSignature::cell_unpack(Ref<vm::Cell> cell_ref, CryptoSignature::Record_chained_signature& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CryptoSignature::cell_unpack_chained_signature(Ref<vm::Cell> cell_ref, Ref<Cell>& signed_cert, Ref<CellSlice>& temp_key_signature) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_chained_signature(cs, signed_cert, temp_key_signature) && cs.empty_ext();
}

bool CryptoSignature::pack(vm::CellBuilder& cb, const CryptoSignature::Record_cons1& data) const {
  return cb.append_cellslice_chk(data.x, 516);
}

bool CryptoSignature::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 516);
}

bool CryptoSignature::cell_pack(Ref<vm::Cell>& cell_ref, const CryptoSignature::Record_cons1& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignature::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignature::pack(vm::CellBuilder& cb, const CryptoSignature::Record_chained_signature& data) const {
  return cb.store_long_bool(15, 4)
      && cb.store_ref_bool(data.signed_cert)
      && cb.append_cellslice_chk(data.temp_key_signature, 516);
}

bool CryptoSignature::pack_chained_signature(vm::CellBuilder& cb, Ref<Cell> signed_cert, Ref<CellSlice> temp_key_signature) const {
  return cb.store_long_bool(15, 4)
      && cb.store_ref_bool(signed_cert)
      && cb.append_cellslice_chk(temp_key_signature, 516);
}

bool CryptoSignature::cell_pack(Ref<vm::Cell>& cell_ref, const CryptoSignature::Record_chained_signature& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignature::cell_pack_chained_signature(Ref<vm::Cell>& cell_ref, Ref<Cell> signed_cert, Ref<CellSlice> temp_key_signature) const {
  vm::CellBuilder cb;
  return pack_chained_signature(cb, std::move(signed_cert), std::move(temp_key_signature)) && std::move(cb).finalize_to(cell_ref);
}

bool CryptoSignature::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons1:
    return pp.open()
        && pp.field()
        && t_CryptoSignatureSimple.print_skip(pp, cs)
        && pp.close();
  case chained_signature:
    return cs.fetch_ulong(4) == 15
        && pp.open("chained_signature")
        && pp.field("signed_cert")
        && t_SignedCertificate.print_ref(pp, cs.fetch_ref())
        && pp.field("temp_key_signature")
        && t_CryptoSignatureSimple.print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for CryptoSignature");
}

const CryptoSignature t_CryptoSignature;

//
// code for auxiliary type `McBlockExtra_aux`
//

int McBlockExtra_aux::check_tag(const vm::CellSlice& cs) const {
  return cons1;
}

bool McBlockExtra_aux::skip(vm::CellSlice& cs) const {
  return t_HashmapE_16_CryptoSignaturePair.skip(cs)
      && t_Maybe_Ref_InMsg.skip(cs)
      && t_Maybe_Ref_InMsg.skip(cs);
}

bool McBlockExtra_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_HashmapE_16_CryptoSignaturePair.validate_skip(cs, weak)
      && t_Maybe_Ref_InMsg.validate_skip(cs, weak)
      && t_Maybe_Ref_InMsg.validate_skip(cs, weak);
}

bool McBlockExtra_aux::unpack(vm::CellSlice& cs, McBlockExtra_aux::Record& data) const {
  return t_HashmapE_16_CryptoSignaturePair.fetch_to(cs, data.prev_blk_signatures)
      && t_Maybe_Ref_InMsg.fetch_to(cs, data.recover_create_msg)
      && t_Maybe_Ref_InMsg.fetch_to(cs, data.mint_msg);
}

bool McBlockExtra_aux::unpack_cons1(vm::CellSlice& cs, Ref<CellSlice>& prev_blk_signatures, Ref<CellSlice>& recover_create_msg, Ref<CellSlice>& mint_msg) const {
  return t_HashmapE_16_CryptoSignaturePair.fetch_to(cs, prev_blk_signatures)
      && t_Maybe_Ref_InMsg.fetch_to(cs, recover_create_msg)
      && t_Maybe_Ref_InMsg.fetch_to(cs, mint_msg);
}

bool McBlockExtra_aux::cell_unpack(Ref<vm::Cell> cell_ref, McBlockExtra_aux::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool McBlockExtra_aux::cell_unpack_cons1(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_blk_signatures, Ref<CellSlice>& recover_create_msg, Ref<CellSlice>& mint_msg) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, prev_blk_signatures, recover_create_msg, mint_msg) && cs.empty_ext();
}

bool McBlockExtra_aux::pack(vm::CellBuilder& cb, const McBlockExtra_aux::Record& data) const {
  return t_HashmapE_16_CryptoSignaturePair.store_from(cb, data.prev_blk_signatures)
      && t_Maybe_Ref_InMsg.store_from(cb, data.recover_create_msg)
      && t_Maybe_Ref_InMsg.store_from(cb, data.mint_msg);
}

bool McBlockExtra_aux::pack_cons1(vm::CellBuilder& cb, Ref<CellSlice> prev_blk_signatures, Ref<CellSlice> recover_create_msg, Ref<CellSlice> mint_msg) const {
  return t_HashmapE_16_CryptoSignaturePair.store_from(cb, prev_blk_signatures)
      && t_Maybe_Ref_InMsg.store_from(cb, recover_create_msg)
      && t_Maybe_Ref_InMsg.store_from(cb, mint_msg);
}

bool McBlockExtra_aux::cell_pack(Ref<vm::Cell>& cell_ref, const McBlockExtra_aux::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool McBlockExtra_aux::cell_pack_cons1(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_blk_signatures, Ref<CellSlice> recover_create_msg, Ref<CellSlice> mint_msg) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, std::move(prev_blk_signatures), std::move(recover_create_msg), std::move(mint_msg)) && std::move(cb).finalize_to(cell_ref);
}

bool McBlockExtra_aux::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open()
      && pp.field("prev_blk_signatures")
      && t_HashmapE_16_CryptoSignaturePair.print_skip(pp, cs)
      && pp.field("recover_create_msg")
      && t_Maybe_Ref_InMsg.print_skip(pp, cs)
      && pp.field("mint_msg")
      && t_Maybe_Ref_InMsg.print_skip(pp, cs)
      && pp.close();
}

const McBlockExtra_aux t_McBlockExtra_aux;

//
// code for type `McBlockExtra`
//
constexpr unsigned short McBlockExtra::cons_tag[1];

int McBlockExtra::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(16) == 0xcca5 ? masterchain_block_extra : -1;
}

bool McBlockExtra::skip(vm::CellSlice& cs) const {
  int key_block;
  return cs.advance(16)
      && cs.fetch_bool_to(key_block)
      && t_ShardHashes.skip(cs)
      && t_ShardFees.skip(cs)
      && cs.advance_refs(1)
      && (!key_block || t_ConfigParams.skip(cs));
}

bool McBlockExtra::validate_skip(vm::CellSlice& cs, bool weak) const {
  int key_block;
  return cs.fetch_ulong(16) == 0xcca5
      && cs.fetch_bool_to(key_block)
      && t_ShardHashes.validate_skip(cs, weak)
      && t_ShardFees.validate_skip(cs, weak)
      && t_McBlockExtra_aux.validate_skip_ref(cs, weak)
      && (!key_block || t_ConfigParams.validate_skip(cs, weak));
}

bool McBlockExtra::unpack(vm::CellSlice& cs, McBlockExtra::Record& data) const {
  return cs.fetch_ulong(16) == 0xcca5
      && cs.fetch_bool_to(data.key_block)
      && t_ShardHashes.fetch_to(cs, data.shard_hashes)
      && t_ShardFees.fetch_to(cs, data.shard_fees)
      && t_McBlockExtra_aux.cell_unpack(cs.fetch_ref(), data.r1)
      && (!data.key_block || t_ConfigParams.fetch_to(cs, data.config));
}

bool McBlockExtra::cell_unpack(Ref<vm::Cell> cell_ref, McBlockExtra::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool McBlockExtra::pack(vm::CellBuilder& cb, const McBlockExtra::Record& data) const {
  Ref<vm::Cell> tmp_cell;
  return cb.store_long_bool(0xcca5, 16)
      && cb.store_ulong_rchk_bool(data.key_block, 1)
      && t_ShardHashes.store_from(cb, data.shard_hashes)
      && t_ShardFees.store_from(cb, data.shard_fees)
      && t_McBlockExtra_aux.cell_pack(tmp_cell, data.r1)
      && cb.store_ref_bool(std::move(tmp_cell))
      && (!data.key_block || t_ConfigParams.store_from(cb, data.config));
}

bool McBlockExtra::cell_pack(Ref<vm::Cell>& cell_ref, const McBlockExtra::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool McBlockExtra::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int key_block;
  return cs.fetch_ulong(16) == 0xcca5
      && pp.open("masterchain_block_extra")
      && cs.fetch_bool_to(key_block)
      && pp.field_int(key_block, "key_block")
      && pp.field("shard_hashes")
      && t_ShardHashes.print_skip(pp, cs)
      && pp.field("shard_fees")
      && t_ShardFees.print_skip(pp, cs)
      && pp.field()
      && t_McBlockExtra_aux.print_ref(pp, cs.fetch_ref())
      && (!key_block || (pp.field("config") && t_ConfigParams.print_skip(pp, cs)))
      && pp.close();
}

const McBlockExtra t_McBlockExtra;

//
// code for type `ValidatorDescr`
//
constexpr unsigned char ValidatorDescr::cons_tag[2];

int ValidatorDescr::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validator:
    return cs.prefetch_ulong(8) == 0x53 ? validator : -1;
  case validator_addr:
    return cs.prefetch_ulong(8) == 0x73 ? validator_addr : -1;
  }
  return -1;
}

bool ValidatorDescr::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validator:
    return cs.advance(360);
  case validator_addr:
    return cs.advance(616);
  }
  return false;
}

bool ValidatorDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case validator:
    return cs.fetch_ulong(8) == 0x53
        && t_SigPubKey.validate_skip(cs, weak)
        && cs.advance(64);
  case validator_addr:
    return cs.fetch_ulong(8) == 0x73
        && t_SigPubKey.validate_skip(cs, weak)
        && cs.advance(320);
  }
  return false;
}

bool ValidatorDescr::unpack(vm::CellSlice& cs, ValidatorDescr::Record_validator& data) const {
  return cs.fetch_ulong(8) == 0x53
      && cs.fetch_subslice_to(288, data.public_key)
      && cs.fetch_uint_to(64, data.weight);
}

bool ValidatorDescr::unpack_validator(vm::CellSlice& cs, Ref<CellSlice>& public_key, unsigned long long& weight) const {
  return cs.fetch_ulong(8) == 0x53
      && cs.fetch_subslice_to(288, public_key)
      && cs.fetch_uint_to(64, weight);
}

bool ValidatorDescr::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorDescr::Record_validator& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorDescr::cell_unpack_validator(Ref<vm::Cell> cell_ref, Ref<CellSlice>& public_key, unsigned long long& weight) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_validator(cs, public_key, weight) && cs.empty_ext();
}

bool ValidatorDescr::unpack(vm::CellSlice& cs, ValidatorDescr::Record_validator_addr& data) const {
  return cs.fetch_ulong(8) == 0x73
      && cs.fetch_subslice_to(288, data.public_key)
      && cs.fetch_uint_to(64, data.weight)
      && cs.fetch_bits_to(data.adnl_addr.bits(), 256);
}

bool ValidatorDescr::unpack_validator_addr(vm::CellSlice& cs, Ref<CellSlice>& public_key, unsigned long long& weight, td::BitArray<256>& adnl_addr) const {
  return cs.fetch_ulong(8) == 0x73
      && cs.fetch_subslice_to(288, public_key)
      && cs.fetch_uint_to(64, weight)
      && cs.fetch_bits_to(adnl_addr.bits(), 256);
}

bool ValidatorDescr::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorDescr::Record_validator_addr& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorDescr::cell_unpack_validator_addr(Ref<vm::Cell> cell_ref, Ref<CellSlice>& public_key, unsigned long long& weight, td::BitArray<256>& adnl_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_validator_addr(cs, public_key, weight, adnl_addr) && cs.empty_ext();
}

bool ValidatorDescr::pack(vm::CellBuilder& cb, const ValidatorDescr::Record_validator& data) const {
  return cb.store_long_bool(0x53, 8)
      && cb.append_cellslice_chk(data.public_key, 288)
      && cb.store_ulong_rchk_bool(data.weight, 64);
}

bool ValidatorDescr::pack_validator(vm::CellBuilder& cb, Ref<CellSlice> public_key, unsigned long long weight) const {
  return cb.store_long_bool(0x53, 8)
      && cb.append_cellslice_chk(public_key, 288)
      && cb.store_ulong_rchk_bool(weight, 64);
}

bool ValidatorDescr::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorDescr::Record_validator& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorDescr::cell_pack_validator(Ref<vm::Cell>& cell_ref, Ref<CellSlice> public_key, unsigned long long weight) const {
  vm::CellBuilder cb;
  return pack_validator(cb, std::move(public_key), weight) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorDescr::pack(vm::CellBuilder& cb, const ValidatorDescr::Record_validator_addr& data) const {
  return cb.store_long_bool(0x73, 8)
      && cb.append_cellslice_chk(data.public_key, 288)
      && cb.store_ulong_rchk_bool(data.weight, 64)
      && cb.store_bits_bool(data.adnl_addr.cbits(), 256);
}

bool ValidatorDescr::pack_validator_addr(vm::CellBuilder& cb, Ref<CellSlice> public_key, unsigned long long weight, td::BitArray<256> adnl_addr) const {
  return cb.store_long_bool(0x73, 8)
      && cb.append_cellslice_chk(public_key, 288)
      && cb.store_ulong_rchk_bool(weight, 64)
      && cb.store_bits_bool(adnl_addr.cbits(), 256);
}

bool ValidatorDescr::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorDescr::Record_validator_addr& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorDescr::cell_pack_validator_addr(Ref<vm::Cell>& cell_ref, Ref<CellSlice> public_key, unsigned long long weight, td::BitArray<256> adnl_addr) const {
  vm::CellBuilder cb;
  return pack_validator_addr(cb, std::move(public_key), weight, adnl_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validator:
    return cs.fetch_ulong(8) == 0x53
        && pp.open("validator")
        && pp.field("public_key")
        && t_SigPubKey.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "weight")
        && pp.close();
  case validator_addr:
    return cs.fetch_ulong(8) == 0x73
        && pp.open("validator_addr")
        && pp.field("public_key")
        && t_SigPubKey.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 64, "weight")
        && pp.fetch_bits_field(cs, 256, "adnl_addr")
        && pp.close();
  }
  return pp.fail("unknown constructor for ValidatorDescr");
}

const ValidatorDescr t_ValidatorDescr;

//
// code for type `ValidatorSet`
//
constexpr unsigned char ValidatorSet::cons_tag[2];

int ValidatorSet::get_tag(const vm::CellSlice& cs) const {
  switch (cs.bselect(6, 0x30)) {
  case 0:
    return cs.bit_at(6) ? validators_ext : validators;
  default:
    return -1;
  }
}

int ValidatorSet::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validators:
    return cs.prefetch_ulong(8) == 17 ? validators : -1;
  case validators_ext:
    return cs.prefetch_ulong(8) == 18 ? validators_ext : -1;
  }
  return -1;
}

bool ValidatorSet::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validators: {
    int total, main;
    return cs.advance(72)
        && cs.fetch_uint_to(16, total)
        && cs.fetch_uint_to(16, main)
        && main <= total
        && 1 <= main
        && t_Hashmap_16_ValidatorDescr.skip(cs);
    }
  case validators_ext: {
    int total, main;
    return cs.advance(72)
        && cs.fetch_uint_to(16, total)
        && cs.fetch_uint_to(16, main)
        && main <= total
        && 1 <= main
        && cs.advance(64)
        && t_HashmapE_16_ValidatorDescr.skip(cs);
    }
  }
  return false;
}

bool ValidatorSet::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case validators: {
    int total, main;
    return cs.fetch_ulong(8) == 17
        && cs.advance(64)
        && cs.fetch_uint_to(16, total)
        && cs.fetch_uint_to(16, main)
        && main <= total
        && 1 <= main
        && t_Hashmap_16_ValidatorDescr.validate_skip(cs, weak);
    }
  case validators_ext: {
    int total, main;
    return cs.fetch_ulong(8) == 18
        && cs.advance(64)
        && cs.fetch_uint_to(16, total)
        && cs.fetch_uint_to(16, main)
        && main <= total
        && 1 <= main
        && cs.advance(64)
        && t_HashmapE_16_ValidatorDescr.validate_skip(cs, weak);
    }
  }
  return false;
}

bool ValidatorSet::unpack(vm::CellSlice& cs, ValidatorSet::Record_validators& data) const {
  return cs.fetch_ulong(8) == 17
      && cs.fetch_uint_to(32, data.utime_since)
      && cs.fetch_uint_to(32, data.utime_until)
      && cs.fetch_uint_to(16, data.total)
      && cs.fetch_uint_to(16, data.main)
      && data.main <= data.total
      && 1 <= data.main
      && t_Hashmap_16_ValidatorDescr.fetch_to(cs, data.list);
}

bool ValidatorSet::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorSet::Record_validators& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorSet::unpack(vm::CellSlice& cs, ValidatorSet::Record_validators_ext& data) const {
  return cs.fetch_ulong(8) == 18
      && cs.fetch_uint_to(32, data.utime_since)
      && cs.fetch_uint_to(32, data.utime_until)
      && cs.fetch_uint_to(16, data.total)
      && cs.fetch_uint_to(16, data.main)
      && data.main <= data.total
      && 1 <= data.main
      && cs.fetch_uint_to(64, data.total_weight)
      && t_HashmapE_16_ValidatorDescr.fetch_to(cs, data.list);
}

bool ValidatorSet::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorSet::Record_validators_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorSet::pack(vm::CellBuilder& cb, const ValidatorSet::Record_validators& data) const {
  return cb.store_long_bool(17, 8)
      && cb.store_ulong_rchk_bool(data.utime_since, 32)
      && cb.store_ulong_rchk_bool(data.utime_until, 32)
      && cb.store_ulong_rchk_bool(data.total, 16)
      && cb.store_ulong_rchk_bool(data.main, 16)
      && data.main <= data.total
      && 1 <= data.main
      && t_Hashmap_16_ValidatorDescr.store_from(cb, data.list);
}

bool ValidatorSet::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorSet::Record_validators& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorSet::pack(vm::CellBuilder& cb, const ValidatorSet::Record_validators_ext& data) const {
  return cb.store_long_bool(18, 8)
      && cb.store_ulong_rchk_bool(data.utime_since, 32)
      && cb.store_ulong_rchk_bool(data.utime_until, 32)
      && cb.store_ulong_rchk_bool(data.total, 16)
      && cb.store_ulong_rchk_bool(data.main, 16)
      && data.main <= data.total
      && 1 <= data.main
      && cb.store_ulong_rchk_bool(data.total_weight, 64)
      && t_HashmapE_16_ValidatorDescr.store_from(cb, data.list);
}

bool ValidatorSet::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorSet::Record_validators_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorSet::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case validators: {
    int total, main;
    return cs.fetch_ulong(8) == 17
        && pp.open("validators")
        && pp.fetch_uint_field(cs, 32, "utime_since")
        && pp.fetch_uint_field(cs, 32, "utime_until")
        && cs.fetch_uint_to(16, total)
        && pp.field_int(total, "total")
        && cs.fetch_uint_to(16, main)
        && pp.field_int(main, "main")
        && main <= total
        && 1 <= main
        && pp.field("list")
        && t_Hashmap_16_ValidatorDescr.print_skip(pp, cs)
        && pp.close();
    }
  case validators_ext: {
    int total, main;
    return cs.fetch_ulong(8) == 18
        && pp.open("validators_ext")
        && pp.fetch_uint_field(cs, 32, "utime_since")
        && pp.fetch_uint_field(cs, 32, "utime_until")
        && cs.fetch_uint_to(16, total)
        && pp.field_int(total, "total")
        && cs.fetch_uint_to(16, main)
        && pp.field_int(main, "main")
        && main <= total
        && 1 <= main
        && pp.fetch_uint_field(cs, 64, "total_weight")
        && pp.field("list")
        && t_HashmapE_16_ValidatorDescr.print_skip(pp, cs)
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for ValidatorSet");
}

const ValidatorSet t_ValidatorSet;

//
// code for type `GlobalVersion`
//
constexpr unsigned char GlobalVersion::cons_tag[1];

int GlobalVersion::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xc4 ? capabilities : -1;
}

bool GlobalVersion::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0xc4
      && cs.advance(96);
}

bool GlobalVersion::unpack(vm::CellSlice& cs, GlobalVersion::Record& data) const {
  return cs.fetch_ulong(8) == 0xc4
      && cs.fetch_uint_to(32, data.version)
      && cs.fetch_uint_to(64, data.capabilities);
}

bool GlobalVersion::unpack_capabilities(vm::CellSlice& cs, unsigned& version, unsigned long long& capabilities) const {
  return cs.fetch_ulong(8) == 0xc4
      && cs.fetch_uint_to(32, version)
      && cs.fetch_uint_to(64, capabilities);
}

bool GlobalVersion::cell_unpack(Ref<vm::Cell> cell_ref, GlobalVersion::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool GlobalVersion::cell_unpack_capabilities(Ref<vm::Cell> cell_ref, unsigned& version, unsigned long long& capabilities) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_capabilities(cs, version, capabilities) && cs.empty_ext();
}

bool GlobalVersion::pack(vm::CellBuilder& cb, const GlobalVersion::Record& data) const {
  return cb.store_long_bool(0xc4, 8)
      && cb.store_ulong_rchk_bool(data.version, 32)
      && cb.store_ulong_rchk_bool(data.capabilities, 64);
}

bool GlobalVersion::pack_capabilities(vm::CellBuilder& cb, unsigned version, unsigned long long capabilities) const {
  return cb.store_long_bool(0xc4, 8)
      && cb.store_ulong_rchk_bool(version, 32)
      && cb.store_ulong_rchk_bool(capabilities, 64);
}

bool GlobalVersion::cell_pack(Ref<vm::Cell>& cell_ref, const GlobalVersion::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool GlobalVersion::cell_pack_capabilities(Ref<vm::Cell>& cell_ref, unsigned version, unsigned long long capabilities) const {
  vm::CellBuilder cb;
  return pack_capabilities(cb, version, capabilities) && std::move(cb).finalize_to(cell_ref);
}

bool GlobalVersion::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0xc4
      && pp.open("capabilities")
      && pp.fetch_uint_field(cs, 32, "version")
      && pp.fetch_uint_field(cs, 64, "capabilities")
      && pp.close();
}

const GlobalVersion t_GlobalVersion;

//
// code for type `WorkchainFormat`
//

int WorkchainFormat::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case wfmt_basic:
    return cs.prefetch_ulong(4) == 1 ? wfmt_basic : -1;
  case wfmt_ext:
    return cs.have(4) ? wfmt_ext : -1;
  }
  return -1;
}

bool WorkchainFormat::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case wfmt_basic:
    return cs.advance(100)
        && m_ == 1;
  case wfmt_ext: {
    int min_addr_len, max_addr_len, addr_len_step, workchain_type_id;
    return cs.advance(4)
        && cs.fetch_uint_to(12, min_addr_len)
        && cs.fetch_uint_to(12, max_addr_len)
        && cs.fetch_uint_to(12, addr_len_step)
        && 64 <= min_addr_len
        && min_addr_len <= max_addr_len
        && max_addr_len <= 1023
        && addr_len_step <= 1023
        && cs.fetch_uint_to(32, workchain_type_id)
        && 1 <= workchain_type_id
        && m_ == 0;
    }
  }
  return false;
}

bool WorkchainFormat::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case wfmt_basic:
    return cs.fetch_ulong(4) == 1
        && cs.advance(96)
        && m_ == 1;
  case wfmt_ext: {
    int min_addr_len, max_addr_len, addr_len_step, workchain_type_id;
    return cs.advance(4)
        && cs.fetch_uint_to(12, min_addr_len)
        && cs.fetch_uint_to(12, max_addr_len)
        && cs.fetch_uint_to(12, addr_len_step)
        && 64 <= min_addr_len
        && min_addr_len <= max_addr_len
        && max_addr_len <= 1023
        && addr_len_step <= 1023
        && cs.fetch_uint_to(32, workchain_type_id)
        && 1 <= workchain_type_id
        && m_ == 0;
    }
  }
  return false;
}

bool WorkchainFormat::unpack(vm::CellSlice& cs, WorkchainFormat::Record_wfmt_basic& data) const {
  return cs.fetch_ulong(4) == 1
      && cs.fetch_int_to(32, data.vm_version)
      && cs.fetch_uint_to(64, data.vm_mode)
      && m_ == 1;
}

bool WorkchainFormat::unpack_wfmt_basic(vm::CellSlice& cs, int& vm_version, unsigned long long& vm_mode) const {
  return cs.fetch_ulong(4) == 1
      && cs.fetch_int_to(32, vm_version)
      && cs.fetch_uint_to(64, vm_mode)
      && m_ == 1;
}

bool WorkchainFormat::cell_unpack(Ref<vm::Cell> cell_ref, WorkchainFormat::Record_wfmt_basic& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool WorkchainFormat::cell_unpack_wfmt_basic(Ref<vm::Cell> cell_ref, int& vm_version, unsigned long long& vm_mode) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_wfmt_basic(cs, vm_version, vm_mode) && cs.empty_ext();
}

bool WorkchainFormat::unpack(vm::CellSlice& cs, WorkchainFormat::Record_wfmt_ext& data) const {
  return cs.fetch_ulong(4) == 0
      && cs.fetch_uint_to(12, data.min_addr_len)
      && cs.fetch_uint_to(12, data.max_addr_len)
      && cs.fetch_uint_to(12, data.addr_len_step)
      && 64 <= data.min_addr_len
      && data.min_addr_len <= data.max_addr_len
      && data.max_addr_len <= 1023
      && data.addr_len_step <= 1023
      && cs.fetch_uint_to(32, data.workchain_type_id)
      && 1 <= data.workchain_type_id
      && m_ == 0;
}

bool WorkchainFormat::cell_unpack(Ref<vm::Cell> cell_ref, WorkchainFormat::Record_wfmt_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool WorkchainFormat::pack(vm::CellBuilder& cb, const WorkchainFormat::Record_wfmt_basic& data) const {
  return cb.store_long_bool(1, 4)
      && cb.store_long_rchk_bool(data.vm_version, 32)
      && cb.store_ulong_rchk_bool(data.vm_mode, 64)
      && m_ == 1;
}

bool WorkchainFormat::pack_wfmt_basic(vm::CellBuilder& cb, int vm_version, unsigned long long vm_mode) const {
  return cb.store_long_bool(1, 4)
      && cb.store_long_rchk_bool(vm_version, 32)
      && cb.store_ulong_rchk_bool(vm_mode, 64)
      && m_ == 1;
}

bool WorkchainFormat::cell_pack(Ref<vm::Cell>& cell_ref, const WorkchainFormat::Record_wfmt_basic& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool WorkchainFormat::cell_pack_wfmt_basic(Ref<vm::Cell>& cell_ref, int vm_version, unsigned long long vm_mode) const {
  vm::CellBuilder cb;
  return pack_wfmt_basic(cb, vm_version, vm_mode) && std::move(cb).finalize_to(cell_ref);
}

bool WorkchainFormat::pack(vm::CellBuilder& cb, const WorkchainFormat::Record_wfmt_ext& data) const {
  return cb.store_long_bool(0, 4)
      && cb.store_ulong_rchk_bool(data.min_addr_len, 12)
      && cb.store_ulong_rchk_bool(data.max_addr_len, 12)
      && cb.store_ulong_rchk_bool(data.addr_len_step, 12)
      && 64 <= data.min_addr_len
      && data.min_addr_len <= data.max_addr_len
      && data.max_addr_len <= 1023
      && data.addr_len_step <= 1023
      && cb.store_ulong_rchk_bool(data.workchain_type_id, 32)
      && 1 <= data.workchain_type_id
      && m_ == 0;
}

bool WorkchainFormat::cell_pack(Ref<vm::Cell>& cell_ref, const WorkchainFormat::Record_wfmt_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool WorkchainFormat::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case wfmt_basic:
    return cs.fetch_ulong(4) == 1
        && pp.open("wfmt_basic")
        && pp.fetch_int_field(cs, 32, "vm_version")
        && pp.fetch_uint_field(cs, 64, "vm_mode")
        && m_ == 1
        && pp.close();
  case wfmt_ext: {
    int min_addr_len, max_addr_len, addr_len_step, workchain_type_id;
    return cs.advance(4)
        && pp.open("wfmt_ext")
        && cs.fetch_uint_to(12, min_addr_len)
        && pp.field_int(min_addr_len, "min_addr_len")
        && cs.fetch_uint_to(12, max_addr_len)
        && pp.field_int(max_addr_len, "max_addr_len")
        && cs.fetch_uint_to(12, addr_len_step)
        && pp.field_int(addr_len_step, "addr_len_step")
        && 64 <= min_addr_len
        && min_addr_len <= max_addr_len
        && max_addr_len <= 1023
        && addr_len_step <= 1023
        && cs.fetch_uint_to(32, workchain_type_id)
        && pp.field_int(workchain_type_id, "workchain_type_id")
        && 1 <= workchain_type_id
        && m_ == 0
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for WorkchainFormat");
}


//
// code for type `WorkchainDescr`
//
constexpr unsigned char WorkchainDescr::cons_tag[1];

int WorkchainDescr::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xa6 ? workchain : -1;
}

bool WorkchainDescr::skip(vm::CellSlice& cs) const {
  int actual_min_split, min_split, basic, flags;
  return cs.advance(40)
      && cs.fetch_uint_to(8, actual_min_split)
      && cs.fetch_uint_to(8, min_split)
      && actual_min_split <= min_split
      && cs.advance(8)
      && cs.fetch_bool_to(basic)
      && cs.advance(2)
      && cs.fetch_uint_to(13, flags)
      && flags == 0
      && cs.advance(544)
      && WorkchainFormat{basic}.skip(cs);
}

bool WorkchainDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  int actual_min_split, min_split, basic, flags;
  return cs.fetch_ulong(8) == 0xa6
      && cs.advance(32)
      && cs.fetch_uint_to(8, actual_min_split)
      && cs.fetch_uint_to(8, min_split)
      && actual_min_split <= min_split
      && cs.advance(8)
      && cs.fetch_bool_to(basic)
      && cs.advance(2)
      && cs.fetch_uint_to(13, flags)
      && flags == 0
      && cs.advance(544)
      && WorkchainFormat{basic}.validate_skip(cs, weak);
}

bool WorkchainDescr::unpack(vm::CellSlice& cs, WorkchainDescr::Record& data) const {
  return cs.fetch_ulong(8) == 0xa6
      && cs.fetch_uint_to(32, data.enabled_since)
      && cs.fetch_uint_to(8, data.actual_min_split)
      && cs.fetch_uint_to(8, data.min_split)
      && cs.fetch_uint_to(8, data.max_split)
      && data.actual_min_split <= data.min_split
      && cs.fetch_bool_to(data.basic)
      && cs.fetch_bool_to(data.active)
      && cs.fetch_bool_to(data.accept_msgs)
      && cs.fetch_uint_to(13, data.flags)
      && data.flags == 0
      && cs.fetch_bits_to(data.zerostate_root_hash.bits(), 256)
      && cs.fetch_bits_to(data.zerostate_file_hash.bits(), 256)
      && cs.fetch_uint_to(32, data.version)
      && WorkchainFormat{data.basic}.fetch_to(cs, data.format);
}

bool WorkchainDescr::cell_unpack(Ref<vm::Cell> cell_ref, WorkchainDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool WorkchainDescr::pack(vm::CellBuilder& cb, const WorkchainDescr::Record& data) const {
  return cb.store_long_bool(0xa6, 8)
      && cb.store_ulong_rchk_bool(data.enabled_since, 32)
      && cb.store_ulong_rchk_bool(data.actual_min_split, 8)
      && cb.store_ulong_rchk_bool(data.min_split, 8)
      && cb.store_ulong_rchk_bool(data.max_split, 8)
      && data.actual_min_split <= data.min_split
      && cb.store_ulong_rchk_bool(data.basic, 1)
      && cb.store_ulong_rchk_bool(data.active, 1)
      && cb.store_ulong_rchk_bool(data.accept_msgs, 1)
      && cb.store_ulong_rchk_bool(data.flags, 13)
      && data.flags == 0
      && cb.store_bits_bool(data.zerostate_root_hash.cbits(), 256)
      && cb.store_bits_bool(data.zerostate_file_hash.cbits(), 256)
      && cb.store_ulong_rchk_bool(data.version, 32)
      && WorkchainFormat{data.basic}.store_from(cb, data.format);
}

bool WorkchainDescr::cell_pack(Ref<vm::Cell>& cell_ref, const WorkchainDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool WorkchainDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int actual_min_split, min_split, max_split, basic, flags;
  return cs.fetch_ulong(8) == 0xa6
      && pp.open("workchain")
      && pp.fetch_uint_field(cs, 32, "enabled_since")
      && cs.fetch_uint_to(8, actual_min_split)
      && pp.field_int(actual_min_split, "actual_min_split")
      && cs.fetch_uint_to(8, min_split)
      && pp.field_int(min_split, "min_split")
      && cs.fetch_uint_to(8, max_split)
      && pp.field_int(max_split, "max_split")
      && actual_min_split <= min_split
      && cs.fetch_bool_to(basic)
      && pp.field_int(basic, "basic")
      && pp.fetch_uint_field(cs, 1, "active")
      && pp.fetch_uint_field(cs, 1, "accept_msgs")
      && cs.fetch_uint_to(13, flags)
      && pp.field_int(flags, "flags")
      && flags == 0
      && pp.fetch_bits_field(cs, 256, "zerostate_root_hash")
      && pp.fetch_bits_field(cs, 256, "zerostate_file_hash")
      && pp.fetch_uint_field(cs, 32, "version")
      && pp.field("format")
      && WorkchainFormat{basic}.print_skip(pp, cs)
      && pp.close();
}

const WorkchainDescr t_WorkchainDescr;

//
// code for type `BlockCreateFees`
//
constexpr unsigned char BlockCreateFees::cons_tag[1];

int BlockCreateFees::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0x6b ? block_grams_created : -1;
}

bool BlockCreateFees::skip(vm::CellSlice& cs) const {
  return cs.advance(8)
      && t_Grams.skip(cs)
      && t_Grams.skip(cs);
}

bool BlockCreateFees::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0x6b
      && t_Grams.validate_skip(cs, weak)
      && t_Grams.validate_skip(cs, weak);
}

bool BlockCreateFees::unpack(vm::CellSlice& cs, BlockCreateFees::Record& data) const {
  return cs.fetch_ulong(8) == 0x6b
      && t_Grams.fetch_to(cs, data.masterchain_block_fee)
      && t_Grams.fetch_to(cs, data.basechain_block_fee);
}

bool BlockCreateFees::unpack_block_grams_created(vm::CellSlice& cs, Ref<CellSlice>& masterchain_block_fee, Ref<CellSlice>& basechain_block_fee) const {
  return cs.fetch_ulong(8) == 0x6b
      && t_Grams.fetch_to(cs, masterchain_block_fee)
      && t_Grams.fetch_to(cs, basechain_block_fee);
}

bool BlockCreateFees::cell_unpack(Ref<vm::Cell> cell_ref, BlockCreateFees::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockCreateFees::cell_unpack_block_grams_created(Ref<vm::Cell> cell_ref, Ref<CellSlice>& masterchain_block_fee, Ref<CellSlice>& basechain_block_fee) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_grams_created(cs, masterchain_block_fee, basechain_block_fee) && cs.empty_ext();
}

bool BlockCreateFees::pack(vm::CellBuilder& cb, const BlockCreateFees::Record& data) const {
  return cb.store_long_bool(0x6b, 8)
      && t_Grams.store_from(cb, data.masterchain_block_fee)
      && t_Grams.store_from(cb, data.basechain_block_fee);
}

bool BlockCreateFees::pack_block_grams_created(vm::CellBuilder& cb, Ref<CellSlice> masterchain_block_fee, Ref<CellSlice> basechain_block_fee) const {
  return cb.store_long_bool(0x6b, 8)
      && t_Grams.store_from(cb, masterchain_block_fee)
      && t_Grams.store_from(cb, basechain_block_fee);
}

bool BlockCreateFees::cell_pack(Ref<vm::Cell>& cell_ref, const BlockCreateFees::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockCreateFees::cell_pack_block_grams_created(Ref<vm::Cell>& cell_ref, Ref<CellSlice> masterchain_block_fee, Ref<CellSlice> basechain_block_fee) const {
  vm::CellBuilder cb;
  return pack_block_grams_created(cb, std::move(masterchain_block_fee), std::move(basechain_block_fee)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockCreateFees::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0x6b
      && pp.open("block_grams_created")
      && pp.field("masterchain_block_fee")
      && t_Grams.print_skip(pp, cs)
      && pp.field("basechain_block_fee")
      && t_Grams.print_skip(pp, cs)
      && pp.close();
}

const BlockCreateFees t_BlockCreateFees;

//
// code for type `StoragePrices`
//
constexpr unsigned char StoragePrices::cons_tag[1];

int StoragePrices::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xcc ? cons1 : -1;
}

bool StoragePrices::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0xcc
      && cs.advance(288);
}

bool StoragePrices::unpack(vm::CellSlice& cs, StoragePrices::Record& data) const {
  return cs.fetch_ulong(8) == 0xcc
      && cs.fetch_uint_to(32, data.utime_since)
      && cs.fetch_uint_to(64, data.bit_price_ps)
      && cs.fetch_uint_to(64, data.cell_price_ps)
      && cs.fetch_uint_to(64, data.mc_bit_price_ps)
      && cs.fetch_uint_to(64, data.mc_cell_price_ps);
}

bool StoragePrices::cell_unpack(Ref<vm::Cell> cell_ref, StoragePrices::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool StoragePrices::pack(vm::CellBuilder& cb, const StoragePrices::Record& data) const {
  return cb.store_long_bool(0xcc, 8)
      && cb.store_ulong_rchk_bool(data.utime_since, 32)
      && cb.store_ulong_rchk_bool(data.bit_price_ps, 64)
      && cb.store_ulong_rchk_bool(data.cell_price_ps, 64)
      && cb.store_ulong_rchk_bool(data.mc_bit_price_ps, 64)
      && cb.store_ulong_rchk_bool(data.mc_cell_price_ps, 64);
}

bool StoragePrices::cell_pack(Ref<vm::Cell>& cell_ref, const StoragePrices::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool StoragePrices::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0xcc
      && pp.open()
      && pp.fetch_uint_field(cs, 32, "utime_since")
      && pp.fetch_uint_field(cs, 64, "bit_price_ps")
      && pp.fetch_uint_field(cs, 64, "cell_price_ps")
      && pp.fetch_uint_field(cs, 64, "mc_bit_price_ps")
      && pp.fetch_uint_field(cs, 64, "mc_cell_price_ps")
      && pp.close();
}

const StoragePrices t_StoragePrices;

//
// code for type `GasLimitsPrices`
//
constexpr unsigned char GasLimitsPrices::cons_tag[3];

int GasLimitsPrices::get_tag(const vm::CellSlice& cs) const {
  switch (cs.bselect(6, 0x1b0000000000000ULL)) {
  case 0:
    return gas_flat_pfx;
  case 2:
    return cs.bit_at(6) ? gas_prices_ext : gas_prices;
  default:
    return -1;
  }
}

int GasLimitsPrices::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case gas_prices:
    return cs.prefetch_ulong(8) == 0xdd ? gas_prices : -1;
  case gas_prices_ext:
    return cs.prefetch_ulong(8) == 0xde ? gas_prices_ext : -1;
  case gas_flat_pfx:
    return cs.prefetch_ulong(8) == 0xd1 ? gas_flat_pfx : -1;
  }
  return -1;
}

bool GasLimitsPrices::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case gas_prices:
    return cs.advance(392);
  case gas_prices_ext:
    return cs.advance(456);
  case gas_flat_pfx:
    return cs.advance(136)
        && skip(cs);
  }
  return false;
}

bool GasLimitsPrices::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case gas_prices:
    return cs.fetch_ulong(8) == 0xdd
        && cs.advance(384);
  case gas_prices_ext:
    return cs.fetch_ulong(8) == 0xde
        && cs.advance(448);
  case gas_flat_pfx:
    return cs.fetch_ulong(8) == 0xd1
        && cs.advance(128)
        && validate_skip(cs, weak);
  }
  return false;
}

bool GasLimitsPrices::unpack(vm::CellSlice& cs, GasLimitsPrices::Record_gas_prices& data) const {
  return cs.fetch_ulong(8) == 0xdd
      && cs.fetch_uint_to(64, data.gas_price)
      && cs.fetch_uint_to(64, data.gas_limit)
      && cs.fetch_uint_to(64, data.gas_credit)
      && cs.fetch_uint_to(64, data.block_gas_limit)
      && cs.fetch_uint_to(64, data.freeze_due_limit)
      && cs.fetch_uint_to(64, data.delete_due_limit);
}

bool GasLimitsPrices::cell_unpack(Ref<vm::Cell> cell_ref, GasLimitsPrices::Record_gas_prices& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool GasLimitsPrices::unpack(vm::CellSlice& cs, GasLimitsPrices::Record_gas_prices_ext& data) const {
  return cs.fetch_ulong(8) == 0xde
      && cs.fetch_uint_to(64, data.gas_price)
      && cs.fetch_uint_to(64, data.gas_limit)
      && cs.fetch_uint_to(64, data.special_gas_limit)
      && cs.fetch_uint_to(64, data.gas_credit)
      && cs.fetch_uint_to(64, data.block_gas_limit)
      && cs.fetch_uint_to(64, data.freeze_due_limit)
      && cs.fetch_uint_to(64, data.delete_due_limit);
}

bool GasLimitsPrices::cell_unpack(Ref<vm::Cell> cell_ref, GasLimitsPrices::Record_gas_prices_ext& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool GasLimitsPrices::unpack(vm::CellSlice& cs, GasLimitsPrices::Record_gas_flat_pfx& data) const {
  return cs.fetch_ulong(8) == 0xd1
      && cs.fetch_uint_to(64, data.flat_gas_limit)
      && cs.fetch_uint_to(64, data.flat_gas_price)
      && fetch_to(cs, data.other);
}

bool GasLimitsPrices::unpack_gas_flat_pfx(vm::CellSlice& cs, unsigned long long& flat_gas_limit, unsigned long long& flat_gas_price, Ref<CellSlice>& other) const {
  return cs.fetch_ulong(8) == 0xd1
      && cs.fetch_uint_to(64, flat_gas_limit)
      && cs.fetch_uint_to(64, flat_gas_price)
      && fetch_to(cs, other);
}

bool GasLimitsPrices::cell_unpack(Ref<vm::Cell> cell_ref, GasLimitsPrices::Record_gas_flat_pfx& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool GasLimitsPrices::cell_unpack_gas_flat_pfx(Ref<vm::Cell> cell_ref, unsigned long long& flat_gas_limit, unsigned long long& flat_gas_price, Ref<CellSlice>& other) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_gas_flat_pfx(cs, flat_gas_limit, flat_gas_price, other) && cs.empty_ext();
}

bool GasLimitsPrices::pack(vm::CellBuilder& cb, const GasLimitsPrices::Record_gas_prices& data) const {
  return cb.store_long_bool(0xdd, 8)
      && cb.store_ulong_rchk_bool(data.gas_price, 64)
      && cb.store_ulong_rchk_bool(data.gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.gas_credit, 64)
      && cb.store_ulong_rchk_bool(data.block_gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.freeze_due_limit, 64)
      && cb.store_ulong_rchk_bool(data.delete_due_limit, 64);
}

bool GasLimitsPrices::cell_pack(Ref<vm::Cell>& cell_ref, const GasLimitsPrices::Record_gas_prices& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool GasLimitsPrices::pack(vm::CellBuilder& cb, const GasLimitsPrices::Record_gas_prices_ext& data) const {
  return cb.store_long_bool(0xde, 8)
      && cb.store_ulong_rchk_bool(data.gas_price, 64)
      && cb.store_ulong_rchk_bool(data.gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.special_gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.gas_credit, 64)
      && cb.store_ulong_rchk_bool(data.block_gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.freeze_due_limit, 64)
      && cb.store_ulong_rchk_bool(data.delete_due_limit, 64);
}

bool GasLimitsPrices::cell_pack(Ref<vm::Cell>& cell_ref, const GasLimitsPrices::Record_gas_prices_ext& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool GasLimitsPrices::pack(vm::CellBuilder& cb, const GasLimitsPrices::Record_gas_flat_pfx& data) const {
  return cb.store_long_bool(0xd1, 8)
      && cb.store_ulong_rchk_bool(data.flat_gas_limit, 64)
      && cb.store_ulong_rchk_bool(data.flat_gas_price, 64)
      && store_from(cb, data.other);
}

bool GasLimitsPrices::pack_gas_flat_pfx(vm::CellBuilder& cb, unsigned long long flat_gas_limit, unsigned long long flat_gas_price, Ref<CellSlice> other) const {
  return cb.store_long_bool(0xd1, 8)
      && cb.store_ulong_rchk_bool(flat_gas_limit, 64)
      && cb.store_ulong_rchk_bool(flat_gas_price, 64)
      && store_from(cb, other);
}

bool GasLimitsPrices::cell_pack(Ref<vm::Cell>& cell_ref, const GasLimitsPrices::Record_gas_flat_pfx& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool GasLimitsPrices::cell_pack_gas_flat_pfx(Ref<vm::Cell>& cell_ref, unsigned long long flat_gas_limit, unsigned long long flat_gas_price, Ref<CellSlice> other) const {
  vm::CellBuilder cb;
  return pack_gas_flat_pfx(cb, flat_gas_limit, flat_gas_price, std::move(other)) && std::move(cb).finalize_to(cell_ref);
}

bool GasLimitsPrices::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case gas_prices:
    return cs.fetch_ulong(8) == 0xdd
        && pp.open("gas_prices")
        && pp.fetch_uint_field(cs, 64, "gas_price")
        && pp.fetch_uint_field(cs, 64, "gas_limit")
        && pp.fetch_uint_field(cs, 64, "gas_credit")
        && pp.fetch_uint_field(cs, 64, "block_gas_limit")
        && pp.fetch_uint_field(cs, 64, "freeze_due_limit")
        && pp.fetch_uint_field(cs, 64, "delete_due_limit")
        && pp.close();
  case gas_prices_ext:
    return cs.fetch_ulong(8) == 0xde
        && pp.open("gas_prices_ext")
        && pp.fetch_uint_field(cs, 64, "gas_price")
        && pp.fetch_uint_field(cs, 64, "gas_limit")
        && pp.fetch_uint_field(cs, 64, "special_gas_limit")
        && pp.fetch_uint_field(cs, 64, "gas_credit")
        && pp.fetch_uint_field(cs, 64, "block_gas_limit")
        && pp.fetch_uint_field(cs, 64, "freeze_due_limit")
        && pp.fetch_uint_field(cs, 64, "delete_due_limit")
        && pp.close();
  case gas_flat_pfx:
    return cs.fetch_ulong(8) == 0xd1
        && pp.open("gas_flat_pfx")
        && pp.fetch_uint_field(cs, 64, "flat_gas_limit")
        && pp.fetch_uint_field(cs, 64, "flat_gas_price")
        && pp.field("other")
        && print_skip(pp, cs)
        && pp.close();
  }
  return pp.fail("unknown constructor for GasLimitsPrices");
}

const GasLimitsPrices t_GasLimitsPrices;

//
// code for type `ParamLimits`
//
constexpr unsigned char ParamLimits::cons_tag[1];

int ParamLimits::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xc3 ? param_limits : -1;
}

bool ParamLimits::validate_skip(vm::CellSlice& cs, bool weak) const {
  int underload, soft_limit, hard_limit;
  return cs.fetch_ulong(8) == 0xc3
      && cs.fetch_uint_to(32, underload)
      && cs.fetch_uint_to(32, soft_limit)
      && underload <= soft_limit
      && cs.fetch_uint_to(32, hard_limit)
      && soft_limit <= hard_limit;
}

bool ParamLimits::unpack(vm::CellSlice& cs, ParamLimits::Record& data) const {
  return cs.fetch_ulong(8) == 0xc3
      && cs.fetch_uint_to(32, data.underload)
      && cs.fetch_uint_to(32, data.soft_limit)
      && data.underload <= data.soft_limit
      && cs.fetch_uint_to(32, data.hard_limit)
      && data.soft_limit <= data.hard_limit;
}

bool ParamLimits::unpack_param_limits(vm::CellSlice& cs, int& underload, int& soft_limit, int& hard_limit) const {
  return cs.fetch_ulong(8) == 0xc3
      && cs.fetch_uint_to(32, underload)
      && cs.fetch_uint_to(32, soft_limit)
      && underload <= soft_limit
      && cs.fetch_uint_to(32, hard_limit)
      && soft_limit <= hard_limit;
}

bool ParamLimits::cell_unpack(Ref<vm::Cell> cell_ref, ParamLimits::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ParamLimits::cell_unpack_param_limits(Ref<vm::Cell> cell_ref, int& underload, int& soft_limit, int& hard_limit) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_param_limits(cs, underload, soft_limit, hard_limit) && cs.empty_ext();
}

bool ParamLimits::pack(vm::CellBuilder& cb, const ParamLimits::Record& data) const {
  return cb.store_long_bool(0xc3, 8)
      && cb.store_ulong_rchk_bool(data.underload, 32)
      && cb.store_ulong_rchk_bool(data.soft_limit, 32)
      && data.underload <= data.soft_limit
      && cb.store_ulong_rchk_bool(data.hard_limit, 32)
      && data.soft_limit <= data.hard_limit;
}

bool ParamLimits::pack_param_limits(vm::CellBuilder& cb, int underload, int soft_limit, int hard_limit) const {
  return cb.store_long_bool(0xc3, 8)
      && cb.store_ulong_rchk_bool(underload, 32)
      && cb.store_ulong_rchk_bool(soft_limit, 32)
      && underload <= soft_limit
      && cb.store_ulong_rchk_bool(hard_limit, 32)
      && soft_limit <= hard_limit;
}

bool ParamLimits::cell_pack(Ref<vm::Cell>& cell_ref, const ParamLimits::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ParamLimits::cell_pack_param_limits(Ref<vm::Cell>& cell_ref, int underload, int soft_limit, int hard_limit) const {
  vm::CellBuilder cb;
  return pack_param_limits(cb, underload, soft_limit, hard_limit) && std::move(cb).finalize_to(cell_ref);
}

bool ParamLimits::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int underload, soft_limit, hard_limit;
  return cs.fetch_ulong(8) == 0xc3
      && pp.open("param_limits")
      && cs.fetch_uint_to(32, underload)
      && pp.field_int(underload, "underload")
      && cs.fetch_uint_to(32, soft_limit)
      && pp.field_int(soft_limit, "soft_limit")
      && underload <= soft_limit
      && cs.fetch_uint_to(32, hard_limit)
      && pp.field_int(hard_limit, "hard_limit")
      && soft_limit <= hard_limit
      && pp.close();
}

const ParamLimits t_ParamLimits;

//
// code for type `BlockLimits`
//
constexpr unsigned char BlockLimits::cons_tag[1];

int BlockLimits::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0x5d ? block_limits : -1;
}

bool BlockLimits::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0x5d
      && t_ParamLimits.validate_skip(cs, weak)
      && t_ParamLimits.validate_skip(cs, weak)
      && t_ParamLimits.validate_skip(cs, weak);
}

bool BlockLimits::unpack(vm::CellSlice& cs, BlockLimits::Record& data) const {
  return cs.fetch_ulong(8) == 0x5d
      && cs.fetch_subslice_to(104, data.bytes)
      && cs.fetch_subslice_to(104, data.gas)
      && cs.fetch_subslice_to(104, data.lt_delta);
}

bool BlockLimits::unpack_block_limits(vm::CellSlice& cs, Ref<CellSlice>& bytes, Ref<CellSlice>& gas, Ref<CellSlice>& lt_delta) const {
  return cs.fetch_ulong(8) == 0x5d
      && cs.fetch_subslice_to(104, bytes)
      && cs.fetch_subslice_to(104, gas)
      && cs.fetch_subslice_to(104, lt_delta);
}

bool BlockLimits::cell_unpack(Ref<vm::Cell> cell_ref, BlockLimits::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockLimits::cell_unpack_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& bytes, Ref<CellSlice>& gas, Ref<CellSlice>& lt_delta) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_limits(cs, bytes, gas, lt_delta) && cs.empty_ext();
}

bool BlockLimits::pack(vm::CellBuilder& cb, const BlockLimits::Record& data) const {
  return cb.store_long_bool(0x5d, 8)
      && cb.append_cellslice_chk(data.bytes, 104)
      && cb.append_cellslice_chk(data.gas, 104)
      && cb.append_cellslice_chk(data.lt_delta, 104);
}

bool BlockLimits::pack_block_limits(vm::CellBuilder& cb, Ref<CellSlice> bytes, Ref<CellSlice> gas, Ref<CellSlice> lt_delta) const {
  return cb.store_long_bool(0x5d, 8)
      && cb.append_cellslice_chk(bytes, 104)
      && cb.append_cellslice_chk(gas, 104)
      && cb.append_cellslice_chk(lt_delta, 104);
}

bool BlockLimits::cell_pack(Ref<vm::Cell>& cell_ref, const BlockLimits::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockLimits::cell_pack_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> bytes, Ref<CellSlice> gas, Ref<CellSlice> lt_delta) const {
  vm::CellBuilder cb;
  return pack_block_limits(cb, std::move(bytes), std::move(gas), std::move(lt_delta)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockLimits::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0x5d
      && pp.open("block_limits")
      && pp.field("bytes")
      && t_ParamLimits.print_skip(pp, cs)
      && pp.field("gas")
      && t_ParamLimits.print_skip(pp, cs)
      && pp.field("lt_delta")
      && t_ParamLimits.print_skip(pp, cs)
      && pp.close();
}

const BlockLimits t_BlockLimits;

//
// code for type `MsgForwardPrices`
//
constexpr unsigned char MsgForwardPrices::cons_tag[1];

int MsgForwardPrices::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xea ? msg_forward_prices : -1;
}

bool MsgForwardPrices::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0xea
      && cs.advance(256);
}

bool MsgForwardPrices::unpack(vm::CellSlice& cs, MsgForwardPrices::Record& data) const {
  return cs.fetch_ulong(8) == 0xea
      && cs.fetch_uint_to(64, data.lump_price)
      && cs.fetch_uint_to(64, data.bit_price)
      && cs.fetch_uint_to(64, data.cell_price)
      && cs.fetch_uint_to(32, data.ihr_price_factor)
      && cs.fetch_uint_to(16, data.first_frac)
      && cs.fetch_uint_to(16, data.next_frac);
}

bool MsgForwardPrices::cell_unpack(Ref<vm::Cell> cell_ref, MsgForwardPrices::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool MsgForwardPrices::pack(vm::CellBuilder& cb, const MsgForwardPrices::Record& data) const {
  return cb.store_long_bool(0xea, 8)
      && cb.store_ulong_rchk_bool(data.lump_price, 64)
      && cb.store_ulong_rchk_bool(data.bit_price, 64)
      && cb.store_ulong_rchk_bool(data.cell_price, 64)
      && cb.store_ulong_rchk_bool(data.ihr_price_factor, 32)
      && cb.store_ulong_rchk_bool(data.first_frac, 16)
      && cb.store_ulong_rchk_bool(data.next_frac, 16);
}

bool MsgForwardPrices::cell_pack(Ref<vm::Cell>& cell_ref, const MsgForwardPrices::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool MsgForwardPrices::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0xea
      && pp.open("msg_forward_prices")
      && pp.fetch_uint_field(cs, 64, "lump_price")
      && pp.fetch_uint_field(cs, 64, "bit_price")
      && pp.fetch_uint_field(cs, 64, "cell_price")
      && pp.fetch_uint_field(cs, 32, "ihr_price_factor")
      && pp.fetch_uint_field(cs, 16, "first_frac")
      && pp.fetch_uint_field(cs, 16, "next_frac")
      && pp.close();
}

const MsgForwardPrices t_MsgForwardPrices;

//
// code for type `CatchainConfig`
//
constexpr unsigned char CatchainConfig::cons_tag[1];

int CatchainConfig::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xc1 ? catchain_config : -1;
}

bool CatchainConfig::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0xc1
      && cs.advance(128);
}

bool CatchainConfig::unpack(vm::CellSlice& cs, CatchainConfig::Record& data) const {
  return cs.fetch_ulong(8) == 0xc1
      && cs.fetch_uint_to(32, data.mc_catchain_lifetime)
      && cs.fetch_uint_to(32, data.shard_catchain_lifetime)
      && cs.fetch_uint_to(32, data.shard_validators_lifetime)
      && cs.fetch_uint_to(32, data.shard_validators_num);
}

bool CatchainConfig::cell_unpack(Ref<vm::Cell> cell_ref, CatchainConfig::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool CatchainConfig::pack(vm::CellBuilder& cb, const CatchainConfig::Record& data) const {
  return cb.store_long_bool(0xc1, 8)
      && cb.store_ulong_rchk_bool(data.mc_catchain_lifetime, 32)
      && cb.store_ulong_rchk_bool(data.shard_catchain_lifetime, 32)
      && cb.store_ulong_rchk_bool(data.shard_validators_lifetime, 32)
      && cb.store_ulong_rchk_bool(data.shard_validators_num, 32);
}

bool CatchainConfig::cell_pack(Ref<vm::Cell>& cell_ref, const CatchainConfig::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool CatchainConfig::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0xc1
      && pp.open("catchain_config")
      && pp.fetch_uint_field(cs, 32, "mc_catchain_lifetime")
      && pp.fetch_uint_field(cs, 32, "shard_catchain_lifetime")
      && pp.fetch_uint_field(cs, 32, "shard_validators_lifetime")
      && pp.fetch_uint_field(cs, 32, "shard_validators_num")
      && pp.close();
}

const CatchainConfig t_CatchainConfig;

//
// code for type `ConsensusConfig`
//
constexpr unsigned char ConsensusConfig::cons_tag[1];

int ConsensusConfig::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xd6 ? consensus_config : -1;
}

bool ConsensusConfig::validate_skip(vm::CellSlice& cs, bool weak) const {
  int round_candidates;
  return cs.fetch_ulong(8) == 0xd6
      && cs.fetch_uint_to(32, round_candidates)
      && 1 <= round_candidates
      && cs.advance(224);
}

bool ConsensusConfig::unpack(vm::CellSlice& cs, ConsensusConfig::Record& data) const {
  return cs.fetch_ulong(8) == 0xd6
      && cs.fetch_uint_to(32, data.round_candidates)
      && 1 <= data.round_candidates
      && cs.fetch_uint_to(32, data.next_candidate_delay_ms)
      && cs.fetch_uint_to(32, data.consensus_timeout_ms)
      && cs.fetch_uint_to(32, data.fast_attempts)
      && cs.fetch_uint_to(32, data.attempt_duration)
      && cs.fetch_uint_to(32, data.catchain_max_deps)
      && cs.fetch_uint_to(32, data.max_block_bytes)
      && cs.fetch_uint_to(32, data.max_collated_bytes);
}

bool ConsensusConfig::cell_unpack(Ref<vm::Cell> cell_ref, ConsensusConfig::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConsensusConfig::pack(vm::CellBuilder& cb, const ConsensusConfig::Record& data) const {
  return cb.store_long_bool(0xd6, 8)
      && cb.store_ulong_rchk_bool(data.round_candidates, 32)
      && 1 <= data.round_candidates
      && cb.store_ulong_rchk_bool(data.next_candidate_delay_ms, 32)
      && cb.store_ulong_rchk_bool(data.consensus_timeout_ms, 32)
      && cb.store_ulong_rchk_bool(data.fast_attempts, 32)
      && cb.store_ulong_rchk_bool(data.attempt_duration, 32)
      && cb.store_ulong_rchk_bool(data.catchain_max_deps, 32)
      && cb.store_ulong_rchk_bool(data.max_block_bytes, 32)
      && cb.store_ulong_rchk_bool(data.max_collated_bytes, 32);
}

bool ConsensusConfig::cell_pack(Ref<vm::Cell>& cell_ref, const ConsensusConfig::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConsensusConfig::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int round_candidates;
  return cs.fetch_ulong(8) == 0xd6
      && pp.open("consensus_config")
      && cs.fetch_uint_to(32, round_candidates)
      && pp.field_int(round_candidates, "round_candidates")
      && 1 <= round_candidates
      && pp.fetch_uint_field(cs, 32, "next_candidate_delay_ms")
      && pp.fetch_uint_field(cs, 32, "consensus_timeout_ms")
      && pp.fetch_uint_field(cs, 32, "fast_attempts")
      && pp.fetch_uint_field(cs, 32, "attempt_duration")
      && pp.fetch_uint_field(cs, 32, "catchain_max_deps")
      && pp.fetch_uint_field(cs, 32, "max_block_bytes")
      && pp.fetch_uint_field(cs, 32, "max_collated_bytes")
      && pp.close();
}

const ConsensusConfig t_ConsensusConfig;

//
// code for type `ValidatorTempKey`
//
constexpr unsigned char ValidatorTempKey::cons_tag[1];

int ValidatorTempKey::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 3 ? validator_temp_key : -1;
}

bool ValidatorTempKey::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 3
      && cs.advance(256)
      && t_SigPubKey.validate_skip(cs, weak)
      && cs.advance(64);
}

bool ValidatorTempKey::unpack(vm::CellSlice& cs, ValidatorTempKey::Record& data) const {
  return cs.fetch_ulong(4) == 3
      && cs.fetch_bits_to(data.adnl_addr.bits(), 256)
      && cs.fetch_subslice_to(288, data.temp_public_key)
      && cs.fetch_uint_to(32, data.seqno)
      && cs.fetch_uint_to(32, data.valid_until);
}

bool ValidatorTempKey::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorTempKey::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorTempKey::pack(vm::CellBuilder& cb, const ValidatorTempKey::Record& data) const {
  return cb.store_long_bool(3, 4)
      && cb.store_bits_bool(data.adnl_addr.cbits(), 256)
      && cb.append_cellslice_chk(data.temp_public_key, 288)
      && cb.store_ulong_rchk_bool(data.seqno, 32)
      && cb.store_ulong_rchk_bool(data.valid_until, 32);
}

bool ValidatorTempKey::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorTempKey::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorTempKey::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int seqno;
  return cs.fetch_ulong(4) == 3
      && pp.open("validator_temp_key")
      && pp.fetch_bits_field(cs, 256, "adnl_addr")
      && pp.field("temp_public_key")
      && t_SigPubKey.print_skip(pp, cs)
      && cs.fetch_uint_to(32, seqno)
      && pp.field_int(seqno, "seqno")
      && pp.fetch_uint_field(cs, 32, "valid_until")
      && pp.close();
}

const ValidatorTempKey t_ValidatorTempKey;

//
// code for type `ValidatorSignedTempKey`
//
constexpr unsigned char ValidatorSignedTempKey::cons_tag[1];

int ValidatorSignedTempKey::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(4) == 4 ? signed_temp_key : -1;
}

bool ValidatorSignedTempKey::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x10004)
      && t_CryptoSignature.skip(cs);
}

bool ValidatorSignedTempKey::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 4
      && t_ValidatorTempKey.validate_skip_ref(cs, weak)
      && t_CryptoSignature.validate_skip(cs, weak);
}

bool ValidatorSignedTempKey::unpack(vm::CellSlice& cs, ValidatorSignedTempKey::Record& data) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_ref_to(data.key)
      && t_CryptoSignature.fetch_to(cs, data.signature);
}

bool ValidatorSignedTempKey::unpack_signed_temp_key(vm::CellSlice& cs, Ref<Cell>& key, Ref<CellSlice>& signature) const {
  return cs.fetch_ulong(4) == 4
      && cs.fetch_ref_to(key)
      && t_CryptoSignature.fetch_to(cs, signature);
}

bool ValidatorSignedTempKey::cell_unpack(Ref<vm::Cell> cell_ref, ValidatorSignedTempKey::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ValidatorSignedTempKey::cell_unpack_signed_temp_key(Ref<vm::Cell> cell_ref, Ref<Cell>& key, Ref<CellSlice>& signature) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_signed_temp_key(cs, key, signature) && cs.empty_ext();
}

bool ValidatorSignedTempKey::pack(vm::CellBuilder& cb, const ValidatorSignedTempKey::Record& data) const {
  return cb.store_long_bool(4, 4)
      && cb.store_ref_bool(data.key)
      && t_CryptoSignature.store_from(cb, data.signature);
}

bool ValidatorSignedTempKey::pack_signed_temp_key(vm::CellBuilder& cb, Ref<Cell> key, Ref<CellSlice> signature) const {
  return cb.store_long_bool(4, 4)
      && cb.store_ref_bool(key)
      && t_CryptoSignature.store_from(cb, signature);
}

bool ValidatorSignedTempKey::cell_pack(Ref<vm::Cell>& cell_ref, const ValidatorSignedTempKey::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorSignedTempKey::cell_pack_signed_temp_key(Ref<vm::Cell>& cell_ref, Ref<Cell> key, Ref<CellSlice> signature) const {
  vm::CellBuilder cb;
  return pack_signed_temp_key(cb, std::move(key), std::move(signature)) && std::move(cb).finalize_to(cell_ref);
}

bool ValidatorSignedTempKey::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(4) == 4
      && pp.open("signed_temp_key")
      && pp.field("key")
      && t_ValidatorTempKey.print_ref(pp, cs.fetch_ref())
      && pp.field("signature")
      && t_CryptoSignature.print_skip(pp, cs)
      && pp.close();
}

const ValidatorSignedTempKey t_ValidatorSignedTempKey;

//
// code for type `ConfigParam`
//

int ConfigParam::get_tag(const vm::CellSlice& cs) const {
  switch (m_) {
  case 0:
    return cons0;
  case 1:
    return cons1;
  case 2:
    return cons2;
  case 3:
    return cons3;
  case 4:
    return cons4;
  case 6:
    return cons6;
  case 7:
    return cons7;
  case 8:
    return cons8;
  case 9:
    return cons9;
  case 12:
    return cons12;
  case 14:
    return cons14;
  case 15:
    return cons15;
  case 16:
    return cons16;
  case 17:
    return cons17;
  case 18:
    return cons18;
  case 20:
    return config_mc_gas_prices;
  case 21:
    return config_gas_prices;
  case 22:
    return config_mc_block_limits;
  case 23:
    return config_block_limits;
  case 24:
    return config_mc_fwd_prices;
  case 25:
    return config_fwd_prices;
  case 28:
    return cons28;
  case 29:
    return cons29;
  case 31:
    return cons31;
  case 32:
    return cons32;
  case 33:
    return cons33;
  case 34:
    return cons34;
  case 35:
    return cons35;
  case 36:
    return cons36;
  case 37:
    return cons37;
  case 39:
    return cons39;
  default:
    return -1;
  }
}

int ConfigParam::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons0:
    return cons0;
  case cons1:
    return cons1;
  case cons2:
    return cons2;
  case cons3:
    return cons3;
  case cons4:
    return cons4;
  case cons6:
    return cons6;
  case cons7:
    return cons7;
  case cons8:
    return cons8;
  case cons9:
    return cons9;
  case cons12:
    return cons12;
  case cons14:
    return cons14;
  case cons15:
    return cons15;
  case cons16:
    return cons16;
  case cons17:
    return cons17;
  case cons18:
    return cons18;
  case config_mc_gas_prices:
    return config_mc_gas_prices;
  case config_gas_prices:
    return config_gas_prices;
  case config_mc_block_limits:
    return config_mc_block_limits;
  case config_block_limits:
    return config_block_limits;
  case config_mc_fwd_prices:
    return config_mc_fwd_prices;
  case config_fwd_prices:
    return config_fwd_prices;
  case cons28:
    return cons28;
  case cons29:
    return cons29;
  case cons31:
    return cons31;
  case cons32:
    return cons32;
  case cons33:
    return cons33;
  case cons34:
    return cons34;
  case cons35:
    return cons35;
  case cons36:
    return cons36;
  case cons37:
    return cons37;
  case cons39:
    return cons39;
  }
  return -1;
}

bool ConfigParam::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons0:
    return cs.advance(256)
        && m_ == 0;
  case cons1:
    return cs.advance(256)
        && m_ == 1;
  case cons2:
    return cs.advance(256)
        && m_ == 2;
  case cons3:
    return cs.advance(256)
        && m_ == 3;
  case cons4:
    return cs.advance(256)
        && m_ == 4;
  case cons6:
    return t_Grams.skip(cs)
        && t_Grams.skip(cs)
        && m_ == 6;
  case cons7:
    return t_ExtraCurrencyCollection.skip(cs)
        && m_ == 7;
  case cons8:
    return cs.advance(104)
        && m_ == 8;
  case cons9:
    return t_Hashmap_32_True.skip(cs)
        && m_ == 9;
  case cons12:
    return t_HashmapE_32_WorkchainDescr.skip(cs)
        && m_ == 12;
  case cons14:
    return t_BlockCreateFees.skip(cs)
        && m_ == 14;
  case cons15:
    return cs.advance(128)
        && m_ == 15;
  case cons16: {
    int max_validators, max_main_validators, min_validators;
    return cs.fetch_uint_to(16, max_validators)
        && cs.fetch_uint_to(16, max_main_validators)
        && cs.fetch_uint_to(16, min_validators)
        && max_main_validators <= max_validators
        && min_validators <= max_main_validators
        && 1 <= min_validators
        && m_ == 16;
    }
  case cons17:
    return t_Grams.skip(cs)
        && t_Grams.skip(cs)
        && t_Grams.skip(cs)
        && cs.advance(32)
        && m_ == 17;
  case cons18:
    return t_Hashmap_32_StoragePrices.skip(cs)
        && m_ == 18;
  case config_mc_gas_prices:
    return t_GasLimitsPrices.skip(cs)
        && m_ == 20;
  case config_gas_prices:
    return t_GasLimitsPrices.skip(cs)
        && m_ == 21;
  case config_mc_block_limits:
    return cs.advance(320)
        && m_ == 22;
  case config_block_limits:
    return cs.advance(320)
        && m_ == 23;
  case config_mc_fwd_prices:
    return cs.advance(264)
        && m_ == 24;
  case config_fwd_prices:
    return cs.advance(264)
        && m_ == 25;
  case cons28:
    return cs.advance(136)
        && m_ == 28;
  case cons29:
    return cs.advance(264)
        && m_ == 29;
  case cons31:
    return t_HashmapE_256_True.skip(cs)
        && m_ == 31;
  case cons32:
    return t_ValidatorSet.skip(cs)
        && m_ == 32;
  case cons33:
    return t_ValidatorSet.skip(cs)
        && m_ == 33;
  case cons34:
    return t_ValidatorSet.skip(cs)
        && m_ == 34;
  case cons35:
    return t_ValidatorSet.skip(cs)
        && m_ == 35;
  case cons36:
    return t_ValidatorSet.skip(cs)
        && m_ == 36;
  case cons37:
    return t_ValidatorSet.skip(cs)
        && m_ == 37;
  case cons39:
    return t_HashmapE_256_ValidatorSignedTempKey.skip(cs)
        && m_ == 39;
  }
  return false;
}

bool ConfigParam::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case cons0:
    return cs.advance(256)
        && m_ == 0;
  case cons1:
    return cs.advance(256)
        && m_ == 1;
  case cons2:
    return cs.advance(256)
        && m_ == 2;
  case cons3:
    return cs.advance(256)
        && m_ == 3;
  case cons4:
    return cs.advance(256)
        && m_ == 4;
  case cons6:
    return t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && m_ == 6;
  case cons7:
    return t_ExtraCurrencyCollection.validate_skip(cs, weak)
        && m_ == 7;
  case cons8:
    return t_GlobalVersion.validate_skip(cs, weak)
        && m_ == 8;
  case cons9:
    return t_Hashmap_32_True.validate_skip(cs, weak)
        && m_ == 9;
  case cons12:
    return t_HashmapE_32_WorkchainDescr.validate_skip(cs, weak)
        && m_ == 12;
  case cons14:
    return t_BlockCreateFees.validate_skip(cs, weak)
        && m_ == 14;
  case cons15:
    return cs.advance(128)
        && m_ == 15;
  case cons16: {
    int max_validators, max_main_validators, min_validators;
    return cs.fetch_uint_to(16, max_validators)
        && cs.fetch_uint_to(16, max_main_validators)
        && cs.fetch_uint_to(16, min_validators)
        && max_main_validators <= max_validators
        && min_validators <= max_main_validators
        && 1 <= min_validators
        && m_ == 16;
    }
  case cons17:
    return t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && t_Grams.validate_skip(cs, weak)
        && cs.advance(32)
        && m_ == 17;
  case cons18:
    return t_Hashmap_32_StoragePrices.validate_skip(cs, weak)
        && m_ == 18;
  case config_mc_gas_prices:
    return t_GasLimitsPrices.validate_skip(cs, weak)
        && m_ == 20;
  case config_gas_prices:
    return t_GasLimitsPrices.validate_skip(cs, weak)
        && m_ == 21;
  case config_mc_block_limits:
    return t_BlockLimits.validate_skip(cs, weak)
        && m_ == 22;
  case config_block_limits:
    return t_BlockLimits.validate_skip(cs, weak)
        && m_ == 23;
  case config_mc_fwd_prices:
    return t_MsgForwardPrices.validate_skip(cs, weak)
        && m_ == 24;
  case config_fwd_prices:
    return t_MsgForwardPrices.validate_skip(cs, weak)
        && m_ == 25;
  case cons28:
    return t_CatchainConfig.validate_skip(cs, weak)
        && m_ == 28;
  case cons29:
    return t_ConsensusConfig.validate_skip(cs, weak)
        && m_ == 29;
  case cons31:
    return t_HashmapE_256_True.validate_skip(cs, weak)
        && m_ == 31;
  case cons32:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 32;
  case cons33:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 33;
  case cons34:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 34;
  case cons35:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 35;
  case cons36:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 36;
  case cons37:
    return t_ValidatorSet.validate_skip(cs, weak)
        && m_ == 37;
  case cons39:
    return t_HashmapE_256_ValidatorSignedTempKey.validate_skip(cs, weak)
        && m_ == 39;
  }
  return false;
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons0& data) const {
  return cs.fetch_bits_to(data.config_addr.bits(), 256)
      && m_ == 0;
}

bool ConfigParam::unpack_cons0(vm::CellSlice& cs, td::BitArray<256>& config_addr) const {
  return cs.fetch_bits_to(config_addr.bits(), 256)
      && m_ == 0;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons0& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons0(Ref<vm::Cell> cell_ref, td::BitArray<256>& config_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons0(cs, config_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons1& data) const {
  return cs.fetch_bits_to(data.elector_addr.bits(), 256)
      && m_ == 1;
}

bool ConfigParam::unpack_cons1(vm::CellSlice& cs, td::BitArray<256>& elector_addr) const {
  return cs.fetch_bits_to(elector_addr.bits(), 256)
      && m_ == 1;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons1& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons1(Ref<vm::Cell> cell_ref, td::BitArray<256>& elector_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons1(cs, elector_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons2& data) const {
  return cs.fetch_bits_to(data.minter_addr.bits(), 256)
      && m_ == 2;
}

bool ConfigParam::unpack_cons2(vm::CellSlice& cs, td::BitArray<256>& minter_addr) const {
  return cs.fetch_bits_to(minter_addr.bits(), 256)
      && m_ == 2;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons2& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons2(Ref<vm::Cell> cell_ref, td::BitArray<256>& minter_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons2(cs, minter_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons3& data) const {
  return cs.fetch_bits_to(data.fee_collector_addr.bits(), 256)
      && m_ == 3;
}

bool ConfigParam::unpack_cons3(vm::CellSlice& cs, td::BitArray<256>& fee_collector_addr) const {
  return cs.fetch_bits_to(fee_collector_addr.bits(), 256)
      && m_ == 3;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons3& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons3(Ref<vm::Cell> cell_ref, td::BitArray<256>& fee_collector_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons3(cs, fee_collector_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons4& data) const {
  return cs.fetch_bits_to(data.dns_root_addr.bits(), 256)
      && m_ == 4;
}

bool ConfigParam::unpack_cons4(vm::CellSlice& cs, td::BitArray<256>& dns_root_addr) const {
  return cs.fetch_bits_to(dns_root_addr.bits(), 256)
      && m_ == 4;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons4& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons4(Ref<vm::Cell> cell_ref, td::BitArray<256>& dns_root_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons4(cs, dns_root_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons6& data) const {
  return t_Grams.fetch_to(cs, data.mint_new_price)
      && t_Grams.fetch_to(cs, data.mint_add_price)
      && m_ == 6;
}

bool ConfigParam::unpack_cons6(vm::CellSlice& cs, Ref<CellSlice>& mint_new_price, Ref<CellSlice>& mint_add_price) const {
  return t_Grams.fetch_to(cs, mint_new_price)
      && t_Grams.fetch_to(cs, mint_add_price)
      && m_ == 6;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons6& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons6(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mint_new_price, Ref<CellSlice>& mint_add_price) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons6(cs, mint_new_price, mint_add_price) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons7& data) const {
  return t_ExtraCurrencyCollection.fetch_to(cs, data.to_mint)
      && m_ == 7;
}

bool ConfigParam::unpack_cons7(vm::CellSlice& cs, Ref<CellSlice>& to_mint) const {
  return t_ExtraCurrencyCollection.fetch_to(cs, to_mint)
      && m_ == 7;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons7& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons7(Ref<vm::Cell> cell_ref, Ref<CellSlice>& to_mint) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons7(cs, to_mint) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons8& data) const {
  return cs.fetch_subslice_to(104, data.x)
      && m_ == 8;
}

bool ConfigParam::unpack_cons8(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(104, x)
      && m_ == 8;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons8& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons8(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons8(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons9& data) const {
  return t_Hashmap_32_True.fetch_to(cs, data.mandatory_params)
      && m_ == 9;
}

bool ConfigParam::unpack_cons9(vm::CellSlice& cs, Ref<CellSlice>& mandatory_params) const {
  return t_Hashmap_32_True.fetch_to(cs, mandatory_params)
      && m_ == 9;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons9& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons9(Ref<vm::Cell> cell_ref, Ref<CellSlice>& mandatory_params) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons9(cs, mandatory_params) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons12& data) const {
  return t_HashmapE_32_WorkchainDescr.fetch_to(cs, data.workchains)
      && m_ == 12;
}

bool ConfigParam::unpack_cons12(vm::CellSlice& cs, Ref<CellSlice>& workchains) const {
  return t_HashmapE_32_WorkchainDescr.fetch_to(cs, workchains)
      && m_ == 12;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons12& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons12(Ref<vm::Cell> cell_ref, Ref<CellSlice>& workchains) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons12(cs, workchains) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons14& data) const {
  return t_BlockCreateFees.fetch_to(cs, data.x)
      && m_ == 14;
}

bool ConfigParam::unpack_cons14(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_BlockCreateFees.fetch_to(cs, x)
      && m_ == 14;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons14& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons14(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons14(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons15& data) const {
  return cs.fetch_uint_to(32, data.validators_elected_for)
      && cs.fetch_uint_to(32, data.elections_start_before)
      && cs.fetch_uint_to(32, data.elections_end_before)
      && cs.fetch_uint_to(32, data.stake_held_for)
      && m_ == 15;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons15& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons16& data) const {
  return cs.fetch_uint_to(16, data.max_validators)
      && cs.fetch_uint_to(16, data.max_main_validators)
      && cs.fetch_uint_to(16, data.min_validators)
      && data.max_main_validators <= data.max_validators
      && data.min_validators <= data.max_main_validators
      && 1 <= data.min_validators
      && m_ == 16;
}

bool ConfigParam::unpack_cons16(vm::CellSlice& cs, int& max_validators, int& max_main_validators, int& min_validators) const {
  return cs.fetch_uint_to(16, max_validators)
      && cs.fetch_uint_to(16, max_main_validators)
      && cs.fetch_uint_to(16, min_validators)
      && max_main_validators <= max_validators
      && min_validators <= max_main_validators
      && 1 <= min_validators
      && m_ == 16;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons16& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons16(Ref<vm::Cell> cell_ref, int& max_validators, int& max_main_validators, int& min_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons16(cs, max_validators, max_main_validators, min_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons17& data) const {
  return t_Grams.fetch_to(cs, data.min_stake)
      && t_Grams.fetch_to(cs, data.max_stake)
      && t_Grams.fetch_to(cs, data.min_total_stake)
      && cs.fetch_uint_to(32, data.max_stake_factor)
      && m_ == 17;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons17& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons18& data) const {
  return t_Hashmap_32_StoragePrices.fetch_to(cs, data.x)
      && m_ == 18;
}

bool ConfigParam::unpack_cons18(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_Hashmap_32_StoragePrices.fetch_to(cs, x)
      && m_ == 18;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons18& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons18(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons18(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_mc_gas_prices& data) const {
  return t_GasLimitsPrices.fetch_to(cs, data.x)
      && m_ == 20;
}

bool ConfigParam::unpack_config_mc_gas_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_GasLimitsPrices.fetch_to(cs, x)
      && m_ == 20;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_mc_gas_prices& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_mc_gas_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_mc_gas_prices(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_gas_prices& data) const {
  return t_GasLimitsPrices.fetch_to(cs, data.x)
      && m_ == 21;
}

bool ConfigParam::unpack_config_gas_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_GasLimitsPrices.fetch_to(cs, x)
      && m_ == 21;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_gas_prices& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_gas_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_gas_prices(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_mc_block_limits& data) const {
  return cs.fetch_subslice_to(320, data.x)
      && m_ == 22;
}

bool ConfigParam::unpack_config_mc_block_limits(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(320, x)
      && m_ == 22;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_mc_block_limits& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_mc_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_mc_block_limits(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_block_limits& data) const {
  return cs.fetch_subslice_to(320, data.x)
      && m_ == 23;
}

bool ConfigParam::unpack_config_block_limits(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(320, x)
      && m_ == 23;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_block_limits& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_block_limits(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_block_limits(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_mc_fwd_prices& data) const {
  return cs.fetch_subslice_to(264, data.x)
      && m_ == 24;
}

bool ConfigParam::unpack_config_mc_fwd_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(264, x)
      && m_ == 24;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_mc_fwd_prices& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_mc_fwd_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_mc_fwd_prices(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_config_fwd_prices& data) const {
  return cs.fetch_subslice_to(264, data.x)
      && m_ == 25;
}

bool ConfigParam::unpack_config_fwd_prices(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(264, x)
      && m_ == 25;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_config_fwd_prices& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_config_fwd_prices(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_config_fwd_prices(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons28& data) const {
  return cs.fetch_subslice_to(136, data.x)
      && m_ == 28;
}

bool ConfigParam::unpack_cons28(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(136, x)
      && m_ == 28;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons28& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons28(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons28(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons29& data) const {
  return cs.fetch_subslice_to(264, data.x)
      && m_ == 29;
}

bool ConfigParam::unpack_cons29(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return cs.fetch_subslice_to(264, x)
      && m_ == 29;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons29& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons29(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons29(cs, x) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons31& data) const {
  return t_HashmapE_256_True.fetch_to(cs, data.fundamental_smc_addr)
      && m_ == 31;
}

bool ConfigParam::unpack_cons31(vm::CellSlice& cs, Ref<CellSlice>& fundamental_smc_addr) const {
  return t_HashmapE_256_True.fetch_to(cs, fundamental_smc_addr)
      && m_ == 31;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons31& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons31(Ref<vm::Cell> cell_ref, Ref<CellSlice>& fundamental_smc_addr) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons31(cs, fundamental_smc_addr) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons32& data) const {
  return t_ValidatorSet.fetch_to(cs, data.prev_validators)
      && m_ == 32;
}

bool ConfigParam::unpack_cons32(vm::CellSlice& cs, Ref<CellSlice>& prev_validators) const {
  return t_ValidatorSet.fetch_to(cs, prev_validators)
      && m_ == 32;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons32& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons32(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons32(cs, prev_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons33& data) const {
  return t_ValidatorSet.fetch_to(cs, data.prev_temp_validators)
      && m_ == 33;
}

bool ConfigParam::unpack_cons33(vm::CellSlice& cs, Ref<CellSlice>& prev_temp_validators) const {
  return t_ValidatorSet.fetch_to(cs, prev_temp_validators)
      && m_ == 33;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons33& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons33(Ref<vm::Cell> cell_ref, Ref<CellSlice>& prev_temp_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons33(cs, prev_temp_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons34& data) const {
  return t_ValidatorSet.fetch_to(cs, data.cur_validators)
      && m_ == 34;
}

bool ConfigParam::unpack_cons34(vm::CellSlice& cs, Ref<CellSlice>& cur_validators) const {
  return t_ValidatorSet.fetch_to(cs, cur_validators)
      && m_ == 34;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons34& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons34(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cur_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons34(cs, cur_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons35& data) const {
  return t_ValidatorSet.fetch_to(cs, data.cur_temp_validators)
      && m_ == 35;
}

bool ConfigParam::unpack_cons35(vm::CellSlice& cs, Ref<CellSlice>& cur_temp_validators) const {
  return t_ValidatorSet.fetch_to(cs, cur_temp_validators)
      && m_ == 35;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons35& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons35(Ref<vm::Cell> cell_ref, Ref<CellSlice>& cur_temp_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons35(cs, cur_temp_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons36& data) const {
  return t_ValidatorSet.fetch_to(cs, data.next_validators)
      && m_ == 36;
}

bool ConfigParam::unpack_cons36(vm::CellSlice& cs, Ref<CellSlice>& next_validators) const {
  return t_ValidatorSet.fetch_to(cs, next_validators)
      && m_ == 36;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons36& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons36(Ref<vm::Cell> cell_ref, Ref<CellSlice>& next_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons36(cs, next_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons37& data) const {
  return t_ValidatorSet.fetch_to(cs, data.next_temp_validators)
      && m_ == 37;
}

bool ConfigParam::unpack_cons37(vm::CellSlice& cs, Ref<CellSlice>& next_temp_validators) const {
  return t_ValidatorSet.fetch_to(cs, next_temp_validators)
      && m_ == 37;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons37& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons37(Ref<vm::Cell> cell_ref, Ref<CellSlice>& next_temp_validators) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons37(cs, next_temp_validators) && cs.empty_ext();
}

bool ConfigParam::unpack(vm::CellSlice& cs, ConfigParam::Record_cons39& data) const {
  return t_HashmapE_256_ValidatorSignedTempKey.fetch_to(cs, data.x)
      && m_ == 39;
}

bool ConfigParam::unpack_cons39(vm::CellSlice& cs, Ref<CellSlice>& x) const {
  return t_HashmapE_256_ValidatorSignedTempKey.fetch_to(cs, x)
      && m_ == 39;
}

bool ConfigParam::cell_unpack(Ref<vm::Cell> cell_ref, ConfigParam::Record_cons39& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ConfigParam::cell_unpack_cons39(Ref<vm::Cell> cell_ref, Ref<CellSlice>& x) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_cons39(cs, x) && cs.empty_ext();
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons0& data) const {
  return cb.store_bits_bool(data.config_addr.cbits(), 256)
      && m_ == 0;
}

bool ConfigParam::pack_cons0(vm::CellBuilder& cb, td::BitArray<256> config_addr) const {
  return cb.store_bits_bool(config_addr.cbits(), 256)
      && m_ == 0;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons0& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons0(Ref<vm::Cell>& cell_ref, td::BitArray<256> config_addr) const {
  vm::CellBuilder cb;
  return pack_cons0(cb, config_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons1& data) const {
  return cb.store_bits_bool(data.elector_addr.cbits(), 256)
      && m_ == 1;
}

bool ConfigParam::pack_cons1(vm::CellBuilder& cb, td::BitArray<256> elector_addr) const {
  return cb.store_bits_bool(elector_addr.cbits(), 256)
      && m_ == 1;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons1& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons1(Ref<vm::Cell>& cell_ref, td::BitArray<256> elector_addr) const {
  vm::CellBuilder cb;
  return pack_cons1(cb, elector_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons2& data) const {
  return cb.store_bits_bool(data.minter_addr.cbits(), 256)
      && m_ == 2;
}

bool ConfigParam::pack_cons2(vm::CellBuilder& cb, td::BitArray<256> minter_addr) const {
  return cb.store_bits_bool(minter_addr.cbits(), 256)
      && m_ == 2;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons2& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons2(Ref<vm::Cell>& cell_ref, td::BitArray<256> minter_addr) const {
  vm::CellBuilder cb;
  return pack_cons2(cb, minter_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons3& data) const {
  return cb.store_bits_bool(data.fee_collector_addr.cbits(), 256)
      && m_ == 3;
}

bool ConfigParam::pack_cons3(vm::CellBuilder& cb, td::BitArray<256> fee_collector_addr) const {
  return cb.store_bits_bool(fee_collector_addr.cbits(), 256)
      && m_ == 3;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons3& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons3(Ref<vm::Cell>& cell_ref, td::BitArray<256> fee_collector_addr) const {
  vm::CellBuilder cb;
  return pack_cons3(cb, fee_collector_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons4& data) const {
  return cb.store_bits_bool(data.dns_root_addr.cbits(), 256)
      && m_ == 4;
}

bool ConfigParam::pack_cons4(vm::CellBuilder& cb, td::BitArray<256> dns_root_addr) const {
  return cb.store_bits_bool(dns_root_addr.cbits(), 256)
      && m_ == 4;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons4& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons4(Ref<vm::Cell>& cell_ref, td::BitArray<256> dns_root_addr) const {
  vm::CellBuilder cb;
  return pack_cons4(cb, dns_root_addr) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons6& data) const {
  return t_Grams.store_from(cb, data.mint_new_price)
      && t_Grams.store_from(cb, data.mint_add_price)
      && m_ == 6;
}

bool ConfigParam::pack_cons6(vm::CellBuilder& cb, Ref<CellSlice> mint_new_price, Ref<CellSlice> mint_add_price) const {
  return t_Grams.store_from(cb, mint_new_price)
      && t_Grams.store_from(cb, mint_add_price)
      && m_ == 6;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons6& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons6(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mint_new_price, Ref<CellSlice> mint_add_price) const {
  vm::CellBuilder cb;
  return pack_cons6(cb, std::move(mint_new_price), std::move(mint_add_price)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons7& data) const {
  return t_ExtraCurrencyCollection.store_from(cb, data.to_mint)
      && m_ == 7;
}

bool ConfigParam::pack_cons7(vm::CellBuilder& cb, Ref<CellSlice> to_mint) const {
  return t_ExtraCurrencyCollection.store_from(cb, to_mint)
      && m_ == 7;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons7& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons7(Ref<vm::Cell>& cell_ref, Ref<CellSlice> to_mint) const {
  vm::CellBuilder cb;
  return pack_cons7(cb, std::move(to_mint)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons8& data) const {
  return cb.append_cellslice_chk(data.x, 104)
      && m_ == 8;
}

bool ConfigParam::pack_cons8(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 104)
      && m_ == 8;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons8& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons8(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons8(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons9& data) const {
  return t_Hashmap_32_True.store_from(cb, data.mandatory_params)
      && m_ == 9;
}

bool ConfigParam::pack_cons9(vm::CellBuilder& cb, Ref<CellSlice> mandatory_params) const {
  return t_Hashmap_32_True.store_from(cb, mandatory_params)
      && m_ == 9;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons9& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons9(Ref<vm::Cell>& cell_ref, Ref<CellSlice> mandatory_params) const {
  vm::CellBuilder cb;
  return pack_cons9(cb, std::move(mandatory_params)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons12& data) const {
  return t_HashmapE_32_WorkchainDescr.store_from(cb, data.workchains)
      && m_ == 12;
}

bool ConfigParam::pack_cons12(vm::CellBuilder& cb, Ref<CellSlice> workchains) const {
  return t_HashmapE_32_WorkchainDescr.store_from(cb, workchains)
      && m_ == 12;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons12& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons12(Ref<vm::Cell>& cell_ref, Ref<CellSlice> workchains) const {
  vm::CellBuilder cb;
  return pack_cons12(cb, std::move(workchains)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons14& data) const {
  return t_BlockCreateFees.store_from(cb, data.x)
      && m_ == 14;
}

bool ConfigParam::pack_cons14(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_BlockCreateFees.store_from(cb, x)
      && m_ == 14;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons14& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons14(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons14(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons15& data) const {
  return cb.store_ulong_rchk_bool(data.validators_elected_for, 32)
      && cb.store_ulong_rchk_bool(data.elections_start_before, 32)
      && cb.store_ulong_rchk_bool(data.elections_end_before, 32)
      && cb.store_ulong_rchk_bool(data.stake_held_for, 32)
      && m_ == 15;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons15& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons16& data) const {
  return cb.store_ulong_rchk_bool(data.max_validators, 16)
      && cb.store_ulong_rchk_bool(data.max_main_validators, 16)
      && cb.store_ulong_rchk_bool(data.min_validators, 16)
      && data.max_main_validators <= data.max_validators
      && data.min_validators <= data.max_main_validators
      && 1 <= data.min_validators
      && m_ == 16;
}

bool ConfigParam::pack_cons16(vm::CellBuilder& cb, int max_validators, int max_main_validators, int min_validators) const {
  return cb.store_ulong_rchk_bool(max_validators, 16)
      && cb.store_ulong_rchk_bool(max_main_validators, 16)
      && cb.store_ulong_rchk_bool(min_validators, 16)
      && max_main_validators <= max_validators
      && min_validators <= max_main_validators
      && 1 <= min_validators
      && m_ == 16;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons16& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons16(Ref<vm::Cell>& cell_ref, int max_validators, int max_main_validators, int min_validators) const {
  vm::CellBuilder cb;
  return pack_cons16(cb, max_validators, max_main_validators, min_validators) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons17& data) const {
  return t_Grams.store_from(cb, data.min_stake)
      && t_Grams.store_from(cb, data.max_stake)
      && t_Grams.store_from(cb, data.min_total_stake)
      && cb.store_ulong_rchk_bool(data.max_stake_factor, 32)
      && m_ == 17;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons17& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons18& data) const {
  return t_Hashmap_32_StoragePrices.store_from(cb, data.x)
      && m_ == 18;
}

bool ConfigParam::pack_cons18(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_Hashmap_32_StoragePrices.store_from(cb, x)
      && m_ == 18;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons18& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons18(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons18(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_mc_gas_prices& data) const {
  return t_GasLimitsPrices.store_from(cb, data.x)
      && m_ == 20;
}

bool ConfigParam::pack_config_mc_gas_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_GasLimitsPrices.store_from(cb, x)
      && m_ == 20;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_mc_gas_prices& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_mc_gas_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_mc_gas_prices(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_gas_prices& data) const {
  return t_GasLimitsPrices.store_from(cb, data.x)
      && m_ == 21;
}

bool ConfigParam::pack_config_gas_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_GasLimitsPrices.store_from(cb, x)
      && m_ == 21;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_gas_prices& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_gas_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_gas_prices(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_mc_block_limits& data) const {
  return cb.append_cellslice_chk(data.x, 320)
      && m_ == 22;
}

bool ConfigParam::pack_config_mc_block_limits(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 320)
      && m_ == 22;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_mc_block_limits& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_mc_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_mc_block_limits(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_block_limits& data) const {
  return cb.append_cellslice_chk(data.x, 320)
      && m_ == 23;
}

bool ConfigParam::pack_config_block_limits(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 320)
      && m_ == 23;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_block_limits& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_block_limits(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_block_limits(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_mc_fwd_prices& data) const {
  return cb.append_cellslice_chk(data.x, 264)
      && m_ == 24;
}

bool ConfigParam::pack_config_mc_fwd_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 264)
      && m_ == 24;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_mc_fwd_prices& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_mc_fwd_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_mc_fwd_prices(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_config_fwd_prices& data) const {
  return cb.append_cellslice_chk(data.x, 264)
      && m_ == 25;
}

bool ConfigParam::pack_config_fwd_prices(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 264)
      && m_ == 25;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_config_fwd_prices& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_config_fwd_prices(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_config_fwd_prices(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons28& data) const {
  return cb.append_cellslice_chk(data.x, 136)
      && m_ == 28;
}

bool ConfigParam::pack_cons28(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 136)
      && m_ == 28;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons28& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons28(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons28(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons29& data) const {
  return cb.append_cellslice_chk(data.x, 264)
      && m_ == 29;
}

bool ConfigParam::pack_cons29(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return cb.append_cellslice_chk(x, 264)
      && m_ == 29;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons29& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons29(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons29(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons31& data) const {
  return t_HashmapE_256_True.store_from(cb, data.fundamental_smc_addr)
      && m_ == 31;
}

bool ConfigParam::pack_cons31(vm::CellBuilder& cb, Ref<CellSlice> fundamental_smc_addr) const {
  return t_HashmapE_256_True.store_from(cb, fundamental_smc_addr)
      && m_ == 31;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons31& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons31(Ref<vm::Cell>& cell_ref, Ref<CellSlice> fundamental_smc_addr) const {
  vm::CellBuilder cb;
  return pack_cons31(cb, std::move(fundamental_smc_addr)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons32& data) const {
  return t_ValidatorSet.store_from(cb, data.prev_validators)
      && m_ == 32;
}

bool ConfigParam::pack_cons32(vm::CellBuilder& cb, Ref<CellSlice> prev_validators) const {
  return t_ValidatorSet.store_from(cb, prev_validators)
      && m_ == 32;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons32& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons32(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_validators) const {
  vm::CellBuilder cb;
  return pack_cons32(cb, std::move(prev_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons33& data) const {
  return t_ValidatorSet.store_from(cb, data.prev_temp_validators)
      && m_ == 33;
}

bool ConfigParam::pack_cons33(vm::CellBuilder& cb, Ref<CellSlice> prev_temp_validators) const {
  return t_ValidatorSet.store_from(cb, prev_temp_validators)
      && m_ == 33;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons33& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons33(Ref<vm::Cell>& cell_ref, Ref<CellSlice> prev_temp_validators) const {
  vm::CellBuilder cb;
  return pack_cons33(cb, std::move(prev_temp_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons34& data) const {
  return t_ValidatorSet.store_from(cb, data.cur_validators)
      && m_ == 34;
}

bool ConfigParam::pack_cons34(vm::CellBuilder& cb, Ref<CellSlice> cur_validators) const {
  return t_ValidatorSet.store_from(cb, cur_validators)
      && m_ == 34;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons34& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons34(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cur_validators) const {
  vm::CellBuilder cb;
  return pack_cons34(cb, std::move(cur_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons35& data) const {
  return t_ValidatorSet.store_from(cb, data.cur_temp_validators)
      && m_ == 35;
}

bool ConfigParam::pack_cons35(vm::CellBuilder& cb, Ref<CellSlice> cur_temp_validators) const {
  return t_ValidatorSet.store_from(cb, cur_temp_validators)
      && m_ == 35;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons35& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons35(Ref<vm::Cell>& cell_ref, Ref<CellSlice> cur_temp_validators) const {
  vm::CellBuilder cb;
  return pack_cons35(cb, std::move(cur_temp_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons36& data) const {
  return t_ValidatorSet.store_from(cb, data.next_validators)
      && m_ == 36;
}

bool ConfigParam::pack_cons36(vm::CellBuilder& cb, Ref<CellSlice> next_validators) const {
  return t_ValidatorSet.store_from(cb, next_validators)
      && m_ == 36;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons36& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons36(Ref<vm::Cell>& cell_ref, Ref<CellSlice> next_validators) const {
  vm::CellBuilder cb;
  return pack_cons36(cb, std::move(next_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons37& data) const {
  return t_ValidatorSet.store_from(cb, data.next_temp_validators)
      && m_ == 37;
}

bool ConfigParam::pack_cons37(vm::CellBuilder& cb, Ref<CellSlice> next_temp_validators) const {
  return t_ValidatorSet.store_from(cb, next_temp_validators)
      && m_ == 37;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons37& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons37(Ref<vm::Cell>& cell_ref, Ref<CellSlice> next_temp_validators) const {
  vm::CellBuilder cb;
  return pack_cons37(cb, std::move(next_temp_validators)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::pack(vm::CellBuilder& cb, const ConfigParam::Record_cons39& data) const {
  return t_HashmapE_256_ValidatorSignedTempKey.store_from(cb, data.x)
      && m_ == 39;
}

bool ConfigParam::pack_cons39(vm::CellBuilder& cb, Ref<CellSlice> x) const {
  return t_HashmapE_256_ValidatorSignedTempKey.store_from(cb, x)
      && m_ == 39;
}

bool ConfigParam::cell_pack(Ref<vm::Cell>& cell_ref, const ConfigParam::Record_cons39& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::cell_pack_cons39(Ref<vm::Cell>& cell_ref, Ref<CellSlice> x) const {
  vm::CellBuilder cb;
  return pack_cons39(cb, std::move(x)) && std::move(cb).finalize_to(cell_ref);
}

bool ConfigParam::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case cons0:
    return pp.open()
        && pp.fetch_bits_field(cs, 256, "config_addr")
        && m_ == 0
        && pp.close();
  case cons1:
    return pp.open()
        && pp.fetch_bits_field(cs, 256, "elector_addr")
        && m_ == 1
        && pp.close();
  case cons2:
    return pp.open()
        && pp.fetch_bits_field(cs, 256, "minter_addr")
        && m_ == 2
        && pp.close();
  case cons3:
    return pp.open()
        && pp.fetch_bits_field(cs, 256, "fee_collector_addr")
        && m_ == 3
        && pp.close();
  case cons4:
    return pp.open()
        && pp.fetch_bits_field(cs, 256, "dns_root_addr")
        && m_ == 4
        && pp.close();
  case cons6:
    return pp.open()
        && pp.field("mint_new_price")
        && t_Grams.print_skip(pp, cs)
        && pp.field("mint_add_price")
        && t_Grams.print_skip(pp, cs)
        && m_ == 6
        && pp.close();
  case cons7:
    return pp.open()
        && pp.field("to_mint")
        && t_ExtraCurrencyCollection.print_skip(pp, cs)
        && m_ == 7
        && pp.close();
  case cons8:
    return pp.open()
        && pp.field()
        && t_GlobalVersion.print_skip(pp, cs)
        && m_ == 8
        && pp.close();
  case cons9:
    return pp.open()
        && pp.field("mandatory_params")
        && t_Hashmap_32_True.print_skip(pp, cs)
        && m_ == 9
        && pp.close();
  case cons12:
    return pp.open()
        && pp.field("workchains")
        && t_HashmapE_32_WorkchainDescr.print_skip(pp, cs)
        && m_ == 12
        && pp.close();
  case cons14:
    return pp.open()
        && pp.field()
        && t_BlockCreateFees.print_skip(pp, cs)
        && m_ == 14
        && pp.close();
  case cons15:
    return pp.open()
        && pp.fetch_uint_field(cs, 32, "validators_elected_for")
        && pp.fetch_uint_field(cs, 32, "elections_start_before")
        && pp.fetch_uint_field(cs, 32, "elections_end_before")
        && pp.fetch_uint_field(cs, 32, "stake_held_for")
        && m_ == 15
        && pp.close();
  case cons16: {
    int max_validators, max_main_validators, min_validators;
    return pp.open()
        && cs.fetch_uint_to(16, max_validators)
        && pp.field_int(max_validators, "max_validators")
        && cs.fetch_uint_to(16, max_main_validators)
        && pp.field_int(max_main_validators, "max_main_validators")
        && cs.fetch_uint_to(16, min_validators)
        && pp.field_int(min_validators, "min_validators")
        && max_main_validators <= max_validators
        && min_validators <= max_main_validators
        && 1 <= min_validators
        && m_ == 16
        && pp.close();
    }
  case cons17:
    return pp.open()
        && pp.field("min_stake")
        && t_Grams.print_skip(pp, cs)
        && pp.field("max_stake")
        && t_Grams.print_skip(pp, cs)
        && pp.field("min_total_stake")
        && t_Grams.print_skip(pp, cs)
        && pp.fetch_uint_field(cs, 32, "max_stake_factor")
        && m_ == 17
        && pp.close();
  case cons18:
    return pp.open()
        && pp.field()
        && t_Hashmap_32_StoragePrices.print_skip(pp, cs)
        && m_ == 18
        && pp.close();
  case config_mc_gas_prices:
    return pp.open("config_mc_gas_prices")
        && pp.field()
        && t_GasLimitsPrices.print_skip(pp, cs)
        && m_ == 20
        && pp.close();
  case config_gas_prices:
    return pp.open("config_gas_prices")
        && pp.field()
        && t_GasLimitsPrices.print_skip(pp, cs)
        && m_ == 21
        && pp.close();
  case config_mc_block_limits:
    return pp.open("config_mc_block_limits")
        && pp.field()
        && t_BlockLimits.print_skip(pp, cs)
        && m_ == 22
        && pp.close();
  case config_block_limits:
    return pp.open("config_block_limits")
        && pp.field()
        && t_BlockLimits.print_skip(pp, cs)
        && m_ == 23
        && pp.close();
  case config_mc_fwd_prices:
    return pp.open("config_mc_fwd_prices")
        && pp.field()
        && t_MsgForwardPrices.print_skip(pp, cs)
        && m_ == 24
        && pp.close();
  case config_fwd_prices:
    return pp.open("config_fwd_prices")
        && pp.field()
        && t_MsgForwardPrices.print_skip(pp, cs)
        && m_ == 25
        && pp.close();
  case cons28:
    return pp.open()
        && pp.field()
        && t_CatchainConfig.print_skip(pp, cs)
        && m_ == 28
        && pp.close();
  case cons29:
    return pp.open()
        && pp.field()
        && t_ConsensusConfig.print_skip(pp, cs)
        && m_ == 29
        && pp.close();
  case cons31:
    return pp.open()
        && pp.field("fundamental_smc_addr")
        && t_HashmapE_256_True.print_skip(pp, cs)
        && m_ == 31
        && pp.close();
  case cons32:
    return pp.open()
        && pp.field("prev_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 32
        && pp.close();
  case cons33:
    return pp.open()
        && pp.field("prev_temp_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 33
        && pp.close();
  case cons34:
    return pp.open()
        && pp.field("cur_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 34
        && pp.close();
  case cons35:
    return pp.open()
        && pp.field("cur_temp_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 35
        && pp.close();
  case cons36:
    return pp.open()
        && pp.field("next_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 36
        && pp.close();
  case cons37:
    return pp.open()
        && pp.field("next_temp_validators")
        && t_ValidatorSet.print_skip(pp, cs)
        && m_ == 37
        && pp.close();
  case cons39:
    return pp.open()
        && pp.field()
        && t_HashmapE_256_ValidatorSignedTempKey.print_skip(pp, cs)
        && m_ == 39
        && pp.close();
  }
  return pp.fail("unknown constructor for ConfigParam");
}


//
// code for type `BlockSignaturesPure`
//

int BlockSignaturesPure::check_tag(const vm::CellSlice& cs) const {
  return block_signatures_pure;
}

bool BlockSignaturesPure::skip(vm::CellSlice& cs) const {
  return cs.advance(96)
      && t_HashmapE_16_CryptoSignaturePair.skip(cs);
}

bool BlockSignaturesPure::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(96)
      && t_HashmapE_16_CryptoSignaturePair.validate_skip(cs, weak);
}

bool BlockSignaturesPure::unpack(vm::CellSlice& cs, BlockSignaturesPure::Record& data) const {
  return cs.fetch_uint_to(32, data.sig_count)
      && cs.fetch_uint_to(64, data.sig_weight)
      && t_HashmapE_16_CryptoSignaturePair.fetch_to(cs, data.signatures);
}

bool BlockSignaturesPure::unpack_block_signatures_pure(vm::CellSlice& cs, unsigned& sig_count, unsigned long long& sig_weight, Ref<CellSlice>& signatures) const {
  return cs.fetch_uint_to(32, sig_count)
      && cs.fetch_uint_to(64, sig_weight)
      && t_HashmapE_16_CryptoSignaturePair.fetch_to(cs, signatures);
}

bool BlockSignaturesPure::cell_unpack(Ref<vm::Cell> cell_ref, BlockSignaturesPure::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockSignaturesPure::cell_unpack_block_signatures_pure(Ref<vm::Cell> cell_ref, unsigned& sig_count, unsigned long long& sig_weight, Ref<CellSlice>& signatures) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_signatures_pure(cs, sig_count, sig_weight, signatures) && cs.empty_ext();
}

bool BlockSignaturesPure::pack(vm::CellBuilder& cb, const BlockSignaturesPure::Record& data) const {
  return cb.store_ulong_rchk_bool(data.sig_count, 32)
      && cb.store_ulong_rchk_bool(data.sig_weight, 64)
      && t_HashmapE_16_CryptoSignaturePair.store_from(cb, data.signatures);
}

bool BlockSignaturesPure::pack_block_signatures_pure(vm::CellBuilder& cb, unsigned sig_count, unsigned long long sig_weight, Ref<CellSlice> signatures) const {
  return cb.store_ulong_rchk_bool(sig_count, 32)
      && cb.store_ulong_rchk_bool(sig_weight, 64)
      && t_HashmapE_16_CryptoSignaturePair.store_from(cb, signatures);
}

bool BlockSignaturesPure::cell_pack(Ref<vm::Cell>& cell_ref, const BlockSignaturesPure::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockSignaturesPure::cell_pack_block_signatures_pure(Ref<vm::Cell>& cell_ref, unsigned sig_count, unsigned long long sig_weight, Ref<CellSlice> signatures) const {
  vm::CellBuilder cb;
  return pack_block_signatures_pure(cb, sig_count, sig_weight, std::move(signatures)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockSignaturesPure::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return pp.open("block_signatures_pure")
      && pp.fetch_uint_field(cs, 32, "sig_count")
      && pp.fetch_uint_field(cs, 64, "sig_weight")
      && pp.field("signatures")
      && t_HashmapE_16_CryptoSignaturePair.print_skip(pp, cs)
      && pp.close();
}

const BlockSignaturesPure t_BlockSignaturesPure;

//
// code for type `BlockSignatures`
//
constexpr unsigned char BlockSignatures::cons_tag[1];

int BlockSignatures::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 17 ? block_signatures : -1;
}

bool BlockSignatures::skip(vm::CellSlice& cs) const {
  return cs.advance(72)
      && t_BlockSignaturesPure.skip(cs);
}

bool BlockSignatures::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 17
      && cs.advance(64)
      && t_BlockSignaturesPure.validate_skip(cs, weak);
}

bool BlockSignatures::unpack(vm::CellSlice& cs, BlockSignatures::Record& data) const {
  return cs.fetch_ulong(8) == 17
      && cs.fetch_subslice_to(64, data.validator_info)
      && t_BlockSignaturesPure.fetch_to(cs, data.pure_signatures);
}

bool BlockSignatures::unpack_block_signatures(vm::CellSlice& cs, Ref<CellSlice>& validator_info, Ref<CellSlice>& pure_signatures) const {
  return cs.fetch_ulong(8) == 17
      && cs.fetch_subslice_to(64, validator_info)
      && t_BlockSignaturesPure.fetch_to(cs, pure_signatures);
}

bool BlockSignatures::cell_unpack(Ref<vm::Cell> cell_ref, BlockSignatures::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockSignatures::cell_unpack_block_signatures(Ref<vm::Cell> cell_ref, Ref<CellSlice>& validator_info, Ref<CellSlice>& pure_signatures) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_signatures(cs, validator_info, pure_signatures) && cs.empty_ext();
}

bool BlockSignatures::pack(vm::CellBuilder& cb, const BlockSignatures::Record& data) const {
  return cb.store_long_bool(17, 8)
      && cb.append_cellslice_chk(data.validator_info, 64)
      && t_BlockSignaturesPure.store_from(cb, data.pure_signatures);
}

bool BlockSignatures::pack_block_signatures(vm::CellBuilder& cb, Ref<CellSlice> validator_info, Ref<CellSlice> pure_signatures) const {
  return cb.store_long_bool(17, 8)
      && cb.append_cellslice_chk(validator_info, 64)
      && t_BlockSignaturesPure.store_from(cb, pure_signatures);
}

bool BlockSignatures::cell_pack(Ref<vm::Cell>& cell_ref, const BlockSignatures::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockSignatures::cell_pack_block_signatures(Ref<vm::Cell>& cell_ref, Ref<CellSlice> validator_info, Ref<CellSlice> pure_signatures) const {
  vm::CellBuilder cb;
  return pack_block_signatures(cb, std::move(validator_info), std::move(pure_signatures)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockSignatures::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 17
      && pp.open("block_signatures")
      && pp.field("validator_info")
      && t_ValidatorBaseInfo.print_skip(pp, cs)
      && pp.field("pure_signatures")
      && t_BlockSignaturesPure.print_skip(pp, cs)
      && pp.close();
}

const BlockSignatures t_BlockSignatures;

//
// code for type `BlockProof`
//
constexpr unsigned char BlockProof::cons_tag[1];

int BlockProof::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xc3 ? block_proof : -1;
}

bool BlockProof::skip(vm::CellSlice& cs) const {
  return cs.advance_ext(0x10290)
      && t_Maybe_Ref_BlockSignatures.skip(cs);
}

bool BlockProof::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(8) == 0xc3
      && t_BlockIdExt.validate_skip(cs, weak)
      && cs.advance_refs(1)
      && t_Maybe_Ref_BlockSignatures.validate_skip(cs, weak);
}

bool BlockProof::unpack(vm::CellSlice& cs, BlockProof::Record& data) const {
  return cs.fetch_ulong(8) == 0xc3
      && cs.fetch_subslice_to(648, data.proof_for)
      && cs.fetch_ref_to(data.root)
      && t_Maybe_Ref_BlockSignatures.fetch_to(cs, data.signatures);
}

bool BlockProof::unpack_block_proof(vm::CellSlice& cs, Ref<CellSlice>& proof_for, Ref<Cell>& root, Ref<CellSlice>& signatures) const {
  return cs.fetch_ulong(8) == 0xc3
      && cs.fetch_subslice_to(648, proof_for)
      && cs.fetch_ref_to(root)
      && t_Maybe_Ref_BlockSignatures.fetch_to(cs, signatures);
}

bool BlockProof::cell_unpack(Ref<vm::Cell> cell_ref, BlockProof::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool BlockProof::cell_unpack_block_proof(Ref<vm::Cell> cell_ref, Ref<CellSlice>& proof_for, Ref<Cell>& root, Ref<CellSlice>& signatures) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_block_proof(cs, proof_for, root, signatures) && cs.empty_ext();
}

bool BlockProof::pack(vm::CellBuilder& cb, const BlockProof::Record& data) const {
  return cb.store_long_bool(0xc3, 8)
      && cb.append_cellslice_chk(data.proof_for, 648)
      && cb.store_ref_bool(data.root)
      && t_Maybe_Ref_BlockSignatures.store_from(cb, data.signatures);
}

bool BlockProof::pack_block_proof(vm::CellBuilder& cb, Ref<CellSlice> proof_for, Ref<Cell> root, Ref<CellSlice> signatures) const {
  return cb.store_long_bool(0xc3, 8)
      && cb.append_cellslice_chk(proof_for, 648)
      && cb.store_ref_bool(root)
      && t_Maybe_Ref_BlockSignatures.store_from(cb, signatures);
}

bool BlockProof::cell_pack(Ref<vm::Cell>& cell_ref, const BlockProof::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool BlockProof::cell_pack_block_proof(Ref<vm::Cell>& cell_ref, Ref<CellSlice> proof_for, Ref<Cell> root, Ref<CellSlice> signatures) const {
  vm::CellBuilder cb;
  return pack_block_proof(cb, std::move(proof_for), std::move(root), std::move(signatures)) && std::move(cb).finalize_to(cell_ref);
}

bool BlockProof::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(8) == 0xc3
      && pp.open("block_proof")
      && pp.field("proof_for")
      && t_BlockIdExt.print_skip(pp, cs)
      && pp.field("root")
      && t_Anything.print_ref(pp, cs.fetch_ref())
      && pp.field("signatures")
      && t_Maybe_Ref_BlockSignatures.print_skip(pp, cs)
      && pp.close();
}

const BlockProof t_BlockProof;

//
// code for type `ProofChain`
//

int ProofChain::get_tag(const vm::CellSlice& cs) const {
  // distinguish by parameter `m_` using 1 2 2 2
  return m_ ? chain_link : chain_empty;
}

int ProofChain::check_tag(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case chain_empty:
    return chain_empty;
  case chain_link:
    return chain_link;
  }
  return -1;
}

bool ProofChain::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case chain_empty:
    return m_ == 0;
  case chain_link: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_refs(1)
        && (!n || cs.advance_refs(1));
    }
  }
  return false;
}

bool ProofChain::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
  case chain_empty:
    return m_ == 0;
  case chain_link: {
    int n;
    return add_r1(n, 1, m_)
        && cs.advance_refs(1)
        && (!n || ProofChain{n}.validate_skip_ref(cs, weak));
    }
  }
  return false;
}

bool ProofChain::unpack(vm::CellSlice& cs, ProofChain::Record_chain_empty& data) const {
  return m_ == 0;
}

bool ProofChain::unpack_chain_empty(vm::CellSlice& cs) const {
  return m_ == 0;
}

bool ProofChain::cell_unpack(Ref<vm::Cell> cell_ref, ProofChain::Record_chain_empty& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ProofChain::cell_unpack_chain_empty(Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_chain_empty(cs) && cs.empty_ext();
}

bool ProofChain::unpack(vm::CellSlice& cs, ProofChain::Record_chain_link& data) const {
  return add_r1(data.n, 1, m_)
      && cs.fetch_ref_to(data.root)
      && (!data.n || cs.fetch_ref_to(data.prev));
}

bool ProofChain::unpack_chain_link(vm::CellSlice& cs, int& n, Ref<Cell>& root, Ref<Cell>& prev) const {
  return add_r1(n, 1, m_)
      && cs.fetch_ref_to(root)
      && (!n || cs.fetch_ref_to(prev));
}

bool ProofChain::cell_unpack(Ref<vm::Cell> cell_ref, ProofChain::Record_chain_link& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool ProofChain::cell_unpack_chain_link(Ref<vm::Cell> cell_ref, int& n, Ref<Cell>& root, Ref<Cell>& prev) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_chain_link(cs, n, root, prev) && cs.empty_ext();
}

bool ProofChain::pack(vm::CellBuilder& cb, const ProofChain::Record_chain_empty& data) const {
  return m_ == 0;
}

bool ProofChain::pack_chain_empty(vm::CellBuilder& cb) const {
  return m_ == 0;
}

bool ProofChain::cell_pack(Ref<vm::Cell>& cell_ref, const ProofChain::Record_chain_empty& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ProofChain::cell_pack_chain_empty(Ref<vm::Cell>& cell_ref) const {
  vm::CellBuilder cb;
  return pack_chain_empty(cb) && std::move(cb).finalize_to(cell_ref);
}

bool ProofChain::pack(vm::CellBuilder& cb, const ProofChain::Record_chain_link& data) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(data.root)
      && (!n || cb.store_ref_bool(data.prev));
}

bool ProofChain::pack_chain_link(vm::CellBuilder& cb, Ref<Cell> root, Ref<Cell> prev) const {
  int n;
  return add_r1(n, 1, m_)
      && cb.store_ref_bool(root)
      && (!n || cb.store_ref_bool(prev));
}

bool ProofChain::cell_pack(Ref<vm::Cell>& cell_ref, const ProofChain::Record_chain_link& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool ProofChain::cell_pack_chain_link(Ref<vm::Cell>& cell_ref, Ref<Cell> root, Ref<Cell> prev) const {
  vm::CellBuilder cb;
  return pack_chain_link(cb, std::move(root), std::move(prev)) && std::move(cb).finalize_to(cell_ref);
}

bool ProofChain::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
  case chain_empty:
    return pp.cons("chain_empty")
        && m_ == 0;
  case chain_link: {
    int n;
    return pp.open("chain_link")
        && add_r1(n, 1, m_)
        && pp.field("root")
        && t_Anything.print_ref(pp, cs.fetch_ref())
        && (!n || (pp.field("prev") && ProofChain{n}.print_ref(pp, cs.fetch_ref())))
        && pp.close();
    }
  }
  return pp.fail("unknown constructor for ProofChain");
}


//
// code for type `TopBlockDescr`
//
constexpr unsigned char TopBlockDescr::cons_tag[1];

int TopBlockDescr::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(8) == 0xd5 ? top_block_descr : -1;
}

bool TopBlockDescr::skip(vm::CellSlice& cs) const {
  int len;
  return cs.advance(656)
      && t_Maybe_Ref_BlockSignatures.skip(cs)
      && cs.fetch_uint_to(8, len)
      && 1 <= len
      && len <= 8
      && ProofChain{len}.skip(cs);
}

bool TopBlockDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len;
  return cs.fetch_ulong(8) == 0xd5
      && t_BlockIdExt.validate_skip(cs, weak)
      && t_Maybe_Ref_BlockSignatures.validate_skip(cs, weak)
      && cs.fetch_uint_to(8, len)
      && 1 <= len
      && len <= 8
      && ProofChain{len}.validate_skip(cs, weak);
}

bool TopBlockDescr::unpack(vm::CellSlice& cs, TopBlockDescr::Record& data) const {
  return cs.fetch_ulong(8) == 0xd5
      && cs.fetch_subslice_to(648, data.proof_for)
      && t_Maybe_Ref_BlockSignatures.fetch_to(cs, data.signatures)
      && cs.fetch_uint_to(8, data.len)
      && 1 <= data.len
      && data.len <= 8
      && ProofChain{data.len}.fetch_to(cs, data.chain);
}

bool TopBlockDescr::cell_unpack(Ref<vm::Cell> cell_ref, TopBlockDescr::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TopBlockDescr::pack(vm::CellBuilder& cb, const TopBlockDescr::Record& data) const {
  return cb.store_long_bool(0xd5, 8)
      && cb.append_cellslice_chk(data.proof_for, 648)
      && t_Maybe_Ref_BlockSignatures.store_from(cb, data.signatures)
      && cb.store_ulong_rchk_bool(data.len, 8)
      && 1 <= data.len
      && data.len <= 8
      && ProofChain{data.len}.store_from(cb, data.chain);
}

bool TopBlockDescr::cell_pack(Ref<vm::Cell>& cell_ref, const TopBlockDescr::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TopBlockDescr::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int len;
  return cs.fetch_ulong(8) == 0xd5
      && pp.open("top_block_descr")
      && pp.field("proof_for")
      && t_BlockIdExt.print_skip(pp, cs)
      && pp.field("signatures")
      && t_Maybe_Ref_BlockSignatures.print_skip(pp, cs)
      && cs.fetch_uint_to(8, len)
      && pp.field_int(len, "len")
      && 1 <= len
      && len <= 8
      && pp.field("chain")
      && ProofChain{len}.print_skip(pp, cs)
      && pp.close();
}

const TopBlockDescr t_TopBlockDescr;

//
// code for type `TopBlockDescrSet`
//
constexpr unsigned TopBlockDescrSet::cons_tag[1];

int TopBlockDescrSet::check_tag(const vm::CellSlice& cs) const {
  return cs.prefetch_ulong(32) == 0x4ac789f3 ? top_block_descr_set : -1;
}

bool TopBlockDescrSet::skip(vm::CellSlice& cs) const {
  return cs.advance(32)
      && t_HashmapE_96_Ref_TopBlockDescr.skip(cs);
}

bool TopBlockDescrSet::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(32) == 0x4ac789f3
      && t_HashmapE_96_Ref_TopBlockDescr.validate_skip(cs, weak);
}

bool TopBlockDescrSet::unpack(vm::CellSlice& cs, TopBlockDescrSet::Record& data) const {
  return cs.fetch_ulong(32) == 0x4ac789f3
      && t_HashmapE_96_Ref_TopBlockDescr.fetch_to(cs, data.collection);
}

bool TopBlockDescrSet::unpack_top_block_descr_set(vm::CellSlice& cs, Ref<CellSlice>& collection) const {
  return cs.fetch_ulong(32) == 0x4ac789f3
      && t_HashmapE_96_Ref_TopBlockDescr.fetch_to(cs, collection);
}

bool TopBlockDescrSet::cell_unpack(Ref<vm::Cell> cell_ref, TopBlockDescrSet::Record& data) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack(cs, data) && cs.empty_ext();
}

bool TopBlockDescrSet::cell_unpack_top_block_descr_set(Ref<vm::Cell> cell_ref, Ref<CellSlice>& collection) const {
  if (cell_ref.is_null()) { return false; }
  auto cs = load_cell_slice(std::move(cell_ref));
  return unpack_top_block_descr_set(cs, collection) && cs.empty_ext();
}

bool TopBlockDescrSet::pack(vm::CellBuilder& cb, const TopBlockDescrSet::Record& data) const {
  return cb.store_long_bool(0x4ac789f3, 32)
      && t_HashmapE_96_Ref_TopBlockDescr.store_from(cb, data.collection);
}

bool TopBlockDescrSet::pack_top_block_descr_set(vm::CellBuilder& cb, Ref<CellSlice> collection) const {
  return cb.store_long_bool(0x4ac789f3, 32)
      && t_HashmapE_96_Ref_TopBlockDescr.store_from(cb, collection);
}

bool TopBlockDescrSet::cell_pack(Ref<vm::Cell>& cell_ref, const TopBlockDescrSet::Record& data) const {
  vm::CellBuilder cb;
  return pack(cb, data) && std::move(cb).finalize_to(cell_ref);
}

bool TopBlockDescrSet::cell_pack_top_block_descr_set(Ref<vm::Cell>& cell_ref, Ref<CellSlice> collection) const {
  vm::CellBuilder cb;
  return pack_top_block_descr_set(cb, std::move(collection)) && std::move(cb).finalize_to(cell_ref);
}

bool TopBlockDescrSet::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return cs.fetch_ulong(32) == 0x4ac789f3
      && pp.open("top_block_descr_set")
      && pp.field("collection")
      && t_HashmapE_96_Ref_TopBlockDescr.print_skip(pp, cs)
      && pp.close();
}

const TopBlockDescrSet t_TopBlockDescrSet;

// definitions of constant types used

const NatWidth t_natwidth_1{1};
const NatWidth t_natwidth_9{9};
const NatLeq t_natleq_30{30};
const Maybe t_Maybe_Anycast{t_Anycast};
const Int t_int8{8};
const Bits t_bits256{256};
const Int t_int32{32};
const VarUInteger t_VarUInteger_16{16};
const VarUInteger t_VarUInteger_32{32};
const HashmapE t_HashmapE_32_VarUInteger_32{32, t_VarUInteger_32};
const UInt t_uint64{64};
const UInt t_uint32{32};
const NatWidth t_natwidth_5{5};
const Maybe t_Maybe_natwidth_5{t_natwidth_5};
const Maybe t_Maybe_TickTock{t_TickTock};
const Maybe t_Maybe_Ref_Cell{t_RefCell};
const HashmapE t_HashmapE_256_SimpleLib{256, t_SimpleLib};
const RefT t_Ref_StateInit{t_StateInit};
const Either t_Either_StateInit_Ref_StateInit{t_StateInit, t_Ref_StateInit};
const Maybe t_Maybe_Either_StateInit_Ref_StateInit{t_Either_StateInit_Ref_StateInit};
const NatLeq t_natleq_96{96};
const Message t_Message_Any{t_Anything};
const RefT t_Ref_Message_Any{t_Message_Any};
const RefT t_Ref_Transaction{t_Transaction};
const RefT t_Ref_MsgEnvelope{t_MsgEnvelope};
const HashmapAugE t_HashmapAugE_256_InMsg_ImportFees{256, t_InMsg, t_ImportFees};
const RefT t_Ref_InMsg{t_InMsg};
const HashmapAugE t_HashmapAugE_256_OutMsg_CurrencyCollection{256, t_OutMsg, t_CurrencyCollection};
const HashmapAugE t_HashmapAugE_352_EnqueuedMsg_uint64{352, t_EnqueuedMsg, t_uint64};
const HashmapE t_HashmapE_96_ProcessedUpto{96, t_ProcessedUpto};
const HashmapE t_HashmapE_320_IhrPendingSince{320, t_IhrPendingSince};
const VarUInteger t_VarUInteger_7{7};
const Maybe t_Maybe_Grams{t_Grams};
const RefT t_Ref_Account{t_Account};
const HashmapAugE t_HashmapAugE_256_ShardAccount_DepthBalanceInfo{256, t_ShardAccount, t_DepthBalanceInfo};
const UInt t_uint15{15};
const Maybe t_Maybe_Ref_Message_Any{t_Ref_Message_Any};
const HashmapE t_HashmapE_15_Ref_Message_Any{15, t_Ref_Message_Any};
const RefT t_Ref_TYPE_1613{t_Transaction_aux};
const HASH_UPDATE t_HASH_UPDATE_Account{t_Account};
const RefT t_Ref_HASH_UPDATE_Account{t_HASH_UPDATE_Account};
const RefT t_Ref_TransactionDescr{t_TransactionDescr};
const HashmapAug t_HashmapAug_64_Ref_Transaction_CurrencyCollection{64, t_Ref_Transaction, t_CurrencyCollection};
const HashmapAugE t_HashmapAugE_256_AccountBlock_CurrencyCollection{256, t_AccountBlock, t_CurrencyCollection};
const VarUInteger t_VarUInteger_3{3};
const Maybe t_Maybe_VarUInteger_3{t_VarUInteger_3};
const Maybe t_Maybe_int32{t_int32};
const RefT t_Ref_TYPE_1624{t_TrComputePhase_aux};
const UInt t_uint16{16};
const Maybe t_Maybe_TrStoragePhase{t_TrStoragePhase};
const Maybe t_Maybe_TrCreditPhase{t_TrCreditPhase};
const RefT t_Ref_TrActionPhase{t_TrActionPhase};
const Maybe t_Maybe_Ref_TrActionPhase{t_Ref_TrActionPhase};
const Maybe t_Maybe_TrBouncePhase{t_TrBouncePhase};
const NatWidth t_natwidth_6{6};
const NatWidth t_natwidth_8{8};
const MessageRelaxed t_MessageRelaxed_Any{t_Anything};
const RefT t_Ref_MessageRelaxed_Any{t_MessageRelaxed_Any};
const NatLeq t_natleq_60{60};
const RefT t_Ref_OutMsgQueueInfo{t_OutMsgQueueInfo};
const RefT t_Ref_ShardAccounts{t_ShardAccounts};
const HashmapE t_HashmapE_256_LibDescr{256, t_LibDescr};
const Maybe t_Maybe_BlkMasterInfo{t_BlkMasterInfo};
const RefT t_Ref_TYPE_1637{t_ShardStateUnsplit_aux};
const RefT t_Ref_McStateExtra{t_McStateExtra};
const Maybe t_Maybe_Ref_McStateExtra{t_Ref_McStateExtra};
const RefT t_Ref_ShardStateUnsplit{t_ShardStateUnsplit};
const Hashmap t_Hashmap_256_True{256, t_True};
const RefT t_Ref_BlkMasterInfo{t_BlkMasterInfo};
const BlkPrevInfo t_BlkPrevInfo_0{0};
const RefT t_Ref_BlkPrevInfo_0{t_BlkPrevInfo_0};
const RefT t_Ref_ExtBlkRef{t_ExtBlkRef};
const RefT t_Ref_BlockInfo{t_BlockInfo};
const RefT t_Ref_ValueFlow{t_ValueFlow};
const MERKLE_UPDATE t_MERKLE_UPDATE_ShardState{t_ShardState};
const RefT t_Ref_MERKLE_UPDATE_ShardState{t_MERKLE_UPDATE_ShardState};
const RefT t_Ref_BlockExtra{t_BlockExtra};
const RefT t_Ref_InMsgDescr{t_InMsgDescr};
const RefT t_Ref_OutMsgDescr{t_OutMsgDescr};
const RefT t_Ref_ShardAccountBlocks{t_ShardAccountBlocks};
const RefT t_Ref_McBlockExtra{t_McBlockExtra};
const Maybe t_Maybe_Ref_McBlockExtra{t_Ref_McBlockExtra};
const RefT t_Ref_TYPE_1647{t_ValueFlow_aux};
const RefT t_Ref_TYPE_1648{t_ValueFlow_aux1};
const NatWidth t_natwidth_3{3};
const BinTree t_BinTree_ShardDescr{t_ShardDescr};
const RefT t_Ref_BinTree_ShardDescr{t_BinTree_ShardDescr};
const HashmapE t_HashmapE_32_Ref_BinTree_ShardDescr{32, t_Ref_BinTree_ShardDescr};
const HashmapAugE t_HashmapAugE_96_ShardFeeCreated_ShardFeeCreated{96, t_ShardFeeCreated, t_ShardFeeCreated};
const Hashmap t_Hashmap_32_Ref_Cell{32, t_RefCell};
const RefT t_Ref_Hashmap_32_Ref_Cell{t_Hashmap_32_Ref_Cell};
const HashmapAugE t_HashmapAugE_32_KeyExtBlkRef_KeyMaxLt{32, t_KeyExtBlkRef, t_KeyMaxLt};
const HashmapE t_HashmapE_256_CreatorStats{256, t_CreatorStats};
const NatWidth t_natwidth_16{16};
const Maybe t_Maybe_ExtBlkRef{t_ExtBlkRef};
const RefT t_Ref_TYPE_1665{t_McStateExtra_aux};
const RefT t_Ref_SignedCertificate{t_SignedCertificate};
const HashmapE t_HashmapE_16_CryptoSignaturePair{16, t_CryptoSignaturePair};
const Maybe t_Maybe_Ref_InMsg{t_Ref_InMsg};
const RefT t_Ref_TYPE_1673{t_McBlockExtra_aux};
const Hashmap t_Hashmap_16_ValidatorDescr{16, t_ValidatorDescr};
const HashmapE t_HashmapE_16_ValidatorDescr{16, t_ValidatorDescr};
const Hashmap t_Hashmap_32_True{32, t_True};
const NatWidth t_natwidth_12{12};
const NatWidth t_natwidth_32{32};
const NatWidth t_natwidth_13{13};
const HashmapE t_HashmapE_32_WorkchainDescr{32, t_WorkchainDescr};
const Hashmap t_Hashmap_32_StoragePrices{32, t_StoragePrices};
const HashmapE t_HashmapE_256_True{256, t_True};
const RefT t_Ref_ValidatorTempKey{t_ValidatorTempKey};
const HashmapE t_HashmapE_256_ValidatorSignedTempKey{256, t_ValidatorSignedTempKey};
const RefT t_Ref_BlockSignatures{t_BlockSignatures};
const Maybe t_Maybe_Ref_BlockSignatures{t_Ref_BlockSignatures};
const RefT t_Ref_TopBlockDescr{t_TopBlockDescr};
const HashmapE t_HashmapE_96_Ref_TopBlockDescr{96, t_Ref_TopBlockDescr};

} // namespace gen

} // namespace block
