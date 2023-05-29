<script setup lang="ts">
import {FormModelItem, NodeInfo, NodeSourceType, SRNodeInfo} from "@/utils/Models";
import {reactive} from "vue";

import DataEditor from "@/components/DataEditor.vue";
import {detailForm, modifyFromItem, moreForm} from "@/views/nodes/components/ModifyFormModel";
import {timeTools} from "@/utils/xbsTool/xbsTools";
import {stringifyJson} from "@/utils/Strutil";

const props = defineProps({
  nodeInfo: {
    type: Object,
    require: true
  }
})

const emits = defineEmits(['itemForce'])

interface NodeDetailInitData {
  node: NodeInfo,
  nodeJson: SRNodeInfo
}

const initData: NodeDetailInitData = reactive({
  node: {},
  nodeJson: {
    sourceName: '',
  },
})

const init = (node: NodeInfo) => {
  clean()
  initData.node = node


  // 处理json
  const {sourceName, sourceJson} = initData.node
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
    const nodeJson = stringifyJson(data, ['httpHeaders']);
    initData.nodeJson = {
      ...{
        sourceName: sourceName
      }, ...nodeJson
    }

  } catch (e) {
    console.error("parse json failure")
    return;
  }


  submit()
}

const clean = () => {
  initData.node = {}
}

/**
 * 判断某项配置是否已设置
 * @param configKey
 */
const hasConfigBtn = (configKey: string): boolean => {
  let configed = false;
  const config = (initData.nodeJson as any)[configKey];
  if (config) {
    for (const key in config) {
      if (key !== 'actionID' && key !== 'parserID' && key !== 'responseFormatType') {
        if (config[key]) {
          configed = true
        }
      }
    }
  }
  return configed;
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
const handleChange = (e: any) => {
  console.log(e, '2444', initData.node.sourceName)
}
const handleForce = (item: FormModelItem) => {
  emits('itemForce', item, (initData.nodeJson as any)[item.model])
}

defineExpose({
  init
})
</script>

<template>
  <div class="node-detail-box">
    <el-form
        label-width="100px"
        :model="initData.nodeJson">
      <el-divider content-position="left">基础信息</el-divider>

      <DataEditor v-for="item in modifyFromItem"
                  :type="item.type"
                  :label="item.label"
                  :name="item.model"
                  :help="item.help"
                  :placeholder="item.placeholder"
                  :options="item.options"
                  v-model:model-value="initData.nodeJson[item.model]"
                  @input="handleInput"
                  @onChange="handleChange"
                  @onForce="handleForce(item)"
                  clearable/>

      <el-row>
        <el-col :span="10">
          <el-divider content-position="center">常用配置</el-divider>

          <el-form-item v-for="itemKey in Object.keys(detailForm)"
                        :key="itemKey"
                        :label="detailForm[itemKey].title">
            <el-button v-if="hasConfigBtn(itemKey)" type="success">已配置</el-button>
            <el-button v-else>未配置</el-button>
          </el-form-item>

        </el-col>
        <el-col :span="10" :offset="1">
          <el-divider content-position="center">更多配置</el-divider>

          <el-form-item v-for="itemKey in Object.keys(moreForm)"
                        :label="moreForm[itemKey].title">
            <el-button v-if="hasConfigBtn(itemKey)" type="success">已配置</el-button>
            <el-button v-else>未配置</el-button>
          </el-form-item>
        </el-col>

      </el-row>
    </el-form>
  </div>
</template>

<style scoped lang="less">

</style>
