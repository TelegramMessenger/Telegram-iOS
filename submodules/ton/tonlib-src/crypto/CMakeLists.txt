cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

if (NOT OPENSSL_FOUND)
  find_package(OpenSSL REQUIRED)
endif()

set(TON_CRYPTO_SOURCE
  Ed25519.cpp
  common/bigint.cpp
  common/refcnt.cpp
  common/refint.cpp
  common/bigexp.cpp
  common/bitstring.cpp
  common/util.cpp
  ellcurve/Ed25519.cpp
  ellcurve/Fp25519.cpp
  ellcurve/Montgomery.cpp
  ellcurve/TwEdwards.cpp
  openssl/bignum.cpp
  openssl/residue.cpp
  openssl/rand.cpp
  vm/stack.cpp
  vm/atom.cpp
  vm/continuation.cpp
  vm/dict.cpp
  vm/memo.cpp
  vm/dispatch.cpp
  vm/opctable.cpp
  vm/cp0.cpp
  vm/stackops.cpp
  vm/tupleops.cpp
  vm/arithops.cpp
  vm/cellops.cpp
  vm/contops.cpp
  vm/dictops.cpp
  vm/debugops.cpp
  vm/tonops.cpp
  vm/boc.cpp
  vm/utils.cpp
  vm/vm.cpp
  tl/tlblib.cpp

  Ed25519.h
  common/AtomicRef.h
  common/bigint.hpp
  common/bitstring.h
  common/refcnt.hpp
  common/refint.h
  common/bigexp.h
  common/util.h
  common/linalloc.hpp

  ellcurve/Ed25519.h
  ellcurve/Fp25519.h
  ellcurve/Montgomery.h
  ellcurve/TwEdwards.h

  openssl/bignum.h
  openssl/digest.hpp
  openssl/rand.hpp
  openssl/residue.h

  tl/tlbc-aux.h
  tl/tlbc-data.h
  tl/tlblib.hpp

  vm/arithops.h
  vm/atom.h
  vm/boc.h
  vm/box.hpp
  vm/cellops.h
  vm/continuation.h
  vm/contops.h
  vm/cp0.h
  vm/debugops.h
  vm/dict.h
  vm/dictops.h
  vm/excno.hpp
  vm/fmt.hpp
  vm/log.h
  vm/memo.h
  vm/opctable.h
  vm/stack.hpp
  vm/stackops.h
  vm/tupleops.h
  vm/tonops.h
  vm/vmstate.h
  vm/utils.h
  vm/vm.h

  vm/cells.h
  vm/cellslice.h

  vm/cells/Cell.cpp
  vm/cells/CellBuilder.cpp
  vm/cells/CellHash.cpp
  vm/cells/CellSlice.cpp
  vm/cells/CellString.cpp
  vm/cells/CellTraits.cpp
  vm/cells/CellUsageTree.cpp
  vm/cells/DataCell.cpp
  vm/cells/LevelMask.cpp
  vm/cells/MerkleProof.cpp
  vm/cells/MerkleUpdate.cpp

  vm/cells/Cell.h
  vm/cells/CellBuilder.h
  vm/cells/CellHash.h
  vm/cells/CellSlice.h
  vm/cells/CellString.h
  vm/cells/CellTraits.h
  vm/cells/CellUsageTree.h
  vm/cells/CellWithStorage.h
  vm/cells/DataCell.h
  vm/cells/ExtCell.h
  vm/cells/LevelMask.h
  vm/cells/MerkleProof.h
  vm/cells/MerkleUpdate.h
  vm/cells/PrunnedCell.h
  vm/cells/UsageCell.h
  vm/cells/VirtualCell.h
  vm/cells/VirtualizationParameters.h

  vm/db/StaticBagOfCellsDb.h
  vm/db/StaticBagOfCellsDb.cpp

  vm/db/BlobView.h
  vm/db/BlobView.cpp
)

