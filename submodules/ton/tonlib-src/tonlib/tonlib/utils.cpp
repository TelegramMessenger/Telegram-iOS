/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "tonlib/utils.h"
#include "td/utils/misc.h"
#include "vm/cellslice.h"
namespace tonlib {
int VERBOSITY_NAME(tonlib_query) = VERBOSITY_NAME(DEBUG);
int VERBOSITY_NAME(last_block) = VERBOSITY_NAME(DEBUG);
int VERBOSITY_NAME(last_config) = VERBOSITY_NAME(DEBUG);
int VERBOSITY_NAME(lite_server) = VERBOSITY_NAME(DEBUG);

}  // namespace tonlib
