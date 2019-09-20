cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

set(TDNET_SOURCE
  td/net/FdListener.cpp
  td/net/TcpListener.cpp
  td/net/UdpServer.cpp

  td/net/FdListener.h
  td/net/TcpListener.h
  td/net/UdpServer.h
)

add_library(tdnet STATIC ${TDNET_SOURCE})
target_include_directories(tdnet PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(tdnet PUBLIC tdactor)

add_executable(tcp_ping_pong example/tcp_ping_pong.cpp)
target_link_libraries(tcp_ping_pong PRIVATE tdactor tdnet)

add_executable(udp_ping_pong example/udp_ping_pong.cpp)
target_link_libraries(udp_ping_pong PRIVATE tdactor tdnet)

set(NET_TEST_SOURCE
  ${CMAKE_CURRENT_SOURCE_DIR}/test/net-test.cpp
  PARENT_SCOPE
)
