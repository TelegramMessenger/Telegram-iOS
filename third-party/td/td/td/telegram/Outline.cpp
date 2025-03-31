//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Outline.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"

namespace td {

td_api::object_ptr<td_api::outline> get_outline_object(CSlice path, double zoom, Slice source) {
  if (path.empty()) {
    return nullptr;
  }

  auto buf = StackAllocator::alloc(1 << 9);
  StringBuilder sb(buf.as_slice(), true);

  sb << 'M';
  for (unsigned char c : path) {
    if (c >= 128 + 64) {
      sb << "AACAAAAHAAALMAAAQASTAVAAAZaacaaaahaaalmaaaqastava.az0123456789-,"[c - 128 - 64];
    } else {
      if (c >= 128) {
        sb << ',';
      } else if (c >= 64) {
        sb << '-';
      }
      sb << (c & 63);
    }
  }
  sb << 'z';

  CHECK(!sb.is_error());
  path = sb.as_cslice();
  LOG(DEBUG) << "Transform SVG path " << path;

  size_t pos = 0;
  auto skip_commas = [&path, &pos] {
    while (path[pos] == ',') {
      pos++;
    }
  };
  auto get_number = [&] {
    skip_commas();
    int sign = 1;
    if (path[pos] == '-') {
      sign = -1;
      pos++;
    }
    double res = 0;
    while (is_digit(path[pos])) {
      res = res * 10 + path[pos++] - '0';
    }
    if (path[pos] == '.') {
      pos++;
      double mul = 0.1;
      while (is_digit(path[pos])) {
        res += (path[pos] - '0') * mul;
        mul *= 0.1;
        pos++;
      }
    }
    return sign * res;
  };
  auto make_point = [zoom](double x, double y) {
    return td_api::make_object<td_api::point>(x * zoom, y * zoom);
  };

  vector<td_api::object_ptr<td_api::closedVectorPath>> result;
  double x = 0;
  double y = 0;
  while (path[pos] != '\0') {
    skip_commas();
    if (path[pos] == '\0') {
      break;
    }

    while (path[pos] == 'm' || path[pos] == 'M') {
      auto command = path[pos++];
      do {
        if (command == 'm') {
          x += get_number();
          y += get_number();
        } else {
          x = get_number();
          y = get_number();
        }
        skip_commas();
      } while (path[pos] != '\0' && !is_alpha(path[pos]));
    }

    double start_x = x;
    double start_y = y;

    vector<td_api::object_ptr<td_api::VectorPathCommand>> commands;
    bool have_last_end_control_point = false;
    double last_end_control_point_x = 0;
    double last_end_control_point_y = 0;
    bool is_closed = false;
    char command = '-';
    while (!is_closed) {
      skip_commas();
      if (path[pos] == '\0') {
        LOG(ERROR) << "Receive unclosed path " << path << " from " << source;
        return nullptr;
      }
      if (is_alpha(path[pos])) {
        command = path[pos++];
      }
      switch (command) {
        case 'l':
        case 'L':
        case 'h':
        case 'H':
        case 'v':
        case 'V':
          if (command == 'l' || command == 'h') {
            x += get_number();
          } else if (command == 'L' || command == 'H') {
            x = get_number();
          }
          if (command == 'l' || command == 'v') {
            y += get_number();
          } else if (command == 'L' || command == 'V') {
            y = get_number();
          }
          commands.push_back(td_api::make_object<td_api::vectorPathCommandLine>(make_point(x, y)));
          have_last_end_control_point = false;
          break;
        case 'C':
        case 'c':
        case 'S':
        case 's': {
          double start_control_point_x;
          double start_control_point_y;
          if (command == 'S' || command == 's') {
            if (have_last_end_control_point) {
              start_control_point_x = 2 * x - last_end_control_point_x;
              start_control_point_y = 2 * y - last_end_control_point_y;
            } else {
              start_control_point_x = x;
              start_control_point_y = y;
            }
          } else {
            start_control_point_x = get_number();
            start_control_point_y = get_number();
            if (command == 'c') {
              start_control_point_x += x;
              start_control_point_y += y;
            }
          }

          last_end_control_point_x = get_number();
          last_end_control_point_y = get_number();
          if (command == 'c' || command == 's') {
            last_end_control_point_x += x;
            last_end_control_point_y += y;
          }
          have_last_end_control_point = true;

          if (command == 'c' || command == 's') {
            x += get_number();
            y += get_number();
          } else {
            x = get_number();
            y = get_number();
          }

          commands.push_back(td_api::make_object<td_api::vectorPathCommandCubicBezierCurve>(
              make_point(start_control_point_x, start_control_point_y),
              make_point(last_end_control_point_x, last_end_control_point_y), make_point(x, y)));
          break;
        }
        case 'm':
        case 'M':
          pos--;
          // fallthrough
        case 'z':
        case 'Z':
          if (x != start_x || y != start_y) {
            x = start_x;
            y = start_y;
            commands.push_back(td_api::make_object<td_api::vectorPathCommandLine>(make_point(x, y)));
          }
          if (!commands.empty()) {
            result.push_back(td_api::make_object<td_api::closedVectorPath>(std::move(commands)));
            commands.clear();
          }
          is_closed = true;
          break;
        default:
          LOG(ERROR) << "Receive invalid command " << command << " at pos " << pos << " from " << source << ": "
                     << path;
          return nullptr;
      }
    }
  }
  /*
  string svg;
  for (const auto &vector_path : result) {
    CHECK(!vector_path->commands_.empty());
    svg += 'M';
    auto add_point = [&](const td_api::object_ptr<td_api::point> &p) {
      svg += to_string(static_cast<int>(p->x_));
      svg += ',';
      svg += to_string(static_cast<int>(p->y_));
      svg += ',';
    };
    auto last_command = vector_path->commands_.back().get();
    switch (last_command->get_id()) {
      case td_api::vectorPathCommandLine::ID:
        add_point(static_cast<const td_api::vectorPathCommandLine *>(last_command)->end_point_);
        break;
      case td_api::vectorPathCommandCubicBezierCurve::ID:
        add_point(static_cast<const td_api::vectorPathCommandCubicBezierCurve *>(last_command)->end_point_);
        break;
      default:
        UNREACHABLE();
    }
    for (auto &command : vector_path->commands_) {
      switch (command->get_id()) {
        case td_api::vectorPathCommandLine::ID: {
          auto line = static_cast<const td_api::vectorPathCommandLine *>(command.get());
          svg += 'L';
          add_point(line->end_point_);
          break;
        }
        case td_api::vectorPathCommandCubicBezierCurve::ID: {
          auto curve = static_cast<const td_api::vectorPathCommandCubicBezierCurve *>(command.get());
          svg += 'C';
          add_point(curve->start_control_point_);
          add_point(curve->end_control_point_);
          add_point(curve->end_point_);
          break;
        }
        default:
          UNREACHABLE();
      }
    }
    svg += 'z';
  }
  */

  return td_api::make_object<td_api::outline>(std::move(result));
}

}  // namespace td
