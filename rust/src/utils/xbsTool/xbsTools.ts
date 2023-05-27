import {Buffer} from 'buffer';

const xxTeaKey = [0xe5, 0x87, 0xbc, 0xe8, 0xa4, 0x86, 0xe6, 0xbb, 0xbf, 0xe9, 0x87, 0x91, 0xe6, 0xba, 0xa1, 0xe5];

const delta = 0x9e3779b9;

const xxteaTools = {
    decrypt(data: Buffer, key: Buffer, padding: boolean, rounds: number) {
        const dLen = data.length;
        const kLen = key.length;
        let aLen, rc;
        if (kLen !== 16) {
            throw new Error("need a 16-byte key");
        }
        if (!padding && (dLen < 8 || (dLen & 3) !== 0)) {
            throw new Error("data length must be a multiple of 4 bytes and must not be less than 8 bytes");
        }
        if ((dLen & 3) !== 0 || dLen < 8) {
            throw new Error("invalid data, data length is not a multiple of 4, or less than 8");
        }
        aLen = dLen / 4;
        const d = byteTools.bytesToUint32(data, dLen, aLen, false);
        const k = byteTools.bytesToUint32(key, kLen, 4, false);
        this.btea(d, -aLen, k, rounds);
        const refBuf: number | Uint8Array = byteTools.uint32sToBytes(d, aLen, padding);
        rc = refBuf.length
        if (padding) {
            if (rc >= 0) {
                return refBuf.subarray(0, rc);
            } else {
                throw new Error("invalid data, illegal PKCS#7 padding. Could be using a wrong key");
            }
        }
        return refBuf;
    },
    encrypt(data: Buffer, key: Buffer, padding: boolean, rounds: number) {
        const dLen = data.length;
        const kLen = key.length;
        let paddingValue = 0;

        if (padding) {
            paddingValue = 1;
        }

        if (kLen !== 16) {
            throw new Error('need a 16-byte key');
        }

        if (!padding && (dLen < 8 || (dLen & 3) !== 0)) {
            throw new Error('data length must be a multiple of 4 bytes and must not be less than 8 bytes');
        }

        let aLen;
        if (dLen < 4) {
            aLen = 2;
        } else {
            aLen = (dLen >> 2) + paddingValue;
        }

        const d = byteTools.bytesToUint32(data, dLen, aLen, padding);
        const k = byteTools.bytesToUint32(key, kLen, 4, false);

        return byteTools.uint32sToBytes(this.btea(d, aLen, k, rounds), aLen, false);
    },
    btea(v: Uint32Array, n: number, key: Uint32Array, rounds: number): Uint32Array {
        let i, y, z, p, e, sum = 0;

        if (n > 1) {
            const un = n >>> 0;
            if (rounds === 0) {
                rounds = Math.floor(6 + 52 / (un));
            }
            z = v[un - 1];

            for (i = 0; i < rounds; i++) {
                sum += delta;
                e = (sum >>> 2) & 3;
                for (p = 0; p < un - 1; p++) {
                    y = v[p + 1];
                    const mm = this.mx(y, z, p, e, sum, key);
                    v[p] += mm;
                    z = v[p];
                }

                y = v[0];
                const mn = this.mx(y, z, p, e, sum, key);
                v[un - 1] += mn;
                z = v[un - 1];
            }

        } else if (n < -1) {
            const un = (-n) >>> 0;
            if (rounds === 0) {
                rounds = Math.floor(6 + 52 / (un));
            }

            sum = rounds * delta;
            y = v[0];

            for (i = 0; i < rounds; i++) {
                e = (sum >>> 2) & 3;
                for (p = un - 1; p > 0; p--) {
                    z = v[p - 1];
                    v[p] -= this.mx(y, z, p, e, sum, key);
                    y = v[p];
                }

                z = v[un - 1];
                v[0] -= this.mx(y, z, p, e, sum, key);
                y = v[0];
                sum -= delta;
            }
        }
        return v
    },
    mx(y: number, z: number, p: number, e: number, sum: number, key: Uint32Array): number {
        return (((z >>> 5) ^ (y << 2)) + ((y >>> 3) ^ (z << 4))) ^ ((sum ^ y) + (key[(p & 3) ^ e] ^ z));
    }
}

