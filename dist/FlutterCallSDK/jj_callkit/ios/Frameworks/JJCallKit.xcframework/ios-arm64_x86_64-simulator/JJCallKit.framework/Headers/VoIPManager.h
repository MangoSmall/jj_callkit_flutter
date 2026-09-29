//
//  VoIPManager.h
//  PhoneSDKTest
//
//  Created by 郝崇峰 on 2025/11/15.
//

#import <Foundation/Foundation.h>
@class JJVoIPSRWebSocket;

// 导入日志管理器以使用 VoIPLogLevel 枚举
@class VoIPLogManager;

NS_ASSUME_NONNULL_BEGIN

// MARK: - 通知名称常量

// 连接相关
extern NSString * const kSIPConnectedNotification;       // SIP连接成功
extern NSString * const kSIPConnectFailedNotification;   // SIP连接失败
extern NSString * const kSIPKickedOutNotification;       // 被踢下线（453）
extern NSString * const kSIPDisconnectedNotification;    // SIP断开连接

// 呼叫相关
extern NSString * const kSIPCallCallingNotification;     // 正在呼叫
extern NSString * const kSIPCallConnectingNotification;  // 振铃中
extern NSString * const kSIPCallConfirmNotification;     // 呼叫接通
extern NSString * const kSIPCallDisconnectNotification;  // 呼叫挂断
extern NSString * const kSIPCallRetryNotification;       // 呼叫重试
extern NSString * const kSocketCallStatusNotification;   // 通话状态通知

// MARK: - UserInfo Keys
extern NSString * const kSIPReasonKey;                   // sipReason 错误码
extern NSString * const kSIPReasonDescriptionKey;        // sipReasonDescription 可读描述

// SIP 通话通知通用 UserInfo Keys（所有呼叫相关通知均包含）
extern NSString * const kSIPCallIdKey;                   // sipCallId PJSIP 内部通话 ID
extern NSString * const kSIPRemoteNumberKey;             // sipRemoteNumber 对方号码
extern NSString * const kSIPCallRoleKey;                 // sipCallRole 主叫/被叫 (SIPHangupType 枚举值：0=主叫 1=被叫)
extern NSString * const kSIPCallIdStringKey;             // sipCallIdString SIP Dialog Call-ID 字符串
extern NSString * const kSIPIsPassiveKey;                // sipIsPassive 是否被动断开
extern NSString * const kSIPTimestampKey;                // sipTimestamp 时间戳
extern NSString * const kSIPHangupTypeKey;               // sipHangupType 挂断类型：SIPHangupType 枚举值（0=主叫挂断，1=被叫挂断）
extern NSString * const kSIPVoIPStatusCodeKey;           // sipVoIPStatusCode VoIPStatusCode 错误码（当SIP状态码映射到VoIPStatusCode时使用）

// Socket.IO 通话状态通知 UserInfo Keys
extern NSString * const kSocketCallIdKey;                // socketCallId 通话ID
extern NSString * const kSocketCallTypeKey;              // socketCallType 通话类型（callout/callin）
extern NSString * const kSocketCallStateKey;             // socketCallState 通话状态（1/2/3等）
extern NSString * const kSocketCallStateNameKey;         // socketCallStateName 通话状态名称
extern NSString * const kSocketCustomerNumberKey;        // socketCustomerNumber 客户号码
extern NSString * const kSocketDisNumberKey;              // socketDisNumber 外显号码
extern NSString * const kSocketEventDataKey;             // socketEventData 完整的事件数据字典

// MARK: - 挂断类型定义
typedef NS_ENUM(NSInteger, SIPHangupType) {
    SIPHangupTypeCaller = 0,    // 主叫挂断
    SIPHangupTypeCallee = 1     // 被叫挂断
};

// MARK: - 状态码定义

