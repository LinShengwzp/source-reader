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
    "enable": "1",
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
    sourceJson?: string,
    enable?: string, // 必须转成 string 否则会导致导入之后无法修改是否启动
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
 * api调用格式
 */
export interface DataApiAction {
    action: 'create' | 'exist' | 'query' | 'count' | 'save' | 'modify' | 'remove',
    cover?: boolean,
    data?: any
}

/**
 * 数据库操作结果
 */
export interface DataOperateRes<T> {
    action: 'create' | 'exist' | 'query' | 'count' | 'save' | 'modify' | 'remove',
    code: 'success' | 'failure' | 'exist',
    msg?: string,
    data?: T
}

/**
 * 数据库表操作
 */
export interface DataBaseOperate<T> {
    exist: (queryParams: ColQueryInfo[]) => Promise<DataOperateRes<T | undefined>>,
    query: (queryParams: DataColQueryInfo) => Promise<DataOperateRes<Array<T>>>,
    one: (queryParams: ColQueryInfo[]) => Promise<DataOperateRes<T>>,
    count: (queryParams: ColQueryInfo[]) => Promise<DataOperateRes<number>>,
    save: (data: T, cover: boolean) => Promise<DataOperateRes<T>>,
    saveBatch: (dataList: Array<T>, cover: boolean) => Promise<DataOperateRes<Array<T>>>,
    modify: (data: T) => Promise<DataOperateRes<T>>,
    remove: (ids: string[] | number[]) => Promise<DataOperateRes<Array<T>>>
}

/**
 * 数据表
 */
export interface DataTable<T> {
    tableName: string,
    IdKey: string,
    columns: Array<TableColumnInfo>,
    operates?: DataBaseOperate<T>,
    index?: string[][] // 索引
}

/**
 * 数据库表结构
 */
export interface TableColumnInfo {
    name: string,
    type: 'INTEGER' | 'TEXT' | 'INT',
    comment: string,
    pk?: boolean,
    notNull?: boolean,
    autoIncrement?: boolean,
    default?: number | string,
    union?: boolean,
}

export interface ColQueryInfo {
    colName: string,
    comp?: '=' | 'like' | 'leftLike' | 'rightLike' | 'between' | '>' | '>=' | '<' | '<=', // 默认 =
    sort?: 'asc' | 'desc', // 默认 asc
    data?: string | number,
    query?: boolean, // 默认 true
}

export interface DataQueryPage {
    index?: number, //从 第 1 页 开始
    size?: number,
    close: boolean
}

/**
 * 数据查询条件
 */
export interface DataColQueryInfo {
    columns: Array<ColQueryInfo>,
    page: DataQueryPage
}

/**
 * 表单项
 */
export interface FormModelItem {
    type: string,
    label: string,
    modelValue?: string | number | boolean,
    name?: string,
    model: string,
    icon?: string,
    placeholder?: string,
    disabled?: boolean,
    rules?: Array<any>,
    options?: Array<TypeInfo>,
    help?: string,
    handle?: Function,
    callback?: Function
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
    enable?: string,
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

/**
 * 将对象转成list
 * @param obj
 * @param keyName
 * @constructor
 */
export const obj2Array = (obj: any, keyName: string = 'key'): Array<any> => {
    if (!!obj) {
        const keyArr = Object.keys(obj)
        let arr: Array<any> = []
        keyArr.forEach(key => {
            let objElement = obj[key];
            if (typeof objElement === 'object') {
                objElement[keyName] = key
            }
            arr.push(objElement)
        })
        return arr
    }
    return []
}

/**
 * list转对象
 * @param arr
 * @param keyName
 */
export const arr2Object = (arr: Array<any>, keyName: string): any => {
    if (arr && arr.length > 0) {
        const obj: any = {}
        arr.forEach(item => {
            if (typeof item === 'object' && item[keyName]) {
                obj[item[keyName]] = item
            }
        })
        if (!!obj) {
            return obj
        }
    }
    return null
}
