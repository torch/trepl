CMAKE_MINIMUM_REQUIRED(VERSION 2.6 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.6)

FIND_PACKAGE(Torch REQUIRED)

INCLUDE_DIRECTORIES("${CMAKE_CURRENT_SOURCE_DIR}")
INCLUDE_DIRECTORIES("${LUA_INCDIR}")
LINK_DIRECTORIES("${LUA_LIBDIR}")

# TODO
INCLUDE(CheckIncludeFiles)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckLibraryExists)

# Check system packages to be installed
IF (UNIX OR NOT WIN32)
  CHECK_INCLUDE_FILES(stdlib.h HAVE_STDLIB_H)
ENDIF (UNIX OR NOT WIN32)

# C source files
SET(src 
  "${CMAKE_CURRENT_SOURCE_DIR}/readline.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/utils.c" )

# LUA source files
SET(luasrc 
  "${CMAKE_CURRENT_SOURCE_DIR}/init.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/colorize.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/colors.lua" )

# Th binary file
SET(trepl-exe
    "${CMAKE_CURRENT_SOURCE_DIR}/th")

# When using MSVC
IF(MSVC)
  # we want to respect the standard, and we are bored of those **** .
  ADD_DEFINITIONS(-D_CRT_SECURE_NO_DEPRECATE=1)
ENDIF(MSVC)

ADD_LIBRARY("trepl" MODULE ${src})

# We would like to rename util.c to treputils.so after compilation
SET_TARGET_PROPERTIES("trepl" PROPERTIES
  OUTPUT_NAME "treputils"
  PREFIX "lib"
  IMPORT_PREFIX "lib" )

# Apple related stuff
IF(APPLE)
  SET_TARGET_PROPERTIES("trepl" PROPERTIES
    LINK_FLAGS "-undefined dynamic_lookup")
ENDIF()

# Install LUA source files
INSTALL(FILES ${luasrc} DESTINATION ${LUADIR}/trepl)

INSTALL(TARGETS trepl
  LIBRARY DESTINATION ${LUA_LIBDIR} )

# TODO
#IF(LUALIB)
#  TARGET_LINK_LIBRARIES(trepl ${LUALIB})
#ENDIF()

# Copy included "binary" executable for trepl
CONFIGURE_FILE(${CMAKE_SOURCE_DIR}/th ${CMAKE_CURRENT_BINARY_DIR}/th COPYONLY)