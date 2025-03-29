//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/OptionParser.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"

TEST(OptionParser, run) {
  td::OptionParser options;
  options.set_description("test description");

  td::string exename = "exename";
  td::vector<td::string> args;
  auto run_option_parser = [&](td::string command_line) {
    args = td::full_split(std::move(command_line), ' ');
    td::vector<char *> argv;
    argv.push_back(&exename[0]);
    for (auto &arg : args) {
      argv.push_back(&arg[0]);
    }
    return options.run_impl(static_cast<int>(argv.size()), &argv[0], -1);
  };

  td::uint64 chosen_options = 0;
  td::vector<td::string> chosen_parameters;
  auto test_success = [&](td::string command_line, td::uint64 expected_options,
                          const td::vector<td::string> &expected_parameters,
                          const td::vector<td::string> &expected_result) {
    chosen_options = 0;
    chosen_parameters.clear();
    auto result = run_option_parser(std::move(command_line));
    ASSERT_TRUE(result.is_ok());
    ASSERT_EQ(expected_options, chosen_options);
    ASSERT_EQ(expected_parameters, chosen_parameters);
    ASSERT_EQ(expected_result.size(), result.ok().size());
    for (size_t i = 0; i < expected_result.size(); i++) {
      ASSERT_STREQ(expected_result[i], td::string(result.ok()[i]));
    }
  };
  auto test_fail = [&](td::string command_line) {
    auto result = run_option_parser(std::move(command_line));
    ASSERT_TRUE(result.is_error());
  };

  options.add_option('q', "", "", [&] { chosen_options += 1; });
  options.add_option('\0', "http-port2", "", [&] { chosen_options += 10; });
  options.add_option('p', "http-port", "", [&](td::Slice parameter) {
    chosen_options += 100;
    chosen_parameters.push_back(parameter.str());
  });
  options.add_option('v', "test", "", [&] { chosen_options += 1000; });

  test_fail("-http-port2");
  test_success("-", 0, {}, {"-"});
  test_fail("--http-port");
  test_fail("--http-port3");
  test_fail("--http-por");
  test_fail("--http-port2=1");
  test_fail("--q");
  test_fail("-qvp");
  test_fail("-p");
  test_fail("-u");
  test_success("-q", 1, {}, {});
  test_success("-vvvvvvvvvv", 10000, {}, {});
  test_success("-qpv", 101, {"v"}, {});
  test_success("-qp -v", 101, {"-v"}, {});
  test_success("-qp --http-port2", 101, {"--http-port2"}, {});
  test_success("-qp -- -v", 1101, {"--"}, {});
  test_success("-qvqvpqv", 2102, {"qv"}, {});
  test_success("aba --http-port2 caba --http-port2 dabacaba", 20, {}, {"aba", "caba", "dabacaba"});
  test_success("das -pqwerty -- -v asd --http-port", 100, {"qwerty"}, {"das", "-v", "asd", "--http-port"});
  test_success("-p option --http-port option2 --http-port=option3 --http-port=", 400,
               {"option", "option2", "option3", ""}, {});
  test_success("", 0, {}, {});
  test_success("a", 0, {}, {"a"});
  test_success("", 0, {}, {});
}
