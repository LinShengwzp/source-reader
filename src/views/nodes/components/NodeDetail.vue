<script setup lang="ts">
import {FormGroupItem, FormModelItem, NodeInfo, NodeSourceType, SRNodeInfo} from "@/utils/Models";
import {reactive, ref} from "vue";

import DataEditor from "@/components/DataEditor.vue";
import {detailForm, groupFromKeyName, modifyFromItem, moreForm} from "@/views/nodes/components/ModifyFormModel";
import {timeTools} from "@/utils/xbsTool/xbsTools";
import {compressJson, parseJson, stringifyJson} from "@/utils/Strutil";
import {ArrowLeftBold, CloseBold, Edit, Select} from "@element-plus/icons-vue";
import SvgIcon from "@/components/SvgIcon/Index.vue";
import {ElMessage, TabPaneName} from "element-plus";
import {bookInfo, BookSource} from "@/utils/storage/Table";

const props = defineProps({
  nodeInfo: {
    type: Object,
    require: true
  }
})

const emits = defineEmits(['itemForce', "valueChange"])

interface NodeDetailInitData {
  node?: NodeInfo,
  nodeJson: SRNodeInfo,
  modifyItem: string, // 编辑某一项
  modifyItemForm: FormGroupItem,
  modifyGroupFormType: boolean, // 是否是groupItem
  modifyGroupTabName: string,
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
  modifyGroupTabName: '',
})

const existNodeConfirmRef = ref()
const existNodeData = reactive({
  dialogVisible: false,
  coverNode: false,
  hasSetCover: false,
})

interface GroupTabOperateData {
  showDialog: boolean,
  addTabName: string,
  showRemove: boolean,
  removeName: string,
}

const groupTabOperate: GroupTabOperateData = reactive({
  showDialog: false,
  addTabName: '',
  showRemove: false,
  removeName: ''
})

const stringifyKeys: string[] = ['requestInfo', 'httpHeaders', 'moreKeys'];
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
    const nodeJson = stringifyJson(data, stringifyKeys);
    initData.nodeJson = {
      ...{
        sourceName: sourceName
      }, ...nodeJson
    }
    submit()
  } catch (e) {
    console.error("parse json failure")
    return;
  }
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
 * 外部直接修改json
 * @param json
 * @param nodeName
 */
const changeJson = (json: string, nodeName: string) => {
  const data = JSON.parse(json)

  // 处理enable
  if (!(typeof data['enable'] === 'boolean')) {
    data['enable'] = !!data['enable']
  }
  if (data['lastModifyTime']) {
    data['lastModifyTimeToLocal'] = timeTools.UnixWithSixDecimalToLocalTime(data['lastModifyTime'])
  }

  // 这里将数据转换成字符串用以编辑
  const nodeJson = stringifyJson(data, stringifyKeys);
  initData.nodeJson = {
    ...{
      sourceName: nodeName
    }, ...nodeJson
  }
  submit()
}

/**
 * 清空面板
 */
const clean = () => {
  console.log("准备清除原有数据: ", initData.node, initData.nodeJson)
  submit()
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
const submit = async () => {
  const node = initData.nodeJson
  handleChange({})
  // 存储
  if (!node || !node.sourceName || !!node.searchBook) {
    const sourceJson: Record<string, SRNodeInfo> = {}
    sourceJson[node.sourceName] = node
    const json = compressJson(sourceJson);
    // 重新组合数据存储
    const item: BookSource = {
      id: undefined,
      platform: 'StandarReader',
      sourceName: node['sourceName'],
      sourceType: node['sourceType'],
      sourceUrl: node['sourceUrl'],
      enable: node['enable'],
      weight: node['weight'],
      sourceJson: json,
      authorId: node['authorId'],
      desc: node['desc'],
      lastModifyTime: node['lastModifyTime'],
      toTop: node['toTop'],
    }

    // 覆盖 || 设置不覆盖
    if (existNodeData.coverNode || (existNodeData.hasSetCover && !existNodeData.coverNode)) {
      const saveRes = await bookInfo.operates?.save(item, existNodeData.coverNode)
      if (saveRes && saveRes.code) {
        const {code} = saveRes
        switch (code) {
          case 'exist': {
            if (!existNodeData.hasSetCover) {
              existNodeData.dialogVisible = true
              return;
            }
            break
          }
          case 'success': {
            ElMessage.success("保存成功")
            // 上级保存

            return
          }
          case  'failure': {
            ElMessage.error(saveRes?.msg)
          }
        }
      }
    }
  }

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
        dataGroupMap[name] = stringifyJson(dataGroupMap[name], stringifyKeys)
      })
    }
  } else {
    // 不分组的数据
    let data = (initData.nodeJson as any)[initData.modifyItem]
    data = stringifyJson(data, stringifyKeys)
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
          data = parseJson({...data}, stringifyKeys)
        })
      } else {
        // 不分组的数据
        let data = (initData.nodeJson as any)[initData.modifyItem]
        data = parseJson({...data}, stringifyKeys)
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
  switch (action) {
    case "add": {
      groupTabOperate.addTabName = ''
      groupTabOperate.showDialog = true
      break
    }
    case "remove": {
      if (targetName) {
        groupTabOperate.showRemove = true
        groupTabOperate.removeName = targetName as string
      }
      break
    }
  }
}

