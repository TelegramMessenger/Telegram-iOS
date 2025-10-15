//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/net/HttpChunkedByteFlow.h"
#include "td/net/HttpContentLengthByteFlow.h"
#include "td/net/HttpQuery.h"

#include "td/utils/buffer.h"
#include "td/utils/ByteFlow.h"
#include "td/utils/common.h"
#include "td/utils/GzipByteFlow.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <limits>

namespace td {

class HttpReader {
 public:
  void init(ChainBufferReader *input, size_t max_post_size = std::numeric_limits<size_t>::max(),
            size_t max_files = 100);

  Result<size_t> read_next(HttpQuery *query, bool can_be_slow = true) TD_WARN_UNUSED_RESULT;  // TODO move query to init

  HttpReader() = default;
  HttpReader(const HttpReader &) = delete;
  HttpReader &operator=(const HttpReader &) = delete;
  HttpReader(HttpReader &&) = delete;
  HttpReader &operator=(HttpReader &&) = delete;
  ~HttpReader() {
    if (!temp_file_.empty()) {
      clean_temporary_file();
    }
  }

  static void delete_temp_file(CSlice file_name);

 private:
  size_t max_post_size_ = 0;
  size_t max_files_ = 0;

  enum class State { ReadHeaders, ReadContent, ReadContentToFile, ReadArgs, ReadMultipartFormData };
  State state_ = State::ReadHeaders;
  size_t headers_read_length_ = 0;
  int64 content_length_ = -1;
  ChainBufferReader *input_ = nullptr;
  ByteFlowSource flow_source_;
  HttpChunkedByteFlow chunked_flow_;
  GzipByteFlow gzip_flow_;
  HttpContentLengthByteFlow content_length_flow_;
  ByteFlowSink flow_sink_;
  ChainBufferReader *content_ = nullptr;

  HttpQuery *query_ = nullptr;
  Slice transfer_encoding_;
  Slice content_encoding_;
  Slice content_type_;
  string content_type_lowercased_;
  size_t total_parameters_length_ = 0;
  size_t total_headers_length_ = 0;

  string boundary_;
  size_t form_data_read_length_ = 0;
  size_t form_data_skipped_length_ = 0;
  enum class FormDataParseState : int32 {
    SkipPrologue,
    ReadPartHeaders,
    ReadPartValue,
    ReadFile,
    CheckForLastBoundary,
    SkipEpilogue
  };
  FormDataParseState form_data_parse_state_ = FormDataParseState::SkipPrologue;
  MutableSlice field_name_;
  string file_field_name_;
  string field_content_type_;
  string file_name_;
  bool has_file_name_ = false;
  FileFd temp_file_;
  string temp_file_name_;
  int64 file_size_ = 0;

  Result<size_t> do_read_next(bool can_be_slow);

  Result<size_t> split_header() TD_WARN_UNUSED_RESULT;
  void process_header(MutableSlice header_name, MutableSlice header_value);
  Result<bool> parse_multipart_form_data(bool can_be_slow) TD_WARN_UNUSED_RESULT;
  Status parse_url(MutableSlice url) TD_WARN_UNUSED_RESULT;
  Status parse_parameters(MutableSlice parameters) TD_WARN_UNUSED_RESULT;
  Status parse_json_parameters(MutableSlice parameters) TD_WARN_UNUSED_RESULT;
  Status parse_http_version(Slice version) TD_WARN_UNUSED_RESULT;
  Status parse_head(MutableSlice head) TD_WARN_UNUSED_RESULT;

  Status open_temp_file(CSlice desired_file_name) TD_WARN_UNUSED_RESULT;
  Status try_open_temp_file(Slice directory_name, CSlice desired_file_name) TD_WARN_UNUSED_RESULT;
  Status save_file_part(BufferSlice &&file_part) TD_WARN_UNUSED_RESULT;
  void close_temp_file();
  void clean_temporary_file();

  static constexpr size_t MAX_CONTENT_SIZE = std::numeric_limits<uint32>::max();  // Some reasonable limit
  static constexpr size_t MAX_TOTAL_PARAMETERS_LENGTH = 1 << 20;                  // Some reasonable limit
  static constexpr size_t MAX_TOTAL_HEADERS_LENGTH = 1 << 18;                     // Some reasonable limit
  static constexpr size_t MAX_BOUNDARY_LENGTH = 70;                               // As defined by RFC1341
  static constexpr int64 MAX_FILE_SIZE = static_cast<int64>(4000) << 20;          // Telegram server file size limit
  static constexpr const char TEMP_DIRECTORY_PREFIX[] = "tdlib-server-tmp";
};

}  // namespace td
