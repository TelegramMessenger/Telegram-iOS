cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)


set(ADNL_LITE_SOURCE
  adnl-ext-client.cpp
  adnl-ext-connection.cpp
  adnl-query.cpp

  ${ADNL_LITE_HEADERS}
)


add_library(adnllite STATIC ${ADNL_LITE_SOURCE})

target_include_directories(adnllite PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(adnllite PUBLIC tdactor ton_crypto tl_lite_api tdnet keys )
