<script setup lang="ts">

import {FormModelItem, NodeInfo} from "@/utils/Models";
import {computed, ComputedRef, onBeforeUnmount, onMounted, reactive, ref} from "vue";
import {ElMessage, ElNotification, TabsPaneContext} from "element-plus";
import NodeDetail from "@/views/nodes/components/NodeDetail.vue";
import CodeEditor from "@/components/CodeEditor.vue";
import NodeDocs from "@/views/nodes/components/NodeDocs.vue";
import {Check, DArrowLeft} from "@element-plus/icons-vue";
import {nodeXsGgSelectEvent} from "@/bus";
import {nodeStore} from '@/store'

interface NodeModifyInitData {
  activeToolName: 'json' | 'docs' | 'cat' | 'code',
  forceItem?: FormModelItem
  showTool: boolean,
}

const nodeState = nodeStore()
const nodeDetailRef = ref()
const modifyToolRef = ref()
const jsonEditorRef = ref()
const codeEditorRef = ref()

const nodeInfoList = computed(() => nodeState.editNodeList || [])

const initData: NodeModifyInitData = reactive({
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

// TODO 从这里开始重写，将节点打开之后，直接存储在 store 中，并直接存储 NodeInfo，此时在store中直接处理成json字符串；
// TODO 代码编辑器中则直接编辑这段字符串，保存提交之后拿这段再回去更新 store 的 NodeInfo
// 使得全局在编辑的json字符串只有一个，而编辑列表可以有多个
const init = (node: NodeInfo) => {
  if (!node || !node.sourceName) {
    return
  }
  // 当前节点是否已经打开
  const hasNode = nodeState.addEditNode(node, () => {
    ElNotification({
      title: '标签页过多',
      message: '别开太多标签',
      type: 'error',
    })
  })
}

/**
 * 表单聚焦
 * @param item
 * @param value
 */
const handleFormItemForce = (item: FormModelItem, value: any) => {
  initData.forceItem = item
  console.debug("当前force", item)
  if (item.type === 'text') {
    initData.activeToolName = 'code'
    codeEditorRef.value.init(value)
  } else {
    initData.activeToolName = 'json'
  }
}

const handleJsonChange = (json: object) => jsonEditorRef.value.init(json)

/**
 * 代码编辑器数据回填
 * @param code
 */
const handleCodeEditorValueChange = (code: string) => nodeDetailRef.value.changeValue(initData.forceItem, code)

/**
 * 直接修改JSON
 */
const handleSetJsonEditorData = () => {
  // nodeDetailRef.value.changeJson(json, initData.currNodeName)
  // 获取编辑器中的json
  const jsonData = jsonEditorRef.value.getData()
  ElMessage.warning("直接编辑内容无法做详细校验，可能会导致无法使用。请谨慎保存")
  // 保存一个副本，如果发现有问题，则提示有问题
  nodeDetailRef.value.changeJson(jsonData, nodeState.currEditName)
}

/**
 * 重置清理
 */
const clean = nodeState.clear()

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
    <el-tabs v-model="nodeState.currEditName"
             closable class="node-tabs"
             @tab-click="(tab: TabsPaneContext, event: Event) => nodeState.setCurrEdit(tab.paneName, 'name')"
             @tab-remove="(targetName: string) => nodeState.delEditNode(targetName)">
      <el-tab-pane v-for="(node, index) in nodeState.editNodeList"
                   :label="node.sourceName"
                   :name="node.sourceName || '空白节点'"
                   :key="index">
      </el-tab-pane>
    </el-tabs>

    <div class="modify-box" :style="{height: `${screenHeight - ((screenHeight/10) + 200)}px`}"
         v-show="nodeState.editNodeList?.length > 0 && nodeState.currEditName">
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
