
cmake_minimum_required(VERSION 2.8.8)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR})

project(GLUON_CONTROLLER C)

set_property(DIRECTORY PROPERTY COMPILE_DEFINITIONS _GNU_SOURCE)

find_path(UBOX_INCLUDE_DIR NAMES libubox/uloop.h)
find_library(UBOX_LIBRARY NAMES ubox)
find_library(UCLIENT_LIBRARY NAMES uclient)

find_library(UCI_LIBRARY NAMES uci)

find_package(JSON_C REQUIRED)
find_package(PkgConfig REQUIRED QUIET)

include_directories(${UBOX_INCLUDE_DIR})

add_executable(gluon-controller-update-nodes
  main.c
  uclient.c
)
set_property(TARGET gluon-controller-update-nodes PROPERTY COMPILE_FLAGS "-std=c99 -Wall ${JSON_C_CFLAGS_OTHER}")
#set_property(TARGET gluon-controller-update-nodes PROPERTY LINK_FLAGS "${JSON_C_LDFLAGS_OTHER}")
target_link_libraries(gluon-controller-update-nodes
    m
    ${UCI_LIBRARY}
    ${UBOX_LIBRARY}
    ${UCLIENT_LIBRARY}
	${JSON_C_LDFLAGS_OTHER}
	${JSON_C_LIBRARIES}
)
set_property(TARGET gluon-controller-update-nodes APPEND PROPERTY INCLUDE_DIRECTORIES ${JSON_C_INCLUDE_DIR})

install(TARGETS gluon-controller-update-nodes RUNTIME DESTINATION bin)
