<script setup lang="ts">

import {FormModelItem, NodeInfo} from "@/utils/Models";
import {onBeforeUnmount, onMounted, reactive, ref} from "vue";
import {ElMessage, ElNotification, TabsPaneContext} from "element-plus";
import NodeDetail from "@/views/nodes/components/NodeDetail.vue";
import CodeEditor from "@/components/CodeEditor.vue";
import NodeDocs from "@/views/nodes/components/NodeDocs.vue";
import {Check, DArrowLeft} from "@element-plus/icons-vue";

interface NodeModifyInitData {
  nodeInfoList: NodeInfo[],
  currNode: number,
  currNodeName: string,
  activeToolName: 'json' | 'docs' | 'cat' | 'code',
  forceItem?: FormModelItem
  showTool: boolean,
}

const nodeDetailRef = ref()
const modifyToolRef = ref()
const jsonEditorRef = ref()
const codeEditorRef = ref()
const initData: NodeModifyInitData = reactive({
  nodeInfoList: [],
  currNode: 0,
  currNodeName: '',
  activeToolName: 'json',
  showTool: true,
})

const style = reactive({
  transTool: {
    transform: "rotate(180deg)",
    transition: "all .3s"
  }
})

const jsonEditor = reactive({
  enableEditor: false
})


onMounted(() => {
  handleResize()
  window.addEventListener('resize', handleResize);
});

onBeforeUnmount(() => {
  handleResize()
  window.removeEventListener('resize', handleResize);
});

const init = (node: NodeInfo) => {
  if (!node || !node.sourceName) {
    return
  }
  let hasNode = false
  for (let index = 0; index < initData.nodeInfoList.length; index++) {
    const item = initData.nodeInfoList[index]
    if (item.sourceName === node.sourceName) {
      initData.currNode = index
      initData.currNodeName = node.sourceName
      hasNode = true
      break
    }
  }
  if (!hasNode) {
    if (initData.nodeInfoList.length > 30) {
      ElNotification({
        title: '标签页过多',
        message: '别开太多标签',
        type: 'error',
      })
      return;
    }
    initData.nodeInfoList.push(node)
    initData.currNode = initData.nodeInfoList.length
    initData.currNodeName = node.sourceName
    selectNode(node)
  } else {
    selectNode(node)
  }
}

/**
 * 切换tab
 * @param tab
 * @param event
 */
const handleNodeTabClick = (tab: TabsPaneContext, event: Event) => {
  initData.nodeInfoList.forEach((item, index) => {
    if (item.sourceName === tab.paneName) {
      initData.currNode = index
      initData.currNodeName = item.sourceName || ''
      selectNode(item)
    }
  })
}

const selectNode = (node: NodeInfo) => {
  nodeDetailRef.value.init(node)
}

/**
 * 移除tab
 * @param targetName
 */
const handleNodeTabRemove = (targetName: string) => {
  initData.nodeInfoList = initData.nodeInfoList.filter((item) => !(item.sourceName === targetName))
  if (initData.currNodeName === targetName) {
    initData.currNode = 0
    if (initData.nodeInfoList.length > 0) {
      initData.currNodeName = initData.nodeInfoList[0].sourceName || '空白节点'
      selectNode(initData.nodeInfoList[0])
    }
  }
}

/**
 * 表单聚焦
 * @param item
 * @param value
 */
const handleFormItemForce = (item: FormModelItem, value: any) => {
  initData.forceItem = item
  console.log("当前force", item)
  if (item.type === 'text') {
    initData.activeToolName = 'code'
    codeEditorRef.value.init(value)
  } else {
    initData.activeToolName = 'json'
  }
}

const handleJsonChange = (json: object) => {
  jsonEditorRef.value.init(json)
}

/**
 * 代码编辑器数据回填
 * @param code
 */
const handleCodeEditorValueChange = (code: string) => {
  nodeDetailRef.value.changeValue(initData.forceItem, code)
}

/**
 * 直接修改JSON
 */
const handleSetJsonEditorData = () => {
  // nodeDetailRef.value.changeJson(json, initData.currNodeName)
  // 获取编辑器中的json
  const jsonData = jsonEditorRef.value.getData()
  ElMessage.warning("请谨慎保存")
}

/**
 * 重置清理
 */
const clean = () => {
  initData.nodeInfoList = []
  initData.currNode = 0
}

/**
 * 监听屏幕高度
 */
