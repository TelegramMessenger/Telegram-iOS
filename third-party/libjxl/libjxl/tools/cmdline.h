// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_CMDLINE_H_
#define TOOLS_CMDLINE_H_

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace jpegxl {
namespace tools {

class CommandLineParser {
 public:
  typedef int OptionId;

  // An abstract class for defining command line options.
  class CmdOptionInterface {
   public:
    CmdOptionInterface() = default;
    virtual ~CmdOptionInterface() = default;

    // Return a string with the option name or available flags.
    virtual std::string help_flags() const = 0;

    // Return the help string if any, or nullptr if no help string.
    virtual const char* help_text() const = 0;

    // Return the verbosity level for this option
    virtual int verbosity_level() const = 0;

    // Return whether the option was passed.
    virtual bool matched() const = 0;

    // Returns whether this option matches the passed command line argument.
    virtual bool Match(const char* arg, bool parse_options) const = 0;

    // Parses the option. The passed i points to the argument with the flag
    // that matches either the short or the long name.
    virtual bool Parse(int argc, const char* argv[], int* i) = 0;

    // Returns whether the option is positional, and therefore will be shown
    // in the first command line representation of the help output.
    virtual bool positional() const = 0;

    // Returns whether the option should be displayed as required in the help
    // output. No effect on validation.
    virtual bool required() const = 0;

    // Returns whether the option is not really an option but just help text
    virtual bool help_only() const = 0;
  };

  // Add help text
  void AddHelpText(const char* help_text, int verbosity_level = 0) {
    options_.emplace_back(new CmdHelpText(help_text, verbosity_level));
  }

  // Add a positional argument. Returns the id of the added option or
  // kOptionError on error.
  // The "required" flag indicates whether the parameter is mandatory or
  // optional, but is only used for how it is displayed in the command line
  // help.
  OptionId AddPositionalOption(const char* name, bool required,
                               const std::string& help_text,
                               const char** storage, int verbosity_level = 0) {
    options_.emplace_back(new CmdOptionPositional(name, help_text, storage,
                                                  verbosity_level, required));
    return options_.size() - 1;
  }

  // Add an option with a value of type T. The option can be passed as
  // '-s <value>' or '--long value' or '--long=value'. The CommandLineParser
  // parser will call the function parser with the string pointing to '<value>'
  // in either case. Returns the id of the added option or kOptionError on
  // error.
  template <typename T>
  OptionId AddOptionValue(char short_name, const char* long_name,
                          const char* metavar, const char* help_text,
                          T* storage, bool(parser)(const char*, T*),
                          int verbosity_level = 0) {
    options_.emplace_back(new CmdOptionFlag<T>(short_name, long_name, metavar,
                                               help_text, storage, parser,
                                               verbosity_level));
    return options_.size() - 1;
  }

  // Add a flag without a value. Returns the id of the added option or
  // kOptionError on error.
  template <typename T>
  OptionId AddOptionFlag(char short_name, const char* long_name,
                         const char* help_text, T* storage, bool(parser)(T*),
                         int verbosity_level = 0) {
    options_.emplace_back(new CmdOptionFlag<T>(
        short_name, long_name, help_text, storage, parser, verbosity_level));
    return options_.size() - 1;
  }

  const CmdOptionInterface* GetOption(OptionId id) const {
    return options_[id].get();
  }

  // Print the help message to stdout.
  void PrintHelp() const;

  // Whether a help flag was specified
  bool HelpFlagPassed() const { return help_; }

  int verbosity = 0;

  // Parse the command line.
  bool Parse(int argc, const char* argv[]);

  // Return the remaining positional args
  std::vector<const char*> PositionalArgs() const;

  // Conditionally print a message to stderr
  void VerbosePrintf(int min_verbosity, const char* format, ...) const;

 private:
  // Help text only.
  class CmdHelpText : public CmdOptionInterface {
   public:
    CmdHelpText(const char* help_text, int verbosity_level)
        : help_text_(help_text), verbosity_level_(verbosity_level) {}

    std::string help_flags() const override { return ""; }
    const char* help_text() const override { return help_text_; }
    int verbosity_level() const override { return verbosity_level_; }
    bool matched() const override { return false; }

    bool Match(const char* arg, bool parse_options) const override {
      return false;
    }

    bool Parse(const int argc, const char* argv[], int* i) override {
      return true;
    }

    bool positional() const override { return false; }

    bool required() const override { return false; }

    bool help_only() const override { return true; }

   private:
    const char* help_text_;
    const int verbosity_level_;
  };

  // A positional argument.
  class CmdOptionPositional : public CmdOptionInterface {
   public:
    CmdOptionPositional(const char* name, const std::string& help_text,
                        const char** storage, int verbosity_level,
                        bool required)
        : name_(name),
          help_text_(help_text),
          storage_(storage),
          verbosity_level_(verbosity_level),
          required_(required) {}

    std::string help_flags() const override { return name_; }
    const char* help_text() const override { return help_text_.c_str(); }
    int verbosity_level() const override { return verbosity_level_; }
    bool matched() const override { return matched_; }

    // Only match non-flag values. This means that you can't pass '-foo' as a
    // positional argument, but it helps with detecting when passed a flag with
    // a typo. After '--', option matching is disabled so positional arguments
    // starting with '-' can be used.
    bool Match(const char* arg, bool parse_options) const override {
      return !matched_ && (!parse_options || arg[0] != '-');
    }

    bool Parse(const int argc, const char* argv[], int* i) override {
      *storage_ = argv[*i];
      (*i)++;
      matched_ = true;
      return true;
    }

    bool positional() const override { return true; }

    bool required() const override { return required_; }

    bool help_only() const override { return false; }

   private:
    const char* name_;
    const std::string help_text_;
    const char** storage_;
    const int verbosity_level_;
    const bool required_;

    bool matched_{false};
  };

  // A class for handling an option flag like '-v' or '--foo=bar'.
  template <typename T>
  class CmdOptionFlag : public CmdOptionInterface {
   public:
    // Construct a flag that doesn't take any value, for example '-v' or
    // '--long'. Passing a value to it raises an error.
    CmdOptionFlag(char short_name, const char* long_name, const char* help_text,
                  T* storage, bool(parser)(T*), int verbosity_level)
        : short_name_(short_name),
          long_name_(long_name),
          long_name_len_(long_name ? strlen(long_name) : 0),
          metavar_(nullptr),
          help_text_(help_text),
          storage_(storage),
          verbosity_level_(verbosity_level) {
      parser_.parser_no_value_ = parser;
    }

    // Construct a flag that expects a value to be passed.
    CmdOptionFlag(char short_name, const char* long_name, const char* metavar,
                  const char* help_text, T* storage,
                  bool(parser)(const char* arg, T*), int verbosity_level)
        : short_name_(short_name),
          long_name_(long_name),
          long_name_len_(long_name ? strlen(long_name) : 0),
          metavar_(metavar ? metavar : ""),
          help_text_(help_text),
          storage_(storage),
          verbosity_level_(verbosity_level) {
      parser_.parser_with_arg_ = parser;
    }

    std::string help_flags() const override {
      std::string ret;
      if (short_name_) {
        ret += std::string("-") + short_name_;
        if (metavar_) ret += std::string(" ") + metavar_;
        if (long_name_) ret += ", ";
      }
      if (long_name_) {
        ret += std::string("--") + long_name_;
        if (metavar_) ret += std::string("=") + metavar_;
      }
      return ret;
    }
    const char* help_text() const override { return help_text_; }
    int verbosity_level() const override { return verbosity_level_; }
    bool matched() const override { return matched_; }

    bool Match(const char* arg, bool parse_options) const override {
      return parse_options && (MatchShort(arg) || MatchLong(arg));
    }

    bool Parse(const int argc, const char* argv[], int* i) override {
      matched_ = true;
      if (MatchLong(argv[*i])) {
        const char* arg = argv[*i] + 2 + long_name_len_;
        if (arg[0] == '=') {
          if (metavar_) {
            // Passed '--long_name=...'.
            (*i)++;
            // Skip over the '=' on the LongMatch.
            arg += 1;
            return (*parser_.parser_with_arg_)(arg, storage_);
          } else {
            fprintf(stderr, "--%s didn't expect any argument passed to it.\n",
                    argv[*i]);
            return false;
          }
        }
      }
      // In any other case, it passed a -s or --long_name
      (*i)++;
      if (metavar_) {
        if (argc <= *i) {
          fprintf(stderr, "--%s expected an argument but none passed.\n",
                  argv[*i - 1]);
          return false;
        }
        return (*parser_.parser_with_arg_)(argv[(*i)++], storage_);
      } else {
        return (*parser_.parser_no_value_)(storage_);
      }
    }

    bool positional() const override { return false; }

    bool required() const override {
      // Only used for help display of positional arguments.
      return false;
    }

    bool help_only() const override { return false; }

   private:
    // Returns whether arg matches the short_name flag of this option.
    bool MatchShort(const char* arg) const {
      if (!short_name_ || arg[0] != '-') return false;
      return arg[1] == short_name_ && arg[2] == 0;
    }

    // Returns whether arg matches the long_name flag of this option,
    // potentially with an argument passed to it.
    bool MatchLong(const char* arg) const {
      if (!long_name_ || arg[0] != '-' || arg[1] != '-') return false;
      arg += 2;  // Skips the '--'
      if (strncmp(long_name_, arg, long_name_len_) != 0) return false;
      arg += long_name_len_;
      // Allow "--long_name=foo" and "--long_name" as long matches.
      return arg[0] == 0 || arg[0] == '=';
    }

    // A short option passed as '-X' where X is the char. A value of 0 means
    // no short option.
    const char short_name_;

    // A long option name passed as '--long' where 'long' is the name of the
    // option.
    const char* long_name_;
    size_t long_name_len_;

    // The text to display when referring to the value passed to this flag, for
    // example "N" in the flag '--value N'. If null, this flag accepts no value
    // and therefore no value must be passed.
    const char* metavar_;

    // The help string for this flag.
    const char* help_text_;

    // The pointer to the storage of this flag used when parsing.
    T* storage_;

    // At which verbosity level do we show this option?
    int verbosity_level_;

    // The function to use to parse the value when matched. The function used is
    // parser_with_arg_ when metavar_ is not null (and the value string will be
    // used) or parser_no_value_ when metavar_ is null.
    union {
      bool (*parser_with_arg_)(const char*, T*);
      bool (*parser_no_value_)(T*);
    } parser_;

    // Whether this flag was matched.
    bool matched_{false};
  };

  const char* program_name_{nullptr};

  std::vector<std::unique_ptr<CmdOptionInterface>> options_;

  // If true, help argument was given, so print help to stdout rather than
  // stderr.
  bool help_ = false;
};

//
// Common parsers for AddOptionValue and AddOptionFlag
//

static inline bool ParseSigned(const char* arg, int* out) {
  char* end;
  *out = static_cast<int>(strtol(arg, &end, 0));
  if (end[0] != '\0') {
    fprintf(stderr, "Unable to interpret as signed integer: %s.\n", arg);
    return false;
  }
  return true;
}

static inline bool ParseUnsigned(const char* arg, size_t* out) {
  char* end;
  *out = static_cast<size_t>(strtoull(arg, &end, 0));
  if (end[0] != '\0') {
    fprintf(stderr, "Unable to interpret as unsigned integer: %s.\n", arg);
    return false;
  }
  return true;
}

static inline bool ParseInt64(const char* arg, int64_t* out) {
  char* end;
  *out = strtol(arg, &end, 0);
  if (end[0] != '\0') {
    fprintf(stderr, "Unable to interpret as signed integer: %s.\n", arg);
    return false;
  }
  return true;
}

static inline bool ParseUint32(const char* arg, uint32_t* out) {
  size_t value = 0;
  bool ret = ParseUnsigned(arg, &value);
  if (ret) *out = value;
  return ret;
}

static inline bool ParseFloat(const char* arg, float* out) {
  char* end;
  *out = static_cast<float>(strtod(arg, &end));
  if (end[0] != '\0') {
    fprintf(stderr, "Unable to interpret as float: %s.\n", arg);
    return false;
  }
  return true;
}

static inline bool ParseDouble(const char* arg, double* out) {
  char* end;
  *out = static_cast<double>(strtod(arg, &end));
  if (end[0] != '\0') {
    fprintf(stderr, "Unable to interpret as double: %s.\n", arg);
    return false;
  }
  return true;
}

static inline bool ParseString(const char* arg, std::string* out) {
  out->assign(arg);
  return true;
}

static inline bool SetBooleanTrue(bool* out) {
  *out = true;
  return true;
}

static inline bool SetBooleanFalse(bool* out) {
  *out = false;
  return true;
}

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_CMDLINE_H_
