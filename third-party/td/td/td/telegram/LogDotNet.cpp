//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma managed(push, off)
#include "td/telegram/Log.h"
#pragma managed(pop)

#include "td/utils/port/CxCli.h"

#pragma managed(push, off)
#include <cstdint>
#pragma managed(pop)

namespace Telegram {
namespace Td {

using namespace CxCli;

/// <summary>
/// Class for managing internal TDLib logging.
/// </summary>
[DEPRECATED_ATTRIBUTE("Telegram.Td.Log class is deprecated, please use Telegram.Td.Api.*Log* requests instead.")]
public ref class Log sealed {
public:
  /// <summary>
  /// Changes TDLib log verbosity.
  /// </summary>
  /// <param name="verbosityLevel">New value of log verbosity level. Must be non-negative.
  /// Value 0 means FATAL, value 1 means ERROR, value 2 means WARNING, value 3 means INFO, value 4 means DEBUG,
  /// value greater than 4 can be used to enable even more logging.
  /// Default value of the log verbosity level is 5.</param>
  [DEPRECATED_ATTRIBUTE("SetVerbosityLevel is deprecated, please use Telegram.Td.Api.SetLogVerbosityLevel request instead.")]
  static void SetVerbosityLevel(int verbosityLevel) {
    ::td::Log::set_verbosity_level(verbosityLevel);
  }

  /// <summary>
  /// Sets file path for writing TDLib internal log. By default TDLib writes logs to the System.err.
  /// Use this method to write the log to a file instead.
  /// </summary>
  /// <param name="filePath">Path to a file for writing TDLib internal log. Use an empty path to switch back to logging
  /// to the System.err.</param>
  /// <returns>Returns whether opening the log file succeeded.</returns>
  [DEPRECATED_ATTRIBUTE("SetFilePath is deprecated, please use Telegram.Td.Api.SetLogStream request instead.")]
  static bool SetFilePath(String^ filePath) {
    return ::td::Log::set_file_path(string_to_unmanaged(filePath));
  }

  /// <summary>
  /// Changes the maximum size of TDLib log file.
  /// </summary>
  /// <param name="maxFileSize">The maximum size of the file to where the internal TDLib log is written
  /// before the file will be auto-rotated. Must be positive. Defaults to 10 MB.</param>
  [DEPRECATED_ATTRIBUTE("SetMaxFileSize is deprecated, please use Telegram.Td.Api.SetLogStream request instead.")]
  static void SetMaxFileSize(std::int64_t maxFileSize) {
    ::td::Log::set_max_file_size(maxFileSize);
  }
};

}  // namespace Td
}  // namespace Telegram
