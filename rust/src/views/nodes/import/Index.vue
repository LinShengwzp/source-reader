<script setup lang="ts">
import {reactive, ref} from "vue";
import {UploadFilled} from '@element-plus/icons-vue'
import {ElMessage, UploadFile, UploadFiles} from "element-plus";
import {FileInfo, FileType, NodeInfo, SRNodeInfo} from "@/utils/Models";
import {analyseJsonFile, analyseXbsFile} from "@/utils/xbsTool/xbsFileTools";
import {compressJson} from "@/utils/Strutil";

import NodeList from "@/views/nodes/components/NodeList.vue";

const fileUploadRef = ref()
const nodeListRef = ref()
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
    nodeCount: 0,
    fileType: currFile.fileType ? "JSON 文件" : "XBS 文件"
  }]

  // 解析文件
  await analyseFile()

  // 存储文件
  saveFileNode()

  // 构建菜单
  nodeListRef.value.init(currFile)
}

/**
 * 移除文件
 * @param uploadFile
 * @param uploadFiles
 */
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

    // 存储到数据库，这一步等点击编辑再存储

    // 放到菜单
    nodeList.push(item)
  }
  (currFile.dataInfo as any)[0].nodeCount = nodeList.length
  currFile.nodeList = nodeList
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
            <el-table-column prop="nodeCount" label="节点个数">
              <template #default="scope">
                {{ scope.row.nodeCount }} 个节点
              </template>
            </el-table-column>
            <el-table-column prop="fileName" label="operation" width="260">
              <template #default="scope">
                <div class="select-file-del">
                  <el-link class="operator-link-btn" type="success" href="#" @click="">全部导出</el-link>
                  <el-link class="operator-link-btn" type="primary" href="#" @click="">全部保存</el-link>
                  <el-link class="operator-link-btn" type="danger" href="#" @click="handleFileRemove">移除</el-link>
                </div>
              </template>
            </el-table-column>
          </el-table>
        </el-row>
      </transition>

      <transition name="slide-left">
        <NodeList ref="nodeListRef" v-show="currFile.nodeList"></NodeList>
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
        .operator-link-btn {
          margin-left: 1rem;
        }
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
