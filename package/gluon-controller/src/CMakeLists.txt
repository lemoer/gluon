
cmake_minimum_required(VERSION 2.8.8)

project(GLUON_CONTROLLER C)

set_property(DIRECTORY PROPERTY COMPILE_DEFINITIONS _GNU_SOURCE)

find_path(UBOX_INCLUDE_DIR NAMES libubox/uloop.h)
find_library(UBOX_LIBRARY NAMES ubox)
find_library(UCLIENT_LIBRARY NAMES uclient)

find_library(UCI_LIBRARY NAMES uci)

find_package(PkgConfig REQUIRED QUIET)

include_directories(${UBOX_INCLUDE_DIR})

add_executable(gluon-controller-update-nodes
  main.c
  uclient.c
)
set_property(TARGET gluon-controller-update-nodes PROPERTY COMPILE_FLAGS "-std=c99 -Wall")
#set_property(TARGET gluon-controller-update-nodes PROPERTY LINK_FLAGS "")
target_link_libraries(gluon-controller-update-nodes
    m
    ${UCI_LIBRARY}
    ${UBOX_LIBRARY}
    ${UCLIENT_LIBRARY}
)

install(TARGETS gluon-controller-update-nodes RUNTIME DESTINATION bin)
