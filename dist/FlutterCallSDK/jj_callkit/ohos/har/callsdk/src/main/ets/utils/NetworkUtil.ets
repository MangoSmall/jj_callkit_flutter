import connection from '@ohos.net.connection';

export class NetworkUtil {
  static isNetworkConnected(): boolean {
    try {
      const net = connection.getDefaultNetSync();
      return net !== null && net.netId >= 0;
    } catch (_) {
      return false;
    }
  }
}