typedef NS_ENUM(NSInteger, VoIPStatusCode) {
    VoIPStatusCodeSuccess = 0,                 // 成功
    
    // 初始化错误 (-1 到 -99)
    VoIPStatusCodeSDKInitFailed = -1,          // SDK初始化失败
    VoIPStatusCodeSDKNotInitialized = -2,      // SDK未初始化
    VoIPStatusCodePJSIPCreateFailed = -3,        // PJSIP创建失败
    VoIPStatusCodePJSIPInitFailed = -4,          // PJSIP初始化失败
    VoIPStatusCodeTransportCreateFailed = -5,    // 传输层创建失败（UDP/TCP）
    VoIPStatusCodePJSIPStartFailed = -6,          // PJSIP启动失败
    
    // 参数验证错误 (-100 到 -199)
    VoIPStatusCodeInvalidAccount = -100,      // 账号无效
    VoIPStatusCodeInvalidPassword = -101,     // 密码无效
    VoIPStatusCodeAccountFormatError = -104,   // 账号格式错误
    VoIPStatusCodeEmptyAccount = -105,         // 账号为空
    VoIPStatusCodeEmptyPassword = -106,        // 密码为空
    VoIPStatusCodeEmptyBaseURL = -107,         // 服务器URL为空
    VoIPStatusCodeEmptyToken = -108,           // Token为空
    
    // 登录流程错误 (-200 到 -299)
    VoIPStatusCodeLoginRequestFailed = -200,   // 登录请求失败
    VoIPStatusCodeLoginAuthFailed = -201,      // 登录认证失败
    VoIPStatusCodeLoginConfigFailed = -202,   // 获取登录配置失败
    VoIPStatusCodeSocketConnectFailed = -203, // Socket连接失败
    VoIPStatusCodeSIPConfigFailed = -205,      // 获取SIP配置失败
    VoIPStatusCodeSIPConfigIncomplete = -206,  // SIP配置信息不完整
    VoIPStatusCodeSIPRegisterFailed = -207,    // SIP注册失败（通用，包含详细SIP状态码在错误消息中）
    VoIPStatusCodeSIPRegisterForbidden = -209, // SIP注册被拒绝 (403)
    VoIPStatusCodeAccountFrozen = -210,        // 账号已被冻结
    VoIPStatusCodeAgentDisabled = -211,         // 坐席已停用
    VoIPStatusCodeAccountNotFound = -212,       // 账户未找到
    VoIPStatusCodeAgentNotFound = -213,         // 坐席未找到
    VoIPStatusCodeSIPRegisterNotFound = -215,  // SIP注册未找到 (404)
    VoIPStatusCodeSIPRegisterServerError = -216, // SIP注册服务器错误 (5xx)
    VoIPStatusCodePublicKeyFetchFailed = -217, // 获取公钥失败
    
    // HTTP 请求错误 (-2000 到 -2099)
    VoIPStatusCodeHTTPInvalidURL = -2001,        // 无效URL
    VoIPStatusCodeHTTPError = -2007,            // HTTP错误 (4xx, 5xx，通用)
    VoIPStatusCodeHTTPEmptyResponseData = -2008, // 空响应数据
    VoIPStatusCodeHTTPJSONParseFailed = -2009,  // JSON解析失败
    
    // WebSocket 相关错误 (-2100 到 -2199)
    VoIPStatusCodeWebSocketInvalidURL = -2100,  // 无效的 WebSocket URL
    VoIPStatusCodeWebSocketConnectFailed = -2101, // WebSocket 连接失败
    
    // 通话相关错误 (-300 到 -399)
    VoIPStatusCodeCallFailed = -300,           // 呼叫失败（通用，包含详细SIP状态码在错误消息中）
    VoIPStatusCodeCallPermissionDenied = -301, // 通话权限被拒绝
    VoIPStatusCodeCallNotLoggedIn = -302,      // 未登录无法呼叫
    VoIPStatusCodeCallEmptyNumber = -303,       // 呼叫号码为空
    VoIPStatusCodeCallForbidden = -304,        // 呼叫被拒绝 (403)
    VoIPStatusCodeCallNotFound = -305,         // 号码不存在 (404)
    VoIPStatusCodeCallBusy = -306,             // 用户忙线 (486)
    VoIPStatusCodeCallTerminated = -307,       // 请求已终止 (487)
    VoIPStatusCodeCallTimeout = -308,          // 呼叫超时 (408)
    VoIPStatusCodeCallUnavailable = -309,      // 暂时不可用 (480)
    VoIPStatusCodeCallFailedBlacklist = -310,  // 号码在黑名单中，无法拨打
    VoIPStatusCodeCallFailedRiskLimit = -311,  // 呼叫次数已达上限（风控拦截）
    VoIPStatusCodeCallFailedUserDataTooLarge = -312, // userData 超过 255 字节限制
    VoIPStatusCodeCallNotAcceptable = -313,    // 媒体协商失败 (488)
    VoIPStatusCodeCallRegistrationDropped = -314, // SIP 注册掉线 (477)
    VoIPStatusCodeCallNotExist = -315,         // 通话不存在 (481)
    VoIPStatusCodeCallAddressIncomplete = -316, // 号码不完整 (484)
    VoIPStatusCodeCallDeclined = -317,         // 对方拒绝接听 (603)
    VoIPStatusCodeCallBusyEverywhere = -318,   // 全局忙线 (600)
    VoIPStatusCodeCallServerError = -319,    // 服务器内部错误 (500)
    VoIPStatusCodeCallBadGateway = -320,     // 网关错误 (502)
    VoIPStatusCodeCallServiceUnavailable = -321, // 服务不可用 (503)
    VoIPStatusCodeCallServerTimeout = -322,  // 服务器超时 (504)
    VoIPStatusCodeCallNetworkLost = -323,    // 通话中网络中断
    
    // 网络错误 (-400 到 -499)
    VoIPStatusCodeNetworkTimeout = -401,       // 网络超时
    
    // 外显号码相关错误 (-4000 到 -4099)
    VoIPStatusCodeEmptyAgentId = -4001,        // 坐席ID为空
    VoIPStatusCodeDisplayNumberConfigFailed = -4002, // 获取外显号码配置失败（通用）
    
    // 其他错误
    VoIPStatusCodeUnknown = -9999              // 未知错误
};