set(TON_DB_SOURCE
  vm/db/DynamicBagOfCellsDb.cpp
  vm/db/CellStorage.cpp
  vm/db/TonDb.cpp

  vm/db/DynamicBagOfCellsDb.h
  vm/db/CellHashTable.h
  vm/db/CellStorage.h
  vm/db/TonDb.h
)

set(FIFT_SOURCE
  fift/Dictionary.cpp
  fift/Fift.cpp
  fift/IntCtx.cpp
  fift/SourceLookup.cpp
  fift/utils.cpp
  fift/words.cpp

  fift/Dictionary.h
  fift/Fift.h
  fift/IntCtx.h
  fift/SourceLookup.h
  fift/utils.h
  fift/words.h
)

set(PARSER_SOURCE
  parser/srcread.cpp
  parser/lexer.cpp
  parser/symtable.cpp

  parser/srcread.h
  parser/lexer.h
  parser/symtable.h
)

set(FUNC_LIB_SOURCE
  func/keywords.cpp
  func/unify-types.cpp
  func/parse-func.cpp
  func/abscode.cpp
  func/gen-abscode.cpp
  func/analyzer.cpp
  func/asmops.cpp
  func/builtins.cpp
  func/stack-transform.cpp
  func/optimize.cpp
  func/codegen.cpp
)

set(TLB_BLOCK_AUTO
  ${CMAKE_CURRENT_SOURCE_DIR}/block/block-auto.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/block/block-auto.h
)

set(BLOCK_SOURCE
  block/Binlog.h
  block/Binlog.cpp
  block/block.cpp
  block/block-db.cpp
  block/block-parse.cpp
  block/check-proof.cpp
  block/mc-config.cpp
  block/output-queue-merger.cpp
  block/transaction.cpp
  ${TLB_BLOCK_AUTO}

  block/block-binlog.h
  block/block-db-impl.h
  block/block-db.h
  block/block.h
  block/block-parse.h
  block/check-proof.h
  block/output-queue-merger.h
  block/transaction.h
)

set(SMC_ENVELOPE_SOURCE
  smc-envelope/GenericAccount.cpp
  smc-envelope/HighloadWallet.cpp
  smc-envelope/HighloadWalletV2.cpp
  smc-envelope/ManualDns.cpp
  smc-envelope/MultisigWallet.cpp
  smc-envelope/SmartContract.cpp
  smc-envelope/SmartContractCode.cpp
  smc-envelope/TestGiver.cpp
  smc-envelope/TestWallet.cpp
  smc-envelope/Wallet.cpp
  smc-envelope/WalletV3.cpp

  smc-envelope/GenericAccount.h
  smc-envelope/HighloadWallet.h
  smc-envelope/HighloadWalletV2.h
  smc-envelope/ManualDns.h
  smc-envelope/MultisigWallet.h
  smc-envelope/SmartContract.h
  smc-envelope/SmartContractCode.h
  smc-envelope/TestGiver.h
  smc-envelope/TestWallet.h
  smc-envelope/Wallet.h
  smc-envelope/WalletInterface.h
  smc-envelope/WalletV3.h
)

set(ED25519_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/Ed25519.cpp
  PARENT_SCOPE
)

set(TONDB_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/test-db.cpp
  PARENT_SCOPE
)

set(CELLS_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/test-cells.cpp
  PARENT_SCOPE
)

set(TONVM_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/vm.cpp
  PARENT_SCOPE
)

set(SMARTCONT_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/test-smartcont.cpp
  PARENT_SCOPE
)

set(FIFT_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/fift.cpp
  PARENT_SCOPE
)

