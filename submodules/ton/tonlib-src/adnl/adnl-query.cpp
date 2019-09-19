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
#include "adnl-query.h"
#include "common/errorcode.h"
#include "td/utils/Random.h"

namespace ton {

namespace adnl {

void AdnlQuery::alarm() {
  promise_.set_error(td::Status::Error(ErrorCode::timeout, "adnl query timeout"));
  stop();
}
void AdnlQuery::result(td::BufferSlice data) {
  promise_.set_value(std::move(data));
  stop();
}

AdnlQueryId AdnlQuery::random_query_id() {
  AdnlQueryId q_id;
  td::Random::secure_bytes(q_id.as_slice());
  return q_id;
}

}  // namespace adnl

}  // namespace ton
