import {defineStore} from "pinia";
import {NodeInfo, SRNodeInfo} from "@/utils/Models";
import {nodeXsGgSelectEvent} from "@/bus";
import {timeTools} from "@/utils/xbsTool/xbsTools";
import {compressJson, stringifyJson} from "@/utils/Strutil";
import {ElMessage} from "element-plus";
import {bookInfo, BookSource} from "@/utils/storage/Table";

export interface IMainStore {
    currentFilePath: string
}

export const mainStore = defineStore('main', {
    state: (): IMainStore => ({
        currentFilePath: '',
    }),
    actions: {
        setCurrFilePath(path: string) {
            this.currentFilePath = path
        }
    },
    getters: {
        currFilePath(): string {
            return this.currentFilePath;
        }
    },
})

export interface INodeStore {
    currEditId?: number,
    currEditName?: string,
    currEditIndex: number,
    maxEditNodeCount: number,
    editNodeList?: Array<NodeInfo>,
    currEditXsGgNodeInfo?: NodeInfo,
    currEditNodeObj?: SRNodeInfo,
}

// 解析和打包时需要特别注意的两个字段
const stringifyKeys: string[] = ['httpHeaders', 'moreKeys'];

export const nodeSaveStore = defineStore('nodeSave', {
    state: () => ({
        dialogVisible: false,
        coverNode: false,
        hasSetCover: false,
    }),
    actions: {

        /**
         * 将当前的node存储到数据库中
         */
        async submitNodeData(node: SRNodeInfo) {
            // 存储
            if (!node || !node.sourceName || !!node.searchBook) {
                const sourceJson: Record<string, SRNodeInfo> = {}
                // @ts-ignore
                sourceJson[node?.sourceName] = node
                const json = compressJson(sourceJson);
                // 重新组合数据存储
                const item: BookSource = {
                    id: undefined,
                    platform: 'StandarReader',
                    sourceName: node?.['sourceName'],
                    sourceType: node?.['sourceType'],
                    sourceUrl: node?.['sourceUrl'],
                    enable: node?.['enable'],
                    weight: node?.['weight'],
                    sourceJson: json,
                    authorId: node?.['authorId'],
                    desc: node?.['desc'],
                    lastModifyTime: timeTools.localTimeToUnixWithSixDecimal(new Date()),
                    toTop: node?.['toTop'],
                }

                // 覆盖 || 设置不覆盖
                if (this.coverNode || (this.hasSetCover && !this.coverNode)) {
                    const saveRes = await bookInfo.operates?.save(item, this.coverNode)
                    if (saveRes && saveRes.code) {
                        const {code} = saveRes
                        switch (code) {
                            case 'exist': {
                                if (!this.hasSetCover) {
                                    this.dialogVisible = true
                                    return;
                                }
                                break
                            }
                            case 'success': {
                                ElMessage.success("保存成功")
                                // 上级保存
                                return
                            }
                            case 'failure': {
                                ElMessage.error(saveRes?.msg)
                            }
                        }
                    }
                }
            }

        },
    }
})

