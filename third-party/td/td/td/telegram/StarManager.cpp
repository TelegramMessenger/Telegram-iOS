//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/InputInvoice.h"
#include "td/telegram/MessageExtendedMedia.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/Photo.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarAmount.h"
#include "td/telegram/StarGift.h"
#include "td/telegram/StarGiftManager.h"
#include "td/telegram/StarSubscription.h"
#include "td/telegram/StatisticsManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"

#include <type_traits>

namespace td {

class GetStarsTopupOptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starPaymentOptions>> promise_;

 public:
  explicit GetStarsTopupOptionsQuery(Promise<td_api::object_ptr<td_api::starPaymentOptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::payments_getStarsTopupOptions()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsTopupOptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    vector<td_api::object_ptr<td_api::starPaymentOption>> options;
    for (auto &result : results) {
      options.push_back(td_api::make_object<td_api::starPaymentOption>(result->currency_, result->amount_,
                                                                       StarManager::get_star_count(result->stars_),
                                                                       result->store_product_, result->extended_));
    }

    promise_.set_value(td_api::make_object<td_api::starPaymentOptions>(std::move(options)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetStarsGiftOptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starPaymentOptions>> promise_;

 public:
  explicit GetStarsGiftOptionsQuery(Promise<td_api::object_ptr<td_api::starPaymentOptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> input_user) {
    int32 flags = 0;
    if (input_user != nullptr) {
      flags |= telegram_api::payments_getStarsGiftOptions::USER_ID_MASK;
    }
    send_query(
        G()->net_query_creator().create(telegram_api::payments_getStarsGiftOptions(flags, std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsGiftOptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    vector<td_api::object_ptr<td_api::starPaymentOption>> options;
    for (auto &result : results) {
      options.push_back(td_api::make_object<td_api::starPaymentOption>(result->currency_, result->amount_,
                                                                       StarManager::get_star_count(result->stars_),
                                                                       result->store_product_, result->extended_));
    }

    promise_.set_value(td_api::make_object<td_api::starPaymentOptions>(std::move(options)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetStarsGiveawayOptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starGiveawayPaymentOptions>> promise_;

 public:
  explicit GetStarsGiveawayOptionsQuery(Promise<td_api::object_ptr<td_api::starGiveawayPaymentOptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::payments_getStarsGiveawayOptions()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsGiveawayOptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    vector<td_api::object_ptr<td_api::starGiveawayPaymentOption>> options;
    for (auto &result : results) {
      vector<td_api::object_ptr<td_api::starGiveawayWinnerOption>> winner_options;
      for (auto &winner : result->winners_) {
        winner_options.push_back(td_api::make_object<td_api::starGiveawayWinnerOption>(
            winner->users_, StarManager::get_star_count(winner->per_user_stars_), winner->default_));
      }
      options.push_back(td_api::make_object<td_api::starGiveawayPaymentOption>(
          result->currency_, result->amount_, StarManager::get_star_count(result->stars_), result->store_product_,
          result->yearly_boosts_, std::move(winner_options), result->default_, result->extended_));
    }

    promise_.set_value(td_api::make_object<td_api::starGiveawayPaymentOptions>(std::move(options)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetStarsTransactionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starTransactions>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStarsTransactionsQuery(Promise<td_api::object_ptr<td_api::starTransactions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &subscription_id, const string &offset, int32 limit,
            td_api::object_ptr<td_api::StarTransactionDirection> &&direction) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }
    int32 flags = 0;
    if (!subscription_id.empty()) {
      flags |= telegram_api::payments_getStarsTransactions::SUBSCRIPTION_ID_MASK;
    }
    if (direction != nullptr) {
      switch (direction->get_id()) {
        case td_api::starTransactionDirectionIncoming::ID:
          flags |= telegram_api::payments_getStarsTransactions::INBOUND_MASK;
          break;
        case td_api::starTransactionDirectionOutgoing::ID:
          flags |= telegram_api::payments_getStarsTransactions::OUTBOUND_MASK;
          break;
        default:
          UNREACHABLE();
      }
    }
    if (td_->auth_manager_->is_bot()) {
      flags |= telegram_api::payments_getStarsTransactions::ASCENDING_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::payments_getStarsTransactions(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                                    subscription_id, std::move(input_peer), offset, limit)));
  }

  void send(DialogId dialog_id, const string &transaction_id, bool is_refund) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }
    int32 flags = 0;
    if (is_refund) {
      flags |= telegram_api::inputStarsTransaction::REFUND_MASK;
    }
    vector<telegram_api::object_ptr<telegram_api::inputStarsTransaction>> transaction_ids;
    transaction_ids.push_back(
        telegram_api::make_object<telegram_api::inputStarsTransaction>(flags, false /*ignored*/, transaction_id));
    send_query(G()->net_query_creator().create(
        telegram_api::payments_getStarsTransactionsByID(std::move(input_peer), std::move(transaction_ids))));
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::payments_getStarsTransactionsByID::ReturnType,
                               telegram_api::payments_getStarsTransactions::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::payments_getStarsTransactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetStarsTransactionsQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetStarsTransactionsQuery");
    td_->chat_manager_->on_get_chats(std::move(result->chats_), "GetStarsTransactionsQuery");

    bool for_bot =
        dialog_id_.get_type() == DialogType::User && td_->user_manager_->is_user_bot(dialog_id_.get_user_id());
    bool for_user = dialog_id_.get_type() == DialogType::User && !for_bot;
    bool for_chat = !for_user && !for_bot;
    bool for_channel = for_chat && td_->dialog_manager_->is_broadcast_channel(dialog_id_);
    bool for_supergroup = for_chat && !for_channel;
    vector<td_api::object_ptr<td_api::starTransaction>> transactions;
    for (auto &transaction : result->history_) {
      vector<FileId> file_ids;
      td_api::object_ptr<td_api::productInfo> product_info;
      string bot_payload;
      td_api::object_ptr<td_api::affiliateInfo> affiliate;
      int32 commission_per_mille = 0;
      if (!transaction->title_.empty() || !transaction->description_.empty() || transaction->photo_ != nullptr) {
        auto photo = get_web_document_photo(td_->file_manager_.get(), std::move(transaction->photo_), DialogId());
        append(file_ids, photo_get_file_ids(photo));
        product_info = get_product_info_object(td_, transaction->title_, transaction->description_, photo);
      }
      if (!transaction->bot_payload_.empty()) {
        if (td_->auth_manager_->is_bot()) {
          bot_payload = transaction->bot_payload_.as_slice().str();
        } else if (!for_bot) {
          LOG(ERROR) << "Receive Star transaction with bot payload";
        }
      }
      if (transaction->starref_peer_ != nullptr) {
        DialogId referrer_dialog_id(transaction->starref_peer_);
        if (transaction->starref_commission_permille_ > 0 && transaction->starref_commission_permille_ < 1000 &&
            referrer_dialog_id.is_valid()) {
          td_->dialog_manager_->force_create_dialog(referrer_dialog_id, "affiliateInfo", true);
          auto referrer_star_amount = StarAmount(std::move(transaction->starref_amount_), true);
          affiliate = td_api::make_object<td_api::affiliateInfo>(
              transaction->starref_commission_permille_,
              td_->dialog_manager_->get_chat_id_object(referrer_dialog_id, "affiliateInfo"),
              referrer_star_amount.get_star_amount_object());
        } else {
          LOG(ERROR) << "Receive invalid affiliate info: " << to_string(transaction);
        }
      } else if (transaction->starref_commission_permille_ != 0) {
        if (transaction->starref_commission_permille_ > 0 && transaction->starref_commission_permille_ < 1000) {
          commission_per_mille = transaction->starref_commission_permille_;
        } else {
          LOG(ERROR) << "Receive invalid commission: " << to_string(transaction);
        }
      }
      auto get_paid_media_object = [&](DialogId dialog_id) -> vector<td_api::object_ptr<td_api::PaidMedia>> {
        auto extended_media = transform(std::move(transaction->extended_media_), [td = td_, dialog_id](auto &&media) {
          return MessageExtendedMedia(td, std::move(media), dialog_id);
        });
        for (auto &media : extended_media) {
          media.append_file_ids(td_, file_ids);
        }
        auto extended_media_objects =
            transform(std::move(extended_media), [td = td_](auto &&media) { return media.get_paid_media_object(td); });
        transaction->extended_media_.clear();
        return extended_media_objects;
      };
      auto get_message_id_object = [&] {
        auto message_id = MessageId(ServerMessageId(transaction->msg_id_));
        if (message_id != MessageId() && !message_id.is_valid()) {
          LOG(ERROR) << "Receive " << message_id << " in " << to_string(transaction);
          message_id = MessageId();
        }
        transaction->msg_id_ = 0;
        return message_id.get();
      };
      auto transaction_amount = StarAmount(std::move(transaction->stars_), true);
      auto is_refund = transaction->refund_;
      auto is_purchase = transaction_amount.is_positive() == is_refund;
      auto type = [&]() -> td_api::object_ptr<td_api::StarTransactionType> {
        switch (transaction->peer_->get_id()) {
          case telegram_api::starsTransactionPeerUnsupported::ID:
            return td_api::make_object<td_api::starTransactionTypeUnsupported>();
          case telegram_api::starsTransactionPeerPremiumBot::ID:
            if (for_user) {
              return td_api::make_object<td_api::starTransactionTypePremiumBotDeposit>();
            }
            return nullptr;
          case telegram_api::starsTransactionPeerAppStore::ID:
            if (for_user) {
              return td_api::make_object<td_api::starTransactionTypeAppStoreDeposit>();
            }
            return nullptr;
          case telegram_api::starsTransactionPeerPlayMarket::ID:
            if (for_user) {
              return td_api::make_object<td_api::starTransactionTypeGooglePlayDeposit>();
            }
            return nullptr;
          case telegram_api::starsTransactionPeerFragment::ID: {
            if (transaction->gift_) {
              if (for_user) {
                transaction->gift_ = false;
                return td_api::make_object<td_api::starTransactionTypeUserDeposit>(
                    0, td_->stickers_manager_->get_premium_gift_sticker_object(0, transaction_amount.get_star_count()));
              }
              return nullptr;
            }
            auto state = [&]() -> td_api::object_ptr<td_api::RevenueWithdrawalState> {
              if (transaction->transaction_date_ > 0) {
                SCOPE_EXIT {
                  transaction->transaction_date_ = 0;
                  transaction->transaction_url_.clear();
                };
                return td_api::make_object<td_api::revenueWithdrawalStateSucceeded>(transaction->transaction_date_,
                                                                                    transaction->transaction_url_);
              }
              if (transaction->pending_) {
                transaction->pending_ = false;
                return td_api::make_object<td_api::revenueWithdrawalStatePending>();
              }
              if (transaction->failed_) {
                transaction->failed_ = false;
                return td_api::make_object<td_api::revenueWithdrawalStateFailed>();
              }
              return nullptr;
            }();
            if (state != nullptr || is_refund) {
              if (for_user || for_bot || for_chat) {
                return td_api::make_object<td_api::starTransactionTypeFragmentWithdrawal>(std::move(state));
              }
              return nullptr;
            }
            if (for_user || for_bot) {
              return td_api::make_object<td_api::starTransactionTypeFragmentDeposit>();
            }
            return nullptr;
          }
          case telegram_api::starsTransactionPeer::ID: {
            DialogId dialog_id(
                static_cast<const telegram_api::starsTransactionPeer *>(transaction->peer_.get())->peer_);
            if (!dialog_id.is_valid()) {
              return nullptr;
            }
            if (commission_per_mille != 0) {
              SCOPE_EXIT {
                commission_per_mille = 0;
              };
              td_->dialog_manager_->force_create_dialog(dialog_id, "starsTransactionPeer", true);
              auto chat_id =
                  td_->dialog_manager_->get_chat_id_object(dialog_id, "starTransactionTypeAffiliateProgramCommission");
              return td_api::make_object<td_api::starTransactionTypeAffiliateProgramCommission>(chat_id,
                                                                                                commission_per_mille);
            }
            if (transaction->paid_messages_) {
              if (is_purchase) {
                if (!td_->dialog_manager_->is_broadcast_channel(dialog_id) && for_user) {
                  SCOPE_EXIT {
                    product_info = nullptr;
                    transaction->paid_messages_ = 0;
                  };
                  td_->dialog_manager_->force_create_dialog(dialog_id, "starsTransactionPeer", true);
                  auto chat_id =
                      td_->dialog_manager_->get_chat_id_object(dialog_id, "starTransactionTypePaidMessageSend");
                  return td_api::make_object<td_api::starTransactionTypePaidMessageSend>(chat_id,
                                                                                         transaction->paid_messages_);
                }
              } else {
                if ((for_user || for_supergroup) && affiliate != nullptr) {
                  SCOPE_EXIT {
                    product_info = nullptr;
                    transaction->paid_messages_ = 0;
                    affiliate = nullptr;
                  };
                  return td_api::make_object<td_api::starTransactionTypePaidMessageReceive>(
                      get_message_sender_object(td_, dialog_id, "starTransactionTypePaidMessageReceive"),
                      transaction->paid_messages_, affiliate->commission_per_mille_,
                      std::move(affiliate->star_amount_));
                }
              }
              return nullptr;
            }
            if (dialog_id.get_type() == DialogType::User) {
              auto user_id = dialog_id.get_user_id();
              auto user_id_object = td_->user_manager_->get_user_id_object(user_id, "starsTransactionPeer");
              if (transaction->stargift_ != nullptr) {
                auto gift = StarGift(td_, std::move(transaction->stargift_), true);
                transaction->stargift_ = nullptr;
                if (!gift.is_valid()) {
                  return nullptr;
                }
                td_->star_gift_manager_->on_get_star_gift(gift, true);
                if (is_purchase) {
                  if (gift.is_unique()) {
                    if (transaction->stargift_upgrade_) {
                      if (for_user) {
                        transaction->stargift_upgrade_ = false;
                        transaction->msg_id_ = 0;  // ignore
                        product_info = nullptr;
                        return td_api::make_object<td_api::starTransactionTypeGiftUpgrade>(
                            user_id_object, gift.get_upgraded_gift_object(td_));
                      }
                    } else {
                      if (for_user) {
                        return td_api::make_object<td_api::starTransactionTypeGiftTransfer>(
                            get_message_sender_object(td_, user_id, DialogId(), "starTransactionTypeGiftTransfer"),
                            gift.get_upgraded_gift_object(td_));
                      }
                    }
                  } else {
                    if (for_user || for_bot) {
                      return td_api::make_object<td_api::starTransactionTypeGiftPurchase>(
                          get_message_sender_object(td_, user_id, DialogId(), "starTransactionTypeGiftPurchase"),
                          gift.get_gift_object(td_));
                    }
                  }
                } else {
                  if (gift.is_unique()) {
                    LOG(ERROR) << "Receive sale of an upgraded gift";
                  } else {
                    if (for_user || for_channel) {
                      return td_api::make_object<td_api::starTransactionTypeGiftSale>(user_id_object,
                                                                                      gift.get_gift_object(td_));
                    }
                  }
                }
                return nullptr;
              }
              if (transaction->subscription_period_ > 0) {
                SCOPE_EXIT {
                  transaction->subscription_period_ = 0;
                };
                if (is_purchase) {
                  if (for_user) {
                    return td_api::make_object<td_api::starTransactionTypeBotSubscriptionPurchase>(
                        user_id_object, transaction->subscription_period_, std::move(product_info));
                  }
                } else {
                  if (for_channel) {
                    return td_api::make_object<td_api::starTransactionTypeChannelSubscriptionSale>(
                        user_id_object, transaction->subscription_period_);
                  } else if (for_bot) {
                    SCOPE_EXIT {
                      bot_payload.clear();
                    };
                    return td_api::make_object<td_api::starTransactionTypeBotSubscriptionSale>(
                        user_id_object, transaction->subscription_period_, std::move(product_info), bot_payload,
                        std::move(affiliate));
                  }
                }
                return nullptr;
              }
              if (transaction->gift_) {
                if (for_user) {
                  transaction->gift_ = false;
                  return td_api::make_object<td_api::starTransactionTypeUserDeposit>(
                      user_id == UserManager::get_service_notifications_user_id()
                          ? 0
                          : td_->user_manager_->get_user_id_object(user_id, "starTransactionTypeUserDeposit"),
                      td_->stickers_manager_->get_premium_gift_sticker_object(0, transaction_amount.get_star_count()));
                }
                return nullptr;
              }
              if (transaction->subscription_period_ > 0) {
                if (for_channel) {
                  SCOPE_EXIT {
                    transaction->subscription_period_ = 0;
                  };
                  return td_api::make_object<td_api::starTransactionTypeChannelSubscriptionSale>(
                      user_id_object, transaction->subscription_period_);
                }
                return nullptr;
              }
              if (transaction->reaction_) {
                if (for_channel) {
                  transaction->reaction_ = false;
                  return td_api::make_object<td_api::starTransactionTypeChannelPaidReactionReceive>(
                      user_id_object, get_message_id_object());
                }
                return nullptr;
              }
              SCOPE_EXIT {
                bot_payload.clear();
              };
              if (product_info != nullptr) {
                if (is_purchase) {
                  if (for_user) {
                    if (transaction->premium_gift_months_ > 0) {
                      SCOPE_EXIT {
                        transaction->premium_gift_months_ = 0;
                        product_info = nullptr;
                      };
                      return td_api::make_object<td_api::starTransactionTypePremiumPurchase>(
                          user_id_object, transaction->premium_gift_months_,
                          td_->stickers_manager_->get_premium_gift_sticker_object(transaction->premium_gift_months_,
                                                                                  0));
                    } else {
                      return td_api::make_object<td_api::starTransactionTypeBotInvoicePurchase>(
                          user_id_object, std::move(product_info));
                    }
                  }
                } else {
                  if (for_bot) {
                    return td_api::make_object<td_api::starTransactionTypeBotInvoiceSale>(
                        user_id_object, std::move(product_info), bot_payload, std::move(affiliate));
                  }
                }
                return nullptr;
              }
              if (!transaction->extended_media_.empty() || is_refund || for_bot) {  // TODO
                if (is_purchase) {
                  if (for_user) {
                    return td_api::make_object<td_api::starTransactionTypeBotPaidMediaPurchase>(
                        user_id_object, get_paid_media_object(dialog_id));
                  }
                } else {
                  if (for_bot) {
                    return td_api::make_object<td_api::starTransactionTypeBotPaidMediaSale>(
                        user_id_object, get_paid_media_object(dialog_id_), bot_payload, std::move(affiliate));
                  } else if (for_channel) {
                    return td_api::make_object<td_api::starTransactionTypeChannelPaidMediaSale>(
                        user_id_object, get_message_id_object(), get_paid_media_object(dialog_id_));
                  }
                }
                return nullptr;
              }
              return nullptr;
            }

            // partner isn't a user now
            td_->dialog_manager_->force_create_dialog(dialog_id, "starsTransactionPeer", true);
            auto chat_id = td_->dialog_manager_->get_chat_id_object(dialog_id, "starsTransactionPeer");
            if (transaction->stargift_ != nullptr) {
              auto gift = StarGift(td_, std::move(transaction->stargift_), true);
              transaction->stargift_ = nullptr;
              if (!gift.is_valid()) {
                return nullptr;
              }
              td_->star_gift_manager_->on_get_star_gift(gift, true);
              if (is_purchase) {
                if (gift.is_unique()) {
                  if (!transaction->stargift_upgrade_) {
                    if (for_user) {
                      return td_api::make_object<td_api::starTransactionTypeGiftTransfer>(
                          get_message_sender_object(td_, UserId(), dialog_id, "starTransactionTypeGiftTransfer"),
                          gift.get_upgraded_gift_object(td_));
                    }
                  }
                } else {
                  if (for_user || for_bot) {
                    return td_api::make_object<td_api::starTransactionTypeGiftPurchase>(
                        get_message_sender_object(td_, UserId(), dialog_id, "starTransactionTypeGiftPurchase"),
                        gift.get_gift_object(td_));
                  }
                }
              }
              return nullptr;
            }
            if (transaction->giveaway_post_id_ > 0) {
              if (for_user && dialog_id.get_type() == DialogType::Channel) {
                SCOPE_EXIT {
                  transaction->giveaway_post_id_ = 0;
                };
                return td_api::make_object<td_api::starTransactionTypeGiveawayDeposit>(
                    chat_id, MessageId(ServerMessageId(transaction->giveaway_post_id_)).get());
              }
              return nullptr;
            }
            if (transaction->subscription_period_ > 0) {
              if (td_->dialog_manager_->is_broadcast_channel(dialog_id) && for_user) {
                SCOPE_EXIT {
                  transaction->subscription_period_ = 0;
                };
                return td_api::make_object<td_api::starTransactionTypeChannelSubscriptionPurchase>(
                    chat_id, transaction->subscription_period_);
              }
              return nullptr;
            }
            if (transaction->reaction_) {
              if (td_->dialog_manager_->is_broadcast_channel(dialog_id) && for_user) {
                transaction->reaction_ = false;
                return td_api::make_object<td_api::starTransactionTypeChannelPaidReactionSend>(chat_id,
                                                                                               get_message_id_object());
              }
              return nullptr;
            }
            if (!transaction->extended_media_.empty() || is_refund) {  // TODO
              if (td_->dialog_manager_->is_broadcast_channel(dialog_id) && for_user) {
                return td_api::make_object<td_api::starTransactionTypeChannelPaidMediaPurchase>(
                    chat_id, get_message_id_object(), get_paid_media_object(dialog_id));
              }
              return nullptr;
            }
            return nullptr;
          }
          case telegram_api::starsTransactionPeerAds::ID:
            if (for_bot || for_channel) {
              return td_api::make_object<td_api::starTransactionTypeTelegramAdsWithdrawal>();
            }
            return nullptr;
          case telegram_api::starsTransactionPeerAPI::ID: {
            if (for_bot) {
              SCOPE_EXIT {
                transaction->floodskip_number_ = 0;
              };
              return td_api::make_object<td_api::starTransactionTypeTelegramApiUsage>(transaction->floodskip_number_);
            }
            return nullptr;
          }
          default:
            UNREACHABLE();
            return nullptr;
        }
      }();
      if (type == nullptr) {
        LOG(ERROR) << "Receive unsupported Star transaction in " << dialog_id_ << ": " << to_string(transaction);
        type = td_api::make_object<td_api::starTransactionTypeUnsupported>();
      }
      auto star_transaction =
          td_api::make_object<td_api::starTransaction>(transaction->id_, transaction_amount.get_star_amount_object(),
                                                       is_refund, transaction->date_, std::move(type));
      if (star_transaction->type_->get_id() != td_api::starTransactionTypeUnsupported::ID) {
        if (product_info != nullptr) {
          LOG(ERROR) << "Receive product info with " << to_string(star_transaction);
        }
        if (!bot_payload.empty()) {
          LOG(ERROR) << "Receive bot payload with " << to_string(star_transaction);
        }
        if (transaction->transaction_date_ || !transaction->transaction_url_.empty() || transaction->pending_ ||
            transaction->failed_) {
          LOG(ERROR) << "Receive withdrawal state with " << to_string(star_transaction);
        }
        if (transaction->msg_id_ != 0) {
          LOG(ERROR) << "Receive message identifier with " << to_string(star_transaction);
        }
        if (transaction->gift_) {
          LOG(ERROR) << "Receive gift with " << to_string(star_transaction);
        }
        if (transaction->subscription_period_ != 0) {
          LOG(ERROR) << "Receive subscription period with " << to_string(star_transaction);
        }
        if (transaction->reaction_) {
          LOG(ERROR) << "Receive reaction with " << to_string(star_transaction);
        }
        if (!transaction->extended_media_.empty()) {
          LOG(ERROR) << "Receive paid media with " << to_string(star_transaction);
        }
        if (transaction->giveaway_post_id_ != 0) {
          LOG(ERROR) << "Receive giveaway message with " << to_string(star_transaction);
        }
        if (transaction->stargift_ != nullptr) {
          LOG(ERROR) << "Receive gift with " << to_string(star_transaction);
        }
        if (transaction->floodskip_number_ != 0) {
          LOG(ERROR) << "Receive API payment with " << to_string(star_transaction);
        }
        if (affiliate != nullptr) {
          LOG(ERROR) << "Receive affiliate with " << to_string(star_transaction);
        }
        if (commission_per_mille != 0) {
          LOG(ERROR) << "Receive commission with " << to_string(star_transaction);
        }
        if (transaction->stargift_upgrade_) {
          LOG(ERROR) << "Receive gift upgrade with " << to_string(star_transaction);
        }
        if (transaction->paid_messages_) {
          LOG(ERROR) << "Receive paid messages with " << to_string(star_transaction);
        }
        if (transaction->premium_gift_months_) {
          LOG(ERROR) << "Receive Telegram Premium purchase with " << to_string(star_transaction);
        }
      }
      if (!file_ids.empty()) {
        auto file_source_id =
            td_->star_manager_->get_star_transaction_file_source_id(dialog_id_, transaction->id_, is_refund);
        for (auto file_id : file_ids) {
          td_->file_manager_->add_file_source(file_id, file_source_id, "GetStarsTransactionsQuery");
        }
      }
      transactions.push_back(std::move(star_transaction));
    }

    auto star_amount = StarAmount(std::move(result->balance_), true);
    if (dialog_id_ == td_->dialog_manager_->get_my_dialog_id()) {
      td_->star_manager_->on_update_owned_star_amount(star_amount);
    }
    promise_.set_value(td_api::make_object<td_api::starTransactions>(star_amount.get_star_amount_object(),
                                                                     std::move(transactions), result->next_offset_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStarsTransactionsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStarsSubscriptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starSubscriptions>> promise_;

 public:
  explicit GetStarsSubscriptionsQuery(Promise<td_api::object_ptr<td_api::starSubscriptions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(bool only_expiring, const string &offset) {
    int32 flags = 0;
    if (only_expiring) {
      flags |= telegram_api::payments_getStarsSubscriptions::MISSING_BALANCE_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::payments_getStarsSubscriptions(
        flags, false /*ignored*/, telegram_api::make_object<telegram_api::inputPeerSelf>(), offset)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsSubscriptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStarsSubscriptionsQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetStarsSubscriptionsQuery");
    td_->chat_manager_->on_get_chats(std::move(result->chats_), "GetStarsSubscriptionsQuery");

    vector<td_api::object_ptr<td_api::starSubscription>> subscriptions;
    for (auto &subscription : result->subscriptions_) {
      StarSubscription star_subscription(td_, std::move(subscription));
      if (!star_subscription.is_valid()) {
        LOG(ERROR) << "Receive invalid subscription " << star_subscription;
      } else {
        subscriptions.push_back(star_subscription.get_star_subscription_object(td_));
      }
    }

    auto star_amount = StarAmount(std::move(result->balance_), true);
    td_->star_manager_->on_update_owned_star_amount(star_amount);
    promise_.set_value(td_api::make_object<td_api::starSubscriptions>(
        star_amount.get_star_amount_object(), std::move(subscriptions),
        StarManager::get_star_count(result->subscriptions_missing_balance_), result->subscriptions_next_offset_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ChangeStarsSubscriptionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ChangeStarsSubscriptionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &subscription_id, bool is_canceled) {
    send_query(G()->net_query_creator().create(telegram_api::payments_changeStarsSubscription(
        telegram_api::payments_changeStarsSubscription::CANCELED_MASK,
        telegram_api::make_object<telegram_api::inputPeerSelf>(), subscription_id, is_canceled)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_changeStarsSubscription>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class BotCancelStarsSubscriptionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit BotCancelStarsSubscriptionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user, const string &telegram_payment_charge_id,
            bool is_canceled) {
    int32 flags = 0;
    if (!is_canceled) {
      flags |= telegram_api::payments_botCancelStarsSubscription::RESTORE_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::payments_botCancelStarsSubscription(
        flags, false /*ignored*/, std::move(input_user), telegram_payment_charge_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_botCancelStarsSubscription>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class FulfillStarsSubscriptionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit FulfillStarsSubscriptionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &subscription_id) {
    send_query(G()->net_query_creator().create(telegram_api::payments_fulfillStarsSubscription(
        telegram_api::make_object<telegram_api::inputPeerSelf>(), subscription_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_fulfillStarsSubscription>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class RefundStarsChargeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit RefundStarsChargeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user, const string &telegram_payment_charge_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::payments_refundStarsCharge(std::move(input_user), telegram_payment_charge_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_refundStarsCharge>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for RefundStarsChargeQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

static td_api::object_ptr<td_api::starRevenueStatus> convert_stars_revenue_status(
    telegram_api::object_ptr<telegram_api::starsRevenueStatus> obj) {
  CHECK(obj != nullptr);
  int32 next_withdrawal_in = 0;
  if (obj->withdrawal_enabled_ && obj->next_withdrawal_at_ > 0) {
    next_withdrawal_in = max(obj->next_withdrawal_at_ - G()->unix_time(), 1);
  }
  return td_api::make_object<td_api::starRevenueStatus>(
      StarAmount(std::move(obj->overall_revenue_), true).get_star_amount_object(),
      StarAmount(std::move(obj->current_balance_), true).get_star_amount_object(),
      StarAmount(std::move(obj->available_balance_), true).get_star_amount_object(), obj->withdrawal_enabled_,
      next_withdrawal_in);
}

class GetStarsRevenueStatsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starRevenueStatistics>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStarsRevenueStatsQuery(Promise<td_api::object_ptr<td_api::starRevenueStatistics>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_dark) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }

    int32 flags = 0;
    if (is_dark) {
      flags |= telegram_api::payments_getStarsRevenueStats::DARK_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::payments_getStarsRevenueStats(flags, false /*ignored*/, std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsRevenueStats>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetStarsRevenueStatsQuery: " << to_string(ptr);
    promise_.set_value(td_api::make_object<td_api::starRevenueStatistics>(
        StatisticsManager::convert_stats_graph(std::move(ptr->revenue_graph_)),
        convert_stars_revenue_status(std::move(ptr->status_)),
        ptr->usd_rate_ > 0 ? clamp(ptr->usd_rate_ * 1e2, 1e-18, 1e18) : 1.3));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStarsRevenueStatsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStarsRevenueWithdrawalUrlQuery final : public Td::ResultHandler {
  Promise<string> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStarsRevenueWithdrawalUrlQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int64 star_count,
            telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::payments_getStarsRevenueWithdrawalUrl(
        std::move(input_peer), star_count, std::move(input_check_password))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsRevenueWithdrawalUrl>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(std::move(result_ptr.ok_ref()->url_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStarsRevenueWithdrawalUrlQuery");
    promise_.set_error(std::move(status));
  }
};

class GetStarsRevenueAdsAccountUrlQuery final : public Td::ResultHandler {
  Promise<string> promise_;
  DialogId dialog_id_;

 public:
  explicit GetStarsRevenueAdsAccountUrlQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }

    send_query(
        G()->net_query_creator().create(telegram_api::payments_getStarsRevenueAdsAccountUrl(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::payments_getStarsRevenueAdsAccountUrl>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(std::move(result_ptr.ok_ref()->url_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetStarsRevenueAdsAccountUrlQuery");
    promise_.set_error(std::move(status));
  }
};

class GetPaidMessageRevenueQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::starCount>> promise_;

 public:
  explicit GetPaidMessageRevenueQuery(Promise<td_api::object_ptr<td_api::starCount>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    send_query(G()->net_query_creator().create(telegram_api::account_getPaidMessagesRevenue(std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getPaidMessagesRevenue>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetPaidMessageRevenueQuery: " << to_string(ptr);
    promise_.set_value(td_api::make_object<td_api::starCount>(StarManager::get_star_count(ptr->stars_amount_)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

StarManager::StarManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void StarManager::start_up() {
  if (td_->auth_manager_->is_bot() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  auto owned_star_count = G()->td_db()->get_binlog_pmc()->get("owned_star_count");
  if (!owned_star_count.empty()) {
    is_owned_star_count_inited_ = true;
    auto star_count = split(owned_star_count);
    owned_star_count_ = to_integer<int64>(star_count.first);
    owned_nanostar_count_ = to_integer<int32>(star_count.second);
    sent_star_count_ = owned_star_count_;
    sent_nanostar_count_ = owned_nanostar_count_;
    send_closure(G()->td(), &Td::send_update, get_update_owned_star_count_object());
  }
}

void StarManager::tear_down() {
  parent_.reset();
}

td_api::object_ptr<td_api::updateOwnedStarCount> StarManager::get_update_owned_star_count_object() const {
  CHECK(is_owned_star_count_inited_);
  // sent_star_count_ can be negative as well as owned_star_count_
  return td_api::make_object<td_api::updateOwnedStarCount>(
      td_api::make_object<td_api::starAmount>(sent_star_count_, sent_nanostar_count_));
}

void StarManager::on_update_owned_star_amount(StarAmount star_amount) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  auto star_count = star_amount.get_star_count();
  auto nanostar_count = star_amount.get_nanostar_count();
  if (is_owned_star_count_inited_ && star_count == owned_star_count_ && nanostar_count == owned_nanostar_count_) {
    return;
  }
  is_owned_star_count_inited_ = true;
  owned_star_count_ = star_count;
  owned_nanostar_count_ = nanostar_count;
  if (owned_star_count_ + pending_owned_star_count_ != sent_star_count_ ||
      owned_nanostar_count_ != sent_nanostar_count_) {
    sent_star_count_ = owned_star_count_ + pending_owned_star_count_;
    sent_nanostar_count_ = owned_nanostar_count_;
    send_closure(G()->td(), &Td::send_update, get_update_owned_star_count_object());
  }
  G()->td_db()->get_binlog_pmc()->set("owned_star_count", PSTRING()
                                                              << owned_star_count_ << ' ' << owned_nanostar_count_);
}

void StarManager::add_pending_owned_star_count(int64 star_count, bool move_to_owned) {
  if (star_count == 0) {
    return;
  }
  pending_owned_star_count_ += star_count;
  if (is_owned_star_count_inited_) {
    if (move_to_owned) {
      owned_star_count_ -= star_count;
      G()->td_db()->get_binlog_pmc()->set("owned_star_count", PSTRING()
                                                                  << owned_star_count_ << ' ' << owned_nanostar_count_);
    } else {
      sent_star_count_ += star_count;
      send_closure(G()->td(), &Td::send_update, get_update_owned_star_count_object());
    }
  }
}

bool StarManager::has_owned_star_count(int64 star_count) const {
  if (star_count <= 0 || !is_owned_star_count_inited_) {
    return true;
  }
  return sent_star_count_ >= star_count;
}

Status StarManager::can_manage_stars(DialogId dialog_id, bool allow_self) const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      auto user_id = dialog_id.get_user_id();
      if (allow_self && user_id == td_->user_manager_->get_my_id()) {
        break;
      }
      TRY_RESULT(bot_data, td_->user_manager_->get_bot_data(user_id));
      if (!bot_data.can_be_edited) {
        return Status::Error(400, "The bot isn't owned");
      }
      break;
    }
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (!td_->chat_manager_->get_channel_permissions(channel_id).is_creator() && !allow_self) {
        return Status::Error(400, "Not enough rights");
      }
      break;
    }
    default:
      return Status::Error(400, "Unallowed chat specified");
  }
  return Status::OK();
}

void StarManager::get_star_payment_options(Promise<td_api::object_ptr<td_api::starPaymentOptions>> &&promise) {
  td_->create_handler<GetStarsTopupOptionsQuery>(std::move(promise))->send();
}

void StarManager::get_star_gift_payment_options(UserId user_id,
                                                Promise<td_api::object_ptr<td_api::starPaymentOptions>> &&promise) {
  if (user_id == UserId()) {
    td_->create_handler<GetStarsGiftOptionsQuery>(std::move(promise))->send(nullptr);
    return;
  }
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
  td_->create_handler<GetStarsGiftOptionsQuery>(std::move(promise))->send(std::move(input_user));
}

void StarManager::get_star_giveaway_payment_options(
    Promise<td_api::object_ptr<td_api::starGiveawayPaymentOptions>> &&promise) {
  td_->create_handler<GetStarsGiveawayOptionsQuery>(std::move(promise))->send();
}

void StarManager::get_star_transactions(td_api::object_ptr<td_api::MessageSender> owner_id,
                                        const string &subscription_id, const string &offset, int32 limit,
                                        td_api::object_ptr<td_api::StarTransactionDirection> &&direction,
                                        Promise<td_api::object_ptr<td_api::starTransactions>> &&promise) {
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, owner_id, true, false));
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id, true));
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Limit must be non-negative"));
  }
  td_->stickers_manager_->load_premium_gift_sticker_set(PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_id, subscription_id, offset, limit, direction = std::move(direction),
       promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &StarManager::do_get_star_transactions, dialog_id, subscription_id, offset, limit,
                       std::move(direction), std::move(promise));
        }
      }));
}

void StarManager::do_get_star_transactions(DialogId dialog_id, const string &subscription_id, const string &offset,
                                           int32 limit,
                                           td_api::object_ptr<td_api::StarTransactionDirection> &&direction,
                                           Promise<td_api::object_ptr<td_api::starTransactions>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id, true));

  td_->create_handler<GetStarsTransactionsQuery>(std::move(promise))
      ->send(dialog_id, subscription_id, offset, limit, std::move(direction));
}

void StarManager::get_star_subscriptions(bool only_expiring, const string &offset,
                                         Promise<td_api::object_ptr<td_api::starSubscriptions>> &&promise) {
  td_->create_handler<GetStarsSubscriptionsQuery>(std::move(promise))->send(only_expiring, offset);
}

void StarManager::edit_star_subscription(const string &subscription_id, bool is_canceled, Promise<Unit> &&promise) {
  td_->create_handler<ChangeStarsSubscriptionQuery>(std::move(promise))->send(subscription_id, is_canceled);
}

void StarManager::edit_user_star_subscription(UserId user_id, const string &telegram_payment_charge_id,
                                              bool is_canceled, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
  td_->create_handler<BotCancelStarsSubscriptionQuery>(std::move(promise))
      ->send(std::move(input_user), telegram_payment_charge_id, is_canceled);
}

void StarManager::reuse_star_subscription(const string &subscription_id, Promise<Unit> &&promise) {
  td_->create_handler<FulfillStarsSubscriptionQuery>(std::move(promise))->send(subscription_id);
}

void StarManager::refund_star_payment(UserId user_id, const string &telegram_payment_charge_id,
                                      Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
  td_->create_handler<RefundStarsChargeQuery>(std::move(promise))
      ->send(std::move(input_user), telegram_payment_charge_id);
}

void StarManager::get_star_revenue_statistics(const td_api::object_ptr<td_api::MessageSender> &owner_id, bool is_dark,
                                              Promise<td_api::object_ptr<td_api::starRevenueStatistics>> &&promise) {
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, owner_id, true, false));
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id, true));
  td_->create_handler<GetStarsRevenueStatsQuery>(std::move(promise))->send(dialog_id, is_dark);
}

void StarManager::get_star_withdrawal_url(const td_api::object_ptr<td_api::MessageSender> &owner_id, int64 star_count,
                                          const string &password, Promise<string> &&promise) {
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, owner_id, true, false));
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id, true));
  if (password.empty()) {
    return promise.set_error(Status::Error(400, "PASSWORD_HASH_INVALID"));
  }
  send_closure(
      td_->password_manager_, &PasswordManager::get_input_check_password_srp, password,
      PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, star_count, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP>> result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &StarManager::send_get_star_withdrawal_url_query, dialog_id, star_count,
                     result.move_as_ok(), std::move(promise));
      }));
}

void StarManager::send_get_star_withdrawal_url_query(
    DialogId dialog_id, int64 star_count,
    telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password, Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  td_->create_handler<GetStarsRevenueWithdrawalUrlQuery>(std::move(promise))
      ->send(dialog_id, star_count, std::move(input_check_password));
}

void StarManager::get_star_ad_account_url(const td_api::object_ptr<td_api::MessageSender> &owner_id,
                                          Promise<string> &&promise) {
  TRY_RESULT_PROMISE(promise, dialog_id, get_message_sender_dialog_id(td_, owner_id, true, false));
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id));
  td_->create_handler<GetStarsRevenueAdsAccountUrlQuery>(std::move(promise))->send(dialog_id);
}

void StarManager::get_paid_message_revenue(UserId user_id, Promise<td_api::object_ptr<td_api::starCount>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
  td_->create_handler<GetPaidMessageRevenueQuery>(std::move(promise))->send(std::move(input_user));
}

void StarManager::reload_star_transaction(DialogId dialog_id, const string &transaction_id, bool is_refund,
                                          Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_stars(dialog_id, true));
  auto query_promise = PromiseCreator::lambda(
      [promise = std::move(promise)](Result<td_api::object_ptr<td_api::starTransactions>> r_transactions) mutable {
        if (r_transactions.is_error()) {
          promise.set_error(r_transactions.move_as_error());
        } else {
          promise.set_value(Unit());
        }
      });
  td_->create_handler<GetStarsTransactionsQuery>(std::move(query_promise))->send(dialog_id, transaction_id, is_refund);
}

void StarManager::reload_owned_star_count() {
  do_get_star_transactions(td_->dialog_manager_->get_my_dialog_id(), string(), string(), 1, nullptr, Auto());
}

void StarManager::on_update_stars_revenue_status(
    telegram_api::object_ptr<telegram_api::updateStarsRevenueStatus> &&update) {
  DialogId dialog_id(update->peer_);
  if (can_manage_stars(dialog_id, true).is_error()) {
    LOG(ERROR) << "Receive " << to_string(update);
    return;
  }
  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateStarRevenueStatus>(
                   get_message_sender_object(td_, dialog_id, "updateStarRevenueStatus"),
                   convert_stars_revenue_status(std::move(update->status_))));
}

FileSourceId StarManager::get_star_transaction_file_source_id(DialogId dialog_id, const string &transaction_id,
                                                              bool is_refund) {
  if (!dialog_id.is_valid() || transaction_id.empty()) {
    return FileSourceId();
  }

  auto &source_id = star_transaction_file_source_ids_[is_refund][dialog_id][transaction_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_star_transaction_file_source(dialog_id, transaction_id, is_refund);
  }
  VLOG(file_references) << "Return " << source_id << " for " << (is_refund ? "refund " : "") << "transaction "
                        << transaction_id << " in " << dialog_id;
  return source_id;
}

int64 StarManager::get_star_count(int64 amount, bool allow_negative) {
  auto max_amount = static_cast<int64>(1) << 51;
  if (amount < 0) {
    if (!allow_negative) {
      LOG(ERROR) << "Receive Telegram Star amount = " << amount;
      return 0;
    }
    if (amount < -max_amount) {
      LOG(ERROR) << "Receive Telegram Star amount = " << amount;
      return -max_amount;
    }
  }
  if (amount > max_amount) {
    LOG(ERROR) << "Receive Telegram Star amount = " << amount;
    return max_amount;
  }
  return amount;
}

int32 StarManager::get_nanostar_count(int64 &star_count, int32 nanostar_count) {
  if (-1000000000 >= nanostar_count || nanostar_count >= 1000000000) {
    LOG(ERROR) << "Receive " << star_count << " + " << nanostar_count << " Telegram Stars";
    return nanostar_count;
  }
  if (star_count < 0 && nanostar_count > 0) {
    LOG(ERROR) << "Receive " << star_count << " + " << nanostar_count << " Telegram Stars";
    star_count++;
    nanostar_count -= 1000000000;
  }
  if (star_count > 0 && nanostar_count < 0) {
    LOG(ERROR) << "Receive " << star_count << " + " << nanostar_count << " Telegram Stars";
    star_count--;
    nanostar_count += 1000000000;
  }
  if (!(star_count < 0 && nanostar_count > 0) && !(star_count > 0 && nanostar_count < 0)) {
    return nanostar_count;
  }
  LOG(ERROR) << "Receive " << star_count << " + " << nanostar_count << " Telegram Stars";
  return 0;
}

int32 StarManager::get_months_by_star_count(int64 star_count) {
  return star_count <= 1000 ? 3 : (star_count < 2500 ? 6 : 12);
}

void StarManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (is_owned_star_count_inited_) {
    updates.push_back(get_update_owned_star_count_object());
  }
}

}  // namespace td
