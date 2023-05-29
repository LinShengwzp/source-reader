<script setup lang="ts">
import {FormGroupItem, FormModelItem, NodeInfo, NodeSourceType, SRNodeInfo} from "@/utils/Models";
import {reactive} from "vue";

import DataEditor from "@/components/DataEditor.vue";
import {detailForm, groupFrom, modifyFromItem, moreForm} from "@/views/nodes/components/ModifyFormModel";
import {timeTools} from "@/utils/xbsTool/xbsTools";
import {stringifyJson} from "@/utils/Strutil";
import {ArrowLeftBold, CloseBold, Select} from "@element-plus/icons-vue";

const props = defineProps({
  nodeInfo: {
    type: Object,
    require: true
  }
})

const emits = defineEmits(['itemForce'])

interface NodeDetailInitData {
  node?: NodeInfo,
  nodeJson: SRNodeInfo,
  modifyItem: string, // 编辑某一项
  modifyItemForm: FormGroupItem,
  modifyGroupFormType: boolean, // 是否是groupItem
}

const initData: NodeDetailInitData = reactive({
  node: undefined,
  nodeJson: {
    sourceName: '',
  },
  modifyItem: '',
  modifyItemForm: {
    title: ''
  },
  modifyGroupFormType: false,
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

const changeValue = (item: FormModelItem, value: any) => {
  (initData.nodeJson as any)[item.model] = value
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

/**
 * 编辑配置
 * @param formName
 * @param itemKey
 */
const modifyDetailItem = (formName: string, itemKey: string) => {
  initData.modifyItem = itemKey
  initData.modifyGroupFormType = groupFrom.indexOf(itemKey) > 0
  switch (formName) {
    case 'detailForm': {
      initData.modifyItemForm = detailForm[itemKey]
      // 数据处理
      break
    }
    case 'moreForm': {
      initData.modifyItemForm = moreForm[itemKey]
      // 数据处理
      break
    }
  }
}

/**
 * 编辑详细配置点击返回键/保存/取消
 */
const detailBackAndSave = (save: boolean = true) => {
  initData.modifyItem = ''
  initData.modifyItemForm = {title: ''}
  initData.modifyGroupFormType = false

  // 数据处理
}

const handleInput = (e: any) => {
  console.log(e, '23333', initData.node?.sourceName)
}
const handleChange = (e: any) => {
  console.log(e, '2444', initData.node?.sourceName)
}
const handleForce = (item: FormModelItem) => {
  emits('itemForce', item, (initData.nodeJson as any)[item.model])
}
const handleForceDetailItem = (item: FormModelItem) => {

}

defineExpose({
  init, changeValue
})
</script>

<template>
  <div class="node-detail" v-if="initData.node">
    <transition name="fade">
      <div class="node-detail-box" v-show="!initData.modifyItem">
        <el-form ref="nodeInfoFormRef"
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

              <el-form-item v-for="itemKey in Object.keys(detailForm as any)"
                            :key="itemKey"
                            :label="detailForm[itemKey].title">
                <el-button v-if="hasConfigBtn(itemKey)" type="success" @click="modifyDetailItem('detailForm', itemKey)">
                  已配置
                </el-button>
                <el-button v-else @click="modifyDetailItem('detailForm', itemKey)">未配置</el-button>
              </el-form-item>

            </el-col>
            <el-col :span="10" :offset="1">
              <el-divider content-position="center">更多配置</el-divider>

              <el-form-item v-for="itemKey in Object.keys(moreForm as any)"
                            @click="modifyDetailItem('moreForm', itemKey)"
                            :label="moreForm[itemKey].title">
                <el-button v-if="hasConfigBtn(itemKey)"
                           @click="modifyDetailItem('moreForm', itemKey)"
                           type="success">已配置
                </el-button>
                <el-button v-else>未配置</el-button>
              </el-form-item>
            </el-col>

          </el-row>
        </el-form>
      </div>
    </transition>

    <transition name="fade">
      <div class="node-detail-item-box" v-show="initData.modifyItem">
        <el-row>
          <el-col :span="2">
            <el-link :underline="false" @click="detailBackAndSave(false)">
              <el-icon>
                <ArrowLeftBold/>
              </el-icon>
            </el-link>
          </el-col>
          <el-col :span="12" style="text-align: left">
            {{ initData.modifyItemForm.title }}
          </el-col>

          <el-col :span="1" :offset="7">
            <el-link :underline="false" @click="detailBackAndSave">
              <el-icon>
                <Select/>
              </el-icon>
            </el-link>
          </el-col>

          <el-col :span="1">
            <el-link :underline="false" @click="detailBackAndSave(false)">
              <el-icon>
                <CloseBold/>
              </el-icon>
            </el-link>
          </el-col>
        </el-row>

        <div class="detail-form-box">
          <div class="modify-detail-item" v-if="!initData.modifyGroupFormType">
            <el-form
                ref="detailInfoFrom"
                label-width="30%"
                :model="initData.nodeJson">

              <div v-for="group in initData.modifyItemForm.formGroups" :key="group.title">
                <el-divider content-position="left">{{ group.title }}</el-divider>

                <div class="detail-tips">
                  <ul>
                    <li class="detail-tip" v-for="tip in group.tips">
                      {{ tip }}
                    </li>
                  </ul>
                </div>

                <DataEditor v-for="item in group.items"
                            :type="item.type"
                            :label="item.label"
                            :name="item.model"
                            :help="item.help"
                            :placeholder="item.placeholder"
                            :options="item.options"
                            v-model:model-value="initData.nodeJson[initData.modifyItem][item.model]"
                            @input="handleInput"
                            @onChange="handleChange"
                            @onForce="handleForceDetailItem(item)"
                            clearable/>
              </div>

            </el-form>
          </div>

          <div class="modify-group-item" v-else>
            <el-form
                ref="groupInfoFrom"
                label-width="100px"
                :model="initData.nodeJson">
            </el-form>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped lang="scss">
.node-detail {
  display: flex;
  height: 100%;

  .node-detail-box {
    flex: 1;
  }

  .node-detail-item-box {
    flex: 1;

    .detail-form-box {
      overflow: scroll;
      height: 95%;
    }
  }
}
</style>
