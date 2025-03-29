//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Client.h"
#include "td/telegram/td_api.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/TsCerr.h"

#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <utility>

static void usage() {
  td::TsCerr() << "Tests specified MTProto-proxies, outputs working proxies to stdout; exits with code 0 if a working "
                  "proxy was found.\n";
  td::TsCerr() << "Usage: check_proxy [options] server:port:secret [server2:port2:secret2 ...]\n";
  td::TsCerr() << "Options:\n";
  td::TsCerr() << "  -v<N>\tSet verbosity level to N\n";
  td::TsCerr() << "  -h/--help\tDisplay this information\n";
  td::TsCerr() << "  -d/--dc-id\tIdentifier of a datacenter to which try to connect (default is 2)\n";
  td::TsCerr() << "  -l/--proxy-list\tName of a file with proxies to check; one proxy per line\n";
  td::TsCerr() << "  -t/--timeout\tMaximum overall timeout for the request (default is 10 seconds)\n";
  std::exit(2);
}

int main(int argc, char **argv) {
  int new_verbosity_level = VERBOSITY_NAME(FATAL);

  td::vector<std::pair<td::string, td::td_api::object_ptr<td::td_api::testProxy>>> requests;

  auto add_proxy = [&requests](td::string arg) {
    if (arg.empty()) {
      return;
    }

    std::size_t offset = 0;
    if (arg[0] == '[') {
      auto end_ipv6_pos = arg.find(']');
      if (end_ipv6_pos == td::string::npos) {
        td::TsCerr() << "Error: failed to find end of IPv6 address in \"" << arg << "\"\n";
        usage();
      }
      offset = end_ipv6_pos;
    }
    if (std::count(arg.begin() + offset, arg.end(), ':') == 3) {
      auto secret_domain_pos = arg.find(':', arg.find(':', offset) + 1) + 1;
      auto domain_pos = arg.find(':', secret_domain_pos);
      auto secret = arg.substr(secret_domain_pos, domain_pos - secret_domain_pos);
      auto domain = arg.substr(domain_pos + 1);
      auto r_decoded_secret = td::hex_decode(secret);
      if (r_decoded_secret.is_error()) {
        r_decoded_secret = td::base64url_decode(secret);
        if (r_decoded_secret.is_error()) {
          td::TsCerr() << "Error: failed to find proxy port and secret in \"" << arg << "\"\n";
          usage();
        }
      }
      arg = arg.substr(0, secret_domain_pos) + td::base64url_encode(r_decoded_secret.ok() + domain);
    }

    auto secret_pos = arg.rfind(':');
    if (secret_pos == td::string::npos) {
      td::TsCerr() << "Error: failed to find proxy port and secret in \"" << arg << "\"\n";
      usage();
    }
    auto secret = arg.substr(secret_pos + 1);
    auto port_pos = arg.substr(0, secret_pos).rfind(':');
    if (port_pos == td::string::npos) {
      td::TsCerr() << "Error: failed to find proxy secret in \"" << arg << "\"\n";
      usage();
    }
    auto r_port = td::to_integer_safe<td::int32>(arg.substr(port_pos + 1, secret_pos - port_pos - 1));
    if (r_port.is_error()) {
      td::TsCerr() << "Error: failed to parse proxy port in \"" << arg << "\"\n";
      usage();
    }
    auto port = r_port.move_as_ok();
    auto server = arg.substr(0, port_pos);
    if (server[0] == '[' && server.back() == ']') {
      server = server.substr(1, server.size() - 2);
    }

    if (server.empty() || port <= 0 || port > 65536 || secret.empty()) {
      td::TsCerr() << "Error: proxy address to check is in wrong format: \"" << arg << "\"\n";
      usage();
    }

    requests.emplace_back(arg,
                          td::td_api::make_object<td::td_api::testProxy>(
                              server, port, td::td_api::make_object<td::td_api::proxyTypeMtproto>(secret), -1, -1));
  };

  td::int32 dc_id = 2;
  double timeout = 10.0;

  for (int i = 1; i < argc; i++) {
    td::string arg(argv[i]);

    auto get_next_arg = [&i, &arg, argc, argv](bool is_optional = false) {
      CHECK(arg.size() >= 2);
      if (arg.size() == 2 || arg[1] == '-') {
        if (i + 1 < argc && argv[i + 1][0] != '-') {
          return td::string(argv[++i]);
        }
      } else {
        if (arg.size() > 2) {
          return arg.substr(2);
        }
      }
      if (!is_optional) {
        td::TsCerr() << "Error: value is required after " << arg << "\n";
        usage();
      }
      return td::string();
    };

    if (td::begins_with(arg, "-v")) {
      arg = get_next_arg(true);
      int new_verbosity = 1;
      while (arg[0] == 'v') {
        new_verbosity++;
        arg = arg.substr(1);
      }
      if (!arg.empty()) {
        new_verbosity += td::to_integer<int>(arg) - (new_verbosity == 1);
      }
      new_verbosity_level = VERBOSITY_NAME(FATAL) + new_verbosity;
    } else if (td::begins_with(arg, "-t") || arg == "--timeout") {
      timeout = td::to_double(get_next_arg());
    } else if (td::begins_with(arg, "-d") || arg == "--dc-id") {
      dc_id = td::to_integer<td::int32>(get_next_arg());
    } else if (td::begins_with(arg, "-l") || arg == "--proxy-list") {
      auto r_proxies = td::read_file_str(get_next_arg());
      if (r_proxies.is_error()) {
        td::TsCerr() << "Error: wrong file name specified\n";
        usage();
      }
      for (auto &proxy : td::full_split(r_proxies.ok(), '\n')) {
        add_proxy(td::trim(proxy));
      }
    } else if (arg[0] == '-') {
      usage();
    } else {
      add_proxy(arg);
    }
  }

  if (requests.empty()) {
    td::TsCerr() << "Error: proxy address to check is not specified\n";
    usage();
  }

  SET_VERBOSITY_LEVEL(new_verbosity_level);

  td::ClientManager client_manager;
  auto client_id = client_manager.create_client_id();
  for (size_t i = 0; i < requests.size(); i++) {
    auto &request = requests[i].second;
    request->dc_id_ = dc_id;
    request->timeout_ = timeout;
    client_manager.send(client_id, i + 1, std::move(request));
  }
  size_t successful_requests = 0;
  size_t failed_requests = 0;

  while (successful_requests + failed_requests != requests.size()) {
    auto response = client_manager.receive(100.0);
    CHECK(client_id == response.client_id);
    if (1 <= response.request_id && response.request_id <= requests.size()) {
      auto &proxy = requests[static_cast<size_t>(response.request_id - 1)].first;
      if (response.object->get_id() == td::td_api::error::ID) {
        LOG(ERROR) << proxy << ": " << to_string(response.object);
        failed_requests++;
      } else {
        std::cout << proxy << std::endl;
        successful_requests++;
      }
    }
  }

  if (successful_requests == 0) {
    return 1;
  }
}
