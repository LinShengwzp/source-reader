<script setup lang="ts">
import Footer from "@/components/Footer.vue";
import {MenuItem} from "@/utils/Models";
import {onMounted, reactive, ref} from "vue";
import router from "@/router/Router";
import {MenuList} from "@/utils/Config";

interface MainInitData {
  currMenu: MenuItem
}

const footerRef = ref()
const initData: MainInitData = reactive({
  currMenu: {
    id: 0,
    icon: '',
    label: '',
    name: ''
  },
})

onMounted(() => {
  menuChang(MenuList[1])
  footerRef.value.setMenu(initData.currMenu)
})

/**
 * 菜单选择
 * @param menu
 */
const menuChang = (menu: MenuItem) => {
  initData.currMenu = menu
  console.log(`current menu: ${initData.currMenu}`)
  router.push({
    name: menu.name
  })
}

</script>

<template>
  <div class="main-container">
    <el-container>
      <el-header class="header-box">{{ initData.currMenu.label }}</el-header>
      <el-main class="main-box">

        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <keep-alive>
              <component :is="Component"/>
            </keep-alive>
          </transition>
        </router-view>
      </el-main>
      <el-footer class="footer-box">
        <Footer ref="footerRef" @menu-chang="menuChang"></Footer>
      </el-footer>
    </el-container>
  </div>
</template>

<style scoped lang="scss">

.main-container {
  height: 100%;
  width: 100%;
  display: flex;

  .header-box {
    flex: 1;
    display: flex;
    /*垂直居中*/
    align-items: center;
    /*水平居中*/
    //justify-content: center;
  }

  .main-box {
    flex: 17;
    padding: 0;
  }

  .footer-box {
    flex: 2;
    /* 颜色 x偏移 y偏移 模糊 扩散 */
    box-shadow: #9a9a9a 0.1rem 0.3rem 0.8rem 0.4rem;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 0.5rem;
  }

  @media screen and (min-height: 1000px) {
    .footer-box {
      flex: 1.5;
    }
  }

  @media screen and (min-height: 1300px) {
    .footer-box {
      flex: 1.3;
    }
  }

}

</style>
