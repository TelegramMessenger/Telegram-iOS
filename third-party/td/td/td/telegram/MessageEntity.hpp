//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageEntity::store(StorerT &storer) const {
  using td::store;
  store(type, storer);
  store(offset, storer);
  store(length, storer);
  if (type == Type::PreCode || type == Type::TextUrl) {
    store(argument, storer);
  }
  if (type == Type::MentionName) {
    store(user_id, storer);
  }
  if (type == Type::MediaTimestamp) {
    store(media_timestamp, storer);
  }
  if (type == Type::CustomEmoji) {
    store(custom_emoji_id, storer);
  }
}

template <class ParserT>
void MessageEntity::parse(ParserT &parser) {
  using td::parse;
  parse(type, parser);
  parse(offset, parser);
  parse(length, parser);
  if (type == Type::PreCode || type == Type::TextUrl) {
    parse(argument, parser);
  }
  if (type == Type::MentionName) {
    parse(user_id, parser);
  }
  if (type == Type::MediaTimestamp) {
    parse(media_timestamp, parser);
  }
  if (type == Type::CustomEmoji) {
    parse(custom_emoji_id, parser);
  }
}

template <class StorerT>
void FormattedText::store(StorerT &storer) const {
  td::store(text, storer);
  td::store(entities, storer);
}

template <class ParserT>
void FormattedText::parse(ParserT &parser) {
  td::parse(text, parser);
  td::parse(entities, parser);
  remove_empty_entities(entities);
}

}  // namespace td
