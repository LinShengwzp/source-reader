<template>
    <a-spin :spinning="loading" tip="加载中..." style="height: 100%">
        <div id="app-analyse" class="analyse-container">
            <a-card size="small" title="导入解析" class="card-container">
                <template #extra><a href="#" @click="handleClean">清空</a></template>
                <a-row>
                    <a-col :span="4">
                        <a-input v-model="analyse.filePath"></a-input>
                    </a-col>
                    <a-col :span="12">
                        <a-upload
                                v-model="fileList"
                                name="file"
                                accept=".xbs"
                                :max-count="1"
                                :multiple="false"
                                :showUploadList="false"
                                @change="handleFileChange"
                                :beforeUpload="() => false">
                            <a-button class="analyse-btn" :disabled="loading">
                                打开文件
                            </a-button>
                        </a-upload>
                        <a-button v-show="analyse.completed" class="analyse-btn" :disabled="loading"
                                  @click="handleSaveFile">
                            全部导出
                        </a-button>

                        <a-button class="analyse-btn" :disabled="loading"
                                  @click="queryNodeMenu">
                            本地节点
                        </a-button>

                        <a-button class="analyse-btn" :disabled="loading"
                                  @click="() => {showAddNodeName = true;addNodeName = ''}">
                            新建节点
                        </a-button>
                    </a-col>
                </a-row>
                <a-row v-show="analyse.completed" class="search-node">
                    <a-col :span="4">
                        <a-input size="small" v-model="menuFilter" @change="handleMenuFilter" placeholder="搜索"
                                 allow-clear/>
                    </a-col>
                </a-row>
                <a-row v-show="analyse.completed" class="node-container">
                    <a-col :span="4" class="list-container">
                        <a-row class="menu-list">
                            <a-col :span="24">
                                <ul>
                                    <li v-for="item in filterList" :key="item.id"
                                        @click="handleMenuClick(item)"
                                        :class="['data-item-menu node-item', {'item-select': item.id === menuModel}]">
                                        {{ item.sourceName }}
                                    </li>
                                </ul>
                            </a-col>
                        </a-row>
                    </a-col>
                    <a-col :span="18" class="modify-container">
                        <a-spin :spinning="contentLoading" tip="加载中..." style="height: 100%">
                            <modify ref="modify" @handleSave="handleNodeSave" @handleRemove="handleNodeRemove"></modify>
                        </a-spin>
                    </a-col>
                </a-row>
            </a-card>
        </div>

        <a-modal v-model="showAddNodeName" title="输入新的节点名称"
                 okText="确认" cancelText="取消" centered
                 @ok="addNewNode">
            <a-row>
                <a-col :span="20" :offset="2">
                    <a-input v-model="addNodeName" placeholder="节点名称"/>
                </a-col>
            </a-row>
        </a-modal>

        <a-modal v-model="showDelNodeKey" title="确认删除节点"
                 okText="确认" cancelText="取消" centered
                 @ok="removeNode">
            <a-alert
                    message="是否确认删除节点"
                    description="删除节点后该节点数据不能恢复"
                    type="warning"
                    show-icon
            />
        </a-modal>

        <a-modal v-model="showCoverNode" title="确认覆盖节点"
                 okText="覆盖" cancelText="不覆盖" centered
                 @ok="coverNodeAndReload(true)"
                 @cancel="coverNodeAndReload(false)">
            <a-alert
                    message="已存在相同节点"
                    description="是否覆盖本地已存储的相同节点"
                    type="warning"
                    show-icon
            />
        </a-modal>

    </a-spin>
</template>
<script>
import Modify from "@/views/reader/analyse/Modify.vue";
import {ipcApiRoute} from "@/api/main";
import {byteTools, xbsTools, xxTeaKey} from "@/utils/analyse/xbsTools";
import {SourceTemplate} from "@/model/typeModel";
import {compressJson} from "@/utils/analyse/StrUtil";

