<script setup lang="ts">

import {FormModelItem, NodeInfo} from "@/utils/Models";
import {onBeforeUnmount, onMounted, reactive, ref} from "vue";
import {ElNotification, TabsPaneContext} from "element-plus";
import NodeDetail from "@/views/nodes/components/NodeDetail.vue";
import CodeEditor from "@/components/CodeEditor.vue";
import NodeDocs from "@/views/nodes/components/NodeDocs.vue";

interface NodeModifyInitData {
  nodeInfoList: NodeInfo[],
  currNode: number,
  currNodeName: string,
  activeToolName: string,
}

const nodeDetailRef = ref()
const modifyToolRef = ref()
const codeEditorRef = ref()
const initData: NodeModifyInitData = reactive({
  nodeInfoList: [],
  currNode: 0,
  currNodeName: '',
  activeToolName: 'docs',
})


onMounted(() => {
  window.addEventListener('resize', handleResize);
});

onBeforeUnmount(() => {
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
    if (initData.nodeInfoList.length > 20) {
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
  }
}

/**
 * 切换tab
 * @param tab
 * @param event
 */
const handleNodeTabClick = (tab: TabsPaneContext, event: Event) => {
  console.log(tab.paneName)
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
    }
  }
}

const handleFormItemForce = (item: FormModelItem, value: any) => {
  if (item.type === 'text') {
    initData.activeToolName = 'code'
    codeEditorRef.value.init(value)
  }
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

    <div class="modify-box" :style="{height: `${screenHeight - ((screenHeight/10) + 200)}px`}">
      <div class="node-modify">
        <NodeDetail v-show="initData.nodeInfoList.length > 0 && initData.currNodeName"
                    @itemForce="handleFormItemForce"
                    ref="nodeDetailRef"/>
      </div>

      <div class="modify-tool" ref="modifyToolRef"
           v-show="initData.nodeInfoList.length > 0 && initData.currNodeName">

        <el-tabs
            v-model="initData.activeToolName"
            type="card"
            class="tool-tabs">
          <el-tab-pane label="文档" name="docs">
            <NodeDocs />
          </el-tab-pane>
          <el-tab-pane label="代码编辑器" name="code">
            <CodeEditor ref="codeEditorRef"></CodeEditor>
          </el-tab-pane>
          <el-tab-pane label="分类工具" name="cat">
            <div class="iframe-box">
              <iframe class="iframe-item" src="https://bigfantu.gitee.io/xsread/"></iframe>
            </div>
          </el-tab-pane>
          <el-tab-pane label="Task" name="fourth">Task</el-tab-pane>
        </el-tabs>
      </div>
    </div>

  </div>
</template>

<style scoped lang="scss">


.node-modify-box {
  position: relative;

  .modify-box {
    display: flex;

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
