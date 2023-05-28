//<editor-fold desc="枚举值">
export enum FileType {
    XBS, JSON
}


//</editor-fold>

//<editor-fold desc="公共类">

export const NodeSourceType: Array<TypeInfo> = [
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

export const RequestParamsEncode: Array<TypeInfo> = [
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

export const ResponseEncode: Array<TypeInfo> = [
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
export const ResponseFormatType: Array<TypeInfo> = [
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

export const SourcePlatform: Array<TypeInfo> = [
    {
        name: 'StandarReader',
        label: '香色闺阁',
        default: true
    },
]

export const SourceTemplate: SRNodeInfo = {
    "chapterContent": {"actionID": "chapterContent", "parserID": "DOM"},
    "enable": 1,
    "shupingList": {"actionID": "shupingList", "parserID": "DOM"},
    "bookDetail": {"actionID": "bookDetail", "parserID": "DOM"},
    "shudanList": [],
    "bookWorld": [],
    "sourceUrl": "",
    "desc": "",
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

//</editor-fold>

//<editor-fold desc="公共interface">

/**
 * 底部菜单
 */
export interface MenuItem {
    id: number,
    icon: string,
    label: string,
    name: string
}

/**
 * 节点操作功能
 */
export interface NodeOperate {
    id: number,
    name: string,
    label: string,
    operate: Function
}

/**
 * 节点信息
 */
export interface NodeInfo {
    id?: number,
    sourceName?: string,
    platform?: string,
    sourceType?: string,
    sourceUrl?: string,
    authorId?: string,
    weight?: string,
    desc?: string,
    lastModifyTime?: string,
    toTop?: string,
    sourceJson?: string | object,
    enable?: number,
}

/**
 * 字典
 */
export interface TypeInfo {
    name: string;
    label: string;
    default?: boolean;
}

/**
 * 分页
 */
export interface PageInfo {
    total: number,
    size: number,
    pageCount: number,
    currPage: number,
}

/**
 * 打开文件
 */
export interface FileInfo {
    file?: File,
    fileType?: FileType,
    analyseNode?: object,
    dataInfo?: Array<any>,
    nodeList?: Array<any>,
    menuList?: Array<any>,
    nodeSearch?: string,
    page: PageInfo
}

/**
 * 表单项
 */
export interface FormModelItem {
    type: string,
    label?: string,
    modelValue?: string | number | boolean,
    name?: string,
    model?: string,
    icon?: string,
    placeholder?: string,
    disabled?: boolean,
    rules?: Array<any>,
    options?: Array<TypeInfo>,
    help?: string,
}

/**
 * 表单组
 */
export interface FormGroupItem {
    title: string,
    action?: string,
    tips?: string[],
    items?: Array<FormModelItem>,
    formGroups?: Array<FormGroupItem>
}

/**
 * 香色闺阁节点详细内容
 */
export interface SRNodeDetail {
    actionID: string,
    parserID: string,
}

/**
 * 香色闺阁节点内容
 */
export interface SRNodeInfo {
    sourceName: string,
    sourceType?: string,
    authorId?: string,
    enable?: number,
    weight?: string,
    sourceUrl?: string,
    desc?: string,
    password?: string,
    miniAppVersion?: string,
    lastModifyTime?: string,
    toTop?: string,
    searchBook?: SRNodeDetail,
    bookDetail?: SRNodeDetail,
    chapterList?: SRNodeDetail,
    chapterContent?: SRNodeDetail,
    bookWorld?: Array<SRNodeDetail>,
    shudanList?: Array<SRNodeDetail>,
    searchShudan?: SRNodeDetail,
    shupingList?: SRNodeDetail,
    shudanDetail?: SRNodeDetail,
    shupingHome?: SRNodeDetail,
    relatedWord?: SRNodeDetail,
}

//</editor-fold>

/**
 * 获取所属的内容
 * @param type
 * @param value
 */
export const findType = (type: Array<TypeInfo>, value: string): TypeInfo | null => {

    if (type && type.length > 0) {
        for (const index in type) {
            const item = type[index]
            if (item.name === value) {
                return item;
            }
        }
    }

    return null;
}
