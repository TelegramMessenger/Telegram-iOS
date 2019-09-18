#pragma once
#include "tonlib_api.h"

#include "TonlibCallback.h"

namespace tonlib {
class Client final {
 public:
  Client();
  struct Request {
    std::uint64_t id;
    tonlib_api::object_ptr<tonlib_api::Function> function;
  };

  void send(Request&& request);

  struct Response {
    std::uint64_t id;
    tonlib_api::object_ptr<tonlib_api::Object> object;
  };

  Response receive(double timeout);

  static Response execute(Request&& request);

  ~Client();
  Client(Client&& other);
  Client& operator=(Client&& other);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};
}  // namespace tonlib
