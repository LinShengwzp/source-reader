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
    "chapterContent": {"actionID": "chapterContent","parserID": "DOM"},
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

export {
    SourceType,
    RequestParamsEncode,
    ResponseEncode,
    ResponseFormatType,
    SourcePlatform,
    SourceTemplate
}
