import {
    FormGroupItem,
    FormModelItem,
    NodeSourceType,
    RequestParamsEncode,
    ResponseEncode,
    ResponseFormatType
} from "@/utils/Models";

const sourceName: FormModelItem = {
    type: 'string',
    label: '名称',
    model: 'sourceName',
    help: '站点名称必须具有唯一性'
};
const password: FormModelItem = {
    type: 'string',
    label: '密码',
    model: 'password',
};
const weight: FormModelItem = {
    type: 'number',
    label: '权重',
    model: 'weight',
    help: `数值越大优先级越高，建议1到9999，<=0时不可用
新版本已增加权重限制`
};
const sourceType: FormModelItem = {
    type: 'select',
    label: '类型',
    model: 'sourceType',
    placeholder: '文本/小说',
    options: NodeSourceType,
};
const sourceUrl: FormModelItem = {
    type: 'string',
    label: 'host',
    model: 'sourceUrl',
    help: `站点首页必须具有唯一性，网址格式
所有url都会检测是否包含host，
如果没有，将使用当前host，也可以通过config.host获取。`
};
const loginUrl: FormModelItem = {
    type: 'text',
    label: '登录url',
    model: 'loginUrl'
};
const enable: FormModelItem = {
    type: 'switch',
    label: '启用',
    model: 'enable',
};
const lastModifyTime: FormModelItem = {
    type: 'string',
    label: '最后更新时间',
    model: 'lastModifyTimeToLocal',
    disabled: true
};

const actionId: FormModelItem = {
    type: 'string',
    label: 'string',
    model: 'actionID',
    disabled: true
};
const parserId: FormModelItem = {
    type: 'string',
    label: 'string',
    model: 'parserID',
    disabled: true
};
const requestInfo: FormModelItem = {
    type: 'text',
    model: 'requestInfo',
    label: '请求信息',
    placeholder: '请输入请求信息',
    help: `请求信息，书籍详情/章节列表/章节内容/书单详情等子级配置一般不用填写，会自动从上一级获取url。


使用方法1，使用替换规则，可替换的参数有%@result(从上一级获取的地址), %@keyWord, %@pageIndex, %@offset, %@filter，使用示例：
https://www.host.com/search?key=%@keyWord&p=%@pageIndex


使用方法2，使用js动态配置，需使用@js:声明，默认js参数有config/params/result，可通过日志功能打印参数内容，使用示例：
@js:
let hp = {};
hp.key = params.keyWord;
hp.p = params.pageIndex;
let url = 'https://www.host.com/search';
let hh = {'User-Agent':'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/14.0.835.163 Safari/535.1', 'Referer':'https://www.baidu.com'};
return {'url':url, 'httpParams':hp, 'httpHeaders':hh};

/*
常用key有:

url: 字符串，要请求的url
POST: 默认false，使用get请求
httpParams: 字典类型，http参数
httpHeaders: 字典类型，http请求头
forbidCookie: 默认false，true时禁用cookie

webView: 不为空时使用webView请求完整的网页
webViewJs: 字符串，webView请求完成后执行的js
webViewJsDelay: 正整数，webView完成后延时执行js，默认1秒
webViewSkipUrls: 数组，webView要跳过的url，可跳过无关的请求
sourceRegex: 字符串正则表达式，嗅探资源url
*/
`,
};
const host: FormModelItem = {
    type: 'text',
    label: 'text',
    model: 'host',
    placeholder: '请输入请求地址',
    help: ``
};
const httpHeaders: FormModelItem = {
    type: 'text',
    model: 'httpHeaders',
    label: 'http请求头',
    placeholder: '请输入请求头',
    help: `全局http请求头，JSON格式，可通过config.httpHeaders获取，示例：
{"User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.75 Safari/537.36", "Referer":"https://www.baidu.com"}


章节内容配置-正文中的图片/音频/视频等资源需动态设置，示例：
//a/@href || @js:
return {'url':result, 'httpHeaders':{"User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.75 Safari/537.36", "Referer":"https://www.baidu.com"}};`,
};
const list: FormModelItem = {
    type: 'text',
    model: 'list',
    label: '列表(list)',
    help: `列表(list)
返回数组格式时继续下一步item解析，返回字典格式时结束解析`,
};
const title: FormModelItem = {
    type: 'text',
    model: 'title',
    label: '标题(title)',
    help: ``
};
const detail: FormModelItem = {
    type: 'text',
    model: 'detail',
    label: '详情(detail)',
    help: ``
};
const bookName: FormModelItem = {
    type: 'text',
    model: 'bookName',
    label: '书名(bookName)',
    help: ``
};
const author: FormModelItem = {
    type: 'text',
    model: 'author',
    label: '作者(author)',
    help: ``
};
const cover: FormModelItem = {
    type: 'text',
    model: 'cover',
    label: '图标(cover)',
    help: `图标(cover)
会自动尝试加host，也可手动尝试params.responseUrl`,
};
const content: FormModelItem = {
    type: 'text',
    model: 'content',
    label: '正文(cover)',
    help: ``
};
const desc: FormModelItem = {
    type: 'text',
    model: 'desc',
    label: '简介(desc)',
    help: '20个字符以内',
};
const cat: FormModelItem = {
    type: 'text',
    model: 'cat',
    label: '类别(cover)',
    help: ``
};
const status: FormModelItem = {
    type: 'text',
    model: 'status',
    label: '状态(status)',
    help: ``
};
const wordCount: FormModelItem = {
    type: 'text',
    model: 'wordCount',
    label: '字数(wordCount)',
    help: ``
};
const replyCount: FormModelItem = {
    type: 'text',
    model: 'replyCount',
    label: '回复或跟帖数(replyCount)',
    help: ``
};
const createTime: FormModelItem = {
    type: 'text',
    model: 'createTime',
    label: '创建时间(createTime)',
    help: ``
};
const formUserName: FormModelItem = {
    type: 'text',
    model: 'formUserName',
    label: '用户名(formUserName)',
    help: ``
};
const formUserCover: FormModelItem = {
    type: 'text',
    model: 'formUserCover',
    label: '用户图标(formUserCover)',
    help: ``
};
const score: FormModelItem = {
    type: 'text',
    model: 'score',
    label: '评分(score)',
    help: ``
};

