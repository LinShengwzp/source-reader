<script setup lang="ts">
import SvgIcon from "@/components/SvgIcon/Index.vue";
import {reactive, ref} from "vue";
import {MenuItem} from "@/utils/Models";
import {MenuList} from "@/utils/Config";

const emit = defineEmits(["menuChang"])
const activeMenuIcon = ref("novel")
const menuList: Array<MenuItem> = reactive(MenuList)

const setMenu = (menu: MenuItem): boolean => {
  if (menu && menu.icon && (menu.icon !== activeMenuIcon.value)) {
    activeMenuIcon.value = menu.icon
    return true
  }
  return false
}

const menuIcon = (icon: string) => {
  return icon === activeMenuIcon.value ? `${icon}-select` : icon
}

const menuSelect = (menu: MenuItem) => {
  // 触发自定义事件，并传递参数
  if (setMenu(menu)) {
    emit('menuChang', menu);
  }
}


defineExpose({
  setMenu
})

</script>

<template>
  <div class="footer-container">
    <div v-for="menu in menuList" class="footer-menu hvr-shrink" @click="menuSelect(menu)">
      <svg-icon class="menu-icon" :icon="menuIcon(menu.icon)"/>
      <span class="menu-name">{{ menu.label }}</span>
    </div>
  </div>
</template>

<style scoped lang="scss">
.footer-container {
  flex: 1;
  height: 100%;
  display: flex;


  .footer-menu {
    flex: 1;
    cursor: pointer;
    user-select: none;
    height: 100%;
    display: flex;
    flex-direction: column;
    /*垂直居中*/
    align-items: center;

    .menu-icon {
      flex: 2;
      display: flex;
      /*垂直居中*/
      align-items: center;
    }

    .menu-name {
      flex: 1;
      display: flex;
      /*垂直居中*/
      align-items: center;
    }

    @media screen and (max-height: 760px) {
      /* 在此处定义屏幕高度小于等于 600px 时的样式 */
      .menu-name {
        display: none;
      }
    }
  }

  .footer-menu:hover {
    background: rgba(197, 192, 192, 0.2);
  }

}

</style>
