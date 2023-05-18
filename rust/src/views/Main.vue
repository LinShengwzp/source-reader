<script setup lang="ts">
import Footer from "@/components/Footer.vue";
</script>

<template>
  <div class="main-container">
    <el-container>
      <el-header class="header-box">Header</el-header>
      <el-main class="main-box">Main</el-main>
      <el-footer class="footer-box">
        <Footer></Footer>
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
    flex: 2;
    display: flex;
    /*垂直居中*/
    align-items: center;
    /*水平居中*/
    justify-content: center;
  }

  .main-box {
    flex: 16;
  }

  .footer-box {
    flex: 2;
    /* 颜色 x偏移 y偏移 模糊 扩散 */
    box-shadow: #9a9a9a 0.1rem 0.3rem 0.8rem 0.4rem;
    display: flex;
    align-items: center;
    justify-content: center;
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
