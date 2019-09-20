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
#include "atom.h"

namespace vm {
using td::Ref;

std::atomic<Atom*> Atom::hashtable[hashtable_size] = {};
std::atomic<int> Atom::atoms_defined{0};
std::atomic<int> Atom::anon_atoms{0};

void Atom::print_to(std::ostream& os) const {
  if (name_.empty()) {
    os << "atom#" << index_;
  } else {
    os << name_;
  }
}

std::string Atom::make_name() const {
  char buffer[16];
  sprintf(buffer, "atom#%d", index_);
  return buffer;
}

std::ostream& operator<<(std::ostream& os, const Atom& atom) {
  atom.print_to(os);
  return os;
}

std::ostream& operator<<(std::ostream& os, Ref<Atom> atom_ref) {
  atom_ref->print_to(os);
  return os;
}

std::pair<unsigned, unsigned> Atom::compute_hash(td::Slice name) {
  unsigned h1 = 1, h2 = 1;
  for (std::size_t i = 0; i < name.size(); i++) {
    h1 = (239 * h1 + (unsigned char)name[i]) % hashtable_size;
    h2 = (17 * h2 + (unsigned char)name[i]) % (hashtable_size - 1);
  }
  return std::make_pair(h1, h2 + 1);
}

Ref<Atom> Atom::find(td::Slice name, bool create) {
  auto hash = compute_hash(name);
  while (true) {
    auto& pos = hashtable[hash.first];
    Atom* ptr = pos.load(std::memory_order_acquire);
    if (ptr) {
      if (ptr->name_as_slice() == name) {
        return Ref<Atom>(ptr);
      }
    } else if (!create) {
      return {};
    } else {
      Atom* p2 = new Atom(name.str(), hash.first);
      Atom* p1 = nullptr;
      if (pos.compare_exchange_strong(p1, p2)) {
        atoms_defined.fetch_add(1, std::memory_order_relaxed);
        return Ref<Atom>(p2);
      }
      delete p2;
      CHECK(p1);
      if (p1->name_as_slice() == name) {
        return Ref<Atom>(p1);
      }
    }
    hash.first += hash.second;
    if (hash.first >= hashtable_size) {
      hash.first -= hashtable_size;
    }
  }
}

Ref<Atom> Atom::anon() {
  int c = anon_atoms.fetch_add(1, std::memory_order_relaxed);
  return Ref<Atom>{true, "", ~c};
}

}  // namespace vm
