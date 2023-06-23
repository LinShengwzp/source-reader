<template>
  <codemirror v-model="code"
              placeholder="代码编辑器"
              :style="{ height: '100%',textAlign:'left' }"
              :autofocus="true"
              :tabSize="4"
              :disabled="disable"
              :options="codeMirrorOptions"
              @change="Change"
              :extensions="extensions"/>
</template>
<script lang="ts" setup>
import {Codemirror} from "vue-codemirror";
import {javascript} from "@codemirror/lang-javascript";
import {oneDark} from "@codemirror/theme-one-dark";
import {ref} from "vue";
import {EditorView} from "@codemirror/view"

let myTheme = EditorView.theme({
  // 输入的字体颜色
  "&": {
    color: "#15a151",
    backgroundColor: "#FFFFFF"
  },
  ".cm-content": {
    caretColor: "#efefef",
  },
  // 激活背景色
  ".cm-activeLine": {
    backgroundColor: "#c4c4c4"
  },
  // 激活序列的背景色
  ".cm-activeLineGutter": {
    backgroundColor: "#c4c4c4"
  },
  //光标的颜色
  "&.cm-focused .cm-cursor": {
    borderLeftColor: "#000000"
  },
  // 选中的状态
  "&.cm-focused .cm-selectionBackground, ::selection": {
    backgroundColor: "#606060",
    color: '#0052D9'
  },
  // 左侧侧边栏的颜色
  ".cm-gutters": {
    backgroundColor: "#FFFFFF",
    color: "#ddd", //侧边栏文字颜色
    border: "none"
  }
}, {dark: true})

interface IProps {
  height?: string,
  disable: boolean,
}

const codeMirrorOptions = {}

// 接受的参数
const props = withDefaults(defineProps<IProps>(), {
  height: '400px',
  disable: false
})
const code = ref('');
const enableEdit = ref(true);
const extensions = [javascript(), myTheme];

const emits = defineEmits(['change'])

const Change = (v: string) => {
  code.value = v
  emits("change", v)
}

const init = (codeStr: string) => {
  code.value = codeStr
}
const getData = () => {
  return code.value
}

defineExpose({
  init, getData
})

</script>
