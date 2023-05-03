'use strict';

const {Service} = require('ee-core');
const {net} = require('electron');

const xxTeaKey = [0xe5, 0x87, 0xbc, 0xe8, 0xa4, 0x86, 0xe6, 0xbb, 0xbf, 0xe9, 0x87, 0x91, 0xe6, 0xba, 0xa1, 0xe5];

const delta = 0x9e3779b9;

const xxteaTools = {

    /**
     * 解密
     * @param data
     * @param key
     * @param padding
     * @param rounds
     * @returns {Uint8Array|number}
     */
    decrypt(data, key, padding, rounds) {
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
        const refBuf = byteTools.uint32sToBytes(d, aLen, padding);
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

    /**
     * 加密
     * @param data
     * @param key
     * @param padding
     * @param rounds
     * @returns {number|Uint8Array}
     */
    encrypt(data, key, padding, rounds) {
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

    /**
     * 加密算法
     * @param v
     * @param n
     * @param key
     * @param rounds
     * @returns {*}
     */
    btea(v, n, key, rounds) {
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

    /**
     * 字符加密
     * @param y
     * @param z
     * @param p
     * @param e
     * @param sum
     * @param key
     * @returns {number}
     */
    mx(y, z, p, e, sum, key) {
        return (((z >>> 5) ^ (y << 2)) + ((y >>> 3) ^ (z << 4))) ^ ((sum ^ y) + (key[(p & 3) ^ e] ^ z));
    }
}

const byteTools = {
    bytesToUint32(data, inLen, outLen, padding) {
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
    uint32sToBytes(inArr, inLen, padding) {
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
                return -1;
            }

            if (outLen < 0) {
                return -2;
            }

            for (let i = outLen; i < inLen * 4; i++) {
                if (out[i] !== pad) {
                    return -3;
                }
            }
        }

        return Uint8Array.from(out.slice(0, outLen));
    },
    jsonObjToUint8Array(obj) {
        // 关闭斜杠的转义
        const jsonString = JSON.stringify(obj, null).replace(/\//g, '\\/');
        const encoder = new TextEncoder();
        return encoder.encode(jsonString);
    },
    uint8Array2JsonObj(uint8Array) {
        const decoder = new TextDecoder("utf-8");
        const jsonString = decoder.decode(uint8Array);
        return JSON.parse(jsonString);
    }
}

const requestTools = {
    get(url, params, headers) {
        // 1. 新建 net.request 请求
        const request = net.request({
            headers: headers,
            method: 'GET',
            url: url,
        })
        // 2. 通过 request.write() 方法，发送的 post 请求数据需要先进行序列化，变成纯文本的形式
        request.write(JSON.stringify(userInfo))

        // 3. 处理返回结果
        request.on('response', response => {
            response.on('data', res => {
                // res 是 Buffer 数据
                // 通过 toString() 可以转为 String
                // 详见： https://blog.csdn.net/KimBing/article/details/124299412
                let data = JSON.parse(res.toString())
                console.log("response:", data)
            })
            response.on('end', () => {
            })
        })

        // 4. 记得关闭请求
        request.end()


    },
    post(url, data, headers) {
        // 1. 新建 net.request 请求
        const request = net.request({
            headers: headers,
            method: 'POST',
            url: url,
        })
        // 2. 通过 request.write() 方法，发送的 post 请求数据需要先进行序列化，变成纯文本的形式
        request.write(JSON.stringify(data))
        // 3. 处理返回结果
        request.on('response', response => {
            response.on('data', res => {
                // res 是 Buffer 数据
                // 通过 toString() 可以转为 String
                // 详见： https://blog.csdn.net/KimBing/article/details/124299412
                let data = JSON.parse(res.toString())
                console.log("response:", data)
            })
            response.on('end', () => {
            })
        })

        // 4. 记得关闭请求
        request.end()
    }
}

/**
 * xpath解析器
 */
class XPathParser {

    str
    xpath

    constructor(str, xpath) {
        this.str = str
        this.xpath = xpath
    }

    raw() {
    }

    // 返回内容
    content() {
    }

    // 返回字符串
    tagName() {
    }

    // 返回字典
    attributes() {
    }

    // 返回查询结果，以数组保存
    queryWithXPath(strXPath) {
    }
}

/**
 * 书源处理
 */
class SourceTools {

    // 存放源内容
    sourceObject
    // 存放的是当前某一项功能的json内容，比如 searchBook
    config
    // 存储工具等
    params = {
        nativeTool: {
            // 打印log，key使用时间截
            log(obj) {

            },
            // 打印log并自定义key
            logWithKey(obj, strKey) {

            },
            // 将任意对象转换为字符串
            stringByObject(obj) {

            },

            // 默认的本地设备id，32位md5小写
            deviceId() {

            },

            // 自定义格式的本地设备id，strTemplate为模版，aaa-aa-aaaa，这里使用-分为3段，每段第一个字符将标识该段类型：0为纯数字，a为纯字母小写，A为纯字母大写，b为字符(数字+字母)小写，B为字符(数字+字母)大写，默认的deviceId模版即为：bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
            deviceIdWithTemplateWithSeparator(strTemplate, strSeparator) {

            },
            // base64解码，返回字符串
            base64Decode(str) {

            },
            // base64编码，返回字符串
            base64Encode(str) {
            },

            // 对二进制流(NSData)base64编码，返回字符串
            base64EncodeWithData(data) {
            },

            // 从path中读取文件，返回二进制流
            readFile(strPath) {
            },
            // 从path中读取文件，返回字符串
            readTxtFile(strPath) {
            },
            // 解压zip文件，返回目录path
            unzipFile(strPath) {
            },
            // 使用密码解压zip文件，返回目录path
            unzipFileWithPassword(strPath, strPassword) {
            },
            // 获取path目录下所有的文件path，返回数组:arr(path)
            allFilesAtPath(strDirPath) {
            },
            // 获取全局缓存对象
            getCache(strKey) {
            },
            // 设置全局缓存对象
            setCache(strKey, obj) {
            },

            // 返回sha1
            sha1Encode(str) {
            },
            // 返回md5
            md5Encode(str) {
            },
            // 返回字符串
            cookieByKey(str) {
            },
            // 返回数组
            cookiesByUrl(url) {
            },
            // 创建XPath解析器，可用于下面XPath解析器专用接口
            XPathParserWithSource(str) {
            },
        },
        responseUrl() {
        }
    }
    // 存放结果
    result

    constructor(sourceJson) {
        if (typeof sourceJson === 'object') {
            for (const name in sourceJson) {
                if (typeof sourceJson[name] === 'object' && sourceJson[name]['sourceName']) {
                    this.sourceObject = sourceJson
                }
            }
        }
        // 解析源
    }

    /**
     * 书籍搜索
     * @param keyWord
     * @param type
     * @param offset
     * @param pageIndex
     */
    searchBook(keyWord, type, offset, pageIndex) {
        const searchBookConfig = this.sourceObject.searchBook
        if (!keyWord) {
            console.error(`empty search string for this source: ${sourceObject['sourceName']}`)
            return null
        }
        if (this.sourceObject['sourceType'] !== type) {
            console.error(`error search type[${type}] for this source: ${sourceObject['sourceName']}`)
            return null
        }
        if (!searchBookConfig) {
            console.error(`error search config for this source: ${sourceObject['sourceName']}`)
            return null
        }

        // 处理config params
        this.config = searchBookConfig

        this.params = {// 不要覆盖掉原有的方法
            ...this.params, ...{
                // 这三个是之前需要处理好的
                keyWord: keyWord || '', // 需要转Unicode？
                offset: offset || 0,
                pageIndex: pageIndex || 1,
            }
        }
        // 处理请求信息
        this.buildRequestUrl()

        // 执行请求


        // 填入结果


        // 处理 requestInfo host httpParams
    }

    /**
     * 处理请求信息，处理结果填入 params.requestUrls(数组？)
     */
    buildRequestUrl() {
        // 处理普通url，占位符，@js，url还需要按需接上url
        const {requestInfo, host, httpHeaders} = this.config

        const result = {
            url: '', // 字符串，要请求的url
            POST: false, // 默认false，使用get请求
            httpParams: {}, // http请求参数
            httpHeaders: {}, // http请求头
            forbidCookie: false, // 默认false，true时禁用cookie
        }

        if (!requestInfo) {
            return result;
        }
        const requestPipe = this.pipeStr(requestInfo)

        requestPipe.forEach(req => {
            switch (req.type) {
                case 'function': {
                    // js的返回值有两种情况，1 返回 object;2 返回 string 直接作为 url
                    break
                }
                case 'xpath': {
                    break
                }
                case 'uri': {
                    // 需要填充
                    break
                }
            }
        })
    }

    /**
     * 处理响应结果，处理结果填入到 result，根据请求位置不同写入不同的内容
     * 比如搜索书籍是 result.list
     */
    buildResponse() {

    }

    /**
     * 执行请求，响应信息填入到 params.responseHeaders(响应头) 和 responseUrl
     */
    requestUrl() {

    }

    /**
     * 处理管道 || 和 js
     * @param str
     * @returns {*[]}
     */
    pipeStr(str) {
        const res = []

        const setFunc = (funStr) => {
            if (str.indexOf("@js") >= 0 || str.indexOf("@js:") >= 0) {
                // 存在js，这需要判断是否存在 || 管道连接
                const jsStr = "";
                const resItem = {
                    type: 'function', // function/string
                    callback: (config, params, result) => {
                        // 执行js，这里需要用到局部作用域，所以还是使用 eval
                        return eval(jsStr);
                    }
                }
                res.push(resItem)
            } else {

            }
        }

        /**
         * 剥离js
         * 利用正则匹配来区分这两部分，string 和 js；
         * string部分自行判断是xpath还是uri
         *
         * @param input
         */
        const parseStringAndJs = (input) => {
            const trimmedStr = input.trim();
            const jsPrefix = "@js:";
            const parts = trimmedStr.split(jsPrefix);

            if (parts.length === 1) {
                return {type: "string", stringPart: trimmedStr};
            }

            let jsPart = parts.pop().trim();
            let stringPart = parts.join(jsPrefix).trim();

            if (stringPart.endsWith("||")) {
                stringPart = stringPart.slice(0, -2).trim();
            }

            if (jsPart.startsWith("\n")) {
                jsPart = jsPart.slice(1);
            }

            if (jsPart.startsWith("\t")) {
                jsPart = jsPart.slice(1);
            }

            return {
                type: "mixed",
                stringPart: stringPart,
                jsPart: jsPart
            };
        }

        //
        let parseRes = parseStringAndJs(str);
        // 有个先后顺序的问题
        if (!parseRes.stringPart) {
            const inputStr = parseRes.stringPart
            // TODO 剥离剩余的内容，是 string还是语法糖


            // 全当 string 处理，根据来源自行区分是uri还是xpath
            res.push({
                type: 'string', // function/string
                content: (config, params, result) => {
                    // 执行js，存在替换的问题
                    const {keyWord, pageIndex, offset, filter} = params
                    let resStr = inputStr.replaceAll(`%@keyWord`, keyWord)
                        .replaceAll(`%@pageIndex`, pageIndex)
                        .replaceAll(`%@offset`, offset)
                        .replaceAll(`%@filter`, filter)

                    // result 如果要参与替换，内容只能是字符串
                    if (typeof result === 'string') {
                        resStr = resStr.replaceAll(`%@result`, result)
                    }
                    return resStr
                }
            })
        }

        if (!parseRes.jsPart) {
            res.push({
                type: 'function', // function/string
                callback: (config, params, result) => {
                    // 执行js，这里需要用到局部作用域，所以还是使用 eval
                    return eval(jsStr);
                }
            })
        }

        return res
    }

}

/**
 * xbs 工具
 */
class XbsToolService extends Service {
    constructor(ctx) {
        super(ctx);
    }

    /**
     * xbs buffer 转 json buffer
     * @param buffer
     * @returns {Uint8Array}
     * @constructor
     */
    XBS2Json(buffer) {
        try {
            let out = xxteaTools.decrypt(buffer, xxTeaKey, false, 0);
            let n = buffer.length;
            n = n - 4;
            let m = new DataView(out.buffer, n, 4).getUint32(0, true);
            if (m < n - 3 || m > n) {
                throw new Error('decode error');
            }
            n = m;
            return new Uint8Array(out.buffer, 0, n);
        } catch (error) {
            throw new Error(error);
        }
    }

    /**
     * json buffer 转 xbs buffer
     * @param buffer
     * @returns {number|Uint8Array}
     * @constructor
     */
    Json2XBS(buffer) {
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

        buffer = new Uint8Array([...buffer, ...buffer_enc_len]);
        return xxteaTools.encrypt(buffer, xxTeaKey, false, 0);
    }

    /**
     * uint8Array转JsonObj
     * @param uint8Array
     * @returns {any}
     */
    uint8Array2JsonObj(uint8Array) {
        return byteTools.uint8Array2JsonObj(uint8Array)
    }

    /**
     * 将本地时间转换成 unix时间戳并保留后6位
     * @param localTime
     * @returns {string}
     */
    localTimeToUnixWithSixDecimal(localTime) {
        const unixTime = Math.floor(localTime.getTime() / 1000);
        const unixTimeStr = unixTime.toString();
        const decimalPart = (localTime.getTime() % 1000 / 1000).toFixed(6).substr(2);
        return `${unixTimeStr}.${decimalPart}`;
    }

    /**
     * 解析 unix 时间戳
     * @param unixTimeStr
     * @returns {string}
     * @constructor
     */
    UnixWithSixDecimalToLocalTime(unixTimeStr) {
        const date = new Date(unixTimeStr * 1000); // 将时间戳乘以1000转换为毫秒
        // 转换为本地日期和时间格式
        return date.toLocaleString();
    }

    /**
     * 压缩json并转字符串
     *
     * @param {Object} jsonStr 包含空白字符（\t、\n、\s）的json字符串
     */
    compressJson(jsonStr) {
        return JSON.stringify({...jsonStr}, (key, value) => {
            const type = typeof value
            if (key === 'weight') {
                return value + ""
            }
            if (key === 'enable') {
                return key ? 1 : 0
            }
            return value
        }).replace(/\//g, '\\/')
            .replaceAll('\r', '')
            .replaceAll('\n', '')
            .replaceAll('\t', '')
            .replaceAll(': "', ':"');
    }

    /**
     * 搜索书籍
     * @param sourceJson 源
     * @param search 搜索名称
     * @param type 类型
     */
    searchBook(sourceJson, search, type) {
        const sourceTools = new SourceTools(sourceJson);
        const searchRes = sourceTools.searchBook(search, type)
    }
}

XbsToolService.toString = () => '[class XbsToolService]';
module.exports = XbsToolService;
