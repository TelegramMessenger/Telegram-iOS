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

#include <cassert>
#include <utility>
#include <atomic>
#include <iostream>

#include "td/utils/StringBuilder.h"
#include "td/utils/logging.h"

namespace td {

template <class T>
class Ref;

class CntObject {
 private:
  mutable std::atomic<int> cnt_;
  template <class T>
  friend class Ref;

  void inc() const {
    cnt_.fetch_add(1, std::memory_order_relaxed);
  }
  bool dec() const {
    return cnt_.fetch_sub(1, std::memory_order_acq_rel) == 1;
  }
  void inc(int cnt) const {
    cnt_.fetch_add(cnt, std::memory_order_relaxed);
  }
  bool dec(int cnt) const {
    return cnt_.fetch_sub(cnt, std::memory_order_acq_rel) == cnt;
  }

 public:
  struct WriteError {};
  CntObject() : cnt_(1) {
  }
  CntObject(const CntObject& other) : CntObject() {
  }
  CntObject(CntObject&& other) : CntObject() {
  }
  CntObject& operator=(const CntObject& other) {
    return *this;
  }
  CntObject& operator=(CntObject&& other) {
    return *this;
  }
  virtual ~CntObject() {
    auto cnt = cnt_.load(std::memory_order_relaxed);
    (void)cnt;
    //TODO: assert(cnt == 0) will fail if object is allocated on stack
    assert(cnt == 0 || cnt == 1);
  }
  virtual CntObject* make_copy() const {
    throw WriteError();
  }
  bool is_unique() const {
    return cnt_.load(std::memory_order_acquire) == 1;
  }
  int get_refcnt() const {
    // use std::memory_order_acquire
    return cnt_.load(std::memory_order_acquire);
  }
  void assert_unique() const {
    assert(is_unique());
  }
};

typedef Ref<CntObject> RefAny;

template <class T>
class Cnt : public CntObject {
  T value;

 public:
  template <typename... Args>
  Cnt(Args&&... args) : value(std::forward<Args>(args)...) {
    ///std::cout << "(N " << (void*)this << ")";
  }
  Cnt(const Cnt& x) : CntObject(), value(x.value) {
    ///std::cout << "(C)";
  }
  virtual ~Cnt() {
    ///std::cout << "(D " << (void*)this << ")";
  }
  T* operator->() {
    return &value;
  }
  const T* operator->() const {
    return &value;
  }
  T& operator*() {
    return value;
  }
  const T& operator*() const {
    return value;
  }
  Cnt* make_copy() const override {
    ///std::cout << "(c " << (const void*)this << ")";
    return new Cnt{value};
  }
};

template <class T>
struct RefValue {
  using Type = T;
  static Type& make_ref(T* ptr) {
    return *ptr;
  }
  static const Type& make_const_ref(const T* ptr) {
    return *ptr;
  }
  static Type* make_ptr(T* ptr) {
    return ptr;
  }
  static const Type* make_const_ptr(const T* ptr) {
    return ptr;
  }
};

template <class T>
struct RefValue<Cnt<T>> {
  using Type = T;
  static Type& make_ref(Cnt<T>* ptr) {
    return **ptr;
  }
  static const Type& make_const_ref(const Cnt<T>* ptr) {
    return **ptr;
  }
  static Type* make_ptr(Cnt<T>* ptr) {
    return &(**ptr);
  }
  static const Type* make_const_ptr(const Cnt<T>* ptr) {
    return &(**ptr);
  }
};

struct static_cast_ref {};

namespace detail {
void safe_delete(const CntObject* ptr);
}
template <class T>
class Ref {
  T* ptr;

  template <class S>
  friend class Ref;

