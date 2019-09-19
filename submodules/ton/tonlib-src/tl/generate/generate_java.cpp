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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "tl_writer_java.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

#include <algorithm>
#include <string>

int main(int argc, char *argv[]) {
  if (argc < 5) {
    return 1;
  }

  std::string api_name = argv[1];
  std::string source = argv[2];
  std::string destination = argv[3];
  std::string package = argv[4];
  std::string package_name = package;
  std::replace(package_name.begin(), package_name.end(), '/', '.');
  destination += "/" + package + "/" + api_name + ".java";
  td::tl::write_tl_to_file(td::tl::read_tl_config_from_file(source), destination,
                           td::TD_TL_writer_java(api_name, package_name));
}
