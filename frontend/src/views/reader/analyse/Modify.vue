<template>
    <div>
        <a-form
                :model="dataForm"
                name="dataForm"
                :label-col="{ span: 4 }"
                :wrapper-col="{ span: 20 }"
                autocomplete="off">

            <a-divider orientation="center">基础信息</a-divider>

            <editor-area v-for="item in modifyFromItem"
                         :key="item.model"
                         :type="item.type"
                         :data.sync="dataForm[item.model]"
                         :label="item.label"
                         :name="item.name"
                         :options="item.options"
                         :placeholder="item.placeholder"
                         :disabled="item.disabled"
                         :help="item.help"
                         :rules="item.rules"></editor-area>

            <a-row>
                <a-col :span="11">
                    <a-divider orientation="center">常用配置</a-divider>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书籍搜索"
                            name="searchBook"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('searchBook')" type="primary"
                                  @click="handleConfigDrawer('searchBook')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('searchBook')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书籍详情"
                            name="bookDetail"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('bookDetail')" type="primary"
                                  @click="handleConfigDrawer('bookDetail')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('bookDetail')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="章节列表"
                            name="chapterList"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('chapterList')" type="primary"
                                  @click="handleConfigDrawer('chapterList')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('chapterList')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="章节内容"
                            name="chapterContent"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('chapterContent')" type="primary"
                                  @click="handleConfigDrawer('chapterContent')">已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('chapterContent')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书籍分类"
                            name="bookWorld"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('bookWorld')" type="primary"
                                  @click="handleConfigDrawer('bookWorld')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('bookWorld')">
                            未配置
                        </a-button>
                    </a-form-item>
                </a-col>

                <a-col :span="11" :offset="1">
                    <a-divider orientation="center">更多配置</a-divider>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书单搜索"
                            name="searchShudan"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('searchShudan')" type="primary"
                                  @click="handleConfigDrawer('searchShudan')">已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('searchShudan')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书单分组"
                            name="shudanList"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('shudanList')" type="primary"
                                  @click="handleConfigDrawer('shudanList')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('shudanList')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书单详情"
                            name="shudanDetail"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('shudanDetail')" type="primary"
                                  @click="handleConfigDrawer('shudanDetail')">已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('shudanDetail')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="书本评论"
                            name="shupingList"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('shupingList')" type="primary"
                                  @click="handleConfigDrawer('shupingList')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" html-type="submit" @click="handleConfigDrawer('shupingList')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="广场"
                            name="shupingHome"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('shupingHome')" type="primary"
                                  @click="handleConfigDrawer('shupingHome')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('shupingHome')">
                            未配置
                        </a-button>
                    </a-form-item>

                    <a-form-item
                            :label-col="{ span: 10 }"
                            :wrapper-col="{ span: 14 }"
                            label="热词"
                            name="relatedWord"
                            :rules="[{ required: true, message: '请输入源节点名称!' }]">
                        <a-button v-if="hasConfigBtn('relatedWord')" type="primary"
                                  @click="handleConfigDrawer('relatedWord')">
                            已配置
                        </a-button>
                        <a-button v-else type="info" @click="handleConfigDrawer('relatedWord')">
                            未配置
                        </a-button>
                    </a-form-item>
                </a-col>
            </a-row>

            <a-row>
                <a-col :span="1" :offset="4">
                    <a-button type="primary" @click="handleSaveAndBuild">保存</a-button>
                </a-col>
                <a-col :span="1" :offset="4">
                    <a-button type="info" @click="handleExport">导出</a-button>
                </a-col>
                <a-col :span="1" :offset="4">
                    <a-button type="danger" @click="handleRemove">删除</a-button>
                </a-col>
            </a-row>
        </a-form>

        <detail-editor ref="detail" @handleSaveConfig="handleSaveConfig"></detail-editor>
        <group-editor ref="group" @handleSaveConfig="handleSaveConfig"></group-editor>

        <!--        <a-drawer-->
        <!--            title="Basic Drawer"-->
        <!--            placement="right"-->
        <!--            :closable="false"-->
        <!--            :visible="true">-->
        <!--            <p>Some contents...</p>-->
        <!--            <p>Some contents...</p>-->
        <!--            <p>Some contents...</p>-->
        <!--        </a-drawer>-->

    </div>
</template>

<script>

