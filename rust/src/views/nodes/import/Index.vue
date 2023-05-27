<script setup lang="ts">
import {computed, reactive, ref} from "vue";
import {CaretLeft, CaretRight, StarFilled, UploadFilled} from '@element-plus/icons-vue'
import {ElMessage, UploadFile, UploadFiles} from "element-plus";
import {FileType, NodeInfo, SRNodeInfo} from "@/utils/Models";
import {analyseXbsFile, analyseJsonFile} from "@/utils/xbsTool/xbsFileTools";
import {compressJson} from "@/utils/Strutil";


interface PageInfo {
  total: number,
  size: number,
  pageCount: number,
  currPage: number,
}

interface FileInfo {
  file?: File,
  fileType?: FileType,
  analyseNode?: object,
  dataInfo?: Array<any>,
  nodeList?: Array<any>,
  menuList?: Array<any>,
  nodeSearch?: string,
  page: PageInfo
}

const fileUploadRef = ref()
const currFile: FileInfo = reactive({
  page: {
    total: 0,
    size: 10,
    pageCount: 0,
    currPage: 0,
  }
})
const existNodeConfirmRef = ref()
const existNodeData = reactive({
  dialogVisible: false,
  coverNode: false,
  hasSetCover: false,
})
const modifyNode = reactive({
  showEditor: false,
  style: {
    listBoxWidth: 100,
    editBoxWidth: 0,
    transform: "rotate(180deg)",
    transition: "all .3s"
  },
  currEdit: null,
})

/**
 * 初始化
 */
const init = () => {
  fileUploadRef.value.clearFiles()
  currFile.file = undefined
  currFile.analyseNode = undefined
  currFile.dataInfo = undefined
  currFile.nodeList = undefined
  currFile.menuList = undefined
  existNodeData.dialogVisible = false
  existNodeData.coverNode = false
  existNodeData.hasSetCover = false
  modifyNode.showEditor = false
  modifyNode.style.listBoxWidth = 100
  modifyNode.style.editBoxWidth = 0
}

/**
 * 选中打开文件
 * @param file
 * @param fileList
 */
const handleFileChange = async (file: UploadFile, fileList: UploadFiles) => {
  console.log("select file", file)
  init()
  if (!file || !file.name) {
    return
  }
  if (file.name.toLowerCase().endsWith('xbs')) {
    currFile.fileType = FileType.XBS
  } else {
    currFile.fileType = FileType.JSON
  }
  currFile.file = file.raw
  currFile.dataInfo = [{
    fileName: file.name,
    filePath: file.name,
    fileType: currFile.fileType ? "JSON" : "XBS"
  }]

  // 解析文件
  await analyseFile()

  // 存储文件
  saveFileNode()

  // 构建菜单
  buildMenu()
}

const handleFileRemove = (uploadFile: UploadFile, uploadFiles: UploadFiles) => {
  init()
}

/**
 * 解析文件
 */
const analyseFile = async () => {
  try {
    if (currFile.fileType === FileType.XBS) {
      currFile.analyseNode = await analyseXbsFile(currFile.file)
    } else {
      analyseJsonFile(currFile.file)
    }
  } catch (e) {
    ElMessage.error(`导入文件解析失败: ${e}`)
  }
}

/**
 * 存储节点
 */
const saveFileNode = () => {
  const {analyseNode} = currFile
  if (!analyseNode) {
    return
  }
  const nodeList: Array<NodeInfo> = []
  // 存储和构建菜单
  for (const name in analyseNode) {
    const node: SRNodeInfo = (analyseNode as any)[name]
    if (!node || !node['sourceName']) {
      continue
    }
    const dataItem: any = {}
    dataItem[name] = node
    let sourceJson = compressJson(dataItem);
    const item: NodeInfo = {
      id: undefined,
      platform: 'StandarReader',
      sourceName: node['sourceName'],
      sourceType: node['sourceType'],
      sourceUrl: node['sourceUrl'],
      enable: node['enable'],
      weight: node['weight'],
      sourceJson: sourceJson,
      authorId: node['authorId'],
      desc: node['desc'],
      lastModifyTime: node['lastModifyTime'],
      toTop: node['toTop'],
    }

    // 存储到数据库

    // 放到菜单
    nodeList.push(item)
  }
  currFile.nodeList = nodeList
}

