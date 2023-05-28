<script setup lang="ts">
import {NodeInfo} from "@/utils/Models";
import {reactive} from "vue";

const props = defineProps({
  nodeInfo: {
    type: Object,
    require: true
  }
})

interface NodeDetailInitData {
  node: NodeInfo,
}

const initData = reactive({
  node: {}
})

const init = (node: NodeInfo) => {
  clean()
  initData.node = node
  submit()
}

const clean = () => {
  initData.node = {}
}

/**
 * 存储提交，如果没有存储过则存储并返回id
 */
const submit = () => {
  console.log(initData.node, "curr node")
}

defineExpose({
  init
})
</script>

<template>
  <div class="node-detail-box">
    <el-form
        label-width="100px"
        :model="initData.node"
        style="max-width: 460px">
      <el-form-item label="名称">
        <el-input v-model="initData.node.sourceName" />
      </el-form-item>
    </el-form>
  </div>
</template>

<style scoped lang="less">

</style>
