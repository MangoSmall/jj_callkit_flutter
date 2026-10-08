import { audio } from '@kit.AudioKit';
import { AudioRoute, AudioRouteChangeListener } from '../listener/SdkListeners';
import { CallAudioUtil } from './CallAudioUtil';
import { SdkLogger } from './SdkLogger';

/**
 * 通话音频路由管理（对齐 Android AudioRouteManager）
 * 监听耳机/蓝牙插拔，自动切换通信设备。
 */
export class AudioRouteManager {
  private static started: boolean = false;
  private static currentRoute: AudioRoute = AudioRoute.RECEIVER;
  private static userForcedSpeaker: boolean = false;
  /** 串行化 OH 路由切换，保证 await 方等到目标路由真正落地 */
  private static ohRouteChain: Promise<boolean> = Promise.resolve(true);
  private static listener: AudioRouteChangeListener | null = null;
  private static deviceChangeHandler: ((action: audio.DeviceChangeAction) => void) | null = null;

  static setAudioRouteChangeListener(listener: AudioRouteChangeListener | null): void {
    AudioRouteManager.listener = listener;
  }

  static getCurrentRoute(): AudioRoute {
    return AudioRouteManager.currentRoute;
  }

  static async start(): Promise<void> {
    if (AudioRouteManager.started) {
      return;
    }
    AudioRouteManager.started = true;
    AudioRouteManager.userForcedSpeaker = false;
    await AudioRouteManager.registerDeviceListener();
    const route = await AudioRouteManager.detectBestRoute();
    AudioRouteManager.commitRoute(route);
    await AudioRouteManager.applyOhRoute(route);
    SdkLogger.info('AudioRouteManager', `started route=${route}`);
  }

  static stop(): void {
    if (!AudioRouteManager.started) {
      return;
    }
    AudioRouteManager.unregisterDeviceListener();
    AudioRouteManager.started = false;
    AudioRouteManager.userForcedSpeaker = false;
    AudioRouteManager.ohRouteChain = Promise.resolve(true);
    AudioRouteManager.currentRoute = AudioRoute.RECEIVER;
    SdkLogger.info('AudioRouteManager', 'stopped');
  }

  static async switchRoute(route: AudioRoute): Promise<boolean> {
    AudioRouteManager.beginUserRoute(route);
    return AudioRouteManager.applyOhRoute(route);
  }

  /** 关闭扬声器时恢复到当前最佳路由（蓝牙 > 有线耳机 > 听筒） */
  static async switchToDetectedRoute(): Promise<boolean> {
    AudioRouteManager.beginUserSpeakerOff();
    const route = await AudioRouteManager.detectBestRoute();
    if (route !== AudioRouteManager.currentRoute) {
      AudioRouteManager.commitRoute(route);
    }
    return AudioRouteManager.applyOhRoute(route);
  }

  /** 用户点扬声器开：同步更新路由状态，UI 立即响应 */
  static beginUserSpeakerOn(): void {
    AudioRouteManager.userForcedSpeaker = true;
    AudioRouteManager.commitRoute(AudioRoute.SPEAKER);
  }

  /** 用户点扬声器关：先切到听筒，后续 detect 可能改为蓝牙/耳机 */
  static beginUserSpeakerOff(): void {
    AudioRouteManager.userForcedSpeaker = false;
    if (AudioRouteManager.currentRoute === AudioRoute.SPEAKER) {
      AudioRouteManager.commitRoute(AudioRoute.RECEIVER);
    }
  }

  static scheduleOhRoute(route: AudioRoute): void {
    void AudioRouteManager.applyOhRoute(route);
  }

  private static beginUserRoute(route: AudioRoute): void {
    if (route === AudioRoute.SPEAKER) {
      AudioRouteManager.userForcedSpeaker = true;
    } else if (route === AudioRoute.RECEIVER) {
      AudioRouteManager.userForcedSpeaker = false;
    }
    AudioRouteManager.commitRoute(route);
  }

  static async refreshRouteFromSystem(): Promise<AudioRoute> {
    if (AudioRouteManager.userForcedSpeaker) {
      return AudioRouteManager.currentRoute;
    }
    const route = await AudioRouteManager.detectBestRoute();
    if (route !== AudioRouteManager.currentRoute) {
      AudioRouteManager.commitRoute(route);
      await AudioRouteManager.applyOhRoute(route);
    }
    return AudioRouteManager.currentRoute;
  }

  private static commitRoute(route: AudioRoute): void {
    if (AudioRouteManager.currentRoute === route) {
      return;
    }
    AudioRouteManager.currentRoute = route;
    AudioRouteManager.notifyRouteChanged(route);
  }

