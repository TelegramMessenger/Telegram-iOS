//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

/**
 * \file
 * C++ interface for managing the internal logging of TDLib.
 * By default TDLib writes logs to stderr or an OS specific log and uses a verbosity level of 5.
 */

#include <cstdint>
#include <string>

namespace td {

/**
 * Interface for managing the internal logging of TDLib.
 * By default TDLib writes logs to stderr or an OS specific log and uses a verbosity level of 5.
 * These functions are deprecated since TDLib 1.4.0 in favor of the td::td_api::setLogVerbosityLevel,
 * td::td_api::setLogStream and other synchronous requests for managing the internal TDLib logging.
 */
class Log {
 public:
  /**
   * Sets the path to the file to where the internal TDLib log will be written.
   * By default TDLib writes logs to stderr or an OS specific log.
   * Use this method to write the log to a file instead.
   *
   * \deprecated Use synchronous td::td_api::setLogStream request instead.
   * \param[in]  file_path Path to a file where the internal TDLib log will be written. Use an empty path to
   *                       switch back to the default logging behaviour.
   * \return True on success, or false otherwise, i.e. if the file can't be opened for writing.
   */
  static bool set_file_path(std::string file_path);

  /**
   * Sets the maximum size of the file to where the internal TDLib log is written before the file will be auto-rotated.
   * Unused if log is not written to a file. Defaults to 10 MB.
   *
   * \deprecated Use synchronous td::td_api::setLogStream request instead.
   * \param[in]  max_file_size The maximum size of the file to where the internal TDLib log is written before the file
   *                           will be auto-rotated. Should be positive.
   */
  static void set_max_file_size(std::int64_t max_file_size);

  /**
   * Sets the verbosity level of the internal logging of TDLib.
   * By default the TDLib uses a verbosity level of 5 for logging.
   *
   * \deprecated Use synchronous td::td_api::setLogVerbosityLevel request instead.
   * \param[in]  new_verbosity_level New value of the verbosity level for logging.
   *                                 Value 0 corresponds to fatal errors,
   *                                 value 1 corresponds to errors,
   *                                 value 2 corresponds to warnings and debug warnings,
   *                                 value 3 corresponds to informational,
   *                                 value 4 corresponds to debug,
   *                                 value 5 corresponds to verbose debug,
   *                                 value greater than 5 and up to 1024 can be used to enable even more logging.
   */
  static void set_verbosity_level(int new_verbosity_level);

  /**
   * A type of callback function that will be called when a fatal error happens.
   *
   * \param error_message Null-terminated string with a description of a happened fatal error.
   */
  using FatalErrorCallbackPtr = void (*)(const char *error_message);

  /**
   * Sets the callback that will be called when a fatal error happens.
   * None of the TDLib methods can be called from the callback.
   * The TDLib will crash as soon as callback returns.
   * By default the callback is not set.
   *
   * \deprecated Use ClientManager::set_log_message_callback instead.
   * \param[in]  callback Callback that will be called when a fatal error happens.
   *                      Pass nullptr to remove the callback.
   */
  static void set_fatal_error_callback(FatalErrorCallbackPtr callback);
};

}  // namespace td
