'use strict';

const {Service} = require('ee-core');
const {net} = require('electron');
const iconv = require('iconv-lite')
const querystring = require('querystring');
const xpath = require('xpath')
const jp = require("jsonpath")
const dom = require('xmldom').DOMParser

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
    /**
     * 发起请求
     * @param url
     * @param data
     * @param headers
     * @param method
     * @param encode
     * @returns {Promise<unknown>}
     */
    request(url, data, headers, method, encode) {
        if (data) {
            for (const key in data) {
                let val = data[key];
                if (val === null || (typeof val === "undefined")) {
                    continue
                }
                if (typeof val === 'string' && /[^\x00-\xff]/.test(val)) {
                    // 处理非 utf-8 编码
                    if (encode === 'gbk' || encode === 'gb2312') {
                        val = iconv.encode(val, 'gbk')
                            .toString('hex').toUpperCase()
                            .replace(/.{2}/g, '%$&');
                    }
                }
                if (url.indexOf("?") > 0) {
                    if (url.endsWith("?")) {
                        url += `${key}=${val}`
                    } else {
                        url += `&${key}=${val}`
                    }
                } else {
                    url += `?${key}=${val}`
                }
            }
        }
        return new Promise((resolve, reject) => {
            let timer = null
            try {
                timer = setTimeout(() => {
                    request.abort();
                    reject(new Error(`http connect [${url}] time out`))
                }, 10000);
                const request = net.request({
                    headers: headers,
                    method: method,
                    url: url,
                    timeout: 2000
                })

                request.on('response', response => {
                    clearTimeout(timer)
                    resolve(response)
                })
                request.on('error', (error) => {
                    clearTimeout(timer)
                    reject(error);
                });
                request.on('redirect', (statusCode, method, redirectUrl, responseHeaders) => {
                    console.log("http request has been redirected!")
                });
                request.on('timeout', () => {
                    clearTimeout(timer)
                    request.abort();
                });

                request.end();
            } catch (e) {
                reject(e)
            }
        })
    },
    get(url, params, headers, encode) {
        return this.request(url, params, headers, "GET", encode)
    },
    async post(url, data, headers, encode) {
        return this.request(url, params, headers, "POST", encode)
    }
}

const SourceType = [
    {
        name: 'text',
        label: '文本/小说'
    },
    {
        name: 'comic',
        label: '图片/漫画/壁纸'
    },
    {
        name: 'audio',
        label: '音频/音乐/听书'
    },
    {
        name: 'video',
        label: '视频/电影/电视剧'
    }
]

const RequestParamsEncode = [
    {
        name: 'utf-8',
        label: 'utf-8',
        default: true
    },
    {
        name: '2147485234',
        label: 'gbk'
    }
]

const ResponseEncode = [
    {
        name: 'utf-8',
        label: 'utf-8'
    },
    {
        name: '2147485232',
        label: '简体中文(gb2312)'
    },
    {
        name: '2147485234',
        label: '简体中文(gbk)'
    }
]

// TODO
const ResponseFormatType = [
    {
        name: 'str',
        label: '普通字符串'
    },
    {
        name: 'base64str',
        label: 'Base64字符串(base64str)'
    },
    {
        name: 'html',
        label: '格式化为DOM(html)'
    },
    {
        name: 'xml',
        label: '格式化为数组/字典(xml)'
    },
    {
        name: 'json',
        label: '格式化为数组/字典(json)'
    },
    {
        name: 'data',
        label: '使用原始数据流(data)'
    },
    {
        name: 'filePath',
        label: '存储为文件并返回路径(filePath)'
    },
]

const SourcePlatform = [
    {
        name: 'StandarReader',
        label: '香色闺阁',
        default: true
    },
]

const SourceTemplate = {
    "chapterContent": {"actionID": "chapterContent", "parserID": "DOM"},
    "enable": 1,
    "shupingList": {"actionID": "shupingList", "parserID": "DOM"},
    "bookDetail": {"actionID": "bookDetail", "parserID": "DOM"},
    "shudanList": {},
    "bookWorld": {},
    "sourceUrl": "",
    "relatedWord": {"actionID": "relatedWord", "parserID": "DOM"},
    "weight": "1000",
    "sourceName": '',
    "sourceType": "text",
    "miniAppVersion": "2.53.2",
    "shudanDetail": {"actionID": "shudanDetail", "parserID": "DOM"},
    "lastModifyTime": "",
    "shupingHome": {"actionID": "shupingHome", "parserID": "DOM"},
    "searchShudan": {"actionID": "searchShudan", "parserID": "DOM"},
    "searchBook": {"actionID": "searchBook", "parserID": "DOM"},
    "chapterList": {"actionID": "chapterList", "parserID": "DOM",}
}