  private static async registerDeviceListener(): Promise<void> {
    if (AudioRouteManager.deviceChangeHandler !== null) {
      return;
    }
    try {
      const routingMgr = audio.getAudioManager().getRoutingManager();
      const handler = (_action: audio.DeviceChangeAction): void => {
        void AudioRouteManager.onDeviceChanged();
      };
      routingMgr.on('deviceChange', audio.DeviceFlag.OUTPUT_DEVICES_FLAG, handler);
      AudioRouteManager.deviceChangeHandler = handler;
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('AudioRouteManager', `registerDeviceListener: ${msg}`);
    }
  }

  private static unregisterDeviceListener(): void {
    if (AudioRouteManager.deviceChangeHandler === null) {
      return;
    }
    try {
      const routingMgr = audio.getAudioManager().getRoutingManager();
      routingMgr.off('deviceChange', AudioRouteManager.deviceChangeHandler);
    } catch (_) {
    }
    AudioRouteManager.deviceChangeHandler = null;
  }

  private static async onDeviceChanged(): Promise<void> {
    if (!AudioRouteManager.started || AudioRouteManager.userForcedSpeaker) {
      return;
    }
    const route = await AudioRouteManager.detectBestRoute();
    if (route !== AudioRouteManager.currentRoute) {
      AudioRouteManager.commitRoute(route);
      await AudioRouteManager.applyOhRoute(route);
    }
  }

  private static async detectBestRoute(): Promise<AudioRoute> {
    if (await CallAudioUtil.isOutputRouteActive(audio.DeviceType.BLUETOOTH_SCO)) {
      return AudioRoute.BLUETOOTH;
    }
    if (await CallAudioUtil.isOutputRouteActive(audio.DeviceType.WIRED_HEADSET) ||
      await CallAudioUtil.isOutputRouteActive(audio.DeviceType.WIRED_HEADPHONES)) {
      return AudioRoute.RECEIVER;
    }
    if (await CallAudioUtil.hasAvailableDevice(audio.DeviceType.BLUETOOTH_SCO)) {
      return AudioRoute.BLUETOOTH;
    }
    if (await CallAudioUtil.hasAvailableDevice(audio.DeviceType.WIRED_HEADSET) ||
      await CallAudioUtil.hasAvailableDevice(audio.DeviceType.WIRED_HEADPHONES)) {
      return AudioRoute.RECEIVER;
    }
    if (AudioRouteManager.userForcedSpeaker) {
      return AudioRoute.SPEAKER;
    }
    return AudioRoute.RECEIVER;
  }

  /**
   * 仅切换 OH 系统音频设备；路由状态由 commitRoute 维护，不在此改 currentRoute。
   * 通过 ohRouteChain 串行，避免「合并 pending 立刻 return false」导致扬声器尚未落地就 reopen OpenSL。
   */
  private static applyOhRoute(route: AudioRoute): Promise<boolean> {
    const run = AudioRouteManager.ohRouteChain.then((): Promise<boolean> => {
      return AudioRouteManager.applyOhRouteNow(route);
    });
    AudioRouteManager.ohRouteChain = run.then((): boolean => true, (): boolean => true);
    return run;
  }

  private static async applyOhRouteNow(route: AudioRoute): Promise<boolean> {
    let ok = false;
    let target = route;
    switch (target) {
      case AudioRoute.BLUETOOTH:
        ok = await CallAudioUtil.setOutputRoute(audio.DeviceType.BLUETOOTH_SCO);
        break;
      case AudioRoute.SPEAKER:
        ok = await CallAudioUtil.setSpeakerRoute(true);
        break;
      case AudioRoute.RECEIVER:
      default:
        if (await CallAudioUtil.hasAvailableDevice(audio.DeviceType.WIRED_HEADSET) ||
          await CallAudioUtil.hasAvailableDevice(audio.DeviceType.WIRED_HEADPHONES)) {
          ok = await CallAudioUtil.setOutputRoute(audio.DeviceType.WIRED_HEADSET);
        } else {
          ok = await CallAudioUtil.setSpeakerRoute(false);
        }
        break;
    }
    if (!ok && target === AudioRoute.BLUETOOTH) {
      ok = await CallAudioUtil.setSpeakerRoute(false);
      target = AudioRoute.RECEIVER;
    }
    if (!ok) {
      SdkLogger.warn('AudioRouteManager', `applyOhRoute failed route=${target}`);
    }
    return ok;
  }

  private static notifyRouteChanged(route: AudioRoute): void {
    SdkLogger.info('AudioRouteManager', `route changed -> ${route}`);
    AudioRouteManager.listener?.onAudioRouteChanged(route);
  }
}
