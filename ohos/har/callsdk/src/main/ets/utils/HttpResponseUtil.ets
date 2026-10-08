export function httpGetSuccess(body: string): boolean {
  try {
    const o = JSON.parse(body) as Record<string, boolean | string>;
    return o['success'] === true || o['Succeed'] === true;
  } catch (_) {
    return false;
  }
}

export function httpGetMessage(body: string, fallback: string): string {
  try {
    const o = JSON.parse(body) as Record<string, string>;
    const m = o['message'] ?? o['Message'] ?? '';
    return m.length > 0 ? m : fallback;
  } catch (_) {
    return fallback;
  }
}