const utils = {
    objNull(obj) {
        if (Object.keys(obj).length === 0) {
            console.log("The object is empty");
        }
    }
}

class JsonPathParser {
    str
    element

    constructor(content) {
        if (typeof content === 'object') {
            this.element = content
            this.str = JSON.stringify(content)
        } else {
            this.str = content
            try {
                this.element = JSON.parse(content)
            } catch (e) {
                this.element = content
            }
        }
    }

    row() {
        return this.str
    }

    content() {
        if (this.element) {
            if (Array.isArray(this.element)) {
                if (this.element.length === 1) {
                    return new JsonPathParser(this.element[0]).content()
                }
            } else {
                if (Object.keys(this.element).length === 1) {
                    const firstKey = Object.keys(this.element)[0]
                    return new JsonPathParser(this.element[firstKey]).content()
                }
            }
        }
        return this.element
    }

    attributes() {

    }

    queryWithPath(path) {

    }

}

/**
 * xpath解析器
 */
class XPathParser {

    str
    xpath
    domBody
    element

    constructor(content) {
        this.xpath = xpath
        if (content) {
            if (typeof content === 'string') {
                // 处理 xhtml 格式问题
                content = content.replace(/<html\s.*?>/g, "<html>");
                this.str = content
                this.domBody = new dom().parseFromString(content)
                this.element = this.domBody.documentElement
            }
            if (typeof content === 'object') {
                // TODO 怎么处理？
                this.domBody = content
                this.element = this.domBody
                this.str = content.toString()
            }
        }
    }

    raw() {
        return this.str;
    }

    // 返回内容
    content() {
        if (this.element) {
            if (this.element.hasOwnProperty("data")) {
                return this.element.data
            }
            if (this.element.hasOwnProperty("value")) {
                return this.element.value
            }
            if (this.element.hasOwnProperty("firstChild")) {
                return new XPathParser(this.element.firstChild).content()
            }
            if (this.element) {
                return this.element.toString()
            }
        }
        return null
    }

    // 返回字符串
    tagName() {
        if (this.element) {
            return this.element.tagName
        }
        return null
    }

    // 返回字典
    attributes() {
        if (this.element) {
            return this.element.attributes
        }
        return null
    }

