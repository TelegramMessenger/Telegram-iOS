//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StickerSetId.h"

#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"

namespace td {

void StickerSetId::store(LogEventStorerCalcLength &storer) const {
  storer.context()->td().get_actor_unsafe()->stickers_manager_->store_sticker_set_id(*this, storer);
}

void StickerSetId::store(LogEventStorerUnsafe &storer) const {
  storer.context()->td().get_actor_unsafe()->stickers_manager_->store_sticker_set_id(*this, storer);
}

void StickerSetId::parse(LogEventParser &parser) {
  parser.context()->td().get_actor_unsafe()->stickers_manager_->parse_sticker_set_id(*this, parser);
}

}  // namespace td
