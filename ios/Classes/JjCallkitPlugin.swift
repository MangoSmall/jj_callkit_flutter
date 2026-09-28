import Flutter
import JJCallKit

public class JjCallkitPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let manager = VoIPManager.shared()
    private var eventSink: FlutterEventSink?
    private var pendingInit: FlutterResult?
    private var observers: [NSObjectProtocol] = []
    private var seenServerCallIds = Set<String>()
    private var cachedLogin: [String: Any]?
    private var currentCall: [String: Any]?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = JjCallkitPlugin()
        let methods = FlutterMethodChannel(
            name: "com.jj/callkit/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methods)

        let events = FlutterEventChannel(
            name: "com.jj/callkit/events",
            binaryMessenger: registrar.messenger()
        )
        events.setStreamHandler(instance)
        instance.startObserving()
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        stopObserving()
        eventSink = nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "init":
            handleInit(args, result: result)
        case "logout":
            cachedLogin = nil
            currentCall = nil
            seenServerCallIds.removeAll()
            manager.logout(completion: {
                result(nil)
            })
        case "release":
            cachedLogin = nil
            currentCall = nil
            seenServerCallIds.removeAll()
            stopObserving()
            manager.cleanupSDK()
            result(nil)
        case "makeCall":
            handleMakeCall(args, result: result)
        case "hangupCall":
            manager.hangupCall()
            result(nil)
        case "setMute":
            manager.openMute((args["enabled"] as? Bool) ?? false)
            result(nil)
        case "isMuted":
            result(manager.isMuted)
        case "setSpeaker":
            let enabled = (args["enabled"] as? Bool) ?? false
            manager.openLoudSpeaker(enabled)
            emit("audioRouteChanged", ["route": enabled ? "speaker" : "receiver"])
            result(nil)
        case "isSpeakerOn":
            result(manager.isLoudSpeakerOn())
        case "getCurrentAudioRoute":
            result(manager.isLoudSpeakerOn() ? "speaker" : "receiver")
        case "sendDTMF":
            manager.sendDTMF((args["digit"] as? String) ?? "")
            result(nil)
        case "getCurrentCallInfo":
            result(currentCall)
        case "canMakeCall":
            result(manager.canMakeCall())
        case "getLoginInfo":
            result(cachedLogin)
        case "getAgentConfig":
            manager.getCallerStrategy(success: { config in
                result(Self.flutterObject(config))
            }, failure: { code, message in
                result(FlutterError(code: "\(code)", message: message, details: nil))
            })
        case "getDisplayNumberList":
            manager.getDisplayNumberList(success: { list in
                result(Self.flutterObject(list) ?? [])
            }, failure: { code, message in
                result(FlutterError(code: "\(code)", message: message, details: nil))
            })
        case "getNumberGroupList":
            manager.getDisplayNumberGroupList(success: { list in
                result([
                    "list": Self.flutterObject(list) ?? [],
                    "pageInfo": NSNull(),
                ])
            }, failure: { code, message in
                result(FlutterError(code: "\(code)", message: message, details: nil))
            })
        case "updateDisplayNumber":
            let number = args["selectNumber"] as? String
            manager.updateAgentDisplayNumber(withSelectNumber: number, numberGroup: nil, success: {
                result(nil)
            }, failure: { code, message in
                result(FlutterError(code: "\(code)", message: message, details: nil))
            })
        case "updateNumberGroup":
            guard let groupId = args["id"] as? String, !groupId.isEmpty else {
                result(FlutterError(code: "-4002", message: "iOS 设置号码组需要传 id", details: nil))
                return
            }
            manager.updateAgentDisplayNumber(withSelectNumber: nil, numberGroup: groupId, success: {
                result(nil)
            }, failure: { code, message in
                result(FlutterError(code: "\(code)", message: message, details: nil))
            })
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInit(_ args: [String: Any], result: @escaping FlutterResult) {
        if pendingInit != nil {
            result(FlutterError(code: "-1", message: "init 正在进行", details: nil))
            return
        }
        if observers.isEmpty {
            startObserving()
        }
        applyLogConfig(args["logConfig"] as? [String: Any])
        let code = manager.initial()
        if code.rawValue != 0 {
            let message = VoIPManager.errorDescription(forCode: code.rawValue)
            result(FlutterError(code: "\(code.rawValue)", message: message, details: nil))
            return
        }
        let account = args["username"] as? String ?? ""
        let password = args["password"] as? String ?? ""
        let passwordPk = args["passwordPk"] as? String
        let environment: VoIPEnvironment = (args["environment"] as? String) == "debug"
            ? .development
            : .production
        pendingInit = result
        manager.login(
            withAccount: account,
            password: password,
            environment: environment,
            passwordPk: passwordPk,
            success: { [weak self] loginResult in
                self?.cachedLogin = Self.loginInfo(from: loginResult)
            },
            failure: { [weak self] code, message in
                self?.failInit(code: code, message: message)
            }
        )
    }

    private func handleMakeCall(_ args: [String: Any], result: @escaping FlutterResult) {
        guard manager.canMakeCall() else {
            result(FlutterError(code: "-302", message: "未登录无法呼叫", details: nil))
            return
        }
        let phone = args["phoneNumber"] as? String ?? ""
        let userData = args["userData"] as? [String: Any]
        var replied = false
        let succeed: (String) -> Void = { [weak self] callId in
            if replied { return }
            replied = true
            let payload: [String: Any] = [
                "callId": callId,
                "phoneNumber": phone,
                "direction": "app",
                "state": "calling",
                "startTime": 0,
            ]
            self?.currentCall = payload
            DispatchQueue.main.async {
                result(payload)
            }
        }
        let fail: (Int, String) -> Void = { code, message in
            if replied { return }
            replied = true
            DispatchQueue.main.async {
                result(FlutterError(code: "\(code)", message: message, details: nil))
            }
        }
        if let userData {
            manager.makeCall(phone, userData: userData, success: succeed, failure: fail)
        } else {
            manager.makeCall(phone, success: succeed, failure: fail)
        }
    }

    private func startObserving() {
        stopObserving()
        observe(.sipConnected) { [weak self] _ in
            guard let self else { return }
            self.emit("sipConnected")
            let pending = self.pendingInit
            self.pendingInit = nil
            pending?(nil)
        }
        observe(.sipConnectFailed) { [weak self] info in
            let code = Self.intValue(info[kSIPVoIPStatusCodeKey], fallback: -207)
            let message = info[kSIPReasonDescriptionKey] as? String
            self?.failInit(code: code, message: message)
        }
        observe(.sipKickedOut) { [weak self] _ in
            self?.cachedLogin = nil
            self?.emit("kicked")
        }
        observe(.sipDisconnected) { [weak self] _ in
            self?.emit("sipDisconnected")
        }
        observe(.sipCallCalling) { [weak self] info in
            self?.emitCall("callCalling", info, state: "calling")
        }
        observe(.sipCallConnecting) { [weak self] info in
            self?.emitCall("callAlerting", info, state: "alerting")
        }
        observe(.sipCallConfirm) { [weak self] info in
            self?.manager.refreshAudioDevice()
            self?.emitCall("callAnswered", info, state: "answered")
        }
        observe(.sipCallDisconnect) { [weak self] info in
            self?.handleDisconnect(info)
        }
        observe(.socketCallStatus) { [weak self] info in
            self?.handleSocket(info)
        }
    }

    private func stopObserving() {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
        observers.removeAll()
    }

    private func observe(_ name: Notification.Name, _ handler: @escaping ([AnyHashable: Any]) -> Void) {
        let token = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { notification in
            handler(notification.userInfo ?? [:])
        }
        observers.append(token)
    }

    private func failInit(code: Int, message: String?) {
        emit("sipConnectFailed", ["errorCode": code, "errorMsg": message ?? ""])
        let pending = pendingInit
        pendingInit = nil
        guard let pending else { return }
        DispatchQueue.main.async {
            pending(FlutterError(code: "\(code)", message: message, details: nil))
        }
    }

    private func handleDisconnect(_ info: [AnyHashable: Any]) {
        seenServerCallIds.removeAll()
        let code = Self.intValue(info[kSIPVoIPStatusCodeKey], fallback: 0)
        if code <= -300 && code >= -399 {
            var payload = callPayload(info, state: "failed")
            payload["errorCode"] = code
            payload["errorMsg"] = info[kSIPReasonDescriptionKey] as? String ?? ""
            currentCall = nil
            emit("callFailed", payload)
            return
        }
        var payload = callPayload(info, state: "released")
        payload["hangupType"] = Self.intValue(info[kSIPHangupTypeKey], fallback: 0)
        payload["reason"] = info[kSIPReasonDescriptionKey] as? String ?? ""
        currentCall = nil
        emit("callReleased", payload)
    }

    private func handleSocket(_ info: [AnyHashable: Any]) {
        let callType = info[kSocketCallTypeKey] as? String ?? ""
        guard callType == "callin" || callType == "callout" else { return }
        let callId = info[kSocketCallIdKey] as? String ?? ""
        let state = Self.intValue(info[kSocketCallStateKey], fallback: 0)
        let stateName = info[kSocketCallStateNameKey] as? String ?? ""
        let payload: [String: Any] = [
            "callId": callId,
            "phoneNumber": info[kSocketCustomerNumberKey] as? String ?? "",
            "direction": callType == "callin" ? "server" : "app",
            "state": socketStateName(state, stateName),
            "startTime": 0,
            "disNumber": info[kSocketDisNumberKey] as? String ?? "",
            "callState": state,
            "callStateName": stateName,
        ]
        if callType == "callin", !seenServerCallIds.contains(callId) {
            seenServerCallIds.insert(callId)
            currentCall = payload
            emit("serverCall", payload)
            return
        }
        switch state {
        case 2:
            emit("callCalling", payload)
        case 3:
            emit("callAlerting", payload)
        default:
            if stateName.contains("接通") || stateName.contains("通话中") {
                emit("callAnswered", payload)
            }
        }
    }

    private func emitCall(_ type: String, _ info: [AnyHashable: Any], state: String) {
        let payload = callPayload(info, state: state)
        currentCall = payload
        emit(type, payload)
    }

    private func callPayload(_ info: [AnyHashable: Any], state: String) -> [String: Any] {
        let role = Self.intValue(info[kSIPCallRoleKey], fallback: 0)
        let callId = (info[kSIPCallIdStringKey] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(info[kSIPCallIdKey] ?? "")"
        return [
            "callId": callId,
            "phoneNumber": info[kSIPRemoteNumberKey] as? String ?? "",
            "direction": role == 1 ? "server" : "app",
            "state": state,
            "startTime": Self.intValue(info[kSIPTimestampKey], fallback: 0),
        ]
    }

    private func socketStateName(_ state: Int, _ name: String) -> String {
        switch state {
        case 3: return "alerting"
        default:
            if name.contains("接通") || name.contains("通话中") { return "answered" }
            return "calling"
        }
    }

    private func applyLogConfig(_ log: [String: Any]?) {
        let level = min(max((log?["logLevel"] as? Int) ?? 1, 0), 2)
        VoIPManager.setLogLevel(level)
        let fileEnabled = (log?["fileLoggingEnabled"] as? Bool)
            ?? (log?["enableLog"] as? Bool)
            ?? false
        VoIPManager.setFileLoggingEnabled(fileEnabled)
        if let path = log?["logFilePath"] as? String, !path.isEmpty {
            VoIPManager.setLogFilePath(path)
        } else {
            VoIPManager.setLogFilePath(nil)
        }
    }

    private func emit(_ type: String, _ payload: [String: Any] = [:]) {
        let event: [String: Any] = ["type": type, "payload": payload]
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    private static func intValue(_ value: Any?, fallback: Int) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        return fallback
    }

    private static func loginInfo(from result: [AnyHashable: Any]) -> [String: Any] {
        let raw = flutterObject(result) as? [String: Any] ?? [:]
        let data = raw["data"] as? [String: Any] ?? raw
        let agent = data["agent"] as? [String: Any] ?? raw["agent"] as? [String: Any] ?? [:]
        let account = data["account"] as? [String: Any] ?? [:]
        return [
            "agentId": agent["_id"] ?? agent["id"] ?? agent["agentId"] ?? data["agentId"] ?? "",
            "agentNumber": agent["agentNumber"] ?? "",
            "mobile": agent["mobile"] ?? "",
            "accountId": account["_id"] ?? account["id"] ?? "",
        ]
    }

    private static func flutterObject(_ value: Any?) -> Any? {
        guard let value else { return nil }
        switch value {
        case let text as String:
            return text
        case let number as NSNumber:
            return number
        case let list as [Any]:
            return list.compactMap { flutterObject($0) }
        case let dict as NSDictionary:
            var out: [String: Any] = [:]
            dict.forEach { key, item in
                let name = "\(key)"
                let lowered = name.lowercased()
                if lowered.contains("token") || lowered.contains("password") {
                    return
                }
                if let converted = flutterObject(item) {
                    out[name] = converted
                }
            }
            return out
        case is NSNull:
            return nil
        default:
            return "\(value)"
        }
    }
}
