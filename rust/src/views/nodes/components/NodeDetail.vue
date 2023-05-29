<script setup lang="ts">
import {FormGroupItem, FormModelItem, NodeInfo, NodeSourceType, SRNodeInfo} from "@/utils/Models";
import {reactive} from "vue";

import DataEditor from "@/components/DataEditor.vue";
import {detailForm, groupFromKeyName, modifyFromItem, moreForm} from "@/views/nodes/components/ModifyFormModel";
import {timeTools} from "@/utils/xbsTool/xbsTools";
import {parseJson, stringifyJson} from "@/utils/Strutil";
import {ArrowLeftBold, CloseBold, Edit, Select} from "@element-plus/icons-vue";
import SvgIcon from "@/components/SvgIcon/Index.vue";
import {TabPaneName} from "element-plus";

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

  modifyGroupTabName: '',
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
  modifyGroupTabName: ''
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

/**
 * 外部修改
 * @param item
 * @param value
 */
const changeValue = (item: FormModelItem, value: any) => {
  if (initData.modifyItem) {
    if (initData.modifyGroupFormType && initData.modifyGroupTabName) {
      // 分组数据
      (initData.nodeJson as any)[initData.modifyItem][initData.modifyGroupTabName][item.model] = value
    } else {
      (initData.nodeJson as any)[initData.modifyItem][item.model] = value
    }
  } else {
    (initData.nodeJson as any)[item.model] = value
  }
}

/**
 * 清空面板
 */
const clean = () => {
  // TODO 清空之前先判断是不是有数据，有数据先存储防止丢失
  initData.node = {}
  initData.nodeJson = {
    sourceName: '',
  }
  initData.modifyItem = ''
  initData.modifyItemForm = {
    title: ''
  }
  initData.modifyGroupFormType = false
  initData.modifyGroupTabName = ''
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
  initData.modifyGroupFormType = groupFromKeyName.indexOf(itemKey) >= 0
  switch (formName) {
    case 'detailForm': {
      initData.modifyItemForm = detailForm[itemKey];
      break
    }
    case 'moreForm': {
      initData.modifyItemForm = moreForm[itemKey]
      break
    }
    default:
      return
  }
  // 数据处理
  if (initData.modifyGroupFormType) {
    // 分组的数据
    let dataGroupMap = (initData.nodeJson as any)[initData.modifyItem]
    if (dataGroupMap) {
      Object.keys(dataGroupMap).forEach((name: string) => {
        dataGroupMap[name] = stringifyJson(dataGroupMap[name], ['requestInfo', 'httpHeaders', 'list', 'moreKeys'])
      })
    }
  } else {
    // 不分组的数据
    let data = (initData.nodeJson as any)[initData.modifyItem]
    data = stringifyJson(data, ['requestInfo', 'httpHeaders', 'list', 'moreKeys'])
  }
}

/**
 * 编辑详细配置点击返回键/保存/取消
 */
const detailBackAndSave = (save: boolean = true) => {
  // 数据处理
  // 数据还原
  if (initData.modifyItem) {
    if (save) {
      if (initData.modifyGroupFormType) {
        // 分组数据
        let groupData = (initData.nodeJson as any)[initData.modifyItem]
        Object.keys(groupData).forEach((name: string) => {
          let data = groupData[name]
          data = parseJson({...data}, ['httpHeaders', 'moreKeys'])
        })
      } else {
        // 不分组的数据
        let data = (initData.nodeJson as any)[initData.modifyItem]
        data = parseJson({...data}, ['httpHeaders', 'moreKeys'])
      }
    }
  }

  initData.modifyItem = ''
  initData.modifyItemForm = {title: ''}
  initData.modifyGroupFormType = false
  initData.modifyGroupTabName = ''
}

/**
 * 编辑分组标签
 * @param targetName
 * @param action
 */
const handleGroupTabsEdit = (targetName: TabPaneName | undefined,
                             action: 'remove' | 'add') => {

}

/**
 * 分组标签切换
 * @param name
 */
const handleGroupTabsChange = (name: TabPaneName) => {
}

const handleInput = (item: FormModelItem) => {
  let commitData = undefined
  if (initData.modifyItem) {
    if (initData.modifyGroupFormType) {
      // 分组数据
      if (initData.modifyGroupTabName) {
        commitData = (initData.nodeJson as any)[initData.modifyItem][initData.modifyGroupTabName][item.model]
      }
    } else {
      commitData = (initData.nodeJson as any)[initData.modifyItem][item.model]
    }
  } else {
    commitData = (initData.nodeJson as any)[item.model]
  }
  if (typeof commitData !== undefined) {
    emits('itemForce', item, commitData)
  }
}
const handleChange = (e: any) => {
  console.log(e, '2444', initData.node?.sourceName)
}
const handleForce = (item: FormModelItem) => {
  handleInput(item)
}

defineExpose({
  init, changeValue
})
</script>

