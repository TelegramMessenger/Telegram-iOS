//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

///\file

#include "td/telegram/td_api.h"

#include <cstdint>

namespace td {

/**
 * Interface of callback for low-level interaction with TDLib.
 */
class TdCallback {
 public:
  /**
   * This function is called for every answer to a request made to TDLib and for every incoming update of the type td_api::Update.
   * \param id Request identifier or 0 for incoming updates.
   * \param result Answer to the TDLib request or an incoming update.
   */
  virtual void on_result(std::uint64_t id, td_api::object_ptr<td_api::Object> result) = 0;

  /**
   * This function is called for every unsuccessful request made to TDLib.
   * \param id Request identifier.
   * \param error An answer to a TDLib request or an incoming update.
   */
  virtual void on_error(std::uint64_t id, td_api::object_ptr<td_api::error> error) = 0;

  /**
   * Destroys the TdCallback.
   */
  virtual ~TdCallback() = default;
};

}  // namespace td