const lastChapterTitle: FormModelItem = {
    type: 'text',
    model: 'lastChapterTitle',
    label: '最后一章标题(lastChapterTitle)',
    help: ``
};
const detailUrl: FormModelItem = {
    type: 'text',
    model: 'detailUrl',
    label: '书本详情页地址(detailUrl)',
    help: `书本详情页地址(detailUrl)
会自动尝试加host，也可手动尝试params.responseUrl`,
};
const childUrl: FormModelItem = {
    type: 'text',
    model: 'url',
    label: '下一级界面地址(url)',
    help: ``
};
const nextPageUrl: FormModelItem = {
    type: 'text',
    model: 'nextPageUrl',
    label: '下一页地址(nextPageUrl)(需要设置maxPage)',
    help: ``
};
const updateTime: FormModelItem = {
    type: 'text',
    model: 'updateTime',
    label: '最后一章更新时间(updateTime)',
    help: ``
};
const requestParamsEncode: FormModelItem = {
    type: 'select',
    model: 'requestParamsEncode',
    label: '请求参数编码方式',
    placeholder: 'utf-8',
    options: RequestParamsEncode,
    help: ``
};
const responseEncode: FormModelItem = {
    type: 'select',
    model: 'responseEncode',
    label: '响应编码方式',
    placeholder: 'utf-8',
    options: ResponseEncode,
    help: ``
};
const responseFormatType: FormModelItem = {
    type: 'select',
    model: 'responseFormatType',
    label: '响应解析方式',
    placeholder: '普通字符串',
    options: ResponseFormatType,
    help: ``
};
const success: FormModelItem = {
    type: 'text',
    model: 'success',
    label: 'success规则',
    placeholder: 'success规则',
    help: `默认不使用
当搜索结果为空，但响应数据success时，应该缓存响应数据，下一次遇到同一请求即可读取缓存，可有效减少网络请求次数`
};
const JSParser: FormModelItem = {
    type: 'text',
    model: 'JSParser',
    label: 'js手动解析',
    placeholder: 'js手动解析',
    help: `默认不使用
也可与标准规则解析一起使用，示例：
function functionName(config, params, result)
{
\t// 返回搜索结果示例：
\tlet list = []; // list为自定义解析结果
\treturn {'list':list};

\t// 学习时可返回任意数据，查看里面到底有什么内容(类型日志功能)，例如：
\treturn {'config':config, 'params':params, 'result':result}; // 需注意，result的内容会变化，在请求信息中result为上一级传入的url或nextPageUrl，在解释响应时result是上一层的解释结果
}`
};
const moreKeys: FormModelItem = {
    type: 'text',
    model: 'moreKeys',
    label: 'moreKeys',
    placeholder: 'moreKeys',
    help: `选填，JSON格式，示例：

{
\t"requestFilters":"最新::lasest\\n最热::hot",
\t"removeHtmlKeys":["bookName","author"],
\t"skipCount":6,
\t"pageSize":30,
\t"maxPage":1,
}

注：
requestFilters:过滤器，用于书海筛选
removeHtmlKeys:需外部删除html标签的key，可删除script内容

章节列表与章节内容有分页时需使用maxPage控制最大分页，其他列表配置(如搜索配置/分类配置)有分页时可使用pageSize/maxPage控制，使用其中一个即可:
pageSize:列表数据每页数量，用于判断是否有更多页
maxPage:有分页时需设置最大分页数

skipCount:列表数据忽略数量，类似于xpath position()>6，但数量小于6时忽略`
};
const validConfig: FormModelItem = {
    type: 'text',
    model: 'validConfig',
    label: '配置校验',
    help: ``
};
const sIndex: FormModelItem = {
    type: 'number',
    model: '_sIndex',
    label: '排序',
    placeholder: '排序',
}