<template>
  <div class="node-detail" v-if="initData.node">
    <transition name="fade">
      <div class="node-detail-box" v-show="!initData.modifyItem">

        <el-row class="header-tool-box">
          <el-col :span="2">
            <el-link style="height: 20px" :underline="false" @click="">
              <el-icon>
                <Edit/>
              </el-icon>
            </el-link>
          </el-col>
          <el-col :span="10" style="text-align: left">
            编辑节点
          </el-col>

          <el-col :span="1" :offset="8" style="display: flex;justify-content: center;">
            <el-tooltip
                class="btn-tooltip"
                effect="light"
                content="导出">
              <el-link style="height: 20px" :underline="false" @click="">
                <svg-icon class="menu-icon" icon="export"/>
              </el-link>
            </el-tooltip>
          </el-col>
          <el-col :span="1">
            <el-tooltip
                class="btn-tooltip"
                effect="light"
                content="保存">
              <el-link :underline="false" @click="">
                <el-icon>
                  <Select/>
                </el-icon>
              </el-link>
            </el-tooltip>
          </el-col>

          <el-col :span="1">
            <el-tooltip
                class="btn-tooltip"
                effect="light"
                content="取消">
              <el-link :underline="false" @click="">
                <el-icon>
                  <CloseBold/>
                </el-icon>
              </el-link>
            </el-tooltip>
          </el-col>
        </el-row>

        <div class="modify-box">
          <el-form ref="nodeInfoFormRef"
                   label-width="20%"
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
                        @input="handleInput(item)"
                        @onChange="handleChange"
                        @onForce="handleForce(item)"
                        clearable/>

            <el-row>
              <el-col :span="10">
                <el-divider content-position="center">常用配置</el-divider>
                <div class="config-btn-group">
                  <el-form-item label-width="100px" v-for="itemKey in Object.keys(detailForm as any)"
                                :key="itemKey"
                                :label="detailForm[itemKey].title">
                    <el-button v-if="hasConfigBtn(itemKey)" type="success"
                               @click="modifyDetailItem('detailForm', itemKey)">
                      已配置
                    </el-button>
                    <el-button v-else @click="modifyDetailItem('detailForm', itemKey)">未配置</el-button>
                  </el-form-item>
                </div>

              </el-col>
              <el-col :span="10" :offset="1">
                <el-divider content-position="center">更多配置</el-divider>
                <div class="config-btn-group">
                  <el-form-item label-width="100px" v-for="itemKey in Object.keys(moreForm as any)"
                                @click="modifyDetailItem('moreForm', itemKey)"
                                :label="moreForm[itemKey].title">
                    <el-button v-if="hasConfigBtn(itemKey)"
                               @click="modifyDetailItem('moreForm', itemKey)"
                               type="success">已配置
                    </el-button>
                    <el-button v-else>未配置</el-button>
                  </el-form-item>
                </div>
              </el-col>

            </el-row>
          </el-form>
        </div>

      </div>
    </transition>

    <transition name="fade">
      <div class="node-detail-item-box" v-show="initData.modifyItem">
        <el-row class="header-tool-box">
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
            <el-tooltip
                class="btn-tooltip"
                effect="light"
                content="保存">
              <el-link :underline="false" @click="detailBackAndSave">
                <el-icon>
                  <Select/>
                </el-icon>
              </el-link>
            </el-tooltip>
          </el-col>

          <el-col :span="1">
            <el-tooltip
                class="btn-tooltip"
                effect="light"
                content="取消">
              <el-link :underline="false" @click="detailBackAndSave(false)">
                <el-icon>
                  <CloseBold/>
                </el-icon>
              </el-link>
            </el-tooltip>
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
                            @input="handleInput(item)"
                            @onChange="handleChange"
                            @onForce="handleForce(item)"
                            clearable/>
              </div>

            </el-form>
          </div>

          <div class="modify-group-item" v-else>

            <el-divider content-position="left">数据分组</el-divider>
            <el-tabs
                v-model="initData.modifyGroupTabName"
                type="card"
                editable
                class="demo-tabs"
                @tabChange="handleGroupTabsChange"
                @edit="handleGroupTabsEdit">
              <el-tab-pane
                  v-for="tabName in Object.keys(initData.nodeJson[initData.modifyItem])"
                  :key="tabName" :label="tabName" :name="tabName">
              </el-tab-pane>
            </el-tabs>

            <el-form v-if="initData.modifyGroupTabName"
                     ref="groupInfoFrom"
                     label-width="100px"
                     :model="initData.nodeJson[initData.modifyItem][initData.modifyGroupTabName]">

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
                            v-model:model-value="initData.nodeJson[initData.modifyItem][initData.modifyGroupTabName][item.model]"
                            @input="handleInput(item)"
                            @onChange="handleChange"
                            @onForce="handleForce(item)"
                            clearable/>
              </div>

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

    .header-tool-box {
      height: 2rem;
      line-height: 2rem;
    }

    .modify-box {
      height: 90%;
      overflow: scroll;
    }

    .config-btn-group {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .menu-icon {
      height: 16px;
      width: 16px;

      ::v-deep {
        svg {
          width: 100% !important;
          height: 100% !important;
        }
      }
    }


  }

  .node-detail-item-box {
    flex: 1;

    .detail-form-box {
      overflow: scroll;
      height: 90%;
    }
  }
}

</style>