const timeTools = {
    // 将本地时间转换成 unix时间戳并保留后6位
    localTimeToUnixWithSixDecimal(localTime: Date): string {
        const unixTime = Math.floor(localTime.getTime() / 1000);
        const unixTimeStr = unixTime.toString();
        const decimalPart = (localTime.getTime() % 1000 / 1000).toFixed(6).substr(2);
        return `${unixTimeStr}.${decimalPart}`;
    },
    // 解析 unix 时间戳
    UnixWithSixDecimalToLocalTime(unixTimeStr: number): string {
        const date = new Date(unixTimeStr * 1000); // 将时间戳乘以1000转换为毫秒
        // 转换为本地日期和时间格式
        return date.toLocaleString();
    }
}

export const byteTools = {
    bytesToUint32(data: Buffer, inLen: number, outLen: number, padding: boolean): Uint32Array {
        const out = new Array(outLen);
        for (let i = 0; i < inLen; i++) {
            out[i >>> 2] = (out[i >>> 2] || 0) | (data[i] & 0xff) << ((i & 3) << 3);
        }

        if (padding) {
            let pad = 4 - (inLen & 3);
            if (inLen < 4) {
                pad += 4;
            }

            for (let i = inLen; i < inLen + pad; i++) {
                out[i >>> 2] = out[i >>> 2] | pad << ((i & 3) << 3);
            }
        }

        return Uint32Array.from(out);
    },
    uint32sToBytes(inArr: Uint32Array, inLen: number, padding: boolean): Uint8Array {
        inLen = inLen || inArr.length
        const out = new Array(inLen * 4);

        for (let i = 0; i < inLen; i++) {
            const idx = i * 4;
            out[idx] = inArr[i] & 0xff;
            out[idx + 1] = (inArr[i] >>> 8) & 0xff;
            out[idx + 2] = (inArr[i] >>> 16) & 0xff;
            out[idx + 3] = (inArr[i] >>> 24) & 0xff;
        }

        let outLen = inLen * 4;

        if (padding) {
            const pad = out[outLen - 1];
            outLen -= pad;

            if (pad < 1 || pad > 8) {
                return Uint8Array.from([-1]);
            }

            if (outLen < 0) {
                return Uint8Array.from([-2]);
            }

            for (let i = outLen; i < inLen * 4; i++) {
                if (out[i] !== pad) {
                    return Uint8Array.from([-3]);
                }
            }
        }

        return Uint8Array.from(out.slice(0, outLen));
    },
    jsonObjToUint8Array(obj: object): Uint8Array {
        // 关闭斜杠的转义
        const jsonString = JSON.stringify(obj, null).replace(/\//g, '\\/');
        const encoder = new TextEncoder();
        return encoder.encode(jsonString);
    },
    uint8Array2JsonObj(uint8Array: Uint8Array): Object {
        const decoder = new TextDecoder("utf-8");
        const jsonString = decoder.decode(uint8Array);
        return JSON.parse(jsonString);
    }
}

/**
 * xbs数据解密转 jsonbBuffer
 * @param buffer
 * @constructor
 */
export const XBS2Json = (buffer: Buffer) => {
    try {
        let out = xxteaTools.decrypt(buffer, (xxTeaKey as any), false, 0);
        let n = buffer.length;
        n = n - 4;
        let m = new DataView(out.buffer, n, 4).getUint32(0, true);
        if (m < n - 3 || m > n) {
            throw new Error('decode error');
        }
        n = m;
        return new Uint8Array(out.buffer, 0, n);
    } catch (error) {
        throw error;
    }
}

export const Json2XBS = (buffer: Buffer) => {
    const buffer_len = buffer.length;
    let n = 0;
    let buffer_enc_len = new Uint8Array();

    if (buffer_len % 4 === 0) {
        n = buffer_len >> 2;
    } else {
        n = (buffer_len >> 2) + 1;
    }

    for (let i = buffer_len; i < n << 2; i++) {
        buffer_enc_len = new Uint8Array([...buffer_enc_len, 0x0]);
    }

    buffer_enc_len = new Uint8Array([...buffer_enc_len, ...new Uint8Array(new Uint32Array([buffer_len]).buffer)]);

    const newBuffer = new Uint8Array([...buffer, ...buffer_enc_len]);
    return xxteaTools.encrypt((newBuffer as any), (xxTeaKey as any), false, 0);
}
