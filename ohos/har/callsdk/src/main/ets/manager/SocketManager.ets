import webSocket from '@ohos.net.webSocket';
import connection from '@ohos.net.connection';
import { SdkConstants } from '../constant/SdkConstants';
import type { AccountSummary, AgentSummary } from '../model/SdkModels';
import { CallManager, RemoteCallEventPayload } from '../manager/CallManager';
import { DeviceUtils } from '../utils/DeviceUtils';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SdkLogger } from '../utils/SdkLogger';

const WS_EXTRA_JSON = '{"loginType":"WEBRTC","channelType":"APP","ability":["call"]}';

interface AgentAccountPair {
  agent: AgentSummary;
  account: AccountSummary;
}

const MAX_RECONNECT = 10;
const MAX_BACKOFF_MS = 30000;
const STALE_MS = 30000;
const WATCHDOG_TICK_MS = 5000;

export interface SocketKickHandler {
  onKicked(): void;
}

/** 对齐 callsdk SocketManager */
export class SocketManager {
  private static instance: SocketManager | null = null;

  private ws: webSocket.WebSocket | null = null;
  private manualDisconnect: boolean = false;
  private reconnectFailures: number = 0;
  private reconnectTimer: number = -1;
  private watchdogTimer: number = -1;
  private lastMessageMs: number = 0;
  private netConn: connection.NetConnection | null = null;
  private netRegistered: boolean = false;
  private namespaceConnectSent: boolean = false;
  private kickHandler: SocketKickHandler | null = null;

  static getInstance(): SocketManager {
    if (SocketManager.instance === null) {
      SocketManager.instance = new SocketManager();
    }
    return SocketManager.instance;
  }

  setKickHandler(handler: SocketKickHandler | null): void {
    this.kickHandler = handler;
  }

  connect(): void {
    this.manualDisconnect = false;
    if (this.ws !== null) {
      return;
    }
    this.reconnectFailures = 0;
    this.clearReconnectTimer();
    void this.performConnect(false);
  }

  disconnectManual(): void {
    this.manualDisconnect = true;
    this.clearReconnectTimer();
    this.clearWatchdog();
    this.reconnectFailures = 0;
    void this.closeWebSocket();
  }

  private ensureNetListener(): void {
    if (this.netRegistered) {
      return;
    }
    try {
      const nc = connection.createNetConnection();
      nc.register(() => {});
      nc.on('netAvailable', () => {
        if (!this.manualDisconnect && this.ws === null &&
          PreferencesUtil.getInstance().getString(SdkConstants.KEY_LOGIN_TOKEN, '').length > 0) {
          this.reconnectFailures = 0;
          void this.performConnect(false);
        }
      });
      this.netConn = nc;
      this.netRegistered = true;
    } catch (_) {
    }
  }

  private async performConnect(isFromReconnect: boolean): Promise<void> {
    this.ensureNetListener();
    if (this.manualDisconnect) {
      return;
    }
    const prefs = PreferencesUtil.getInstance();
    const wsHost = prefs.getString(SdkConstants.KEY_WS_HOST, '');
    const wsToken = prefs.getString(SdkConstants.KEY_WS_TOKEN, '');
    const timestamp = prefs.getString(SdkConstants.KEY_WS_TIMESTAMP, '');
    if (wsHost.length === 0 || wsToken.length === 0 || timestamp.length === 0) {
      return;
    }
    const ctx = SocketManager.loadAgentAccountFromPrefs();
    if (ctx === null) {
      return;
    }
    const url = SocketManager.buildSocketUrl(wsHost, wsToken, timestamp, ctx, isFromReconnect);
    await this.closeWebSocket();
    this.namespaceConnectSent = false;
    const sock = webSocket.createWebSocket();
    this.ws = sock;

    sock.on('open', () => {
      this.reconnectFailures = 0;
      this.touchMessageTime();
      this.startWatchdog();
      void this.sendNamespaceConnect();
      SdkLogger.info('SocketManager', 'WebSocket open');
    });

    sock.on('message', (_err, data) => {
      this.touchMessageTime();
      this.handleIncomingText(SocketManager.messageToString(data));
    });

    sock.on('close', () => {
      this.ws = null;
      this.clearWatchdog();
      if (!this.manualDisconnect) {
        this.scheduleReconnect();
      }
    });

    sock.on('error', () => {});

    sock.connect(url, (err) => {
      if (err) {
        void this.closeWebSocket();
        if (!this.manualDisconnect) {
          this.scheduleReconnect();
        }
      }
    });
  }

  private static messageToString(data: string | ArrayBuffer): string {
    if (typeof data === 'string') {
      return data;
    }
    const u8 = new Uint8Array(data);
    let s = '';
    for (let i = 0; i < u8.length; i++) {
      s += String.fromCharCode(u8[i]);
    }
    return s;
  }

  private touchMessageTime(): void {
    this.lastMessageMs = Date.now();
  }

  private startWatchdog(): void {
    this.clearWatchdog();
    this.lastMessageMs = Date.now();
    this.watchdogTimer = setInterval((): void => {
      if (this.manualDisconnect || this.ws === null) {
        this.clearWatchdog();
        return;
      }
      if (Date.now() - this.lastMessageMs > STALE_MS) {
        this.clearWatchdog();
        void this.closeWebSocket();
      }
    }, WATCHDOG_TICK_MS) as number;
  }

  private clearWatchdog(): void {
    if (this.watchdogTimer >= 0) {
      clearInterval(this.watchdogTimer);
      this.watchdogTimer = -1;
    }
  }

