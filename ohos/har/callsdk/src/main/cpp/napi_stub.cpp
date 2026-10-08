/**
 * HAR 侧 libcallsdk_entry.so：
 * 1) dlopen libpjsua2_ohos.so（随 HAR 打包）
 * 2) dlsym pjsua2_ohos_module_init，把 N-API 挂到本模块 exports
 *
 * 宿主只需依赖 HAR，ArkTS 侧 import 'libcallsdk_entry.so' 即可，无需 entry 再写 cpp/bootstrap。
 */
#include <dlfcn.h>
#include <hilog/log.h>
#include <napi/native_api.h>

static constexpr unsigned int CALLSDK_LOG_DOMAIN = 0x3200;
static const char* CALLSDK_LOG_TAG = "CallSdkNative";

typedef napi_value (*Pjsua2ModuleInitFn)(napi_env env, napi_value exports);

static napi_value Init(napi_env env, napi_value exports) {
    void* handle = dlopen("libpjsua2_ohos.so", RTLD_NOW | RTLD_GLOBAL);
    if (handle == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, CALLSDK_LOG_DOMAIN, CALLSDK_LOG_TAG,
            "dlopen libpjsua2_ohos.so failed: %{public}s", dlerror());
        return exports;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, CALLSDK_LOG_DOMAIN, CALLSDK_LOG_TAG,
        "dlopen libpjsua2_ohos.so ok");

    dlerror();
    Pjsua2ModuleInitFn moduleInit =
        reinterpret_cast<Pjsua2ModuleInitFn>(dlsym(handle, "pjsua2_ohos_module_init"));
    const char* err = dlerror();
    if (err != nullptr || moduleInit == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, CALLSDK_LOG_DOMAIN, CALLSDK_LOG_TAG,
            "dlsym pjsua2_ohos_module_init failed: %{public}s",
            err != nullptr ? err : "null");
        return exports;
    }

    napi_value result = moduleInit(env, exports);
    OH_LOG_Print(LOG_APP, LOG_INFO, CALLSDK_LOG_DOMAIN, CALLSDK_LOG_TAG,
        "pjsua2 N-API re-export ok");
    return result;
}

extern "C" __attribute__((visibility("default"))) napi_value callsdk_entry_module_init(
    napi_env env, napi_value exports) {
    return Init(env, exports);
}

static napi_module g_entryModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "callsdk_entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterCallSdkEntryModule(void) {
    napi_module_register(&g_entryModule);
}
