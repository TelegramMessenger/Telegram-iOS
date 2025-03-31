//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_cpp.h"
#include "tl_writer_h.h"
#include "tl_writer_hpp.h"
#include "tl_writer_jni_cpp.h"
#include "tl_writer_jni_h.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

#include <string>
#include <vector>

template <bool generate_multiple_headers = false, class WriterCpp = td::TD_TL_writer_cpp,
          class WriterH = td::TD_TL_writer_h, class WriterHpp = td::TD_TL_writer_hpp>
static void generate_cpp(const std::string &directory, const std::string &tl_name, const std::string &string_type,
                         const std::string &bytes_type, const std::vector<std::string> &ext_cpp_includes,
                         const std::vector<std::string> &ext_h_includes) {
  std::string path = directory + "/" + tl_name;
  td::tl::tl_config config = td::tl::read_tl_config_from_file("tlo/" + tl_name + ".tlo");
  td::tl::write_tl_to_file(config, path + ".cpp", WriterCpp(tl_name, string_type, bytes_type, ext_cpp_includes));
  if (generate_multiple_headers) {
    td::tl::write_tl_to_multiple_files(config, path, ".h", WriterH(tl_name, string_type, bytes_type, ext_h_includes));
  } else {
    td::tl::write_tl_to_file(config, path + ".h", WriterH(tl_name, string_type, bytes_type, ext_h_includes));
  }
  td::tl::write_tl_to_file(config, path + ".hpp", WriterHpp(tl_name, string_type, bytes_type));
}

int main() {
  generate_cpp<>("td/telegram", "telegram_api", "std::string", "BufferSlice",
                 {"\"td/tl/tl_object_parse.h\"", "\"td/tl/tl_object_store.h\""}, {"\"td/utils/buffer.h\""});

  generate_cpp<>("td/telegram", "secret_api", "std::string", "BufferSlice",
                 {"\"td/tl/tl_object_parse.h\"", "\"td/tl/tl_object_store.h\""}, {"\"td/utils/buffer.h\""});

  generate_cpp<>("td/telegram", "e2e_api", "std::string", "std::string",
                 {"\"td/tl/tl_object_parse.h\"", "\"td/tl/tl_object_store.h\""}, {"\"td/utils/UInt.h\""});

#ifdef TD_ENABLE_JNI
  generate_cpp<false, td::TD_TL_writer_jni_cpp, td::TD_TL_writer_jni_h>(
      "td/telegram", "td_api", "std::string", "std::string", {"\"td/tl/tl_jni_object.h\""}, {"<string>"});
#else
  generate_cpp<>("td/telegram", "td_api", "std::string", "std::string", {}, {"<string>"});
#endif
}