const screenHeight = ref(window.innerHeight);
const screenWidth = ref(window.innerWidth);
const handleResize = () => {
  screenHeight.value = window.innerHeight;
  screenWidth.value = window.innerWidth;
  initData.showTool = screenWidth.value >= 1200;
};

defineExpose({
  init, clean
})
</script>

<template>
  <div class="node-modify-box">
    <el-tabs v-model="initData.currNodeName"
             closable class="node-tabs"
             @tab-click="handleNodeTabClick"
             @tab-remove="handleNodeTabRemove">
      <el-tab-pane v-for="(node, index) in initData.nodeInfoList"
                   :label="node.sourceName"
                   :name="node.sourceName || '空白节点'"
                   :key="index">
      </el-tab-pane>
    </el-tabs>

    <div class="modify-box" :style="{height: `${screenHeight - ((screenHeight/10) + 200)}px`}"
         v-show="initData.nodeInfoList.length > 0 && initData.currNodeName">
      <div class="node-modify">
        <NodeDetail @itemForce="handleFormItemForce"
                    @valueChange="handleJsonChange"
                    ref="nodeDetailRef"/>
      </div>

      <transition name="fade">
        <div class="modify-tool" ref="modifyToolRef" v-show="initData.showTool">

          <el-tabs v-model="initData.activeToolName"
                   type="card"
                   class="tool-tabs">
            <el-tab-pane label="JSON" name="json">
              <CodeEditor ref="jsonEditorRef" @change="handleCodeEditorValueChange"
                          :disable="!jsonEditor.enableEditor"></CodeEditor>
              <div class="json-editor-tool">
                <transition name="slide">
                  <el-switch class="enable-edit"
                             v-model="jsonEditor.enableEditor"
                             inline-prompt
                             active-text="编辑"
                             inactive-text="禁用"/>
                </transition>

                <transition name="slide-right">
                  <el-button type="primary" v-show="jsonEditor.enableEditor"
                             :icon="Check as any"
                             @click="handleSetJsonEditorData"
                             circle/>
                </transition>
              </div>
            </el-tab-pane>
            <el-tab-pane label="文档" name="docs">
              <NodeDocs/>
            </el-tab-pane>
            <el-tab-pane label="代码编辑器" name="code">
              <CodeEditor ref="codeEditorRef" :disable="false" @change="handleCodeEditorValueChange"></CodeEditor>
            </el-tab-pane>
            <el-tab-pane label="分类工具" name="cat">
              <div class="iframe-box">
                <iframe class="iframe-item" src="https://bigfantu.gitee.io/xsread/"></iframe>
              </div>
            </el-tab-pane>
            <el-tab-pane label="测试" name="fourth">Task</el-tab-pane>
          </el-tabs>
        </div>
      </transition>

      <div class="show-tool-btn">
        <el-tooltip
            class="btn-tooltip"
            effect="light"
            content="工具">
          <el-link :underline="false" @click="initData.showTool = !initData.showTool">
            <el-icon
                :style="{transform: initData.showTool ?style.transTool.transform:'', transition:style.transTool.transition}">
              <DArrowLeft/>
            </el-icon>
          </el-link>
        </el-tooltip>
      </div>
    </div>

  </div>
</template>

<style scoped lang="scss">


.node-modify-box {
  position: relative;

  .modify-box {
    display: flex;
    position: relative;

    .node-modify {
      flex: 1;
      margin-left: 1rem;
      overflow: scroll;
      display: inline-block;
    }

    .modify-tool {
      flex: 1;
      display: inline-block;
      overflow: scroll;
      position: relative;

      .json-editor-tool {
        position: absolute;
        bottom: 1rem;
        right: 1rem;
        width: 6rem;
        height: 3rem;
        overflow: hidden;
        display: flex;
        justify-content: center;
        justify-items: center;
        align-items: center;

        .editor-submit {
          flex: 1;
        }

        .enable-edit {
          flex: 4;
        }
      }

      div {
        height: 100%;
      }

      .iframe-box {
        height: 100%;

        .iframe-item {
          width: 100%;
          height: 100%;
          border: none;
        }
      }
    }

    .show-tool-btn {
      position: absolute;
      right: 0;
      top: 0.3rem;
    }
  }


}
</style>


<style lang="scss">

.modify-tool {
  .el-tabs__content {
    height: 85% !important;
  }
}


</style>