  private clearReconnectTimer(): void {
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
  }

  private scheduleReconnect(): void {
    this.clearReconnectTimer();
    if (this.manualDisconnect || this.reconnectFailures >= MAX_RECONNECT) {
      return;
    }
    const delay = Math.min(MAX_BACKOFF_MS, 1000 * Math.pow(2, this.reconnectFailures));
    this.reconnectFailures += 1;
    this.reconnectTimer = setTimeout((): void => {
      this.reconnectTimer = -1;
      void this.performConnect(true);
    }, delay) as number;
  }

  private async closeWebSocket(): Promise<void> {
    const s = this.ws;
    this.ws = null;
    if (s !== null) {
      try {
        await s.close();
      } catch (_) {
      }
    }
  }

  private handleIncomingText(message: string): void {
    if (message.length === 0) {
      return;
    }
    if (message === '2') {
      void this.safeSend('3');
      return;
    }
    if (message.startsWith('0') || message.startsWith('40')) {
      void this.sendNamespaceConnect();
      return;
    }
    const jsonStr = SocketManager.extractJsonFromMessage(message);
    if (jsonStr.length === 0) {
      return;
    }
    let arr: Object[] | null = null;
    try {
      arr = JSON.parse(jsonStr) as Object[];
    } catch (_) {
      return;
    }
    if (arr === null || !Array.isArray(arr) || arr.length === 0) {
      return;
    }
    const type = String(arr[0]);
    if (type === 'call' && arr.length > 1) {
      SocketManager.dispatchCallPacket(arr[1] as Record<string, Object>);
      return;
    }
    if (type === 'event' && arr.length > 1) {
      const eventObj = arr[1] as Record<string, string>;
      if ((eventObj['subType'] ?? '') === 'KICK_OFF') {
        this.disconnectManual();
        this.kickHandler?.onKicked();
      }
    }
  }

  private static dispatchCallPacket(callObj: Record<string, Object>): void {
    const dataObj = callObj['data'] as Record<string, string> | undefined;
    if (dataObj === undefined) {
      return;
    }
    const eventType = dataObj['eventType'] ?? '';
    const callId = dataObj['callId'] ?? '';
    let phoneNumber = dataObj['customerNumber'] ?? dataObj['calledNum'] ?? dataObj['phoneNumber'] ?? dataObj['called'] ?? '';
    const payload: RemoteCallEventPayload = {
      eventType: eventType,
      callId: callId,
      phoneNumber: phoneNumber
    };
    CallManager.getInstance().applyRemoteCallEvent(payload);
  }

  private sendNamespaceConnect(): void {
    if (this.namespaceConnectSent || this.ws === null) {
      return;
    }
    this.namespaceConnectSent = true;
    void this.safeSend('40');
  }

  private async safeSend(text: string): Promise<void> {
    const s = this.ws;
    if (s === null) {
      return;
    }
    try {
      await s.send(text);
    } catch (_) {
    }
  }

  private static extractJsonFromMessage(message: string): string {
    const re = /\{[\s\S]*\}|\[[\s\S]*\]/;
    const m = message.match(re);
    return m !== null && m.length > 0 ? m[0] : '';
  }

  private static buildSocketUrl(
    wsHost: string, wsToken: string, timestamp: string, ctx: AgentAccountPair, isReconnect: boolean
  ): string {
    const wsExtra = encodeURIComponent(WS_EXTRA_JSON);
    const loginDevice = isReconnect ? `reLogin_${DeviceUtils.getLoginDevice()}` : DeviceUtils.getLoginDevice();
    const sb =
      `agentId=${ctx.agent._id ?? ''}` +
      `&agentNumber=${encodeURIComponent(ctx.agent.agentNumber ?? '')}` +
      `&accountId=${ctx.account._id ?? ''}` +
      `&token=${encodeURIComponent(wsToken)}` +
      `&wsExtra=${wsExtra}` +
      `&timestamp=${encodeURIComponent(timestamp)}` +
      '&clientType=2&EIO=4&transport=websocket' +
      `&loginDevice=${encodeURIComponent(loginDevice)}`;
    return `wss://${wsHost}/socket.io/?${sb}`;
  }

  private static loadAgentAccountFromPrefs(): AgentAccountPair | null {
    const raw = PreferencesUtil.getInstance().getString(SdkConstants.KEY_SDK_LOGIN_INFO, '');
    if (raw.length === 0) {
      return null;
    }
    try {
      const root = JSON.parse(raw) as Record<string, Object>;
      const d = root['data'];
      let dataRaw: Record<string, Object> | null = null;
      if (typeof d === 'string' && d.length > 0) {
        dataRaw = JSON.parse(d) as Record<string, Object>;
      } else if (typeof d === 'object' && d !== null) {
        dataRaw = d as Record<string, Object>;
      }
      if (dataRaw === null) {
        return null;
      }
      const agentObj = dataRaw['agent'] as Record<string, string> | undefined;
      const accountObj = dataRaw['account'] as Record<string, string> | undefined;
      if (agentObj === undefined || accountObj === undefined) {
        return null;
      }
      const agent: AgentSummary = {
        _id: String(agentObj['_id'] ?? ''),
        agentNumber: String(agentObj['agentNumber'] ?? ''),
        mobile: String(agentObj['mobile'] ?? '')
      };
      const account: AccountSummary = { _id: String(accountObj['_id'] ?? '') };
      if ((agent._id ?? '').length === 0 || (account._id ?? '').length === 0) {
        return null;
      }
      return { agent: agent, account: account };
    } catch (_) {
      return null;
    }
  }
}