 public:
  struct NullRef {};
  Ref() : ptr(0) {
  }
  //explicit Ref(bool init) : ptr(init ? new T : 0) {
  //}
  template <typename... Args>
  explicit Ref(bool init, Args&&... args) : ptr(0) {
    //assert(init);
    ptr = new T(std::forward<Args>(args)...);
  }
  /*
  explicit Ref(const T& c) : ptr(&c) {
    ptr.inc();
  }
  */
  explicit Ref(T* pc) : ptr(pc) {
    if (ptr) {
      acquire_shared(ptr);
    }
  }
  explicit Ref(const T* pc) : ptr(const_cast<T*>(pc)) {
    if (ptr) {
      acquire_shared(ptr);
    }
  }
  explicit Ref(const T& obj) : ptr(obj.make_copy()) {
  }
  Ref(const Ref& r) : ptr(r.ptr) {
    if (ptr) {
      acquire_shared(ptr);
      ///std::cout << "(rc+ " << (const void*)ptr << ")";
    }
  }
  Ref(Ref&& r) noexcept : ptr(std::move(r.ptr)) {
    r.ptr = 0;
  }

  T* release() {
    auto res = ptr;
    ptr = nullptr;
    return res;
  }
  struct acquire_t {};
  Ref(T* ptr, acquire_t) : ptr(ptr) {
  }

  template <class S>
  Ref(const Ref<S>& r, std::enable_if_t<std::is_base_of<T, S>::value, int> t = 0) : ptr(static_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<T, S>::value, "Invalid static Ref conversion");
    if (ptr) {
      acquire_shared(ptr);
    }
  }

  template <class S>
  explicit Ref(const Ref<S>& r,
               std::enable_if_t<!std::is_base_of<T, S>::value && std::is_base_of<S, T>::value, int> t = 0)
      : ptr(dynamic_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<S, T>::value, "Invalid dynamic Ref conversion");
    if (ptr) {
      acquire_shared(ptr);
      //std::cout << "(rv+ " << (const void*)ptr << ")";
    } else {
      //std::cout << "(error converting " << (const void*)r.ptr << ")";
    }
  }

  template <class S>
  Ref(static_cast_ref, const Ref<S>& r, std::enable_if_t<std::is_base_of<S, T>::value, int> t = 0)
      : ptr(static_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<S, T>::value, "Invalid static Ref downcast");
    if (r.ptr) {
      acquire_shared(ptr);
    } else {
      ptr = nullptr;
    }
  }

  template <class S>
  Ref(Ref<S>&& r, std::enable_if_t<std::is_base_of<T, S>::value, int> t = 0) : ptr(static_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<T, S>::value, "Invalid static Ref conversion");
    r.ptr = nullptr;
  }

  template <class S>
  explicit Ref(Ref<S>&& r, std::enable_if_t<!std::is_base_of<T, S>::value && std::is_base_of<S, T>::value, int> t = 0)
      : ptr(dynamic_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<S, T>::value, "Invalid dynamic Ref conversion");
    if (!ptr && r.ptr) {
      release_shared(r.ptr);
    }
    r.ptr = nullptr;
  }

  template <class S>
  Ref(static_cast_ref, Ref<S>&& r, std::enable_if_t<std::is_base_of<S, T>::value, int> t = 0) noexcept
      : ptr(static_cast<T*>(r.ptr)) {
    static_assert(std::is_base_of<S, T>::value, "Invalid static Ref downcast");
    if (r.ptr) {
      r.ptr = nullptr;
    } else {
      ptr = nullptr;
    }
  }

  ~Ref() {
    clear();
  }
  Ref& operator=(const Ref& r);
  template <class S>
  Ref& operator=(const Ref<S>& r);
  Ref& operator=(Ref&& r);
  template <class S>
  Ref& operator=(Ref<S>&& r);
  const typename RefValue<T>::Type* operator->() const {
    if (!ptr) {
      CHECK(ptr && "deferencing null Ref");
      throw NullRef{};
    }
    return RefValue<T>::make_const_ptr(ptr);
  }
  const typename RefValue<T>::Type& operator*() const {
    if (!ptr) {
      CHECK(ptr && "deferencing null Ref");
      throw NullRef{};
    }
    return RefValue<T>::make_const_ref(ptr);
  }
  const T* get() const {
    return ptr;
  }
  bool is_null() const {
    return ptr == 0;
  }
  bool not_null() const {
    return ptr != 0;
  }
  bool is_unique() const {
    if (!ptr) {
      CHECK(ptr && "defererencing null Ref");
      throw NullRef{};
    }
    return ptr->is_unique();
  }
  void clear() {
    if (ptr) {
      ///std::cout << "(r- " << (const void*)ptr << ")";
      release_shared(ptr);
      ptr = 0;
    }
  }
  void swap(Ref& r) {
    std::swap(ptr, r.ptr);
  }
  Ref& operator^=(const Ref& r);
  Ref& operator^=(Ref&& r);
  Ref& operator&=(bool retain);
  bool operator==(const Ref& r) const;
  bool operator!=(const Ref& r) const;
  typename RefValue<T>::Type& write();
  typename RefValue<T>::Type& unique_write() const;

 public:
  template <class S>
  static void release_shared(S* obj, int cnt = 1) {
    if (obj->dec(cnt)) {
      detail::safe_delete(obj);
    }
  }
  template <class S>
  static void acquire_shared(S* obj, int cnt = 1) {
    obj->inc(cnt);
  }

 private:
  void assign(T* p) {
    ptr = p;
    if (p) {
      acquire_shared(p);
      ///std::cout << "(r+ " << (const void*)ptr << ")";
    }
  }
};

