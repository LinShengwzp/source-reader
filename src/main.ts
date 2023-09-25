import {createApp} from "vue";
import App from "./App.vue";
import "./styles.css";
import "./animate.css";

import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'

import router from "@/router/Router";

import SvgIcon from "@/components/SvgIcon/Index.vue"
import 'virtual:svg-icons-register'


// @ts-ignore
import VMdEditor from '@kangc/v-md-editor';
import '@kangc/v-md-editor/lib/style/base-editor.css';
// @ts-ignore
import githubTheme from '@kangc/v-md-editor/lib/theme/github.js';
import '@kangc/v-md-editor/lib/theme/style/github.css';

// highlightjs
import hljs from 'highlight.js';

VMdEditor.use(githubTheme, {
    Hljs: hljs,
});

// Pinia
import {createPinia} from 'pinia'

const app = createApp(App);
app.use(createPinia()).use(ElementPlus).use(router).component('svg-icon', SvgIcon).use(VMdEditor)

// 引入 element 图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
    app.component(key, component)
}

app.mount("#app");

