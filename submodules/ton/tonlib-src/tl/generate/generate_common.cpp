/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "tl_writer_cpp.h"
#include "tl_writer_h.h"
#include "tl_writer_hpp.h"
#include "tl_writer_jni_h.h"
#include "tl_writer_jni_cpp.h"
#include "tl_json_converter.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

#include <string>
#include <vector>

template <class WriterCpp = td::TD_TL_writer_cpp, class WriterH = td::TD_TL_writer_h,
          class WriterHpp = td::TD_TL_writer_hpp>
static void generate_cpp(const std::string &directory, const std::string &tl_name, const std::string &string_type,
                         const std::string &bytes_type, const std::string &secure_string_type,
                         const std::string &secure_bytes_type, const std::vector<std::string> &ext_cpp_includes,
                         const std::vector<std::string> &ext_h_includes) {
  std::string path = directory + "/" + tl_name;
  td::tl::tl_config config = td::tl::read_tl_config_from_file("scheme/" + tl_name + ".tlo");
  td::tl::write_tl_to_file(
      config, path + ".cpp",
      WriterCpp(tl_name, string_type, bytes_type, secure_string_type, secure_bytes_type, ext_cpp_includes));
  td::tl::write_tl_to_file(
      config, path + ".h",
      WriterH(tl_name, string_type, bytes_type, secure_string_type, secure_bytes_type, ext_h_includes));
  td::tl::write_tl_to_file(config, path + ".hpp",
                           WriterHpp(tl_name, string_type, bytes_type, secure_string_type, secure_bytes_type));
}

int main() {
  generate_cpp("auto/tl", "ton_api", "std::string", "td::BufferSlice", "std::string", "td::BufferSlice",
               {"\"tl/tl_object_parse.h\"", "\"tl/tl_object_store.h\"", "\"td/utils/int_types.h\"",
                "\"crypto/common/bitstring.h\""},
               {"<string>", "\"td/utils/buffer.h\"", "\"crypto/common/bitstring.h\""});

  generate_cpp("auto/tl", "lite_api", "std::string", "td::BufferSlice", "std::string", "td::BufferSlice",
               {"\"tl/tl_object_parse.h\"", "\"tl/tl_object_store.h\"", "\"td/utils/int_types.h\"",
                "\"crypto/common/bitstring.h\""},
               {"<string>", "\"td/utils/buffer.h\"", "\"crypto/common/bitstring.h\""});
  td::gen_json_converter(td::tl::read_tl_config_from_file("scheme/ton_api.tlo"), "auto/tl/ton_api_json", "ton_api");

#ifdef TONLIB_ENABLE_JNI
  generate_cpp<td::TD_TL_writer_jni_cpp, td::TD_TL_writer_jni_h>(
      "auto/tl", "tonlib_api", "std::string", "std::string", "td::SecureString", "td::SecureString",
      {"\"tl/tl_jni_object.h\"", "\"tl/tl_object_store.h\"", "\"td/utils/int_types.h\""},
      {"<string>", "\"td/utils/SharedSlice.h\""});
#else
  generate_cpp<>("auto/tl", "tonlib_api", "std::string", "std::string", "td::SecureString", "td::SecureString",
                 {"\"tl/tl_object_parse.h\"", "\"tl/tl_object_store.h\"", "\"td/utils/int_types.h\""},
                 {"<string>", "\"td/utils/SharedSlice.h\""});
#endif
  td::gen_json_converter(td::tl::read_tl_config_from_file("scheme/tonlib_api.tlo"), "auto/tl/tonlib_api_json",
                         "tonlib_api");
}