template <class T, typename... Args>
Ref<T> make_ref(Args&&... args) {
  return Ref<T>{true, std::forward<Args>(args)...};
}

template <class T, typename... Args>
Ref<Cnt<T>> make_cnt_ref(Args&&... args) {
  return Ref<Cnt<T>>{true, std::forward<Args>(args)...};
}

template <class T>
td::StringBuilder& operator<<(td::StringBuilder& sb, const Ref<T>& ref) {
  if (ref.is_null()) {
    return sb << "nullptr";
  }
  return sb << *ref;
}

template <class T>
Ref<T>& Ref<T>::operator=(const Ref<T>& r) {
  if (ptr != r.ptr) {
    clear();
    assign(r.ptr);
  }
  return *this;
}

template <class T>
template <class S>
Ref<T>& Ref<T>::operator=(const Ref<S>& r) {
  if (ptr != static_cast<T*>(r.ptr)) {
    clear();
    assign(r.ptr);
  }
  return *this;
}

template <class T>
Ref<T>& Ref<T>::operator=(Ref<T>&& r) {
  clear();
  ptr = r.ptr;
  r.ptr = 0;
  return *this;
}

template <class T>
template <class S>
Ref<T>& Ref<T>::operator=(Ref<S>&& r) {
  clear();
  ptr = r.ptr;
  r.ptr = 0;
  return *this;
}

template <class T>
typename RefValue<T>::Type& Ref<T>::write() {
  if (!ptr) {
    throw CntObject::WriteError();
  }
  if (!ptr->is_unique()) {
    T* copy = dynamic_cast<T*>(ptr->make_copy());
    if (!copy) {
      throw CntObject::WriteError();
    }
    release_shared(ptr);
    ptr = copy;
  }
  return RefValue<T>::make_ref(ptr);
}

template <class T>
typename RefValue<T>::Type& Ref<T>::unique_write() const {
  if (!ptr || !ptr->is_unique()) {
    throw CntObject::WriteError();
  }
  return RefValue<T>::make_ref(ptr);
}

template <class T>
Ref<T>& Ref<T>::operator^=(const Ref<T>& r) {
  if (r.ptr && r.ptr != ptr) {
    clear();
    assign(r.ptr);
  }
  return *this;
}

template <class T>
Ref<T>& Ref<T>::operator^=(Ref<T>&& r) {
  if (r.ptr && r.ptr != ptr) {
    clear();
    ptr = r.ptr;
    r.ptr = 0;
  }
  return *this;
}

template <class T>
Ref<T>& Ref<T>::operator&=(bool retain) {
  if (!retain && ptr) {
    clear();
  }
  return *this;
}

template <class T>
bool Ref<T>::operator==(const Ref<T>& r) const {
  return ptr == r.ptr;
}

template <class T>
bool Ref<T>::operator!=(const Ref<T>& r) const {
  return ptr != r.ptr;
}

template <class T>
void swap(Ref<T>& r1, Ref<T>& r2) {
  r1.swap(r2);
}

}  // namespace td
