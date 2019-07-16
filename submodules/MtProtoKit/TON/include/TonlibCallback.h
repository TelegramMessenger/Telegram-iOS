#pragma once

#include "tonlib_api.h"

namespace tonlib_api = ton::tonlib_api;

class TonlibCallback {
 public:
  virtual void on_result(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::Object> result) = 0;
  virtual void on_error(std::uint64_t id, tonlib_api::object_ptr<tonlib_api::error> error) = 0;
  virtual ~TonlibCallback() = default;
};