const buildMenu = (pageNum: number = 1) => {
  const {nodeList, page} = currFile
  if (!nodeList || nodeList.length < 1) {
    return;
  }

  if (pageNum < 1) {
    pageNum = 1
  }

  page.total = nodeList.length
  page.pageCount = page.total / page.size

  if (pageNum > page.pageCount) {
    pageNum = page.pageCount
  }

  page.currPage = pageNum
  const start: number = (pageNum - 1) * page.size
  let end: number = start + page.size
  if (end > page.total) {
    end = page.total
  }
  currFile.menuList = nodeList.slice(start, end)
}


/**
 * 本地已存在节点，准备覆盖
 * @param cover
 */
const coverNodeAndReload = (cover: boolean) => {
  existNodeData.coverNode = cover
  existNodeData.hasSetCover = true
  existNodeData.dialogVisible = false
  // 继续导入
  saveFileNode()
}

/**
 * 点击某行
 * @param row
 * @param column
 * @param event
 */
const handleNodeRowClick = (row: NodeInfo, column: string | number | undefined, event: PointerEvent) => {
  if (!modifyNode.showEditor) {
    showEdit()
    modifyNode.currEdit = (row as any)
  }
}

/**
 * 点击箭头展开
 */
const handleExportNodeList = () => {
  if (modifyNode.showEditor) {
    showEdit()
  }
}

const showEdit = () => {
  const change = !modifyNode.showEditor
  if (change) {
    modifyNode.showEditor = change
    modifyNode.style.listBoxWidth = 20
    modifyNode.style.editBoxWidth = 80
  } else {
    modifyNode.style.listBoxWidth = 100
    modifyNode.style.editBoxWidth = 0
    setTimeout(() => {
      modifyNode.showEditor = change
    }, 400)
  }
}

const leftWidth = computed(() => `${modifyNode.style.listBoxWidth}%`);
const rightWidth = computed(() => `${modifyNode.style.editBoxWidth}%`);

const nodePageData = computed(() => {
  if (modifyNode.showEditor) {
    return [{
      prep: currFile.page.currPage - 1,
      curr: currFile.page.currPage,
      next: currFile.page.currPage + 1,
    }]
  } else {
    return [{
      prep: currFile.page.currPage - 1,
      curr: currFile.page.currPage,
      next: currFile.page.currPage + 1,
    }]
  }
})

defineExpose({
  init
})
</script>

