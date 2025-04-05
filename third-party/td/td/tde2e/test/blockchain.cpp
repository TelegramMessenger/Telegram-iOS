//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/TestBlockchain.h"

#include "td/utils/simple_tests.h"
#include "td/utils/Status.h"

using namespace tde2e_core;
using BB = BlockBuilder;
using BT = BlockchainTester;

S_TEST(BlockchainValidation, ZeroBlock) {
  auto alice_pk = PrivateKey::generate().move_as_ok();
  auto bob_pk = PrivateKey::generate().move_as_ok();
  {
    TEST_DEBUG_VALUE(description, "Valid: zero block with empty group state");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .with_group_state({{1, AllPermissions, alice_pk.to_public_key()}}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_ok(block));
  }
  {
    TEST_DEBUG_VALUE(description, "Valid: zero block with group state only in proof");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .set_value("a", "b")  // need some changes
                     .with_group_state({}, false, true, 7)
                     .with_shared_key({}, false, true)
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_ok(block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with wrong height");
    auto block = BB().with_height(1)
                     .with_block_hash({})
                     .with_group_state({}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_HeightMismatch, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with wrong hash");
    auto block = BB().with_height(0)
                     .with_block_hash({1})
                     .with_group_state({}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_HashMismatch, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Valid: zero block with invalid signature");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .with_group_state({}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .with_public_key(alice_pk)
                     .build_zero_sign();
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidSignature, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with skipped group state proof");
    auto block = BB().with_height(0)
                     .set_value("a", "b")
                     .with_block_hash({})
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_DEBUG_VALUE(block, block);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidStateProof_Group, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with wrong user_id in group state proof");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .set_value("a", "b")
                     .with_group_state({{1, 3, alice_pk.to_public_key()}}, false, true)
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidStateProof_Group, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with other person in group state");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .with_group_state({{2, 3, bob_pk.to_public_key()}}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_NoPermissions, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: zero block with duplicate group state");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .with_group_state({{1, 3, alice_pk.to_public_key()}}, true, true)
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidStateProof_Group, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: duplicate user_id");
    auto block = BB().with_height(0)
                     .with_block_hash({})
                     .with_group_state({{1, 1, alice_pk.to_public_key()}, {1, 1, bob_pk.to_public_key()}}, true, false)
                     .with_shared_key({1}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidGroupState, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: duplicate public key");
    auto block =
        BB().with_height(0)
            .with_block_hash({})
            .with_group_state({{1, 1, alice_pk.to_public_key()}, {2, 1, alice_pk.to_public_key()}}, true, false)
            .with_shared_key({1}, true, false)
            .skip_group_state_proof()
            .skip_shared_key_proof()
            .build(alice_pk);
    TEST_TRY_STATUS(BT().expect_error(E::InvalidBlock_InvalidGroupState, block));
  }
  return td::Status::OK();
}

S_TEST(BlockchainValidation, GroupStateChanges) {
  auto alice_pk = PrivateKey::generate().move_as_ok();
  auto bob_pk = PrivateKey::generate().move_as_ok();
  auto carol_pk = PrivateKey::generate().move_as_ok();
  Block minus_one_block;
  auto zero_block =
      BB().with_previous_block(minus_one_block)
          .with_group_state({{1, 1, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}}, true, false, 3)
          .with_shared_key({1}, true, false)
          .skip_group_state_proof()
          .skip_shared_key_proof()
          .build(alice_pk);
  {
    TEST_DEBUG_VALUE(description, "Valid: sanity check of zero block");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: can't remove without permissions");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block = BB().with_previous_block(zero_block)
                     .with_group_state({{1, 1, alice_pk.to_public_key()}}, true, false)
                     .with_shared_key({1}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(bt.expect_error(E::InvalidBlock_NoPermissions, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: can't add without permissions");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block = BB().with_previous_block(zero_block)
                     .with_group_state({{3, 2, carol_pk.to_public_key()}}, true, false)
                     .with_shared_key({3}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(bob_pk);
    TEST_TRY_STATUS(bt.expect_error(E::InvalidBlock_NoPermissions, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: can't raise permissions");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block = BB().with_previous_block(zero_block)
                     .with_group_state({{1, 3, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}}, true, false)
                     .with_shared_key({1, 2}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(bt.expect_error(E::InvalidBlock_NoPermissions, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Valid: new shared key");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block = BB().with_previous_block(zero_block)
                     .with_group_state({{1, 1, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}}, true, false)
                     .with_shared_key({1, 2}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(alice_pk);
    TEST_TRY_STATUS(bt.expect_ok(block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: remove self and change shared key");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block = BB().with_previous_block(zero_block)
                     .with_group_state({{1, 1, alice_pk.to_public_key()}}, true, false)
                     .with_shared_key({1}, true, false)
                     .skip_group_state_proof()
                     .skip_shared_key_proof()
                     .build(bob_pk);
    TEST_TRY_STATUS(bt.expect_error(E::InvalidBlock_NoPermissions, block));
  }
  {
    TEST_DEBUG_VALUE(description, "Valid: self join");
    BT bt;
    TEST_TRY_STATUS(bt.expect_ok(zero_block));
    auto block =
        BB().with_previous_block(zero_block)
            .with_group_state(
                {{1, 1, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}, {3, 2, carol_pk.to_public_key()}},
                true, false)
            .with_shared_key({1, 2, 3}, true, false)
            .skip_group_state_proof()
            .skip_shared_key_proof()
            .build(carol_pk);
    TEST_TRY_STATUS(bt.expect_ok(block));
  }
  {
    TEST_DEBUG_VALUE(description, "Invalid: self join when there is no permissions");
    BT bt;
    auto zero_block_without_external =
        BB().with_previous_block(minus_one_block)
            .with_group_state({{1, 1, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}}, true, false, 0)
            .with_shared_key({1}, true, false)
            .skip_group_state_proof()
            .skip_shared_key_proof()
            .build(alice_pk);
    TEST_TRY_STATUS(bt.expect_ok(zero_block_without_external));
    auto block =
        BB().with_previous_block(zero_block_without_external)
            .with_group_state(
                {{1, 1, alice_pk.to_public_key()}, {2, 2, bob_pk.to_public_key()}, {3, 0, carol_pk.to_public_key()}},
                true, false)
            .with_shared_key({1, 2, 3}, true, false)
            .skip_group_state_proof()
            .skip_shared_key_proof()
            .build(carol_pk);
    TEST_TRY_STATUS(bt.expect_error(E::InvalidBlock_NoPermissions, block));
  }
  // TODO(now): we should rethink how permission works
  // 1. Who may set shared key?
  // 2. Who may rewrite group state with the **same** state?
  return td::Status::OK();
}
