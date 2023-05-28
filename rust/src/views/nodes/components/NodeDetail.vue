<script setup lang="ts">
import {NodeInfo} from "@/utils/Models";
import {reactive} from "vue";
import EditorArea from "@/components/EditorArea.vue";

import DataEditor from "@/components/SvgIcon/DataEditor.vue";

const props = defineProps({
  nodeInfo: {
    type: Object,
    require: true
  }
})

interface NodeDetailInitData {
  node: NodeInfo,
}

const initData: NodeDetailInitData = reactive({
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
const handleInput = (e: any) => {
  console.log(e, '23333', initData.node.sourceName)
}

defineExpose({
  init
})
</script>

<template>
  <div class="node-detail-box">
    <el-form
        label-width="100px"
        :model="initData.node">
      <!--      <EditorArea name="sourceName" label="名称" :model-value="initData.node['sourceName']" type="string"-->
      <!--                  :clearable="true"/>-->

      <DataEditor v-model:model-value="initData.node.sourceName" name="名称" type="string" @input="handleInput"
                  clearable/>
    </el-form>
  </div>
</template>

<style scoped lang="less">

</style>
