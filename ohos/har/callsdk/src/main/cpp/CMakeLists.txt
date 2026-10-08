cmake_minimum_required(VERSION 3.5.0)
project(callsdk_entry)

# 构建 libcallsdk_entry.so（dlopen + re-export）。
# 同时把预编译 libpjsua2_ohos.so 拷到 native 输出目录，确保随 HAR/HAP 打包
# （仅放在 src/main/libs 时 HAR 依赖进 entry 后可能丢 so）。
add_library(callsdk_entry SHARED napi_stub.cpp)
target_link_libraries(callsdk_entry PRIVATE ace_napi.z hilog_ndk.z dl)

if(NOT DEFINED OHOS_ARCH OR OHOS_ARCH STREQUAL "")
  set(OHOS_ARCH "arm64-v8a")
endif()

set(PJSUA2_SO "${CMAKE_CURRENT_SOURCE_DIR}/../libs/${OHOS_ARCH}/libpjsua2_ohos.so")
if(EXISTS "${PJSUA2_SO}")
  add_custom_command(TARGET callsdk_entry POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${PJSUA2_SO}"
      "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libpjsua2_ohos.so"
    COMMENT "Copy libpjsua2_ohos.so into native output for packaging"
  )
else()
  message(WARNING "libpjsua2_ohos.so not found at ${PJSUA2_SO}")
endif()