import {RequestParamsEncode, ResponseEncode, ResponseFormatType, SourceType} from "@/model/typeModel";
import DetailEditor from '@/views/reader/analyse/DetailEditor.vue'
import GroupEditor from "@/views/reader/analyse/GroupEditor.vue";
import {compressJson, parseJson, stringifyJson} from "@/utils/analyse/StrUtil";
import {ipcApiRoute} from "@/api/main";
import EditorArea from "@/components/EditorArea.vue";

import moment from "moment";
import "moment/locale/zh-cn"
import {timeTools} from "@/utils/analyse/xbsTools";

export default {
    name: "Modify",
    components: {
        EditorArea,
        DetailEditor,
        GroupEditor
    },
    data() {
        const that = this

        const sourceName = {
            type: 'string',
            label: '名称',
            model: 'sourceName',
            help: '站点名称必须具有唯一性'
        };
        const password = {
            type: 'string',
            label: '密码',
            model: 'password',
        };
        const weight = {
            type: 'number',
            label: '权重',
            model: 'weight',
            help: `数值越大优先级越高，建议1到9999，<=0时不可用
新版本已增加权重限制`
        };
        const sourceType = {
            type: 'select',
            label: '类型',
            model: 'sourceType',
            placeholder: '文本/小说',
            options: SourceType,
        };
        const sourceUrl = {
            type: 'string',
            label: 'host',
            model: 'sourceUrl',
            options: SourceType,
            help: `站点首页必须具有唯一性，网址格式
所有url都会检测是否包含host，
如果没有，将使用当前host，也可以通过config.host获取。`
        };
        const loginUrl = {
            type: 'text',
            label: '登录url',
            model: 'loginUrl',
            options: SourceType,
        };
        const enable = {
            type: 'switch',
            label: '启用',
            model: 'enable',
        };
        const lastModifyTime = {
            type: 'string',
            label: '最后更新时间',
            model: 'lastModifyTimeToLocal',
            disabled: true
        };

        const actionId = {
            type: 'string',
            model: 'actionID',
            disabled: true
        };
        const parserId = {
            type: 'string',
            model: 'parserID',
            disabled: true
        };
        const requestInfo = {
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
        const host = {
            type: 'text',
            model: 'host',
            placeholder: '请输入请求地址',
            help: ``
        };
        const httpHeaders = {
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
        const list = {
            type: 'text',
            model: 'list',
            label: '列表(list)',
            help: `列表(list)
返回数组格式时继续下一步item解析，返回字典格式时结束解析`,
        };
        const title = {
            type: 'text',
            model: 'title',
            label: '标题(title)',
            help: ``
        };
        const detail = {
            type: 'text',
            model: 'detail',
            label: '详情(detail)',
            help: ``
        };
        const bookName = {
            type: 'text',
            model: 'bookName',
            label: '书名(bookName)',
            help: ``
        };
        const author = {
            type: 'text',
            model: 'author',
            label: '作者(author)',
            help: ``
        };
        const cover = {
            type: 'text',
            model: 'cover',
            label: '图标(cover)',
            help: `图标(cover)
会自动尝试加host，也可手动尝试params.responseUrl`,
        };
        const content = {
            type: 'text',
            model: 'content',
            label: '正文(cover)',
            help: ``
        };
        const desc = {
            type: 'text',
            model: 'desc',
            label: '简介(desc)',
            help: '20个字符以内',
        };
        const cat = {
            type: 'text',
            model: 'cat',
            label: '类别(cover)',
            help: ``
        };
        const status = {
            type: 'text',
            model: 'status',
            label: '状态(status)',
            help: ``
        };
        const wordCount = {
            type: 'text',
            model: 'wordCount',
            label: '字数(wordCount)',
            help: ``
        };
        const replyCount = {
            type: 'text',
            model: 'replyCount',
            label: '回复或跟帖数(replyCount)',
            help: ``
        };
        const createTime = {
            type: 'text',
            model: 'createTime',
            label: '创建时间(createTime)',
            help: ``
        };
        const formUserName = {
            type: 'text',
            model: 'formUserName',
            label: '用户名(formUserName)',
            help: ``
        };
        const formUserCover = {
            type: 'text',
            model: 'formUserCover',
            label: '用户图标(formUserCover)',
            help: ``
        };
        const score = {
            type: 'text',
            model: 'score',
            label: '评分(score)',
            help: ``
        };

        const lastChapterTitle = {
            type: 'text',
            model: 'lastChapterTitle',
            label: '最后一章标题(lastChapterTitle)',
            help: ``
        };
        const detailUrl = {
            type: 'text',
            model: 'detailUrl',
            label: '书本详情页地址(detailUrl)',
            help: `书本详情页地址(detailUrl)
会自动尝试加host，也可手动尝试params.responseUrl`,
        };
        const childUrl = {
            type: 'text',
            model: 'url',
            label: '下一级界面地址(url)',
            help: ``
        };
        const nextPageUrl = {
            type: 'text',
            model: 'nextPageUrl',
            label: '下一页地址(nextPageUrl)(需要设置maxPage)',
            help: ``
        };
        const updateTime = {
            type: 'text',
            model: 'updateTime',
            label: '最后一章更新时间(updateTime)',
            help: ``
        };
        const requestParamsEncode = {
            type: 'select',
            model: 'requestParamsEncode',
            label: '请求参数编码方式',
            placeholder: 'utf-8',
            options: RequestParamsEncode,
            help: ``
        };
        const responseEncode = {
            type: 'select',
            model: 'responseEncode',
            label: '响应编码方式',
            placeholder: 'utf-8',
            options: ResponseEncode,
            help: ``
        };
        const responseFormatType = {
            type: 'select',
            model: 'responseFormatType',
            label: '响应解析方式',
            placeholder: '普通字符串',
            options: ResponseFormatType,
            help: ``
        };
        const success = {
            type: 'text',
            model: 'success',
            label: 'success规则',
            placeholder: 'success规则',
            help: `默认不使用
当搜索结果为空，但响应数据success时，应该缓存响应数据，下一次遇到同一请求即可读取缓存，可有效减少网络请求次数`
        };
        const JSParser = {
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
        const moreKeys = {
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
        const validConfig = {
            type: 'text',
            model: 'validConfig',
            help: ``
        };
        const sIndex = {
            type: 'number',
            model: '_sIndex',
            label: '排序',
            placeholder: '排序',
        }

        let modifyFromItem = [sourceName, sourceUrl, password, weight, sourceType, desc, loginUrl, httpHeaders, lastModifyTime, enable]
            .map(item => {
                if (!item.model) {
                    return null
                }

                if (item.type === 'select') {
                    if (!item.options || item.options.length <= 0) {
                        return null
                    }
                }

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
        return {
            queryInfo: {}, // 存储id和文件路径
            dataForm: {},
            sourceType: SourceType,
            showDrawer: true,
            modifyFromItem: modifyFromItem,
            detailForm: {
                searchBook: {
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
                },
                bookDetail: {
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
                },
                chapterList: {
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
                },
                chapterContent: {
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
                },

                searchShudan: {
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
                },
                shudanDetail: {
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
                },
                shupingList: {
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
                },
                shupingHome: {
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
                },
                relatedWord: {
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
                },
            },
            groupFrom: {
                bookWorld: {
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
                },
                shudanList: {
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
                },
            },
            moment,
        }
    },
    methods: {
        /**
         * 初始化
         * @param data
         * @returns {Promise<void>}
         */
        async init(data) {
            const that = this
            that.dataForm = {}
            if (data) {
                that.queryInfo = data

                if (!data.sourceJson) {
                    console.error("please provide json string")
                    return;
                }

                try { // const fileData = await that.$ipc.invoke(ipcApiRoute.bookSourceFileRead, {filePath: data.sourceJson})
                    data = JSON.parse(data.sourceJson)[data.sourceName]

                    // 处理enable
                    if (!(typeof data['enable'] === 'boolean')) {
                        data['enable'] = !!data['enable']
                    }
                    if (data['lastModifyTime']) {
                        data['lastModifyTimeToLocal'] = timeTools.UnixWithSixDecimalToLocalTime(data['lastModifyTime'])
                    }

                    // 这里将数据转换成字符串用以编辑
                    that.dataForm = stringifyJson(data, ['httpHeaders'])
                } catch (e) {
                    console.error("parse json failure")
                    return;
                }

                console.log("load data success", that.queryInfo, that.dataForm)
            }
        },
        handleConfigDrawer(type) {
            const that = this
            switch (type) {
                case 'searchBook':
                case 'bookDetail':
                case 'chapterList':
                case 'chapterContent':
                case 'searchShudan':
                case 'shudanDetail':
                case 'shupingList':
                case 'shupingHome':
                case 'relatedWord':
                    that.$refs['detail'].init(that.detailForm[type], that.dataForm[type])
                    break
                case 'bookWorld':
                    that.$refs['group'].init(that.groupFrom[type], that.dataForm[type], that.dataForm['searchBook'])
                    break
                case 'shudanList':
                    that.$refs['group'].init(that.groupFrom[type], that.dataForm[type], that.dataForm['searchShudan'])
                    break
                default:
                    break
            }
        },
        handleSaveConfig(data, keyName, parseKeys) {
            this.dataForm[keyName] = {...data}
            console.log("modify data save success", data, keyName, this.dataForm)
        },
        /**
         * 存储数据
         * @param exp 是否导出
         */
        handleSaveAndBuild(exp) {
            const that = this

            const hasConfiged = (config) => {
                let configed = false
                if (config) {
                    for (const key in config) {
                        if (key !== 'actionID' && key !== 'parserID' && key !== 'responseFormatType') {
                            if (config[key]) {
                                configed = true
                            }
                        }
                    }
                }
                return configed
            }
            // httpHeaders 还原成json
            that.dataForm = parseJson(that.dataForm, ['httpHeaders'])
            // 校验
            for (const key in that.dataForm) {
                if (that.detailForm[key]) {
                    // 无需分组配置项
                    if (hasConfiged(that.dataForm[key])) {
                        // 插入这俩
                        that.dataForm[key]['validConfig'] = ''
                        that.dataForm[key].host = that.dataForm.sourceUrl
                        that.dataForm[key].httpHeaders = that.dataForm.httpHeaders
                        // 保证是json格式的字符串，也都被转成了json对象
                    }
                }
                if (that.groupFrom[key]) {
                    // 分组配置项
                    for (const groupKey in that.dataForm[key]) {
                        const group = that.dataForm[key][groupKey]
                        if (hasConfiged(group)) {
                            // 插入这俩
                            that.dataForm[key][groupKey]['validConfig'] = ''
                            that.dataForm[key][groupKey].host = that.dataForm.sourceUrl
                            that.dataForm[key][groupKey].httpHeaders = that.dataForm.httpHeaders
                            // 保证是json格式的字符串，也都被转成了json对象
                        }
                    }
                }
            }

            // 整理
            const sourceJson = {}
            let newObj = {...that.dataForm};

            // 处理时间
            delete newObj['lastModifyTimeToLocal']
            newObj['lastModifyTime'] = timeTools.localTimeToUnixWithSixDecimal(new Date())
            sourceJson[that.dataForm.sourceName] = newObj
            // 压缩
            let compressJsonStr = compressJson(sourceJson);

            // 存储
            // TODO 禁用源会产生两个问题，1 没有正确显示启用/禁用状态；2 可能导致 type 为空
            const submitData = {
                id: that.queryInfo.id,
                platform: 'StandarReader',
                sourceName: that.dataForm['sourceName'],
                sourceType: that.dataForm['sourceType'],
                sourceUrl: that.dataForm['sourceUrl'],
                enable: that.dataForm['enable'],
                weight: that.dataForm['weight'],
                sourceJson: compressJsonStr,
                authorId: that.dataForm['authorId'],
                desc: that.dataForm['desc'],
                lastModifyTime: that.dataForm['lastModifyTime'],
                toTop: that.dataForm['toTop'],
            }
            // 提交到父组件
            that.$emit("handleSave", submitData, exp && exp.needExp)
        },
        hasConfigBtn(configKey) {
            let configed = false;
            let config = this.dataForm[configKey];
            if (config) {
                for (const key in config) {
                    if (key !== 'actionID' && key !== 'parserID' && key !== 'responseFormatType') {
                        if (config[key]) {
                            configed = true
                        }
                    }
                }
            }
            return configed;
        },
        handleExport() {
            this.handleSaveAndBuild({needExp: true})
        },
        handleRemove() {
            this.$emit('handleRemove', this.queryInfo.id)
        },
        queryData(data) {
            return this.$ipc.invoke(ipcApiRoute.bookSourceOperation, {
                action: 'get',
                data: data
            })
        }
    }
}
</script>

<style>
.timeline-tips {
    margin-left: 20%;
}

.ant-popover {
    max-width: 500px !important;
}

</style>