// MARK: - 环境配置

typedef NS_ENUM(NSInteger, VoIPEnvironment) {
    VoIPEnvironmentProduction = 0,            // 生产环境
    VoIPEnvironmentDevelopment = 1            // 开发/测试环境
};

// MARK: - Typedefs

typedef void (^MessageHandler)(NSString *message);

@interface VoIPManager : NSObject

/**
 * 日志消息回调
 *
 * @discussion 设置此回调以接收SDK的日志消息，用于调试和监控
 */
@property (atomic, copy) MessageHandler messageHandler;

/**
 * 季节回调
 *
 * @discussion 设置此回调以接收季节相关的事件通知
 */
@property (atomic, copy) void (^seasonCallback)(int season);

/**
 * SDK初始化状态
 *
 * @discussion 标识SDK是否已成功初始化
 */
@property (atomic, assign) BOOL isSDKInitialized;

/**
 * 是否自动接听来电
 *
 * @discussion 设置为YES时，收到来电后会自动接听（默认YES）
 *             设置为NO时，需要手动调用acceptCall方法接听
 */
@property (atomic, assign) BOOL autoAnswerIncomingCall;

+ (instancetype)sharedManager;

#pragma mark - 日志配置

/**
 * 设置日志级别
 *
 * @param level 日志级别（错误/一般/全量）
 *
 * @discussion 设置SDK的日志输出级别：
 *             - VoIPLogLevelError: 仅输出错误日志
 *             - VoIPLogLevelNormal: 输出业务和错误日志（不含SIP）
 *             - VoIPLogLevelVerbose: 输出所有日志（业务、SIP、错误）
 */
+ (void)setLogLevel:(NSInteger)level;

/**
 * 设置日志文件路径
 *
 * @param filePath 日志文件完整路径，nil表示使用默认路径
 *
 * @discussion 设置日志文件的存储路径，默认路径为 Documents/VoIPLogs/voip.log
 *             此方法会同时设置应用日志和PJSIP详细协议日志的路径：
 *             - 应用日志：使用指定的 filePath（如 Documents/VoIPLogs/voip.log）
 *             - PJSIP协议日志：自动在同一目录生成，文件名为原文件名加上 "_pjsip" 后缀
 *               （如 Documents/VoIPLogs/voip_pjsip.log）
 *             两个日志文件会保存在同一目录，便于统一管理和分析。
 */
+ (void)setLogFilePath:(NSString * _Nullable)filePath;

/**
 * 启用或禁用文件日志
 *
 * @param enabled YES启用文件日志，NO禁用
 *
 * @discussion 控制是否将日志写入文件
 */
+ (void)setFileLoggingEnabled:(BOOL)enabled;

/**
 * 初始化SDK
 * 
 * @discussion 此方法是线程安全的，会检查是否已经初始化，防止重复初始化导致的问题
 * @warning 多次调用此方法不会重复初始化SDK，而是返回成功状态
 * @note 如果需要重新初始化，请先调用 cleanupSDK 方法清理状态
 * 
 * @return VoIPStatusCode，VoIPStatusCodeSuccess表示成功，VoIPStatusCodeSDKInitFailed表示失败
 */
- (VoIPStatusCode)initial;

/**
 * 完整的登录流程
 *
 * @param account 登录账号（格式：用户名@域名）
 * @param password 登录密码
 * @param environment 环境类型（生产环境或测试环境）
 * @param passwordPk 可选的已加密密码（RSA加密后的密码）
 * @param success 成功回调，返回登录结果字典
 * @param failure 失败回调，返回错误码和错误信息
 *
 */
