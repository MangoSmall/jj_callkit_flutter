import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

export class CryptoUtils {
  private static textEncoder: util.TextEncoder = new util.TextEncoder();
  private static textDecoder: util.TextDecoder = new util.TextDecoder('utf-8');

  private static uint8ToHexLower(bytes: Uint8Array): string {
    let out = '';
    for (let i = 0; i < bytes.length; i++) {
      const h = (bytes[i] & 0xff).toString(16);
      out += h.length === 1 ? '0' + h : h;
    }
    return out;
  }

  static base64DecodeToUint8(b64: string): Uint8Array {
    const helper = new util.Base64Helper();
    const ascii: Uint8Array = CryptoUtils.textEncoder.encode(b64);
    return helper.decodeSync(ascii);
  }

  static base64EncodeFromUint8(data: Uint8Array): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(data);
  }

  static async md5HexUtf8(plain: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    const input: cryptoFramework.DataBlob = { data: CryptoUtils.textEncoder.encode(plain) };
    await md.update(input);
    const out = await md.digest();
    return CryptoUtils.uint8ToHexLower(out.data);
  }

  static async rsaEncryptUtf8WithPkcs1(plainUtf8: string, publicKeyBase64: string): Promise<string> {
    const normalized = publicKeyBase64.replace(/ /g, '+');
    const keyBytes = CryptoUtils.base64DecodeToUint8(normalized);
    const pubBlob: cryptoFramework.DataBlob = { data: keyBytes };
    const algos: string[] = ['RSA2048', 'RSA1024'];
    let lastErr: string = '';
    for (const algo of algos) {
      try {
        const gen = cryptoFramework.createAsyKeyGenerator(algo);
        const kp = await gen.convertKey(pubBlob, null);
        const cipherSpec = `${algo}|PKCS1`;
        const cipher = cryptoFramework.createCipher(cipherSpec);
        await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, kp.pubKey, null);
        const plainBlob: cryptoFramework.DataBlob = {
          data: CryptoUtils.textEncoder.encode(plainUtf8)
        };
        const enc = await cipher.doFinal(plainBlob);
        return CryptoUtils.base64EncodeFromUint8(enc.data);
      } catch (e) {
        lastErr = (e instanceof Error) ? e.message : String(e);
      }
    }
    throw new Error(`RSA encrypt failed: ${lastErr}`);
  }

  static async parsePasswordWithServerPk(pk: string, plainPassword: string): Promise<string> {
    const md5Hex = await CryptoUtils.md5HexUtf8(plainPassword);
    const outerBytes = CryptoUtils.base64DecodeToUint8(pk);
    const middle: string = CryptoUtils.textDecoder.decode(outerBytes);
    const innerKeyStr = CryptoUtils.urlDecodeJavaLike(middle);
    return await CryptoUtils.rsaEncryptUtf8WithPkcs1(md5Hex, innerKeyStr);
  }

  private static urlDecodeJavaLike(s: string): string {
    return decodeURIComponent(s.replace(/\+/g, ' '));
  }
}
