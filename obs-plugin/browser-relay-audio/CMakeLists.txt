cmake_minimum_required(VERSION 3.24)

project(browser-relay-audio VERSION 0.1.0 LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "browser-relay-audio currently targets Windows OBS builds only.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(BRS_OBS_SDK_ROOT "" CACHE PATH "Path to the OBS Studio source checkout root")
set(BRS_OBS_CONFIG_DIR "" CACHE PATH "Path to generated obs-config.h directory")
set(BRS_OBS_IMPORT_LIB "" CACHE FILEPATH "Path to an import library for obs.dll")

if(BRS_OBS_SDK_ROOT AND BRS_OBS_CONFIG_DIR AND BRS_OBS_IMPORT_LIB)
  add_library(obs SHARED IMPORTED)
  set_target_properties(obs PROPERTIES IMPORTED_IMPLIB "${BRS_OBS_IMPORT_LIB}")
else()
  find_package(libobs REQUIRED)
endif()

add_library(browser-relay-audio MODULE src/plugin-main.cpp)
if(BRS_OBS_SDK_ROOT AND BRS_OBS_CONFIG_DIR AND BRS_OBS_IMPORT_LIB)
  target_include_directories(
    browser-relay-audio
    PRIVATE
      "${BRS_OBS_CONFIG_DIR}"
      "${BRS_OBS_SDK_ROOT}/libobs"
  )
  target_link_libraries(browser-relay-audio PRIVATE obs ws2_32)
else()
  target_link_libraries(browser-relay-audio PRIVATE OBS::libobs ws2_32)
endif()
target_compile_features(browser-relay-audio PRIVATE cxx_std_17)
target_compile_definitions(browser-relay-audio PRIVATE UNICODE _UNICODE)

set_target_properties(browser-relay-audio PROPERTIES PREFIX "")

install(
  TARGETS browser-relay-audio
  RUNTIME DESTINATION obs-plugins/64bit
  LIBRARY DESTINATION obs-plugins/64bit
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data")
  install(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/data/"
    DESTINATION data/obs-plugins/browser-relay-audio
  )
endif()