- (void)loginWithAccount:(NSString *)account
                password:(NSString *)password
               environment:(VoIPEnvironment)environment
                passwordPk:(NSString * _Nullable)passwordPk
                 success:(void(^)(NSDictionary *result))success
                 failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 重新注册 SIP
 *
 * @discussion 仅在 loginWithAccount 已成功后可用。会先断开当前 SIP 注册，再使用缓存的 SIP 信息（域名、端口、账号、密码）重新注册。
 * @param success 重新注册成功回调（收到 200 时调用）
 * @param failure 失败回调，返回 SIP 状态码和描述
 */
- (void)reregisterSIPWithSuccess:(void(^)(void))success
                         failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 登出
 *
 * @discussion 断开WebSocket连接、注销SIP账号并清理登录状态。PJSIP 注销在后台串行队列执行，避免阻塞主线程；如需在彻底完成后通知 Flutter，请使用 logoutWithCompletion:。
 */
- (void)logout;

/**
 * 登出并在完成后回调（callback 在主线程执行）
 *
 * @param completion 可选；SIP 账号已提交注销且派发到主线程发通知后调用，可与 MethodChannel result 对齐
 */
- (void)logoutWithCompletion:(void (^ _Nullable)(void))completion;

/**
 * 发起呼叫
 *
 * @param callNumber 被叫号码
 * @param success 成功回调，返回callId
 * @param failure 失败回调，返回错误码和错误信息
 *
 * @discussion 使用指定的号码发起SIP呼叫。成功时会返回callId，失败时返回错误码和错误信息。
 */
- (void)makeCall:(NSString *)callNumber
          success:(void(^)(NSString *callId))success
          failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 发起呼叫（带自定义参数）
 *
 * @param callNumber 被叫号码
 * @param userData 自定义数据字典（可选），将作为JSON字符串进行base64编码后添加到P-Call-UserData头传递，编码后长度需小于255字节
 * @param success 成功回调，返回callId
 * @param failure 失败回调，返回错误码和错误信息
 *
 * @discussion 使用指定的号码发起SIP呼叫，支持传递自定义数据。userData字典会在方法内部转换为JSON字符串，然后进行base64编码后添加到P-Call-UserData SIP头中。
 *             如果userData为nil，则行为与makeCall:success:failure:相同。
 */
- (void)makeCall:(NSString *)callNumber
         userData:(NSDictionary * _Nullable)userData
          success:(void(^)(NSString *callId))success
          failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 挂断当前通话
 *
 * @discussion 挂断当前正在进行的通话
 */
- (void)hangupCall;

/**
 * 接听来电
 *
 * @discussion 接听当前来电
 */
- (void)acceptCall;

/**
 * 发送DTMF信号
 *
 * @param dtmfNumber DTMF号码（0-9, *, #）
 *
 * @discussion 在通话过程中发送DTMF双音多频信号
 */
- (void)sendDTMF:(NSString *)dtmfNumber;

/**
 * 设置扬声器开关
 *
 * @param open YES开启扬声器，NO关闭扬声器
 *
 * @discussion 控制通话时的音频输出设备
 */
- (void)openLoudSpeaker:(BOOL)open;

/**
 * 设置静音开关
 *
 * @param open YES开启静音，NO关闭静音
 *
 * @discussion 控制通话时的麦克风输入
 */
- (void)openMute:(BOOL)open;

/**
 * 查询当前是否为静音状态
 *
 * @return YES表示当前已静音，NO表示未静音
 *
 * @discussion 查询当前通话的静音状态。如果没有正在进行的通话，返回NO。
 */
- (BOOL)isMuted;

/**
 * 查询当前是否使用扬声器
 *
 * @return YES表示当前使用扬声器，NO表示使用听筒或其他音频输出设备
 *
 * @discussion 查询当前音频输出设备状态。通过查询 AVAudioSession 的实际输出端口来判断。
 */
- (BOOL)isLoudSpeakerOn;

/**
 * 设置音频配置
 *
 * @param type 音频类型
 * @param enabled 是否启用
 * @param mode 音频模式
 *
 * @discussion 配置音频相关参数
 */
- (void)setAudioConfig:(int)type enabled:(bool)enabled mode:(int)mode;

/**
 * 重置重试次数
 *
 * @discussion 重置呼叫重试计数器
 */
- (void)resetRetryNumber;

/**
 * 刷新并重新设置音频设备
 *
 * @discussion 刷新音频设备列表并重新设置为默认设备，通常在通话建立后调用以确保音频设备正确配置
 */
