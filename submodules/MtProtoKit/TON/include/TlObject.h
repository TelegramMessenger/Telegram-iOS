#pragma once

/**
 * \file
 * Contains declarations of a base class for all TL-objects and some helper methods
 */

#include <cstdint>
#include <memory>
#include <string>
#include <utility>

namespace td {
class TlStorerCalcLength;

class TlStorerUnsafe;

class TlStorerToString;
}  // namespace td
namespace ton {
/**
 * This class is a base class for all TL-objects.
 */
class TlObject {
 public:
  /**
   * Returns identifier uniquely determining TL-type of the object.
   */
  virtual std::int32_t get_id() const = 0;

  /**
   * Appends object to the storer serializing object to a buffer of fixed length.
   * \param[in] s Storer to which object will be appended.
   */
  virtual void store(td::TlStorerUnsafe &s) const {
  }

  /**
   * Appends object to the storer calculating TL-length of the serialized object.
   * \param[in] s Storer to which object will be appended.
   */
  virtual void store(td::TlStorerCalcLength &s) const {
  }

  /**
   * Helper function for to_string method. Appends string representation of the object to the storer.
   * \param[in] s Storer to which object string representation will be appended.
   * \param[in] field_name Object field_name if applicable.
   */
  virtual void store(td::TlStorerToString &s, const char *field_name) const = 0;

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
   * Virtual desctructor.
   */
  virtual ~TlObject() = default;
};

/**
 * A smart wrapper to store a pointer to a TL-object.
 */
template <class Type>
using tl_object_ptr = std::unique_ptr<Type>;

/**
 * A function to create a dynamically allocated TL-object. Can be treated as an analogue of std::make_unique.
 * Examples of usage:
 * \code
 * auto get_auth_state_request = td::create_tl_object<td::td_api::getAuthState>();
 * auto send_message_request = td::create_tl_object<td::td_api::sendMessage>(chat_id, 0, false, false, nullptr,
 *      td::create_tl_object<td::td_api::inputMessageText>("Hello, world!!!", false, true, {}, nullptr));
 * \endcode
 *
 * \tparam Type Type of a TL-object to construct.
 * \param[in] args Arguments to pass to the object constructor.
 * \return Wrapped pointer to the created TL-object.
 */
template <class Type, class... Args>
tl_object_ptr<Type> create_tl_object(Args &&... args) {
  return tl_object_ptr<Type>(new Type(std::forward<Args>(args)...));
}

/**
 * A function to downcast a wrapped pointer to TL-object to a pointer to its subclass.
 * It is undefined behaviour to cast an object to the wrong type.
 * Examples of usage:
 * \code
 * td::tl_object_ptr<td::td_api::AuthState> auth_state = ...;
 * switch (auth_state->get_id()) {
 *   case td::td_api::authStateWaitPhoneNumber::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::authStateWaitPhoneNumber>(auth_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::authStateWaitCode::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::authStateWaitCode>(auth_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::authStateWaitPassword::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::authStateWaitPassword>(auth_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::authStateOk::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::authStateOk>(auth_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::authStateLoggingOut::ID: {
 *     auto state = td::move_tl_object_as<td::td_api::authStateLoggingOut>(auth_state);
 *     // use state
 *     break;
 *   }
 * }
 * \endcode
 *
 * \tparam ToT Type of a TL-object to move to.
 * \tparam FromT Type of a TL-object to move from, auto-deduced.
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

}  // namespace ton