add_library(ton_crypto STATIC ${TON_CRYPTO_SOURCE})
target_include_directories(ton_crypto PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(ton_crypto PUBLIC ${OPENSSL_CRYPTO_LIBRARY} tdutils)
if (NOT WIN32)
  target_link_libraries(ton_crypto PUBLIC dl z)
endif()
target_include_directories(ton_crypto SYSTEM PUBLIC $<BUILD_INTERFACE:${OPENSSL_INCLUDE_DIR}>)

add_library(ton_db STATIC ${TON_DB_SOURCE})
target_include_directories(ton_db PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(ton_db PUBLIC tdutils tddb ton_crypto)

add_executable(test-ed25519-crypto test/test-ed25519-crypto.cpp)
target_include_directories(test-ed25519-crypto PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(test-ed25519-crypto PUBLIC ton_crypto)

add_library(fift-lib ${FIFT_SOURCE})
target_include_directories(fift-lib PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(fift-lib PUBLIC ton_crypto ton_db tdutils ton_block)
set_target_properties(fift-lib PROPERTIES OUTPUT_NAME fift)

add_executable(fift fift/fift-main.cpp)
target_link_libraries(fift PUBLIC fift-lib)
if (WINGETOPT_FOUND)
  target_link_libraries_system(fift wingetopt)
endif()

add_library(src_parser ${PARSER_SOURCE})
target_include_directories(src_parser PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(src_parser PUBLIC ton_crypto)

add_executable(func func/func.cpp ${FUNC_LIB_SOURCE})
target_include_directories(func PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(func PUBLIC ton_crypto src_parser)
if (WINGETOPT_FOUND)
  target_link_libraries_system(func wingetopt)
endif()

add_executable(tlbc tl/tlbc.cpp)
target_include_directories(tlbc PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tlbc PUBLIC ton_crypto src_parser)
if (WINGETOPT_FOUND)
  target_link_libraries_system(tlbc wingetopt)
endif()

add_library(ton_block ${BLOCK_SOURCE})
target_include_directories(ton_block PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/block> $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(ton_block PUBLIC ton_crypto tdutils tdactor tl_api)

set(TURN_OFF_LSAN cd .)
if (TON_USE_ASAN AND NOT WIN32)
  set(TURN_OFF_LSAN export LSAN_OPTIONS=detect_leaks=0)
endif()

file(MAKE_DIRECTORY smartcont/auto)
if (NOT CMAKE_CROSSCOMPILING)
  set(GENERATE_TLB_CMD tlbc)
  add_custom_command(
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/block
    COMMAND ${TURN_OFF_LSAN}
    COMMAND ${GENERATE_TLB_CMD} -o block-auto -n block::gen -z block.tlb
    COMMENT "Generate block tlb source files"
    OUTPUT ${TLB_BLOCK_AUTO}
    DEPENDS tlbc block/block.tlb
  )
  add_custom_target(tlb_generate_block DEPENDS ${TLB_BLOCK_AUTO})
  add_dependencies(ton_block tlb_generate_block)

  add_custom_target(gen_fif ALL)
  function(GenFif)
    set(options )
    set(oneValueArgs DEST NAME)
    set(multiValueArgs SOURCE)
    set(FUNC_LIB_SOURCE smartcont/stdlib.fc)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )
    string(REGEX REPLACE "[^a-zA-Z_]" "_" ID ${ARG_DEST})
    set(ARG_DEST_FIF "${ARG_DEST}.fif")
    add_custom_command(
      COMMENT "Generate ${ARG_DEST_FIF}"
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMAND func -PS -o ${ARG_DEST_FIF} ${FUNC_LIB_SOURCE} ${ARG_SOURCE}
      MAIN_DEPENDENCY ${ARG_SOURCE}
      DEPENDS func ${FUNC_LIB_SOURCE}
      OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/${ARG_DEST_FIF}
    )
    set(ARG_DEST_CPP "${ARG_DEST}.cpp")
    add_custom_command(
      COMMENT "Generate ${ARG_DEST_CPP}"
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMAND fift -Ifift/lib:smartcont -s asm-to-cpp.fif ${ARG_DEST_FIF} ${ARG_DEST_CPP} ${ARG_NAME}
      MAIN_DEPENDENCY ${ARG_SOURCE}
      DEPENDS fift ${ARG_DEST_FIF} smartcont/asm-to-cpp.fif fift/lib/Asm.fif
      OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/${ARG_DEST_CPP}
    )
    add_custom_target(gen_fif_${ID} DEPENDS ${ARG_DEST_FIF} ${ARG_DEST_CPP})
    add_dependencies(gen_fif gen_fif_${ID})
  endfunction()

  GenFif(DEST smartcont/auto/config-code SOURCE smartcont/config-code.fc NAME config)
  GenFif(DEST smartcont/auto/wallet-code SOURCE smartcont/wallet-code.fc NAME wallet)
  GenFif(DEST smartcont/auto/wallet3-code SOURCE smartcont/wallet3-code.fc NAME wallet3)
  GenFif(DEST smartcont/auto/simple-wallet-code SOURCE smartcont/simple-wallet-code.fc NAME simple-wallet)
  GenFif(DEST smartcont/auto/highload-wallet-code SOURCE smartcont/highload-wallet-code.fc NAME highload-wallet)
  GenFif(DEST smartcont/auto/highload-wallet-v2-code SOURCE smartcont/highload-wallet-v2-code.fc NAME highload-wallet-v2)
  GenFif(DEST smartcont/auto/elector-code SOURCE smartcont/elector-code.fc NAME elector-code)
  GenFif(DEST smartcont/auto/multisig-code SOURCE smartcont/multisig-code.fc NAME multisig)
  GenFif(DEST smartcont/auto/restricted-wallet-code SOURCE smartcont/restricted-wallet-code.fc NAME restricted-wallet)
  GenFif(DEST smartcont/auto/restricted-wallet2-code SOURCE smartcont/restricted-wallet2-code.fc NAME restricted-wallet2)

  GenFif(DEST smartcont/auto/dns-manual-code SOURCE smartcont/dns-manual-code.fc NAME dns-manual)
  GenFif(DEST smartcont/auto/dns-auto-code SOURCE smartcont/dns-auto-code.fc NAME dns-auto)

  GenFif(DEST smartcont/auto/simple-wallet-ext-code SOURCE smartcont/simple-wallet-ext-code.fc NAME simple-wallet-ext)
endif()

add_library(smc-envelope ${SMC_ENVELOPE_SOURCE})
target_include_directories(smc-envelope PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(smc-envelope PUBLIC ton_crypto PRIVATE tdutils ton_block)
if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(smc-envelope gen_fif)
endif()

add_executable(create-state block/create-state.cpp)
target_include_directories(create-state PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
if (INTERNAL_COMPILE)
  target_link_libraries(create-state PUBLIC ton_crypto fift-lib ton_block tonlib)
else()
  if (TONLIB_COMPILE) 
    target_link_libraries(create-state PUBLIC ton_crypto fift-lib ton_block tonlib)
  else()
    target_link_libraries(create-state PUBLIC ton_crypto fift-lib ton_block)
  endif()
endif()
if (WINGETOPT_FOUND)
  target_link_libraries_system(create-state wingetopt)
endif()

add_executable(dump-block block/dump-block.cpp)
target_include_directories(dump-block PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(dump-block PUBLIC ton_crypto fift-lib ton_block)
if (WINGETOPT_FOUND)
  target_link_libraries_system(dump-block wingetopt)
endif()

add_executable(adjust-block block/adjust-block.cpp)
target_include_directories(adjust-block PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(adjust-block PUBLIC ton_crypto fift-lib ton_block)
if (WINGETOPT_FOUND)
  target_link_libraries_system(dump-block wingetopt)
endif()

install(TARGETS fift func RUNTIME DESTINATION bin)
install(DIRECTORY fift/lib/ DESTINATION lib/fift)
