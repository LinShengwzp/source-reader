<script setup lang="ts">
import {FileInfo, findType, NodeInfo, NodeSourceType, SourcePlatform} from "@/utils/Models";
import {computed, onBeforeUnmount, onMounted, reactive, ref} from "vue";
import {ArrowLeft, ArrowRight, CaretLeft} from "@element-plus/icons-vue";

const currFile: FileInfo = reactive({
  page: {
    total: 0,
    size: 10,
    pageCount: 0,
    currPage: 0,
  }
})
const modifyNode = reactive({
  showEditor: false,
  style: {
    listBoxWidth: 100,
    editBoxWidth: 0,
    transform: "rotate(180deg)",
    transition: "all .3s"
  },
  currEdit: null,
})

onMounted(() => {
  window.addEventListener('resize', handleResize);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
});


const init = (fileInfo: FileInfo) => {
  currFile.file = fileInfo.file
  currFile.fileType = fileInfo.fileType
  currFile.analyseNode = fileInfo.analyseNode
  currFile.dataInfo = fileInfo.dataInfo
  currFile.nodeList = fileInfo.nodeList
  currFile.menuList = fileInfo.menuList
  currFile.nodeSearch = fileInfo.nodeSearch
  currFile.page = fileInfo.page
  modifyNode.showEditor = false
  modifyNode.style.listBoxWidth = 100
  modifyNode.style.editBoxWidth = 0
  buildMenu()
}

/**
 * 展开/收缩节点
 */
const showEdit = () => {
  const change = !modifyNode.showEditor
  if (change) {
    modifyNode.showEditor = change
    modifyNode.style.listBoxWidth = 20
    modifyNode.style.editBoxWidth = 80
  } else {
    modifyNode.style.listBoxWidth = 100
    modifyNode.style.editBoxWidth = 0
    setTimeout(() => {
      modifyNode.showEditor = change
    }, 400)
  }
}


/**
 * build 菜单
 * @param pageNum
 */
const buildMenu = (pageNum: number = 1) => {
  const {nodeList, page} = currFile
  if (!nodeList || nodeList.length < 1) {
    return;
  }

  if (pageNum < 1) {
    pageNum = 1
  }

  // 根据屏幕高度来计算显示条数
  // 大概 70xp 一条左右，
  let x = screenHeight.value / 50 - 4;
  page.size = Math.floor(x)

  let filer = [...nodeList]
  if (currFile.nodeSearch) {
    filer = filer.filter((i: NodeInfo) => i.sourceName && currFile.nodeSearch && i.sourceName.indexOf(currFile.nodeSearch) >= 0)
  }

  page.total = filer.length
  page.pageCount = Math.ceil(page.total / page.size)

  if (pageNum > page.pageCount) {
    pageNum = page.pageCount
  }

  page.currPage = pageNum
  const start: number = (pageNum - 1) * page.size
  let end: number = start + page.size
  if (end > page.total) {
    end = page.total
  }
  currFile.menuList = filer.slice(start, end)
  console.log("build menu", currFile)
}

/**
 * 点击某行
 * @param row
 * @param column
 * @param event
 */
const handleNodeRowClick = (row: NodeInfo, column: string | number | undefined, event: PointerEvent) => {
  if (!modifyNode.showEditor) {
    showEdit()
    modifyNode.currEdit = (row as any)
  }
}

/**
 * 点击箭头展开
 */
const handleExportNodeList = () => {
  if (modifyNode.showEditor) {
    showEdit()
  }
}

/**
 * 监听屏幕高度
 */
const screenHeight = ref(window.innerHeight);

const leftWidth = computed(() => `${modifyNode.style.listBoxWidth}%`);
const rightWidth = computed(() => `${modifyNode.style.editBoxWidth}%`);

const handleResize = () => {
  screenHeight.value = window.innerHeight;
  buildMenu()
};

/**
 * 手动计算分页工具
 */
const nodePageData = computed(() => {
  return [{
    prep: currFile.page.currPage - 1,
    curr: currFile.page.currPage,
    next: currFile.page.currPage + 1,
  }]
})

defineExpose({
  init
})

</script>