- (void)refreshAudioDevice;

// MARK: - 辅助方法

/**
 * 获取错误码的友好描述
 *
 * @param errorCode 错误码
 * @return 错误码对应的可读描述字符串
 */
+ (NSString *)errorDescriptionForCode:(NSInteger)errorCode;

/**
 * 获取SIP状态码的描述信息
 *
 * @param statusCode SIP状态码（如200, 401, 403等）
 * @return 状态码对应的可读描述字符串（包含中文和英文说明）
 *
 * @discussion 此方法将SIP协议的状态码转换为可读的描述信息，包括：
 *             - 1xx: 临时响应（如100 Trying, 180 Ringing）
 *             - 2xx: 成功响应（如200 OK）
 *             - 3xx: 重定向响应
 *             - 4xx: 客户端错误（如401 Unauthorized, 403 Forbidden, 404 Not Found）
 *             - 5xx: 服务器错误（如500 Internal Server Error, 503 Service Unavailable）
 *             - 6xx: 全局失败
 */
+ (NSString *)sipStatusDescription:(int)statusCode;

/**
 * 检查当前是否可以拨打电话
 *
 * @return YES表示可以拨打电话，NO表示当前状态不允许拨打电话
 *
 * @discussion 检查SIP连接状态和通话状态，判断是否可以发起新的呼叫
 */
- (BOOL)canMakeCall;

// MARK: - 状态清理方法

/**
 * 呼叫失败时的完整状态清理
 *
 * @param errorCode 错误码
 *
 * @discussion 当呼叫失败时，清理所有相关的通话状态和资源
 */
- (void)cleanupCallStateOnFailure:(int)errorCode;

/**
 * 重置音频设备状态
 *
 * @discussion 重置音频设备到初始状态
 */
- (void)resetAudioDeviceState;

/**
 * 完整的通话状态清理
 *
 * @discussion 清理所有通话相关的状态，适用于正常挂断和异常断开场景
 */
- (void)cleanupCompleteCallState;

/**
 * SDK清理方法
 *
 * @discussion 清理SDK的所有状态，包括停止定时器、清理通话状态、重置初始化标志位和清理回调
 *
 * @warning 调用此方法后，需要重新调用 initial 方法才能使用SDK功能
 */
- (void)cleanupSDK;

// MARK: - 外显号码相关接口

/**
 * 获取坐席的外显策略及相关配置
 *
 * @param success 成功回调，返回包含以下字段的字典：mobile, agentNumber, numbers, numberSelect, selectNumber, numberGroup, sipNumber, callerStrategy
 * @param failure 失败回调
 *
 * @discussion 根据坐席信息配置接口获取外显策略及相关配置信息。使用登录成功后获取的坐席ID。
 */
- (void)getCallerStrategyWithSuccess:(void(^)(NSDictionary *config))success
                             failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 获取外显号码列表
 *
 * @param success 成功回调，返回外显号码数组（每个字典包含 id、status、number、province、city）
 * @param failure 失败回调
 *
 * @discussion 获取可用的外显号码列表
 */
- (void)getDisplayNumberListWithSuccess:(void(^)(NSArray<NSDictionary *> *numberList))success
                               failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 获取外显号码组列表
 *
 * @param success 成功回调，返回外显号码组数组（每个字典包含 id、name、groupName、remark）
 * @param failure 失败回调
 *
 * @discussion 获取可用的外显号码组列表
 */
- (void)getDisplayNumberGroupListWithSuccess:(void(^)(NSArray<NSDictionary *> *groupList))success
                                     failure:(void(^)(NSInteger code, NSString *message))failure;

/**
 * 指定外显号码组或外显号
 *
 * @param selectNumber 指定的外显号码（可选，如果指定了 numberGroup 则此参数可为 nil）
 * @param numberGroup 指定的外显号码组ID（可选，如果指定了 selectNumber 则此参数可为 nil）
 * @param success 成功回调
 * @param failure 失败回调
 *
 * @discussion 为指定坐席设置外显号码或外显号码组，必须指定 selectNumber 或 numberGroup 之一。使用登录成功后获取的坐席ID。
 */
- (void)updateAgentDisplayNumberWithSelectNumber:(NSString * _Nullable)selectNumber
                                    numberGroup:(NSString * _Nullable)numberGroup
                                        success:(void(^)(void))success
                                        failure:(void(^)(NSInteger code, NSString *message))failure;

@end

NS_ASSUME_NONNULL_END
