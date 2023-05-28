<script setup lang="ts">

import {NodeInfo} from "@/utils/Models";
import {reactive, ref} from "vue";
import {ElNotification, TabsPaneContext} from "element-plus";
import NodeDetail from "@/views/nodes/components/NodeDetail.vue";

interface NodeModifyInitData {
  nodeInfoList: NodeInfo[],
  currNode: number,
  currNodeName: string,
}

const nodeDetailRef = ref()
const initData: NodeModifyInitData = reactive({
  nodeInfoList: [],
  currNode: 0,
  currNodeName: '',
})

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
    if (initData.nodeInfoList.length > 10) {
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

/**
 * 重置清理
 */
const clean = () => {
  initData.nodeInfoList = []
  initData.currNode = 0
}

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

    <NodeDetail v-show="initData.currNodeName" ref="nodeDetailRef"/>
  </div>
</template>

<style scoped lang="scss">

</style>
