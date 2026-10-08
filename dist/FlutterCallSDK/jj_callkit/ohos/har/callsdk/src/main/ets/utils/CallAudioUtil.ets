import { audio } from '@kit.AudioKit';
import { SdkLogger } from './SdkLogger';

export class CallAudioUtil {
  private static voipSessionActive: boolean = false;

  static async prepareVoipAudio(speaker: boolean = false): Promise<boolean> {
    await CallAudioUtil.ensureVoipSession();
    return CallAudioUtil.setSpeakerRoute(speaker);
  }

  static async ensureVoipSession(): Promise<void> {
    try {
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      try {
        sessionMgr.setAudioSessionScene(audio.AudioSessionScene.AUDIO_SESSION_SCENE_VOICE_COMMUNICATION);
      } catch (e) {
        const msg = (e instanceof Error) ? e.message : String(e);
        SdkLogger.warn('CallAudioUtil', `setAudioSessionScene: ${msg}`);
      }
      if (!sessionMgr.isAudioSessionActivated()) {
        const strategy: audio.AudioSessionStrategy = {
          concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
        };
        await sessionMgr.activateAudioSession(strategy);
        CallAudioUtil.voipSessionActive = true;
      }
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallAudioUtil', `ensureVoipSession: ${msg}`);
    }
  }

  static async endVoipSession(): Promise<void> {
    if (!CallAudioUtil.voipSessionActive) {
      return;
    }
    try {
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      await sessionMgr.deactivateAudioSession();
      CallAudioUtil.voipSessionActive = false;
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallAudioUtil', `endVoipSession: ${msg}`);
    }
  }

  /**
   * 切换扬声器/听筒。
   * OpenSL 热切常不可靠：调用方应在 native reopen 之后再调一次本方法。
   */
  static async setSpeakerRoute(speaker: boolean): Promise<boolean> {
    try {
      await CallAudioUtil.ensureVoipSession();
      const device: audio.DeviceType = speaker ? audio.DeviceType.SPEAKER : audio.DeviceType.EARPIECE;
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      await sessionMgr.setDefaultOutputDevice(device);

      const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
      await routingMgr.setCommunicationDevice(audio.CommunicationDeviceType.SPEAKER, speaker);

      await CallAudioUtil.logPreferredVoiceDevice(speaker);

      const active = await routingMgr.isCommunicationDeviceActive(audio.CommunicationDeviceType.SPEAKER);
      const defDev = sessionMgr.getDefaultOutputDevice();
      SdkLogger.info('CallAudioUtil',
        `setSpeakerRoute want=${speaker ? 'SPEAKER' : 'EARPIECE'} default=${defDev} commActive=${active}`);
      return true;
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallAudioUtil', `setSpeakerRoute(${speaker}) failed: ${msg}`);
      return false;
    }
  }

  private static async logPreferredVoiceDevice(speaker: boolean): Promise<void> {
    try {
      const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
      const info: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION,
        rendererFlags: 0
      };
      const prefs = await routingMgr.getPreferOutputDeviceForRendererInfo(info);
      let desc = 'none';
      if (prefs !== undefined && prefs.length > 0) {
        desc = `type=${prefs[0].deviceType} id=${prefs[0].id}`;
      }
      SdkLogger.info('CallAudioUtil',
        `prefer VOICE_COMMUNICATION -> ${desc} (wantSpeaker=${speaker})`);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallAudioUtil', `logPreferredVoiceDevice: ${msg}`);
    }
  }

  /** 切换通话输出设备（蓝牙/有线耳机等通过 DeviceType + setDefaultOutputDevice） */
  static async setOutputRoute(deviceType: audio.DeviceType): Promise<boolean> {
    try {
      await CallAudioUtil.ensureVoipSession();
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      await sessionMgr.setDefaultOutputDevice(deviceType);
      const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
      const speaker = deviceType === audio.DeviceType.SPEAKER;
      await routingMgr.setCommunicationDevice(audio.CommunicationDeviceType.SPEAKER, speaker);
      return true;
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallAudioUtil', `setOutputRoute(${deviceType}) failed: ${msg}`);
      return false;
    }
  }

  static async isOutputRouteActive(deviceType: audio.DeviceType): Promise<boolean> {
    try {
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      if (sessionMgr.getDefaultOutputDevice() === deviceType) {
        return true;
      }
      if (deviceType === audio.DeviceType.SPEAKER) {
        const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
        return await routingMgr.isCommunicationDeviceActive(audio.CommunicationDeviceType.SPEAKER);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static async hasAvailableDevice(deviceType: audio.DeviceType): Promise<boolean> {
    try {
      const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
      const devices = routingMgr.getAvailableDevices(audio.DeviceUsage.CALL_OUTPUT_DEVICES);
      for (let i = 0; i < devices.length; i++) {
        if (devices[i].deviceType === deviceType) {
          return true;
        }
      }
      return false;
    } catch (_) {
      try {
        const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
        const devices = routingMgr.getAvailableDevices(audio.DeviceUsage.MEDIA_OUTPUT_DEVICES);
        for (let i = 0; i < devices.length; i++) {
          if (devices[i].deviceType === deviceType) {
            return true;
          }
        }
      } catch (e) {
        const msg = (e instanceof Error) ? e.message : String(e);
        SdkLogger.warn('CallAudioUtil', `hasAvailableDevice: ${msg}`);
      }
      return false;
    }
  }

  static async isSpeakerActive(): Promise<boolean> {
    try {
      const sessionMgr: audio.AudioSessionManager = audio.getAudioManager().getSessionManager();
      return sessionMgr.getDefaultOutputDevice() === audio.DeviceType.SPEAKER;
    } catch (_) {
      try {
        const routingMgr: audio.AudioRoutingManager = audio.getAudioManager().getRoutingManager();
        return await routingMgr.isCommunicationDeviceActive(audio.CommunicationDeviceType.SPEAKER);
      } catch (e) {
        const msg = (e instanceof Error) ? e.message : String(e);
        SdkLogger.warn('CallAudioUtil', `isSpeakerActive: ${msg}`);
        return false;
      }
    }
  }
}