/**
 * 添加分组标签
 * @param copy 是否复制
 */
const handleAddGroup = (copy: boolean) => {
  if (!initData.modifyItem || !groupTabOperate.addTabName || !initData.modifyGroupFormType) {
    return
  }
  const modifyItem = (initData.nodeJson as any)[initData.modifyItem]
  let itemKeys = Object.keys(modifyItem);
  if (itemKeys.indexOf(groupTabOperate.addTabName) >= 0) {
    return;
  }
  let newTabData = {
    actionID: initData.modifyItem,
    parserID: "DOM",
    _sIndex: itemKeys.length + 1
  };
  if (copy) {
    const copyTargetName = initData.modifyItem === 'bookWorld' ? 'searchBook' : 'searchShudan'
    let copyTarget = stringifyJson(initData.nodeJson[copyTargetName], stringifyKeys)
    newTabData = {...copyTarget, ...newTabData}
  }
  modifyItem[groupTabOperate.addTabName] = newTabData

  initData.modifyGroupTabName = groupTabOperate.addTabName
  groupTabOperate.showDialog = false
  groupTabOperate.addTabName = ''
}

/**
 * 删除分组标签
 */
const handleRemoveGroup = () => {
  if (!initData.modifyItem || !groupTabOperate.removeName || !initData.modifyGroupFormType) {
    return
  }
  const modifyItem = (initData.nodeJson as any)[initData.modifyItem]
  let itemKeys = Object.keys(modifyItem).filter(i => i !== groupTabOperate.removeName);

  // 切换标签页
  if (initData.modifyGroupTabName === groupTabOperate.removeName) {
    if (itemKeys.length > 0) {
      initData.modifyGroupTabName = itemKeys[0]
    } else {
      initData.modifyGroupTabName = ''
    }
  }

  delete modifyItem[groupTabOperate.removeName]
  groupTabOperate.showRemove = false
  groupTabOperate.removeName = ''
}

/**
 * 分组标签切换
 * @param name
 */
const handleGroupTabsChange = (name: TabPaneName) => {

}

const handleChange = (e: any) => {
  let jsonStr = JSON.stringify(initData.nodeJson, null, 2);
  emits('valueChange', jsonStr)
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
  handleChange(item)
}
const handleForce = (item: FormModelItem) => {
  handleInput(item)
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
  submit()
}

defineExpose({
  init, changeValue, changeJson
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

    <el-dialog
        v-model="groupTabOperate.showDialog"
        title="添加分组"
        width="30%"
        :close-on-click-modal="false"
        :close-on-press-escape="false"
        :draggable="true"
        align-center>
      <div>
        <el-input placeholder="分组名称" v-model="groupTabOperate.addTabName"/>
      </div>
      <template #footer>
      <span class="dialog-footer">
        <el-button @click="groupTabOperate.showDialog = false">取消</el-button>
        <el-button type="success" @click="handleAddGroup(true)">复制搜索</el-button>
        <el-button type="primary" @click="handleAddGroup(false)">添加分组</el-button>
      </span>
      </template>
    </el-dialog>

    <el-dialog
        v-model="groupTabOperate.showRemove"
        title="删除分组"
        width="30%"
        align-center>
      <span>是否删除分组 [{{ groupTabOperate.removeName }}] ？</span>
      <template #footer>
      <span class="dialog-footer">
        <el-button @click="groupTabOperate.showRemove = false">取消</el-button>
        <el-button type="danger" @click="handleRemoveGroup">删除</el-button>
      </span>
      </template>
    </el-dialog>

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
    width: 100%;

    .detail-form-box {
      overflow: scroll;
      height: 90%;
    }
  }
}

</style>
