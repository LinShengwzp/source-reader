<script setup lang="ts">

import {onMounted, reactive, ref} from "vue";
import {NodeOperate} from "@/utils/Models";
import {TabsPaneContext} from "element-plus";

import ImportNode from './import/Index.vue'
import LocalNode from './local/Index.vue'

const localNodeRef = ref()
const importNodeRef = ref()
const initData = reactive({
  currNodeOption: {},
  nodeOperateFormData: {},
  activeTabName: 'localNodes',
})

onMounted(() => {
  handleNodeOperateClick(nodeOptions[1])
})

const nodeOptions: Array<NodeOperate> = [{
  id: 0,
  name: 'localNodes',
  label: '本地节点',
  operate: () => {
  }
}, {
  id: 1,
  name: 'importNodes',
  label: '导入节点',
  operate: () => {
  }
}, {
  id: 2,
  name: 'exportNodes',
  label: '导出节点',
  operate: () => {
  }
}, {
  id: 3,
  name: 'createNodes',
  label: '新建节点',
  operate: () => {
  }
}]

const handleNodeOperateClick = (operate: NodeOperate) => {
  if (operate && operate) {
    initData.currNodeOption = operate
    initData.activeTabName = operate.name
  }
}
const handleTabClick = (pane: TabsPaneContext, ev: Event) => {
}

</script>

<template>
  <div class="main-container">

    <el-container>
      <el-header class="header-box">
        <el-tabs v-model="initData.activeTabName" class="operate-tab-box" @tab-click="handleTabClick">
          <el-tab-pane :label="nodeOptions[0].label" :name="nodeOptions[0].name">
            <local-node ref="localNodeRef"></local-node>
          </el-tab-pane>
          <el-tab-pane :label="nodeOptions[1].label" :name="nodeOptions[1].name">
            <import-node ref="importNodeRef"></import-node>
          </el-tab-pane>
        </el-tabs>
      </el-header>
      <el-main class="main-box">

      </el-main>
      <el-footer class="footer-box">
      </el-footer>
    </el-container>

    <div class="operate-box" v-if="false">
      <div class="node-operate-box">
        <div class="node-operate-item hvr-grow-shadow" v-for="operate in nodeOptions"
             @click="handleNodeOperateClick(operate)">
          {{ operate.label }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">

.main-container {
  position: relative;
  display: flex;

  .operate-box {
    height: 90%;
    width: 98%;
    padding: 1rem;
    display: flex;
    position: relative;

    .node-operate-box {
      width: 98%;
      height: 100%;
      display: flex;
      position: relative;
      border-radius: 0.5rem;
      margin-left: 1%;
      align-items: center;
      justify-content: center;

      .node-operate-item {
        flex: 1;
        display: flex;
        height: 5%;
        cursor: pointer;
        user-select: none;
        align-items: center;
        justify-content: center;
      }

      .node-operate-item:hover {
        background: linear-gradient(rgba(123, 126, 255, 0.2), rgba(64, 213, 246, 0.6));
        color: white;
        border-radius: 5px;
      }
    }

  }

  .header-box {
    flex: 1;
    display: flex;
    position: relative;

    .operate-tab-box {
      width: 100%;
      user-select: none;
    }

  }

  .main-container {
    flex: 17;
    display: flex;
    position: relative;
  }

  .footer-box {
    flex: 2;
  }
}

</style>