export default {
    components: {Modify},
    data() {
        return {
            analyse: {
                filePath: '',
                file: {},
                analyseData: {},
                analyseMap: {},
                completed: false
            },
            loading: false,
            contentLoading: false,
            formList: [
                {
                    id: "",
                    name: "",
                    data: {}
                }
            ],
            filterList: [],
            menuModel: '',
            menuFilter: '',
            fileList: [],
            showAddNodeName: false,
            showDelNodeKey: false,
            showCoverNode: false,
            addNodeName: '',
            delNodeId: '',
            coverNode: false,
            hasSetCover: false,
        };
    },
    mounted() {
        const that = this
        that.handleClean()
    },
    methods: {
        handleClean() {
            const that = this
            that.analyse = {
                filePath: '',
                file: {},
                analyseData: {}, // 临时存储
                analyseMap: {},
                completed: false
            }
            that.loading = false
            that.contentLoading = false
            that.formList = []
            that.filterList = []
            that.menuModel = ''
            that.menuFilter = ''
            that.fileList = []
        },
        /**
         * 选中文件
         * @param info
         * @returns {boolean}
         */
        handleFileChange(info) {
            const that = this
            that.handleClean()
            if (info && info.file) {
                that.analyse.file = info.file
                that.analyse.filePath = that.analyse.file.path
                that.handleAnalyseFile()
            }
            return false;
        },
        /**
         * 解析文件
         */
        handleAnalyseFile() {
            const that = this
            const {analyse} = that
            if (!analyse.filePath || !analyse.file) {
                this.$message.error('请选择需要解析的文件');
                return;
            }
            that.loading = true
            that.$refs['modify'].init()

            let reader = new FileReader();
            reader.readAsArrayBuffer(analyse.file);
            // reader.onload = (e) => {
            //     //获取数据
            //     let res = xbsTools.XBS2Json(Buffer.from(e.currentTarget.result), xxTeaKey, false, 0);
            //     that.analyse.analyseData = byteTools.uint8Array2JsonObj(res)
            //     // 存储
            //     that.saveSourceData()
            // };

            reader.onload = async (e) => {
                //获取数据
                const res = await that.$ipc.invoke(ipcApiRoute.bookSourceFileRead, {
                    filePath: analyse.filePath,
                    cover: that.coverNode,
                    hasSetCover: that.hasSetCover,
                    bufArr: e.currentTarget.result
                })
                if (res && res.code) {
                    switch (res.code) {
                        case 'success':
                        case 'cover':
                            that.formList = res.result
                            break
                        case 'exist':
                            // 没有设置覆盖策略则中断存储，设置之后再导入
                            that.showCoverNode = true;
                            // 中断导入
                            return false;
                    }

                    if (that.formList.length >= 1) {
                        this.handleMenuClick(that.formList[0])
                    }
                    // 清空临时存储
                    that.analyse.analyseData = {}
                    that.analyse.completed = true
                    that.loading = false

                    // 覆盖策略改回false，下次打开文件重新设置
                    that.coverNode = false
                    that.hasSetCover = false
                } else {
                    that.$message.error('打开文件失败')
                }

                // TODO 重新导入要改成 that.handleAnalyseFile()
            };
        },
        /**
         * 存储文件并导出
         * @param menuList
         * @param fileName
         * @returns {Promise<void>}
         */
        async handleSaveFile(menuList, fileName) {
            // 本地存储
            const that = this
            let {analyseData} = that.analyse;
            // 遍历目录
            that.loading = true
            let exportList = []
            if ((menuList instanceof Array)) {
                exportList = [...menuList]
            }

            if (!exportList || exportList.length <= 0) {
                exportList = that.filterList
            }
            if (exportList && exportList.length > 0) {
                await Promise.all(
                    exportList.map(async (menu) => {
                        if (!menu.sourceName) {
                            return;
                        }
                        // 全部数据都从数据库中获取，保证导出的取值统一
                        const res = await that.queryData({
                            id: menu.id,
                            sourceName: menu.sourceName
                        })
                        console.log("query data from local storage", menu.sourceName, res)
                        if (res && res.result && res.result[0]) {
                            // let parse = JSON.parse(await that.$ipc.invoke(ipcApiRoute.bookSourceFileRead, {filePath: res.result[0].sourceJson}));
                            let parse = JSON.parse(res.result[0].sourceJson);
                            analyseData[menu.sourceName] = parse[menu.sourceName]
                        }
                    })
                )
            }
            that.loading = false

            console.log("export data to local", that.analyse.analyseData)

            if (that.analyse.analyseData) {
                let json2XBS = xbsTools.Json2XBS(byteTools.jsonObjToUint8Array(that.analyse.analyseData));
                that.handleExportXbs(json2XBS, fileName)
            }
        },
        /**
         * 选中节点菜单
         * @param menuInfo
         */
        handleMenuClick(menuInfo) {
            const that = this
            that.contentLoading = true
            let {analyseData} = that.analyse;
            if (!analyseData) {
                return
            }
            that.handleMenuFilter()
            that.menuModel = menuInfo.id
            let analyseDatum = analyseData[menuInfo.sourceName];
            console.log("current node select: ", analyseDatum, menuInfo)
            if (menuInfo.sourceName === that.addNodeName) {
                that.$refs['modify'].init({
                    id: menuInfo.id,
                    sourceJson: analyseDatum,
                    sourceName: menuInfo.sourceName
                })
                that.contentLoading = false
                that.analyse.completed = true
                that.loading = false
            } else {
                that.queryData({
                    id: {
                        data: menuInfo.id,
                        query: true
                    }, sourceJson: {query: true}, sourceName: {query: true}
                }).then(async (r) => {
                    if (r && r.result) {
                        let resData = r.result[0];
                        that.menuModel = resData.id
                        that.$refs['modify'].init(resData)
                        that.contentLoading = false
                    }
                }).then(() => {
                    that.analyse.completed = true
                    that.loading = false
                })
            }
        },
        /**
         * 菜单搜索过滤
         */
        handleMenuFilter() {
            const that = this
            that.filterList = that.formList
                .filter(i => i.sourceName.indexOf(that.menuFilter) >= 0)
        },
        handleExportJson(jsonBuffer) {
            const that = this
            that.$ipc.invoke(ipcApiRoute.saveFile, {
                title: '保存源节点',
                fileFilters: [
                    {name: 'JSON Files', extensions: ['json']}
                ],
                fileDefaultPath: '1234.json'
            }).then(r => {
                if (!r.canceled) {
                    that.$ipc.invoke(ipcApiRoute.writeFile, {
                        savePath: r.filePath,
                        content: jsonBuffer
                    })
                    that.$message.info("文件保存成功")
                }
            })
        },
        /**
         * 导出 xbs 文件
         * @param buffer
         * @param fileName
         */
        handleExportXbs(buffer, fileName) {
            const that = this
            that.$ipc.invoke(ipcApiRoute.saveFile, {
                title: '保存文件',
                fileFilters: [
                    {name: 'XBS Files', extensions: ['xbs']}
                ],
                fileDefaultPath: fileName || 'save.xbs'
            }).then(r => {
                if (!r.canceled) {
                    // 多节点保存还是有问题
                    // 单节点打开之后，保存有问题
                    that.$ipc.invoke(ipcApiRoute.writeFile, {
                        savePath: r.filePath,
                        content: buffer
                    })
                    that.$message.info("文件保存成功")
                }
            })
        },
        /**
         * 存储到数据库
         * @returns {Promise<void>}
         */
        async saveSourceData() {
            const that = this
            let {analyseData} = this.analyse;
            if (!analyseData) {
                return
            }
            that.contentLoading = true
            for (const menu in analyseData) {
                that.loading = true
                const data = analyseData[menu]
                if (!data) {
                    continue
                }
                const dataItem = {}
                dataItem[menu] = data
                // 存储json文件
                // const sourceJson = await that.$ipc.invoke(ipcApiRoute.bookSourceFileSave, {
                //     fileName: `StandarReader_${data['sourceName']}.json`,
                //     content: byteTools.jsonObjToUint8Array(dataItem)
                // })
                const sourceJson = compressJson(dataItem);
                const res = await that.$ipc.invoke(ipcApiRoute.bookSourceOperation, {
                    action: 'add',
                    cover: that.coverNode,
                    data: {
                        platform: 'StandarReader',
                        sourceName: data['sourceName'],
                        sourceType: data['sourceType'],
                        sourceUrl: data['sourceUrl'],
                        enable: data['enable'],
                        weight: data['weight'],
                        sourceJson: sourceJson,
                        authorId: data['authorId'],
                        desc: data['desc'],
                        lastModifyTime: data['lastModifyTime'],
                        toTop: data['toTop'],
                    }
                })
                if (res && res.message) {
                    switch (res.message) {
                        case 'success':
                        case 'cover':
                            that.formList.push({
                                id: res.result.id,
                                sourceName: menu
                            })
                            // 存储之后删除这个临时存储节点
                            delete analyseData[menu]
                            break
                        case 'exist':
                            if (that.hasSetCover) {
                                // 已设置覆盖策略则直接导入
                                that.formList.push({
                                    id: res.result.id,
                                    sourceName: menu
                                })
                                // 存储之后删除这个临时存储节点
                                delete analyseData[menu]
                                break
                            } else {
                                // 没有设置覆盖策略则中断存储，设置之后再导入
                                that.showCoverNode = true;
                                // 中断导入
                                return;
                            }
                    }
                }
            }

            if (that.formList.length >= 1) {
                this.handleMenuClick(that.formList[0])
            }
            // 清空临时存储
            that.analyse.analyseData = {}
            that.analyse.completed = true
            that.loading = false

            // 覆盖策略改回false，下次打开文件重新设置
            that.coverNode = false
            that.hasSetCover = false
        },
        /**
         * 是否覆盖本地存储节点，并重新解析
         * @param cover
         * @returns {Promise<void>}
         */
        async coverNodeAndReload(cover) {
            const that = this
            that.coverNode = cover
            that.showCoverNode = false
            // 标识已设置
            that.hasSetCover = true
            // 继续导入
            that.saveSourceData()
        },
        /**
         * 加载本地存储
         * @returns {Promise<void>}
         */
        async queryNodeMenu() {
            const that = this
            that.handleClean()
            that.loading = true
            // 获取菜单和第一个数据
            that.queryData({
                id: {
                    query: true
                },
                platform: "StandarReader",
                sourceName: {
                    query: true
                },
                sourceType: {
                    query: true
                },
                enable: {
                    query: true
                },
                weight: {
                    query: true
                },
                page: {
                    close: true
                }
            }).then(res => {
                if (res && res.result && res.result.length > 0) {
                    that.formList = res.result
                    that.handleMenuFilter()
                    if (that.formList.length > 0) {
                        this.handleMenuClick(that.formList[0])
                    }
                } else {
                    that.$message.error("加载本地数据失败，请先导入")
                    that.loading = false
                }
            }).catch(e => {
                console.error(e)
                that.analyse.completed = true
                that.loading = false
            })

        },
        queryData(data) {
            return this.$ipc.invoke(ipcApiRoute.bookSourceOperation, {
                action: 'get',
                data: data
            })
        },
        /**
         * 新建节点
         * @returns {Promise<void>}
         */
        async addNewNode() {
            const that = this

            if (!that.addNodeName) {
                return;
            }

            let exist = that.formList.filter(i => i.sourceName === that.addNodeName);
            if (exist && exist.length > 0) {
                this.$message.error('当前节点名称已存在');
                return;
            }

            // 当前新建，保存之后写入数据库
            const sourceJson = {
                ...SourceTemplate, ...{
                    "sourceName": that.addNodeName
                }
            }
            let randomId = 'new_node_tem_id_' + new Date().getTime();
            const dataItem = {}
            dataItem[that.addNodeName] = sourceJson

            let sourceJsonStr = compressJson(dataItem);
            const template = {
                id: randomId, // 临时id
                platform: 'StandarReader',
                sourceName: that.addNodeName,
                sourceType: '',
                sourceUrl: '',
                enable: '',
                weight: '',
                sourceJson: sourceJsonStr,
                authorId: '',
                desc: '',
                lastModifyTime: '',
                toTop: '',
            }
            // 插入到列表
            let newMenu = {
                id: template.id,
                sourceName: template.sourceName
            }
            that.$nextTick(() => {
                // 插入到 analyseData
                that.analyse.analyseData[that.addNodeName] = sourceJsonStr
                that.formList = [...[newMenu], ...that.formList]
                that.handleMenuClick(newMenu)
                that.showAddNodeName = false
            })
        },
        /**
         * 修改保存
         * @param submitData
         * @param exp 是否导出
         */
        async handleNodeSave(submitData, exp) {
            const that = this
            if (!submitData) {
                return;
            }
            // 存储
            const res = await that.$ipc.invoke(ipcApiRoute.bookSourceOperation, {
                action: 'saveOrUpdate',
                data: submitData
            })
            const entity = res.result
            if (!(entity && entity.id)) {
                that.$message.error("保存数据失败")
                return;
            }
            this.$message.success("保存节点成功")
            console.log("save data", entity)
            // 如果修改了名称需要刷新菜单
            if (that.menuModel === submitData.id) {
                // 普通修改
                let currMenu = {}
                if (that.menuModel === entity.id) {
                    for (const index in that.formList) {
                        const form = that.formList[index]
                        if (form.id === entity.id) {
                            form.sourceName = entity.sourceName
                            currMenu = form
                            break
                        }
                    }
                }
                // 新增数据
                if (that.addNodeName === entity.sourceName) {
                    for (const index in that.formList) {
                        const form = that.formList[index]
                        if (form.id === submitData.id) {
                            form.id = entity.id
                            form.sourceName = entity.sourceName
                            currMenu = form
                        }
                    }
                    that.analyse.analyseData = {}
                }
                that.addNodeName = ""
                that.handleMenuClick(currMenu)

                if (exp) {
                    that.handleSaveFile([currMenu], entity.sourceName + '.xbs')
                }

            }
        },
        /**
         * 移除
         * @param id
         * @returns {Promise<void>}
         */
        handleNodeRemove(id) {
            this.showDelNodeKey = true
            this.delNodeId = id
        },
        async removeNode() {
            const newList = this.formList.filter(node => node.id !== this.delNodeId)
            const res = await this.$ipc.invoke(ipcApiRoute.bookSourceOperation, {
                action: 'del',
                data: {
                    id: this.delNodeId
                }
            })

            this.$nextTick(() => {
                this.formList = newList
                this.showDelNodeKey = false
                this.delNodeId = ''
                if (newList.length > 0) {
                    this.handleMenuClick(this.formList[0])
                } else {
                    this.handleClean()
                }
            })
        }
    }
};
</script>
<style lang="less" scoped>
#app-analyse {
  padding: 10px 10px;
  text-align: left;
  width: 100%;

  .card-container {
    width: 100%;
    height: 100%;
    position: relative;

    .analyse-btn {
      margin-left: 10px;
    }

    .one-block-2 {
      padding-top: 10px;
    }

    .search-node {
      position: absolute;
      z-index: 100;
      margin-top: 10px;
      width: 95%;
    }

    .node-container {
      position: relative;
      margin-top: 10px;

      .list-container {
        position: absolute;
        height: 100%;
        overflow-y: scroll;
        padding-top: 25px;

        .menu-list {
          overflow-y: scroll;

          ul {
            list-style: none;
            padding: 0;
          }

          .data-item-menu {
            text-align: center;
            cursor: pointer;
          }

          .data-item-menu:hover {
            color: #07C160;
          }

          .item-select {
            background-color: #e6ffee;
            color: #07C160;
          }

          .node-item {
            height: 40px;
            line-height: 40px;
            overflow-x: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            display: -webkit-box;
            -webkit-box-orient: vertical;
            -webkit-line-clamp: 3;
          }

        }
      }

      .modify-container {
        margin-left: 20%;
        min-height: 1080px;
      }
    }
  }

}
</style>
