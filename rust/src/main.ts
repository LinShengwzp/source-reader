import {createApp} from "vue";
import "./styles.css";
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import App from "./App.vue";
import * as ElementPlusIconsVue from '@element-plus/icons-vue'


let app = createApp(App);
app.use(ElementPlus)
// 引入 element 图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
    app.component(key, component)
}

app.mount("#app");
