if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

option(TDE2E_ENABLE_INSTALL "Enable installation of the library." ON)

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR "lib")
endif()

set_source_files_properties(${TL_E2E_AUTO_SOURCE} PROPERTIES GENERATED TRUE)

set(TDE2E_SOURCE
  td/e2e/bip39.cpp
  td/e2e/BitString.cpp
  td/e2e/Blockchain.cpp
  td/e2e/Call.cpp
  td/e2e/CheckSharedSecret.cpp
  td/e2e/DecryptedKey.cpp
  td/e2e/e2e_api.cpp
  td/e2e/EncryptedKey.cpp
  td/e2e/EncryptedStorage.cpp
  td/e2e/Keys.cpp
  td/e2e/MessageEncryption.cpp
  td/e2e/Mnemonic.cpp
  td/e2e/QRHandshake.cpp
  td/e2e/Trie.cpp

  td/e2e/bip39.h
  td/e2e/BitString.h
  td/e2e/Blockchain.h
  td/e2e/Call.h
  td/e2e/CheckSharedSecret.h
  td/e2e/Container.h
  td/e2e/DecryptedKey.h
  td/e2e/e2e_api.h
  td/e2e/e2e_errors.h
  td/e2e/EncryptedKey.h
  td/e2e/EncryptedStorage.h
  td/e2e/Keys.h
  td/e2e/MessageEncryption.h
  td/e2e/Mnemonic.h
  td/e2e/QRHandshake.h
  td/e2e/Trie.h
  td/e2e/utils.h

  ${TL_E2E_AUTO_SOURCE}

  ../td/tl/TlObject.h
  ../td/tl/tl_object_parse.h
  ../td/tl/tl_object_store.h
)

set(TDE2E_TEST_SOURCE
        ${CMAKE_CURRENT_SOURCE_DIR}/td/e2e/TestBlockchain.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/td/e2e/TestBlockchain.h
        ${CMAKE_CURRENT_SOURCE_DIR}/test/blockchain.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/test/e2e.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/test/encryption.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/test/EncryptionTestVectors.h
)

set(TDE2E_TEST_SOURCE "${TDE2E_TEST_SOURCE}" PARENT_SCOPE)

add_library(tde2e STATIC ${TDE2E_SOURCE})
if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tde2e tl_generate_common)
endif()
target_link_libraries(tde2e PUBLIC tdutils PRIVATE ${OPENSSL_CRYPTO_LIBRARY} ${CMAKE_DL_LIBS} ${ZLIB_LIBRARIES})
target_include_directories(tde2e SYSTEM PRIVATE $<BUILD_INTERFACE:${OPENSSL_INCLUDE_DIR}>)
target_include_directories(tde2e PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>/..)
target_include_directories(tde2e PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_include_directories(tde2e PUBLIC $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)

add_executable(test-e2e EXCLUDE_FROM_ALL
  ${TDE2E_TEST_SOURCE}
  ../test/main.cpp)
target_link_libraries(test-e2e PRIVATE tde2e)


if (TDE2E_ENABLE_INSTALL)
  install(TARGETS tde2e EXPORT TdStaticTargets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  )
endif()