<template>
  <div class="import-node-box">
    <div class="import-file-box">
      <transition name="fade">
        <el-upload class="upload-box"
                   ref="fileUploadRef"
                   v-show="!currFile.file"
                   accept=".xbs,.json"
                   :auto-upload="false"
                   :limit="1" drag
                   :show-file-list="false"
                   @change="handleFileChange"
                   :before-upload="() => false">
          <template #trigger>
            <div class="file-select">
              <el-icon class="el-icon--upload">
                <upload-filled/>
              </el-icon>
              <div class="el-upload__text">
                点击选择 XBS/JSON 文件
              </div>
            </div>
          </template>
          <template #tip>
            <div class="el-upload__tip">
            </div>
          </template>
        </el-upload>
      </transition>

      <transition name="fade">
        <el-row class="select-file-box" v-if="currFile.file">
          <el-table ref="tableFileDataInfoRef" :data="currFile.dataInfo" style="width: 100%" :show-header="false">
            <el-table-column prop="fileName" label="文件名称"/>
            <el-table-column prop="fileType" label="文件类型"/>
            <el-table-column prop="fileName" label="operation" width="60">
              <template #default="scope">
                <div class="select-file-del">
                  <el-link type="danger" href="#" @click="handleFileRemove">移除</el-link>
                </div>
              </template>
            </el-table-column>
          </el-table>
        </el-row>
      </transition>

      <transition name="slide-left">
        <div class="node-list-edit-box" v-if="currFile.nodeList">
          <div class="node-list-box" :style="{ width: leftWidth }">
            <div class="node-list">
              <transition name="slide-left">
                <div class="node-list-table">
                  <el-table ref="tableNodeDataInfoRef"
                            border highlight-current-row
                            @row-click="handleNodeRowClick"
                            :data="currFile.menuList" style="width: 100%">
                    <el-table-column :resizable="false" type="index" show-overflow-tooltip width="50">
                      <template #header>
                      <span style="float: right" @click="handleExportNodeList">
                        <el-icon
                            :style="{transform: modifyNode.showEditor ?modifyNode.style.transform:'', transition:modifyNode.style.transition}">
                          <CaretLeft/>
                        </el-icon>
                      </span>
                      </template>
                    </el-table-column>
                    <el-table-column :resizable="false" prop="sourceName" show-overflow-tooltip label="节点名称">
                      <template #header>
                        <el-input v-model="currFile.nodeSearch" size="small" placeholder="搜索名称" clearable/>
                      </template>
                    </el-table-column>
                    <el-table-column :resizable="false" prop="platform" label="节点平台" v-if="!modifyNode.showEditor"/>
                    <el-table-column :resizable="false" prop="sourceType" label="节点类型"
                                     v-if="!modifyNode.showEditor"/>
                    <el-table-column :resizable="false" prop="authorId" label="作者" v-if="!modifyNode.showEditor"/>
                    <el-table-column :resizable="false" prop="weight" label="权重" v-if="!modifyNode.showEditor"/>
                    <el-table-column :resizable="false" prop="enable" label="启用" v-if="!modifyNode.showEditor"/>
                  </el-table>

                  <div class="node-list-page-tool">

                    <el-pagination v-if="currFile.page.total > 10" layout="prev, pager, next"
                                   :hide-on-single-page="true"
                                   :total="currFile.page.total"
                                   :page-count="currFile.page.pageCount"
                                   :page-size="currFile.page.size"
                                   :current-page="currFile.page.currPage"
                                   @current-change="(v:number) => buildMenu(v)"/>
                  </div>
                </div>
              </transition>
            </div>
            <div>
              <el-table ref="tableNodePageRef" :data="nodePageData" style="width: 100%" :show-header="false">
                <el-table-column prop="prep" label="文件名称"/>
                <el-table-column prop="curr" label="文件类型"/>
                <el-table-column prop="next" label="operation"></el-table-column>
              </el-table>
            </div>
          </div>
          <div class="node-edit-box" :style="{ width: rightWidth }">
            23
          </div>
        </div>
      </transition>

    </div>
  </div>
  <el-dialog
      ref="existNodeConfirmRef"
      v-model="existNodeData.dialogVisible"
      title="是否覆盖节点"
      width="30%"
      align-center>
    <h3>已存在相同节点</h3>
    <span>是否覆盖本地已存储的相同节点？</span>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="coverNodeAndReload(true)">覆盖</el-button>
        <el-button type="primary" @click="coverNodeAndReload(false)">不覆盖</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.import-node-box {
  position: relative;

  .import-file-box {
    .upload-box {
      position: relative;

      .file-select {
      }
    }

    .select-file-box {
      margin: 0.1rem;
      cursor: pointer;
      //height: 1.5rem;

      .select-file-info {

      }

      .select-file-del {

      }
    }

    .node-list-edit-box {
      display: flex;

      .node-edit-box {
        transition: width .5s ease; /* 添加过渡动画 */
      }

      .node-list-box {
        transition: width .5s ease; /* 添加过渡动画 */
      }

      .node-list {
        .node-list-table {
          position: relative;

          .node-list-page-tool {
            position: absolute;
            left: 1rem;
            bottom: -30rem;
          }
        }
      }
    }
  }
}

.el-table .warning-row {
  --el-table-tr-bg-color: var(--el-color-warning-light-9);
}

.el-table .success-row {
  --el-table-tr-bg-color: var(--el-color-success-light-9);
}

.slide-left-enter-active,
.slide-left-leave-active {
  transition: transform 0.5s;
}

.slide-left-enter-from,
.slide-left-leave-to {
  transform: translateX(-100%);
}

</style>