    // 返回查询结果，以数组保存
    queryWithXPath(strXPath) {
        try {
            if (strXPath === "|") {
                strXPath = "."
            }

            if (this.domBody) {
                return xpath.select(strXPath, this.domBody)
            }

            if (this.element) {
                return xpath.select(strXPath, this.element)
            }
        } catch (e) {
            console.error(`xpath tag [${strXPath}] parse failure`)
            return null
        }
        return null
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
                return new XPathParser(str)
            },
        },
        keyWord: '',
        offset: 0,
        pageIndex: 1,
        requestUrls: [],
        responseUrl: '',
        responseHeaders: {},
        queryInfo: {
            contentUrl: "",
        },
        lastResponse: {}, // result，两次相同则停止
    }
    // 存放结果
    result
    // 存储请求信息
    reqInfo
    // 存储响应信息
    resInfo
    // 存储当前解析有哪些path
    tagPath
    // 存储返回结果的格式
    resultTemplate
    // 返回结果中的主要内容
    templateMainKey

    constructor(sourceJson) {
        if (typeof sourceJson === 'object') {
            for (const name in sourceJson) {
                if (typeof sourceJson[name] === 'object' && sourceJson[name]['sourceName']) {
                    this.sourceObject = sourceJson[name]
                    // 处理默认值
                    this.sourceObject['sourceType'] = this.sourceObject['sourceType'] || "text"
                }
            }
        }
        // 解析源
    }

    //<editor-fold desc="public方法">

    /**
     * 书籍搜索
     * @param type
     * @param queryInfo
     */
    async searchBook(type, queryInfo) {
        const searchBookConfig = this.sourceObject.searchBook

        return new Promise(async (resolve, reject) => {
            const {keyWord, offset, pageIndex} = queryInfo

            if (!keyWord) {
                console.error(`empty search string for this source: ${sourceObject['sourceName']}`)
                reject(new Error(`empty search string for this source: ${sourceObject['sourceName']}`))
            }
            if (this.sourceObject['sourceType'] !== type) {
                console.error(`error search type[${type}] for this source: ${sourceObject['sourceName']}`)
                reject(new Error(`error search type[${type}] for this source: ${sourceObject['sourceName']}`))
            }
            if (!searchBookConfig) {
                console.error(`error search config for this source: ${sourceObject['sourceName']}`)
                reject(new Error(`error search config for this source: ${sourceObject['sourceName']}`))
            }

            // 处理config params
            this.config = searchBookConfig

            this.params = {// 不要覆盖掉原有的方法
                ...this.params, ...queryInfo
            }
            this.tagPath = [{
                tag: "list",
                child: [{tag: 'bookName'}, {tag: 'author'},
                    {tag: 'cover', type: 'url'}, {tag: 'desc'}, {tag: 'status'},
                    {tag: 'wordCount'}, {tag: 'lastChapterTitle'}, {tag: 'detailUrl'}]
            }]
            this.resultTemplate = {
                list: [],
                maxPage: 1,
                success: true,
                listLengthOnlyDebug: 1,
            }
            this.result = this.resultTemplate

            try {
                // 处理请求信息
                await this.buildRequestUrl()

                // 执行请求
                await this.requestUrl()

                // 填入结果
                await this.buildResponse()

                // 处理 requestInfo host httpParams
                resolve({
                    config: this.config,
                    params: this.params,
                    result: this.result || []
                })
            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     * 书籍详情
     * @param queryInfo
     * @returns {Promise<unknown>}
     */
    async bookDetail(queryInfo) {
        const searchConfig = this.sourceObject.searchBook
        const bookDetailConfig = this.sourceObject.bookDetail
        const chapterListConfig = this.sourceObject.chapterList

        return new Promise(async (resolve, reject) => {
            const {detailUrl} = queryInfo
            if (!detailUrl) {
                reject(`error book detail url [${detailUrl}]`)
            }

            // 处理 config，由于 detail 可能不配置，所以需要结合两个配置
            const detailConfig = {
                ...bookDetailConfig, ...{
                    host: searchConfig.host,
                    httpHeaders: searchConfig.httpHeaders,
                }
            }

            // 存储url，后面要用
            this.result = detailUrl
            this.config = detailConfig
            this.params.queryInfo = queryInfo
            // 处理config中的 requestInfo 被 search 覆盖的问题
            if (!detailConfig['requestInfo']) {
                detailConfig['requestInfo'] = detailUrl
            }

            try {
                this.buildRequestUrl()

                // 执行请求
                await this.requestUrl()

                // 处理详情内容
                this.result = queryInfo
                this.tagPath = [{tag: 'cover', type: 'url'}, {tag: 'desc'}, {tag: 'status'},
                    {tag: 'wordCount'}, {tag: 'lastChapterTitle'}]
                // 填入结果
                await this.buildResponse()
                let detailResult = {}
                if (detailConfig.hasOwnProperty("validConfig")) {
                    detailResult = this.result
                }


                // 处理章节列表
                this.result = detailUrl
                const chapterConfig = {
                    ...detailConfig, ...chapterListConfig, ...{
                        host: searchConfig.host,
                        httpHeaders: searchConfig.httpHeaders,
                    }
                }
                this.config = chapterConfig
                if (chapterConfig['requestInfo'] !== detailConfig['requestInfo']) {
                    // 重新请求
                    this.buildRequestUrl()

                    // 执行请求
                    await this.requestUrl()
                }

                this.tagPath = [{
                    tag: "list",
                    type: "list",
                    child: [{tag: 'title'}, {tag: 'url', type: 'url'}]
                }, {tag: "nextPageUrl"}, {tag: 'updateTime'}]
                this.resultTemplate = {
                    list: [],
                    success: true,
                    autoRequestMore: true,
                    nextPageUrl: '',
                    more: true,
                    maxPage: 1,
                }
                this.templateMainKey = "list"
                this.config = chapterListConfig
                // 填入结果
                await this.buildResponse()

                // 下一页
                await this.nextPage()

                const chapterList = {...this.result}

                resolve({
                    config: this.config,
                    params: this.params,
                    detail: detailResult || {},
                    chapter: chapterList || []
                })

            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     * 获取章节内容
     * @param queryInfo
     * @returns {Promise<void>}
     */
    async bookContent(queryInfo) {
        const {chapterContent} = this.sourceObject
        return new Promise(async (resolve, reject) => {
            const chapterUrl = queryInfo.url
            if (!chapterUrl) {
                reject(`error book content url [${chapterUrl}]`)
            }
            this.config = chapterContent
            this.result = chapterUrl
            this.params.queryInfo = queryInfo

            if (!chapterContent['requestInfo']) {
                chapterContent['requestInfo'] = chapterUrl
            }
            try {
                // 处理详情内容
                this.tagPath = [{tag: 'content'}, {tag: 'nextPageUrl'}]

                this.resultTemplate = {
                    content: "",
                    removeHtmlKeys: '',
                    nextPageUrl: '',
                    maxPage: 1,
                    autoRequestMore: true,
                    success: 1 || true,
                    more: true,
                }
                this.templateMainKey = 'content'
                this.result = this.resultTemplate
                this.buildRequestUrl()

                // 执行请求
                await this.requestUrl()

                // 填入结果
                await this.buildResponse()

                // 下一页
                await this.nextPage()

                if (typeof this.result === 'string') {
                    this.result.content = this.result
                }
                if (typeof this.result === 'object') {
                    this.result = {...this.result}
                }
                resolve({
                    config: this.config,
                    params: this.params,
                    result: this.result || {}
                })
            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     *
     * @returns {Promise<void>}
     */
    async nextPage() {
        this.result = {
            ...this.resultTemplate, ...this.result
        }

        const {config, result, params} = this

        if (!config.hasOwnProperty("moreKeys")
            || !config.moreKeys.hasOwnProperty("maxPage")) {
            return this.result
        }
        const {moreKeys} = config
        this.result.removeHtmlKeys = moreKeys.moreKeys
        this.result.maxPage = moreKeys.maxPage
        this.result.pageSize = moreKeys.pageSize
        if (!result.autoRequestMore || !config.nextPageUrl) {
            this.result.autoRequestMore = false
            this.result.more = false
            return this.result
        }
        // 缓存result
        params.lastResponse = {...result}
        let resultMerge = {...params.lastResponse}

        // 存在 nextPageUrl
        for (let page = params.pageIndex; page <= moreKeys.maxPage; page++) {
            console.log("begin next page", page)
            params.pageIndex = page
            let resultTemp = {}

            // 请求
            this.result = config.nextPageUrl
            config.requestInfo = config.nextPageUrl
            // 重新请求
            this.buildRequestUrl()

            // 执行请求
            await this.requestUrl()

            // 填入结果
            await this.buildResponse()

            resultTemp = {
                ...this.resultTemplate, ...this.result
            }

            // 判断两次获取的临时内容是否一致，一致则跳出循环
            if (params.lastResponse[this.templateMainKey] === resultTemp[this.templateMainKey]) {
                result.more = false
                console.log("stop next page")
                break
            }

            // 合并两次的result
            // 这里覆盖除 mainKey 以外的数据
            for (const key in resultTemp) {
                if (key !== this.templateMainKey) {
                    this.result[key] = resultTemp[key]
                    resultMerge[key] = resultTemp[key]
                }
            }

            // 处理 mainKey 的数据，合并result和resultTemp
            if (typeof resultTemp[this.templateMainKey] === 'string') {
                resultMerge[this.templateMainKey] += resultTemp[this.templateMainKey]
            }
            if (typeof resultTemp[this.templateMainKey] === 'object') {
                if (Array.isArray(resultTemp[this.templateMainKey])) {
                    resultMerge[this.templateMainKey] = [...resultMerge[this.templateMainKey], ...resultTemp[this.templateMainKey]]
                    resultMerge.listLengthOnlyDebug = resultMerge[this.templateMainKey].length
                } else {
                    resultMerge[this.templateMainKey] = {...resultMerge[this.templateMainKey], ...resultTemp[this.templateMainKey]}
                }
            }

            // 缓存本次result
            params.lastResponse = resultTemp

        }
        this.result = resultMerge
        return this.result
    }

    //</editor-fold>

    //<editor-fold desc="对源的处理">

    /**
     * 处理请求信息，处理结果填入 params.requestUrls(数组？)
     */
    async buildRequestUrl() {
        // 处理普通url，占位符，@js，url还需要按需接上url
        const {requestInfo, host, httpHeaders} = this.config

        // 除了 httpHeaders默认存储在config，其余都只有默认值，
        this.reqInfo = {
            url: '', // 字符串，要请求的url
            POST: false, // 默认false，使用get请求
            httpParams: {}, // http请求参数
            httpHeaders: this.config.httpHeaders || {}, // http请求头
            forbidCookie: false, // 默认false，true时禁用cookie
            webView: {}, // 不为空时使用webView请求完整的网页
            webViewJs: "", // 字符串，webView请求完成后执行的js
            webViewJsDelay: 0, // 正整数，webView完成后延时执行js，默认1秒
            webViewSkipUrls: [], // 数组，webView要跳过的url，可跳过无关的请求
            sourceRegex: "", // 字符串正则表达式，嗅探资源url
        }

        if (!requestInfo) {
            return;
        }
        const requestPipe = this.pipeStr(requestInfo)

        // 管道运行时，result的临时存储
        let resultTemp = this.result;
        // 执行
        for (let i = 0; i < requestPipe.length; i++) {
            const pipe = requestPipe[i]
            if (!pipe || !pipe.type) {
                continue;
            }
            // js的返回值有两种情况，1 返回 object;2 返回 string 直接作为 url
            resultTemp = pipe.callback(this.config, this.params, resultTemp)
        }

        // 处理最终执行结果
        const resType = typeof resultTemp
        switch (resType) {
            case "string": {
                this.reqInfo.url = resultTemp
                break
            }
            case "object": {
                // 如果在js中，有配置result中的内容，就覆盖掉默认值
                this.reqInfo = {...this.reqInfo, ...resultTemp}
            }
        }
        // 补充请求地址
        if (!this.reqInfo.url.startsWith("http")) {
            const {host} = this.config
            if (host.endsWith("/")) {
                // 去掉最后的/
                host.slice(0, host.length - 1)
            }
            this.reqInfo.url = `${host}${this.reqInfo.url.startsWith("/") ? "" : "/"}${this.reqInfo.url}`
        }

        try {
            new URL(this.reqInfo.url)
        } catch (e) {
            console.log(`error url: [${this.reqInfo.url}]`)
        }

        // url 编码
        this.reqInfo.url = this.reqInfo.url
        this.params.requestUrls = [this.reqInfo.url]
    }

    /**
     * 处理响应结果，处理结果填入到 result，根据请求位置不同写入不同的内容
     * 比如搜索书籍是 result.list
     */
    buildResponse() {
        const {resInfo, config} = this
        if (!resInfo) {
            return;
        }
        this.result = this.resultTemplate
        const encode = this.getEncoding('requestParamsEncode')

        let jsonPath = false
        // 判断响应格式
        switch (config.responseFormatType) {
            case 'base64str': {
                break
            }
            case 'json': {
                // 这里用下面一样的处理方式
                jsonPath = true
            }
            case 'html':
            case 'xml': {
                // 使用 path 解析器
                if (typeof resInfo === 'string') {
                    // 当你归来依旧是string
                    for (const index in this.tagPath) {
                        const tag = this.tagPath[index]
                        const tagPath = tag['tag'];
                        if (!tagPath || !config[tagPath]) {
                            continue
                        }
                        const matchesRes = this.buildPathContent(resInfo, [tag], jsonPath)
                        let matches = new JsonPathParser(matchesRes[tagPath]).content()
                        if (!matches) {
                            continue
                        }
                        if (tag.hasOwnProperty("child")) {
                            if (typeof matches === 'object' && matches && matches.length > 0) {
                                console.log(`node has search [${matches.length}] records`)
                                // ['bookName', 'author', 'cover', 'desc', 'status', 'wordCount', 'lastChapterTitle', 'detailUrl']
                                let pageList = matches.map(item => this.buildPathContent(item, tag.child, jsonPath));
                                this.result = {
                                    maxPage: 1,
                                    success: 1,
                                    list: pageList
                                }
                            }
                        } else {
                            this.result[tagPath] = matches
                        }
                    }
                }

                break
            }
            case 'data': {
                break
            }
            case 'filePath': {
                break
            }
            default: {
                // 按照默认str处理
                // 也就是不处理
                this.result = resInfo
            }
        }

        // 判断是否存在 js 手动解析
        if (this.config["JSParser"]) {
            // 使用js处理内容
            const wrappedJsPart = `(
                ${this.config["JSParser"]}
            )`;
            this.result = (new Function(`return ${wrappedJsPart}`))()(this.config, this.params, resInfo)
            return this.result;
        }
    }

    /**
     * 执行请求，响应信息填入到 params.responseHeaders(响应头) 和 responseUrl
     */
    async requestUrl() {
        const {reqInfo} = this
        if (!reqInfo || !reqInfo.url) {
            return;
        }

        // 禁用cookie
        if (reqInfo.forbidCookie) {
            if (reqInfo.httpHeaders) {
                reqInfo.httpHeaders['Cookie'] = 'none'
            }
        }

        const encode = this.getEncoding('requestParamsEncode')
        return new Promise(async (resolve, reject) => {
            try {
                let response = await requestTools.request(reqInfo.url, reqInfo.httpParams, reqInfo.httpHeaders, reqInfo.POST ? "POST" : "GET", encode)

                if (response) {
                    let data = '';
                    this.params.responseHeaders = response.headers
                    this.params.responseUrl = this.reqInfo.url
                    if (response.url) {
                        this.params.responseUrl = response.url
                    }
                    if (response.responseURL) {
                        this.params.responseUrl = response.responseURL
                    }

                    response.on('data', (chunk) => {
                        // res 是 Buffer 数据
                        const req = new Uint8Array(chunk);
                        const decoder = new TextDecoder(encode || 'utf-8')
                        const resData = decoder.decode(req)
                        data += resData;
                    });
                    response.on('end', () => {
                        this.resInfo = data
                        resolve(data)
                    });
                }
            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     * 获取配置中的编码
     * @param encodeConfigName
     * @returns {string}
     */
    getEncoding(encodeConfigName) {
        let encode = "utf-8"
        if (this.config[encodeConfigName]) {
            switch (this.config[encodeConfigName]) {
                case '2147485232': {
                    encode = "gb2312"
                    break
                }
                case '2147485234': {
                    encode = "gbk"
                    break
                }
            }
        }
        return encode
    }

    /**
     * 将内容通过 xpath 标签命令解析
     * @param content 被解析的内容
     * @param tagNames 标签
     * @param jsonPath 是否是jsonpath
     * @returns {{}|null}
     */
    buildPathContent(content, tagNames, jsonPath) {
        if (!content || !tagNames || tagNames.length < 1) {
            return null
        }
        const {config} = this
        const res = {}
        tagNames.forEach(tag => {
            // 标签解析命令
            const tagName = tag['tag']
            try {
                res[tagName] = this.pathMatch(content, tag, jsonPath)
                if (tag['type'] && tag['type'] === 'url') {
                    res[tagName] = this.addDomain(res[tagName])
                }
            } catch (e) {
                console.error(`parse path tag [${tagName}] for content [${content}] failure!`)
            }
        })

        return res
    }

    /**
     * 为url加上域名
     * @param url
     * @returns {string}
     */
    addDomain(url) {
        if (!url.startsWith("http")) {
            const {host} = this.config
            if (host.endsWith("/")) {
                // 去掉最后的/
                host.slice(0, host.length - 1)
            }
            if (url.startsWith("//")) {
                url = "https:" + url
            } else {
                url = `${host}${url.startsWith("/") ? "" : "/"}${url}`
            }
        }
        return url
    }

    /**
     * 处理path，path可能是 xpath 或者 jsonpath
     * 解析标签包括 path js tagCommand 三种不同
     * @param content 被解析的字符串
     * @param tag 解析标签
     * @param jsonPath 是否是jsonpath
     * @returns {*[]}
     */
    pathMatch(content, tag, jsonPath) {
        const {config} = this
        if (!content || !tag) {
            return null;
        }
        const tagName = tag['tag']
        const tagType = tag['type'] || 'string'
        if (!config.hasOwnProperty(tagName)) {
            return null;
        }
        const tagCommand = config[tagName]
        const commandPipe = this.pipeStr(tagCommand)
        const xPathParser = new XPathParser(content.toString())

        // 管道运行时，result的临时存储
        let resultTemp = content;
        // 执行
        for (let i = 0; i < commandPipe.length; i++) {
            const pipe = commandPipe[i]
            if (!pipe || !pipe.type) {
                continue;
            }
            switch (pipe.type) {
                case "javascript":
                case "replace": {
                    resultTemp = pipe.callback(this.config, this.params, resultTemp)
                    break
                }
                case "string": {
                    // xpath
                    let pathTag = pipe.callback(this.config, this.params, resultTemp)
                    let needOriginal = false

                    // 解析path
                    let query = null
                    try {
                        if (jsonPath) {
                            if (typeof content === 'string') {
                                content = JSON.parse(content)
                            }
                            try {
                                query = jp.query(content, pathTag);
                            } catch (e) {
                                // 尝试将 / 替换成 .
                                let replaceTag = pathTag.replaceAll(/\//g, ".")
                                    .replaceAll("|", "*");
                                query = jp.query(content, replaceTag);
                            }
                        } else {
                            query = xPathParser.queryWithXPath(pathTag)

                            if (!query) {
                                // TODO 处理 @data-original
                                // 由于 data-original 也可以是标签属性，所以优先作为标签属性查询
                                // 如果获取失败再尝试替换成 src
                                if (pathTag.indexOf("@data-original") >= 0) {
                                    needOriginal = true
                                    pathTag = pathTag.replaceAll("@data-original", "@src")

                                    if (pathTag.endsWith("/")) {
                                        pathTag = pathTag.slice(0, pathTag.length - 1)
                                    }
                                    query = xPathParser.queryWithXPath(pathTag)
                                }
                            }

                        }
                    } catch (e) {
                        console.error(`path [${pathTag}] parse for content [${content}] failure`)
                    }
                    if (!query) {
                        continue
                    }
                    if (query && query.length > 1) {
                        if (!jsonPath) {
                            // xpath 需要处理成 string方便下一层搜索
                            query = query.map(i => new XPathParser(i).raw())
                            if (tagType === 'string' && Array.isArray(query)) {
                                if (tagName === 'content') {
                                    query = query.join("\n")
                                }
                            }
                        }
                    } else {
                        if (query.length === 0) {
                            continue
                        }
                        const firstNode = query[0]

                        // 直接取值
                        if (jsonPath) {
                            query = new JsonPathParser(firstNode).content()
                            if (tagType === 'list' && !Array.isArray(query)) {
                                query = [query]
                            }
                        } else {
                            query = new XPathParser(firstNode).content()
                        }

                        if (needOriginal) {
                            query = this.addDomain(query)
                        }
                    }
                    // 保证新的空数据不会覆盖原有数据
                    resultTemp = query
                    break
                }
            }
        }

        // 根据不同的type最后处理
        if (tagType && tagType === 'url') {
            resultTemp = this.addDomain(resultTemp)
        }

        return resultTemp
    }

    /**
     * 剥离js/自定义语法和string
     * 利用正则匹配来区分这两部分，string 和 js；
     * string部分自行判断是xpath还是uri
     * @param input
     * @returns {*[]}
     */
    parseStringAndJs(input) {
        const partList = []
        const trimmedStr = input.trim();
        const jsPrefix = "@js:";
        const parts = trimmedStr.split(jsPrefix);

        /**
         * 剥离剩余的内容，是 string还是自定义语法
         * @param str
         */
        const parseStringAndCommand = (str) => {
            if (str) {
                const strParts = str.split('||');
                for (let i = 0; i < strParts.length; i++) {
                    let part = strParts[i]

                    if (!part) {
                        continue
                    }
                    part = part.trim();

                    if (part.startsWith('@')) {
                        // 剥离这种语法格式
                        const match = part.match(/^@(\w+):/);
                        if (match) {
                            const [_, command] = match;
                            // ...
                            partList.push({
                                type: command,
                                content: part
                            });
                        } else {
                            partList.push({
                                type: "command",
                                content: part
                            });
                        }
                    } else {
                        partList.push({
                            type: "string",
                            content: part
                        })
                    }
                }
            }
        }

        if (parts.length === 1) {
            parseStringAndCommand(trimmedStr);
            return partList;
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

        parseStringAndCommand(stringPart);

        if (jsPart) {
            partList.push({
                type: "javascript",
                content: jsPart
            })
        }

        return partList;
    }

    /**
     * 处理管道 || 和 js
     * @param str
     * @returns {*[]}
     */
    pipeStr(str) {
        const res = []
        let parseRes = this.parseStringAndJs(str);
        if (parseRes && parseRes.length > 0) {
            parseRes.forEach(part => {
                if (part && part.content) {
                    switch (part.type) {
                        case "javascript": {
                            res.push({
                                type: 'javascript', // javascript/string/
                                callback: (config, params, result) => {
                                    // 执行js，这里需要用到局部作用域，但 new Function 默认使用全局作用域
                                    try {
                                        // 换行避免有坑
                                        const wrappedJsPart = `(function(config, params, result) {
                                            ${part.content}
                                        })`;
                                        return (new Function(`return ${wrappedJsPart}`))()(config, params, result)
                                    } catch (e) {
                                        console.error(`execute function string error: [${part.content}]`, e)
                                        return result
                                    }
                                }
                            })
                            break
                        }
                        case "replace": {
                            // 内置语法，@replace:xxx，将结果中的 xxx 替换为空
                            const replaceStr = part.content.replace('@replace:', "").trim()
                            res.push({
                                type: 'javascript', // javascript/string/
                                callback: (config, params, result) => {
                                    // 执行js，这里需要用到局部作用域，所以还是使用 eval
                                    if (typeof result === 'string') {
                                        return result.replaceAll(replaceStr, "");
                                    }
                                    return result
                                }
                            })
                            break
                        }
                        case "command": {
                            // 其他尚未解析的命令
                            console.error("cannot exec this command", part.content)
                            throw new Error(`cannot exec this command [${part.content}]`)
                        }
                        case "string": {
                            // 全当 string 处理，根据来源自行区分是uri还是xpath
                            res.push({
                                type: 'string', // function/string
                                callback: (config, params, result) => {
                                    // 执行js，存在替换的问题
                                    const {keyWord, pageIndex, offset, filter} = params
                                    let resStr = part.content.replaceAll(`%@keyWord`, keyWord)
                                        .replaceAll(`%@pageIndex`, pageIndex)
                                        .replaceAll(`%@offset`, offset)
                                        .replaceAll(`%@filter`, filter)

                                    // result 如果要参与替换，内容只能是字符串
                                    if (typeof result !== 'object') {
                                        resStr = resStr.replaceAll(`%@result`, result)
                                    }

                                    // xpath则不用处理，它本身没有占位符

                                    return resStr
                                }
                            })
                            break
                        }
                    }
                }
            })
        }

        return res
    }

    //</editor-fold>

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
    async searchBook(sourceJson, search, type) {
        const sourceTools = new SourceTools(sourceJson);
        // TODO 处理初始化pageIndex 填入 queryInfo
        return new Promise(async (resolve, reject) => {
            try {
                const queryInfo = {
                    // 这三个是之前需要处理好的
                    keyWord: search || '', // 需要转Unicode？
                    offset: 0,
                    pageIndex: 1,
                };
                const searchRes = await sourceTools.searchBook(type, queryInfo)
                resolve(searchRes)
            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     * 书籍详情
     * @param sourceJson 源
     * @param queryInfo 详情地址
     * @returns {Promise<unknown>}
     */
    async bookDetail(sourceJson, queryInfo) {
        const sourceTools = new SourceTools(sourceJson);
        return new Promise(async (resolve, reject) => {
            try {
                const detail = await sourceTools.bookDetail(queryInfo);
                resolve(detail)
            } catch (e) {
                reject(e)
            }
        })
    }

    /**
     * 获取章节内容
     * @param sourceJson
     * @param queryInfo
     * @returns {Promise<unknown>}
     */
    async bookContent(sourceJson, queryInfo) {
        const sourceTools = new SourceTools(sourceJson);
        return new Promise(async (resolve, reject) => {
            try {
                const content = await sourceTools.bookContent(queryInfo);
                resolve(content)
            } catch (e) {
                reject(e)
            }
        })
    }
}

XbsToolService.toString = () => '[class XbsToolService]';
module.exports = XbsToolService;
