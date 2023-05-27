import {createApp} from "vue";
import App from "./App.vue";
import "./styles.css";

import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'

import router from "@/router/Router";

import SvgIcon from "@/components/SvgIcon/Index.vue"
import 'virtual:svg-icons-register'


const app = createApp(App);
app.use(ElementPlus).use(router).component('svg-icon', SvgIcon)

// 引入 element 图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
    app.component(key, component)
}

app.mount("#app");