const searchBook: FormGroupItem = {
    title: '书籍搜索',
    action: 'searchBook',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, bookName, author, cover, desc, cat, status, wordCount, lastChapterTitle, detailUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, success, JSParser, moreKeys]
        }
    ]
};
const bookDetail: FormGroupItem = {
    title: '书籍详情',
    action: 'bookDetail',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [cover, desc, cat, status, wordCount, lastChapterTitle]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const chapterList: FormGroupItem = {
    title: '章节列表',
    action: 'chapterList',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title, childUrl, nextPageUrl, updateTime]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const chapterContent: FormGroupItem = {
    title: '章节内容',
    action: 'chapterContent',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [content, nextPageUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const searchShudan: FormGroupItem = {
    title: '书单搜索',
    action: 'searchShudan',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title, detail, cover, childUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const shudanDetail: FormGroupItem = {
    title: '书单详情',
    action: 'shudanDetail',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, detail, bookName, author, cover, desc, cat, status, wordCount, lastChapterTitle, detailUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const shupingList: FormGroupItem = {
    title: '书本评论',
    action: 'shupingList',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title, detail, replyCount, createTime, formUserName, formUserCover, score, childUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const shupingHome: FormGroupItem = {
    title: '广场',
    action: 'shupingHome',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title, detail, replyCount, createTime, formUserName, formUserCover, score, childUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const relatedWord: FormGroupItem = {
    title: '热词',
    action: 'relatedWord',
    formGroups: [
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const bookWorld: FormGroupItem = {
    title: '书籍分类',
    action: 'bookWorld',
    formGroups: [
        {
            title: '基础信息',
            items: [sIndex]
        },
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, bookName, author, cover, desc, cat, status, wordCount, lastChapterTitle, detailUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};
const shudanList: FormGroupItem = {
    title: '书单分组',
    action: 'shudanList',
    formGroups: [
        {
            title: '基础信息',
            items: [sIndex]
        },
        {
            title: '请求信息',
            items: [requestInfo]
        },
        {
            title: "响应规则",
            tips: ['多个规则之间使用双竖杠||连接，可以加空格提高可读性，例如：A || B'],
            items: [list, title, desc, cover, childUrl]
        },
        {
            title: "更多配置",
            items: [requestParamsEncode, responseEncode, responseFormatType, JSParser, moreKeys]
        }
    ]
};

export const modifyFromItem: Array<FormModelItem> = [sourceName, sourceUrl, password, weight, sourceType, desc, loginUrl, httpHeaders, lastModifyTime, enable]
    .map(item => {
        return {
            ...{
                type: 'string',
                label: item.model,
                name: item.model,
                placeholder: item.label || item.model,
                disabled: false,
                options: [],
                rules: []
            }, ...item
        }
    }).filter(i => i);
export const detailForm: any = {
    searchBook: searchBook,
    bookDetail: bookDetail,
    chapterList: chapterList,
    chapterContent: chapterContent,
    bookWorld: bookWorld,
}

export const moreForm: any = {
    searchShudan: searchShudan,
    shudanDetail: shudanDetail,
    shupingList: shupingList,
    shupingHome: shupingHome,
    relatedWord: relatedWord,
    shudanList: shudanList,
}

export const groupFromKeyName: Array<string> = ['bookWorld', 'shudanList',]
