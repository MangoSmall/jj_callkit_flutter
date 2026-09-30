package com.jj.jj_callkit

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.useasy.callsdk.CallSDK
import com.useasy.callsdk.bean.AgentConfig
import com.useasy.callsdk.bean.CallInfo
import com.useasy.callsdk.bean.CallState
import com.useasy.callsdk.bean.DisplayNumber
import com.useasy.callsdk.bean.NumberGroup
import com.useasy.callsdk.bean.NumberGroupListResponse
import com.useasy.callsdk.config.Environment
import com.useasy.callsdk.config.LogConfig
import com.useasy.callsdk.config.SDKConfig
import com.useasy.callsdk.listener.AgentConfigListener
import com.useasy.callsdk.listener.CallStateListener
import com.useasy.callsdk.listener.DisplayNumberListListener
import com.useasy.callsdk.listener.InitListener
import com.useasy.callsdk.listener.MakeCallCallback
import com.useasy.callsdk.listener.NumberGroupListListener
import com.useasy.callsdk.utils.AudioRoute
import com.useasy.callsdk.utils.AudioRouteChangeListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class JjCallkitPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var appContext: Context? = null
    private var pendingInit: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val callStateListener = object : CallStateListener {
        override fun onCallCalling(callInfo: CallInfo) {
            emit("callCalling", callInfoMap(callInfo))
        }

        override fun onCallAlerting(callInfo: CallInfo) {
            emit("callAlerting", callInfoMap(callInfo))
        }

        override fun onCallAnswered(callInfo: CallInfo) {
            emit("callAnswered", callInfoMap(callInfo))
        }

        override fun onCallReleased(callInfo: CallInfo, hangupType: Int) {
            emit("callReleased", callInfoMap(callInfo) + mapOf("hangupType" to hangupType))
        }

        override fun onCallFailed(callInfo: CallInfo, errorCode: Int, errorMsg: String) {
            emit(
                "callFailed",
                callInfoMap(callInfo) + mapOf(
                    "errorCode" to errorCode,
                    "errorMsg" to errorMsg,
                ),
            )
        }

        override fun onDtmfReceived(callInfo: CallInfo, dtmf: String) {
            emit("dtmfReceived", callInfoMap(callInfo) + mapOf("dtmf" to dtmf))
        }
    }

    private val audioRouteChangeListener = object : AudioRouteChangeListener {
        override fun onAudioRouteChanged(route: AudioRoute) {
            emit("audioRouteChanged", mapOf("route" to routeName(route)))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        val messenger = binding.binaryMessenger
        methodChannel = MethodChannel(messenger, "com.jj/callkit/methods")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(messenger, "com.jj/callkit/events")
        eventChannel.setStreamHandler(this)
        registerPersistentListeners()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        CallSDK.removeCallStateListener(callStateListener)
        CallSDK.setOnServerCallListener(null)
        CallSDK.setOnKickedListener(null)
        CallSDK.setOnSipDisconnectedListener(null)
        CallSDK.setAudioRouteChangeListener(null)
        // 热重载会拆 Engine，这里不要 CallSDK.release()。
        // 下次 onAttachedToEngine → registerPersistentListeners 会重新挂监听。
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "logout" -> {
                CallSDK.logout()
                result.success(null)
            }
            "release" -> {
                CallSDK.removeCallStateListener(callStateListener)
                CallSDK.setOnServerCallListener(null)
                CallSDK.setOnKickedListener(null)
                CallSDK.setOnSipDisconnectedListener(null)
                CallSDK.setAudioRouteChangeListener(null)
                CallSDK.release()
                result.success(null)
            }
            "makeCall" -> handleMakeCall(call, result)
            "hangupCall" -> {
                CallSDK.hangupCall()
                result.success(null)
            }
            "setMute" -> {
                CallSDK.openMute(call.argument<Boolean>("enabled") == true)
                result.success(null)
            }
            "isMuted" -> result.success(CallSDK.isMuteOn())
            "setSpeaker" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                CallSDK.openLoudSpeaker(enabled)
                emit("audioRouteChanged", mapOf("route" to routeName(CallSDK.getCurrentAudioRoute())))
                result.success(null)
            }
            "isSpeakerOn" -> result.success(CallSDK.isLoudSpeakerOn())
            "getCurrentAudioRoute" -> {
                result.success(routeName(CallSDK.getCurrentAudioRoute()))
            }
            "sendDTMF" -> {
                CallSDK.sendDTMF(call.argument<String>("digit").orEmpty())
                result.success(null)
            }
            "getCurrentCallInfo" -> result.success(CallSDK.getCurrentCallInfo()?.let { callInfoMap(it) })
            "canMakeCall" -> result.success(canMakeCall())
            "getLoginInfo" -> result.success(loginInfoMap())
            "getAgentConfig" -> handleAgentConfig(result)
            "getDisplayNumberList" -> handleDisplayNumbers(result)
            "getNumberGroupList" -> handleNumberGroups(call, result)
            "updateDisplayNumber" -> handleUpdateNumber(call, result)
            "updateNumberGroup" -> handleUpdateGroup(call, result)
            else -> result.notImplemented()
        }
    }

    private fun canMakeCall(): Boolean {
        if (CallSDK.getLoginInfo() == null) return false
        val current = CallSDK.getCurrentCallInfo() ?: return true
        return current.state == CallState.RELEASED || current.state == CallState.FAILED
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        if (pendingInit != null) {
            result.error("-1", "init 正在进行", null)
            return
        }
        val ctx = appContext
        if (ctx == null) {
            result.error("-1", "context 为空", null)
            return
        }
        val username = call.argument<String>("username").orEmpty()
        val password = call.argument<String>("password")
        val passwordPk = call.argument<String>("passwordPk")
        val environment = call.argument<String>("environment") ?: "production"
        val log = call.argument<Map<String, Any?>>("logConfig")
        val config = SDKConfig(
            username = username,
            password = password,
            baseUrl = if (environment == "debug") Environment.DEBUG else Environment.PRODUCTION,
            logConfig = LogConfig(
                enableLog = log?.get("enableLog") as? Boolean ?: false,
                logLevel = androidLogLevel(log?.get("logLevel") as? Int),
                logFilePath = log?.get("logFilePath") as? String,
                fileLoggingEnabled = log?.get("fileLoggingEnabled") as? Boolean ?: false,
                consoleLogEnabled = log?.get("consoleLogEnabled") as? Boolean ?: false,
            ),
            passwordPk = passwordPk,
        )
        pendingInit = result
        registerPersistentListeners()
        CallSDK.init(
            ctx,
            config,
            object : InitListener {
                override fun onInitSuccess() {
                    emit("sipConnected", emptyMap())
                    val pending = pendingInit
                    pendingInit = null
                    pending?.success(null)
                }

                override fun onInitFailed(errorCode: Int, errorMsg: String?) {
                    emit(
                        "sipConnectFailed",
                        mapOf("errorCode" to errorCode, "errorMsg" to (errorMsg ?: "")),
                    )
                    val pending = pendingInit
                    pendingInit = null
                    pending?.error(errorCode.toString(), errorMsg, null)
                }
            },
        )
    }

    private fun registerPersistentListeners() {
        CallSDK.removeCallStateListener(callStateListener)
        CallSDK.addCallStateListener(callStateListener)
        CallSDK.setOnServerCallListener { info ->
            emit("serverCall", callInfoMap(info))
        }
        CallSDK.setOnKickedListener {
            emit("kicked", emptyMap())
        }
        CallSDK.setOnSipDisconnectedListener {
            emit("sipDisconnected", emptyMap())
        }
        CallSDK.setAudioRouteChangeListener(audioRouteChangeListener)
    }

    private fun routeName(route: AudioRoute): String = when (route) {
        AudioRoute.SPEAKER -> "speaker"
        AudioRoute.BLUETOOTH -> "bluetooth"
        AudioRoute.RECEIVER -> "receiver"
    }

    private fun handleMakeCall(call: MethodCall, result: MethodChannel.Result) {
        if (CallSDK.getLoginInfo() == null) {
            result.error("-302", "未登录无法呼叫", null)
            return
        }
        val ctx = appContext
        if (ctx != null &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("-301", "通话权限被拒绝", null)
            return
        }
        val phone = call.argument<String>("phoneNumber").orEmpty()
        val userData = call.argument<Map<String, Any?>>("userData")
        var replied = false
        val callback = object : MakeCallCallback {
            override fun onSuccess(callInfo: CallInfo) {
                if (replied) return
                replied = true
                mainHandler.post { result.success(callInfoMap(callInfo)) }
            }

            override fun onFailed(errorCode: Int, errorMsg: String) {
                if (replied) return
                replied = true
                mainHandler.post { result.error(errorCode.toString(), errorMsg, null) }
            }
        }
        if (userData.isNullOrEmpty()) {
            CallSDK.makeCall(phone, callback)
        } else {
            CallSDK.makeCall(phone, JSONObject(userData), callback)
        }
    }

    private fun handleAgentConfig(result: MethodChannel.Result) {
        CallSDK.getAgentConfig(object : AgentConfigListener {
            override fun onSuccess(config: AgentConfig?) {
                mainHandler.post { result.success(agentConfigMap(config)) }
            }

            override fun onFailed(errorMsg: String?) {
                mainHandler.post { result.error("-4002", errorMsg, null) }
            }
        })
    }

    private fun handleDisplayNumbers(result: MethodChannel.Result) {
        CallSDK.queryDisplayNumberList(object : DisplayNumberListListener {
            override fun onSuccess(numbers: List<DisplayNumber>?) {
                mainHandler.post {
                    result.success(numbers.orEmpty().map { displayNumberMap(it) })
                }
            }

            override fun onFailed(errorMsg: String?) {
                mainHandler.post { result.error("-4002", errorMsg, null) }
            }
        })
    }

    private fun handleNumberGroups(call: MethodCall, result: MethodChannel.Result) {
        val page = call.argument<Int>("page") ?: 1
        val pageSize = call.argument<Int>("pageSize") ?: 20
        CallSDK.queryNumberGroupList(page, pageSize, object : NumberGroupListListener {
            override fun onSuccess(response: NumberGroupListResponse?) {
                val pageInfo = response?.page
                mainHandler.post {
                    result.success(
                        mapOf(
                            "list" to response?.list.orEmpty().map { numberGroupMap(it) },
                            "pageInfo" to mapOf(
                                "pageSize" to pageInfo?.pageSize,
                                "pageNumber" to pageInfo?.pageNumber,
                                "totalPage" to pageInfo?.totalPage,
                                "total" to pageInfo?.total,
                            ),
                        ),
                    )
                }
            }

            override fun onFailed(errorMsg: String?) {
                mainHandler.post { result.error("-4002", errorMsg, null) }
            }
        })
    }

    private fun handleUpdateNumber(call: MethodCall, result: MethodChannel.Result) {
        val number = call.argument<String>("selectNumber").orEmpty()
        CallSDK.updateAgentSelectNumber(number, configListener(result))
    }

    private fun handleUpdateGroup(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val name = call.argument<String>("name")
        val listener = configListener(result)
        when {
            !id.isNullOrEmpty() -> CallSDK.updateAgentNumberGroupById(id, listener)
            !name.isNullOrEmpty() -> CallSDK.updateAgentNumberGroupByName(name, listener)
            else -> result.error("-4002", "号码组 id 和 name 都为空", null)
        }
    }

    private fun configListener(result: MethodChannel.Result) = object : AgentConfigListener {
        override fun onSuccess(config: AgentConfig?) {
            mainHandler.post { result.success(null) }
        }

        override fun onFailed(errorMsg: String?) {
            mainHandler.post { result.error("-4002", errorMsg, null) }
        }
    }

    private fun loginInfoMap(): Map<String, Any?>? {
        val info = CallSDK.getLoginInfo() ?: return null
        return mapOf(
            "agentId" to info.agent?._id,
            "mobile" to info.agent?.mobile,
            "agentNumber" to info.agent?.agentNumber,
            "accountId" to info.account?._id,
        )
    }

    private fun callInfoMap(info: CallInfo): Map<String, Any?> = mapOf(
        "callId" to info.callId,
        "phoneNumber" to info.phoneNumber,
        "direction" to info.direction.name.lowercase(),
        "state" to info.state.name.lowercase(),
        "startTime" to info.startTime,
    )

    private fun agentConfigMap(config: AgentConfig?): Map<String, Any?> {
        val call = config?.agentCallConfig
        return mapOf(
            "id" to config?._id,
            "agentName" to config?.agentName,
            "mobile" to config?.mobile,
            "agentNumber" to config?.agentNumber,
            "callerStrategy" to (call?.callerStrategy ?: emptyList<String>()),
            "selectNumber" to call?.selectNumber,
            "numberGroup" to call?.numberGroup,
            "sipNumber" to call?.sipNumber,
            "numbers" to (call?.numbers ?: emptyList<String>()),
            "numberSelect" to call?.numberSelect,
        )
    }

    private fun displayNumberMap(item: DisplayNumber): Map<String, Any?> = mapOf(
        "id" to item.id,
        "status" to item.status,
        "number" to item.number,
        "province" to item.province,
        "city" to item.city,
    )

    private fun numberGroupMap(item: NumberGroup): Map<String, Any?> = mapOf(
        "id" to item.id,
        "groupName" to item.groupName,
        "name" to item.groupName,
        "remark" to item.remark,
    )

    private fun androidLogLevel(level: Int?): Int {
        return when (level) {
            0 -> Log.ERROR
            2 -> Log.DEBUG
            null, 1 -> Log.INFO
            else -> level
        }
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        val event = mapOf("type" to type, "payload" to payload)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink.success(event)
        } else {
            mainHandler.post { eventSink?.success(event) }
        }
    }
}