<template>
  <div class="node-list">
    <div class="node-list-edit-box">
      <div class="node-list-box" :style="{ width: leftWidth }">
        <div class="node-list">
          <transition name="slide-left">
            <div class="node-list-table">
              <el-table ref="tableNodeDataInfoRef"
                        border highlight-current-row
                        @row-click="handleNodeRowClick"
                        :data="currFile.menuList" style="width: 100%">
                <el-table-column :resizable="false" type="index" show-overflow-tooltip width="50">
                  <template #header>
                                <span style="float: right" @click="handleExportNodeList">
                                  <el-icon
                                      :style="{transform: modifyNode.showEditor ?modifyNode.style.transform:'', transition:modifyNode.style.transition}">
                                    <CaretLeft/>
                                  </el-icon>
                                </span>
                  </template>
                </el-table-column>
                <el-table-column :resizable="false" prop="sourceName" show-overflow-tooltip label="节点名称">
                  <template #header>
                    <el-input v-model="currFile.nodeSearch" @input="buildMenu" size="small" placeholder="搜索名称"
                              clearable/>
                  </template>
                </el-table-column>
                <el-table-column :resizable="false" prop="platform" show-overflow-tooltip label="节点平台"
                                 v-if="!modifyNode.showEditor">
                  <template #default="scope">
                    {{ findType(SourcePlatform, scope.row.platform)?.label }}
                  </template>
                </el-table-column>
                <el-table-column :resizable="false" prop="sourceType" show-overflow-tooltip label="节点类型"
                                 v-if="!modifyNode.showEditor">
                  <template #default="scope">
                    {{ findType(NodeSourceType, scope.row.sourceType)?.label }}
                  </template>
                </el-table-column>
                <el-table-column :resizable="false" prop="authorId" show-overflow-tooltip label="作者"
                                 v-if="!modifyNode.showEditor"/>
                <el-table-column :resizable="false" prop="weight" show-overflow-tooltip label="权重"
                                 v-if="!modifyNode.showEditor"/>
                <el-table-column :resizable="false" prop="enable" show-overflow-tooltip label="启用"
                                 v-if="!modifyNode.showEditor"/>
              </el-table>
            </div>
          </transition>
        </div>
        <div class="node-list-page-bar" v-show="currFile.page.pageCount > 1">
          <el-table ref="tableNodePageRef" :data="nodePageData" :show-header="false"
                    :cell-style="{background: 'unset'}">
            <el-table-column prop="prep" align="center" width="50" label="上一页" v-if="modifyNode.showEditor">
              <template #default="scope">
                <el-link :underline="false" :disabled="scope.row.prep <= 0"
                         @click="buildMenu(scope.row.prep)">
                  <el-icon>
                    <ArrowLeft/>
                  </el-icon>
                </el-link>
              </template>
            </el-table-column>
            <el-table-column prop="curr" align="center" width="50" label="当前页" v-if="modifyNode.showEditor">
              <template #default="scope">
                <el-link :underline="false">{{ scope.row.curr }}</el-link>
              </template>
            </el-table-column>
            <el-table-column prop="next" align="center" width="50" label="下一页" v-if="modifyNode.showEditor">
              <template #default="scope">
                <el-link :underline="false"
                         :disabled="scope.row.next > currFile.page.pageCount"
                         @click="buildMenu(scope.row.next)">
                  <el-icon>
                    <ArrowRight/>
                  </el-icon>
                </el-link>
              </template>
            </el-table-column>

            <el-table-column prop="curr" align="center" width="500" label="分页" v-if="!modifyNode.showEditor">
              <template #default>
                <div class="node-list-page-tool">
                  <el-pagination v-if="currFile.page.total > 10" layout="prev, pager, next"
                                 :hide-on-single-page="true"
                                 :total="currFile.page.total"
                                 :page-count="currFile.page.pageCount"
                                 :page-size="currFile.page.size"
                                 :current-page="currFile.page.currPage"
                                 @current-change="(v:number) => buildMenu(v)"/>
                </div>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </div>

      <div class="node-edit-box" :style="{ width: rightWidth }">
        23
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">

.node-list-edit-box {
  display: flex;

  .node-edit-box {
    transition: width .5s ease; /* 添加过渡动画 */
  }

  .node-list-box {
    transition: width .5s ease; /* 添加过渡动画 */
  }

}

.node-list-page-bar {
  .node-list {
    .node-list-table {
      position: relative;
    }
  }
}

.node-list-page-tool {
  display: flex;
  justify-items: center;
  justify-content: center;
  align-items: center;
}

.el-table .warning-row {
  --el-table-tr-bg-color: var(--el-color-warning-light-9);
}

.el-table .success-row {
  --el-table-tr-bg-color: var(--el-color-success-light-9);
}

.slide-left-enter-active,
.slide-left-leave-active {
  transition: transform 0.5s;
}

.slide-left-enter-from,
.slide-left-leave-to {
  transform: translateX(-100%);
}


</style>
