//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

/**
 * \file
 * Contains the declarations of a base class for all TL-objects and some helper methods
 */

#include <cstddef>
#include <cstdint>
#include <string>
#include <type_traits>
#include <utility>

namespace td {

class TlStorerCalcLength;

class TlStorerUnsafe;

class TlStorerToString;

/**
 * This class is a base class for all TDLib TL-objects.
 */
class TlObject {
 public:
  /**
   * Returns an identifier, uniquely determining the TL-type of the object.
   */
  virtual std::int32_t get_id() const = 0;

  /**
   * Appends the object to the storer serializing object, a buffer of fixed length.
   * \param[in] s Storer to which the object will be appended.
   */
  virtual void store(TlStorerUnsafe &s) const {
  }

  /**
   * Appends the object to the storer, calculating the TL-length of the serialized object.
   * \param[in] s Storer to which the object will be appended.
   */
  virtual void store(TlStorerCalcLength &s) const {
  }

  /**
   * Helper function for the to_string method. Appends a string representation of the object to the storer.
   * \param[in] s Storer to which the object string representation will be appended.
   * \param[in] field_name Object field_name if applicable.
   */
  virtual void store(TlStorerToString &s, const char *field_name) const = 0;

  /**
   * Default constructor.
   */
  TlObject() = default;

  /**
   * Deleted copy constructor.
   */
  TlObject(const TlObject &) = delete;

  /**
   * Deleted copy assignment operator.
   */
  TlObject &operator=(const TlObject &) = delete;

  /**
   * Default move constructor.
   */
  TlObject(TlObject &&) = default;

  /**
   * Default move assignment operator.
   */
  TlObject &operator=(TlObject &&) = default;

  /**
   * Virtual destructor.
   */
  virtual ~TlObject() = default;
};

/// @cond UNDOCUMENTED
namespace tl {

template <class T>
class unique_ptr {
 public:
  using pointer = T *;
  using element_type = T;

  unique_ptr() noexcept = default;
  unique_ptr(const unique_ptr &) = delete;
  unique_ptr &operator=(const unique_ptr &) = delete;
  unique_ptr(unique_ptr &&other) noexcept : ptr_(other.release()) {
  }
  unique_ptr &operator=(unique_ptr &&other) noexcept {
    reset(other.release());
    return *this;
  }
  ~unique_ptr() {
    reset();
  }

  unique_ptr(std::nullptr_t) noexcept {
  }
  explicit unique_ptr(T *ptr) noexcept : ptr_(ptr) {
  }
  template <class S, class = typename std::enable_if<std::is_base_of<T, S>::value>::type>
  unique_ptr(unique_ptr<S> &&other) noexcept : ptr_(static_cast<S *>(other.release())) {
  }
  template <class S, class = typename std::enable_if<std::is_base_of<T, S>::value>::type>
  unique_ptr &operator=(unique_ptr<S> &&other) noexcept {
    reset(static_cast<T *>(other.release()));
    return *this;
  }
  void reset(T *new_ptr = nullptr) noexcept {
    static_assert(sizeof(T) > 0, "Can't destroy unique_ptr with incomplete type");
    delete ptr_;
    ptr_ = new_ptr;
  }
  T *release() noexcept {
    auto res = ptr_;
    ptr_ = nullptr;
    return res;
  }
  T *get() noexcept {
    return ptr_;
  }
  const T *get() const noexcept {
    return ptr_;
  }
  T *operator->() noexcept {
    return ptr_;
  }
  const T *operator->() const noexcept {
    return ptr_;
  }
  T &operator*() noexcept {
    return *ptr_;
  }
  const T &operator*() const noexcept {
    return *ptr_;
  }
  explicit operator bool() const noexcept {
    return ptr_ != nullptr;
  }

 private:
  T *ptr_{nullptr};
};

template <class T>
bool operator==(std::nullptr_t, const unique_ptr<T> &p) {
  return !p;
}
template <class T>
bool operator==(const unique_ptr<T> &p, std::nullptr_t) {
  return !p;
}
template <class T>
bool operator!=(std::nullptr_t, const unique_ptr<T> &p) {
  return static_cast<bool>(p);
}
template <class T>
bool operator!=(const unique_ptr<T> &p, std::nullptr_t) {
  return static_cast<bool>(p);
}

}  // namespace tl
/// @endcond

/**
 * A smart wrapper to store a pointer to a TL-object.
 */
template <class Type>
using tl_object_ptr = tl::unique_ptr<Type>;

/**
 * A function to create a dynamically allocated TL-object. Can be treated as an analogue of std::make_unique.
 * Usage example:
 * \code
 * auto get_me_request = td::make_tl_object<td::td_api::getMe>();
 * auto message_text = td::make_tl_object<td::td_api::formattedText>("Hello, world!!!",
 *                     td::td_api::array<td::tl_object_ptr<td::td_api::textEntity>>());
 * auto send_message_request = td::make_tl_object<td::td_api::sendMessage>(chat_id, 0, nullptr, nullptr, nullptr,
 *      td::make_tl_object<td::td_api::inputMessageText>(std::move(message_text), nullptr, true));
 * \endcode
 *
 * \tparam Type Type of the TL-object to construct.
 * \param[in] args Arguments to pass to the object constructor.
 * \return Wrapped pointer to the created TL-object.
 */
template <class Type, class... Args>
tl_object_ptr<Type> make_tl_object(Args &&...args) {
  return tl_object_ptr<Type>(new Type(std::forward<Args>(args)...));
}

/**
 * A function to downcast a wrapped pointer to a TL-object to a pointer to its subclass.
 * Casting an object to an incorrect type will lead to undefined behaviour.
 * Examples of usage:
 * \code
 * td::tl_object_ptr<td::td_api::callState> call_state = ...;
 * switch (call_state->get_id()) {
 *   case td::td_api::callStatePending::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::callStatePending>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateExchangingKeys::ID: {
 *     // no additional fields, so cast isn't needed
 *     break;
 *   }
 *   case td::td_api::callStateReady::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::callStateReady>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateHangingUp::ID: {
 *     // no additional fields, so cast isn't needed
 *     break;
 *   }
 *   case td::td_api::callStateDiscarded::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::callStateDiscarded>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateError::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::callStateError>(call_state);
 *     // use state
 *     break;
 *   }
 *   default:
 *     assert(false);
 * }
 * \endcode
 *
 * \tparam ToT Type of TL-object to move to.
 * \tparam FromT Type of TL-object to move from, this is auto-deduced.
 * \param[in] from Wrapped pointer to a TL-object.
 */
template <class ToT, class FromT>
tl_object_ptr<ToT> move_tl_object_as(tl_object_ptr<FromT> &from) {
  return tl_object_ptr<ToT>(static_cast<ToT *>(from.release()));
}

/**
 * \overload
 */
template <class ToT, class FromT>
tl_object_ptr<ToT> move_tl_object_as(tl_object_ptr<FromT> &&from) {
  return tl_object_ptr<ToT>(static_cast<ToT *>(from.release()));
}

}  // namespace td