export const nodeStore = defineStore("node", {
    state: (): INodeStore => ({
        editNodeList: [], // 编辑的节点列表
        currEditId: undefined, // 编辑的节点id（仅已存储）
        currEditName: '', // 编辑的节点名称
        currEditIndex: 0, // 编辑的节点下标
        maxEditNodeCount: 30, // 允许打开的最大节点数
        currEditXsGgNodeInfo: undefined, // 当前正在编辑的节点
    }),
    actions: {
        /**
         * 将新的节点加入到编辑列表中
         * @param node 节点
         * @param errCall 节点最大数，无法继续打开
         * @return 节点是否已存在
         */
        addEditNode(node: NodeInfo, errCall?: () => void): boolean {
            if (!node || !node.sourceName) {
                return false;
            }
            // 判断是否已存在
            const exist = this.editNodeList?.filter((item) => !(item.sourceName === node.sourceName))
            if (!exist) {
                if ((this.editNodeList?.length || 0) >= this.maxEditNodeCount) {
                    errCall?.()
                } else {
                    this.editNodeList?.push(node)
                    this.setCurrEdit((this.editNodeList?.length || 1) - 1, 'index')
                }
            } else {
                this.setCurrEdit(exist[0].sourceName, 'name')
            }
            return !!exist
        },
        /**
         * 移除一个编辑节点
         * 如果正是当前编辑的节点，则让 currEditIndex 置为0
         * 如果不是则 currEditIndex 不变
         * @param sourceName
         */
        delEditNode(sourceName: string) {
            // 移除命中的节点
            this.editNodeList = this.editNodeList?.filter((item) => !(item.sourceName === sourceName))
            // 判断是否是当前编辑的节点
            if (this.currEditName === sourceName) {
                this.setCurrEdit(0, 'index')
            }
        },
        /**
         * 设置当前正在编辑的节点，参数可以是 id/name/index
         * @param params 参数
         * @param type 参数类型
         */
        setCurrEdit(params: number | string | undefined, type: 'id' | 'name' | 'index') {
            if (params === undefined) {
                return;
            }
            this.currEditName = '空白节点'
            switch (type) {
                case "id": {
                    this.editNodeList?.forEach((item, index) => {
                        if (item.id === (params as number)) {
                            this.currEditId = item.id
                            this.currEditName = item.sourceName
                            this.currEditIndex = index
                            this.currEditXsGgNodeInfo = item
                        }
                    })
                    break;
                }
                case "name": {
                    this.editNodeList?.forEach((item, index) => {
                        if (item.sourceName === (params as string)) {
                            this.currEditId = item.id
                            this.currEditName = item.sourceName
                            this.currEditIndex = index
                            this.currEditXsGgNodeInfo = item
                        }
                    })
                    break;
                }
                case "index": {
                    this.currEditIndex = (params as number)
                    const currNode = (this.editNodeList || [])[this.currEditIndex]
                    if (currNode) {
                        this.currEditId = currNode.id
                        this.currEditName = currNode.sourceName
                        this.currEditXsGgNodeInfo = currNode
                    }
                    break;
                }
            }
            this.setCurrNodeJson()

            // 通知 编辑表单初始化、JSON编辑器初始化
            nodeXsGgSelectEvent.emit((this.editNodeList || [])[this.currEditIndex])
        },
        /**
         * 设置json对象
         */
        setCurrNodeJson() {
            const {currEditXsGgNodeInfo} = this
            if (currEditXsGgNodeInfo && currEditXsGgNodeInfo.sourceJson) {
                // 解析成对象
                const {sourceName, sourceJson} = currEditXsGgNodeInfo
                // 处理jsonStr
                if (!sourceJson || !sourceName) {
                    return
                }
                try {
                    const data = JSON.parse(sourceJson)[sourceName]

                    // 处理enable
                    if (!(typeof data['enable'] === 'boolean')) {
                        data['enable'] = !!data['enable']
                    }
                    if (data['lastModifyTime']) {
                        data['lastModifyTimeToLocal'] = timeTools.UnixWithSixDecimalToLocalTime(data['lastModifyTime'])
                    }
                    // 这里将数据转换成字符串用以编辑
                    this.currEditNodeObj = stringifyJson(data, stringifyKeys) as SRNodeInfo;
                } catch (e) {
                    throw e
                }
            }
        },
        /**
         * 数据更新
         * @param node
         */
        updateNodeJson(node: SRNodeInfo) {
            if (node && node.sourceName) {
                this.currEditNodeObj = node
                //
            }
        },
        /**
         *
         * @param nodeStr
         */
        updateNodeJsonStr(nodeStr: string) {

        },
        /**
         * 清空重置
         */
        clear() {
            this.currEditId = undefined
            this.currEditName = undefined
            this.currEditIndex = 0
            this.editNodeList = []
            this.currEditXsGgNodeInfo = undefined
            this.currEditNodeObj = undefined
        },
    },
    getters: {
        getNodeJsonStr(): string {
            return ''
        }
    },
})
