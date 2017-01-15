CMAKE_MINIMUM_REQUIRED(VERSION 2.8 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.8)

FIND_LIBRARY(Readline REQUIRED)
FIND_PACKAGE(Torch REQUIRED)

INCLUDE_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}")
INCLUDE_DIRECTORIES("${LUA_INCDIR}")
LINK_DIRECTORIES("${LUA_LIBDIR}")
LINK_DIRECTORIES("${LIBDIR}")

# TODO
INCLUDE(CheckIncludeFiles)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckLibraryExists)

SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

# Check system packages to be installed
IF (UNIX OR NOT WIN32)
  CHECK_INCLUDE_FILES(stdlib.h HAVE_STDLIB_H)
ENDIF (UNIX OR NOT WIN32)

CONFIGURE_FILE("utils.c" "${CMAKE_CURRENT_SOURCE_DIR}/treplutils.c")
# C source files
SET(src 
  "${CMAKE_CURRENT_SOURCE_DIR}/readline.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/treplutils.c" )

# LUA source files
SET(luasrc 
  "${CMAKE_CURRENT_SOURCE_DIR}/init.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/colorize.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/colors.lua" )

# Th executable script -> CLI for Torch
SET(scriptsrc
    "${CMAKE_CURRENT_SOURCE_DIR}/th")

# When using MSVC
IF(MSVC)
  # we want to respect the standard, and we are bored of those **** .
  ADD_DEFINITIONS(-D_CRT_SECURE_NO_DEPRECATE=1)
ENDIF(MSVC)

ADD_LIBRARY("treplutils" SHARED ${src})

# OUTPUT_NAME "treplutils"
# We would like to rename util.c to treputils.so after compilation and without prefix lib
SET_TARGET_PROPERTIES("treplutils" PROPERTIES
  PREFIX ""
  IMPORT_PREFIX "lib" )

# Apple related stuff
IF(APPLE)
  SET_TARGET_PROPERTIES("treplutils" PROPERTIES
    LINK_FLAGS "-undefined dynamic_lookup")
ENDIF()

# Install LUA source files
INSTALL(FILES ${luasrc} DESTINATION ${LUADIR}/trepl)
# Install compiled C libraries
INSTALL(TARGETS treplutils LIBRARY DESTINATION ${LUA_LIBDIR} )
IF(LUALIB)
  TARGET_LINK_LIBRARIES(treplutils ${LUALIB} readline)
ENDIF()
# Install cli script
INSTALL(PROGRAMS ${scriptsrc} DESTINATION ${LUA_BINDIR})