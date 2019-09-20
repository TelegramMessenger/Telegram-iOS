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
#include <atomic>
#include "vm/stack.hpp"
#include "td/utils/Slice.h"

namespace vm {
using td::Ref;

class Atom : public td::CntObject {
  std::string name_;
  int index_;
  static constexpr unsigned hashtable_size = 170239;
  static std::atomic<Atom*> hashtable[hashtable_size];
  static std::atomic<int> atoms_defined;
  static std::atomic<int> anon_atoms;
  static std::pair<unsigned, unsigned> compute_hash(td::Slice name);

 public:
  Atom(const Atom&) = delete;
  Atom &operator=(const Atom&) = delete;
  Atom(Atom&&) = delete;
  Atom &operator=(Atom&&) = delete;
  ~Atom() override = default;
  Atom(std::string name, int index) : name_(name), index_(index) {
  }
  static Ref<Atom> anon();
  static Ref<Atom> find(td::Slice name, bool create = false);
  static Ref<Atom> create(td::Slice name) {
    return find(std::move(name), true);
  }
  std::string name() const {
    return name_;
  }
  std::string name_ext() const {
    return name_.empty() ? make_name() : name_;
  }
  td::Slice name_as_slice() const {
    return td::Slice{name_};
  }
  int index() const {
    return index_;
  }
  void print_to(std::ostream& os) const;

 private:
  std::string make_name() const;
};

std::ostream& operator<<(std::ostream& os, const Atom& atom);
std::ostream& operator<<(std::ostream& os, Ref<Atom> atom_ref);

}  // namespace vm
