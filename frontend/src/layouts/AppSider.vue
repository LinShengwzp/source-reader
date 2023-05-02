<template>
    <a-layout id="app-layout-sider">
        <a-layout-sider
                v-model="collapsed"
                theme="light"
                class="layout-sider">
            <div class="logo">
                <img class="pic-logo" src="~@/assets/logo.png">
            </div>
            <a-menu class="menu-item" theme="light" mode="inline" :default-selected-keys="[default_key]"
                    :inline-collapsed="true" @click="menuHandle">
                <a-menu-item v-for="(menuInfo, index) in menu" :key="index">
                    <a-icon :type="menuInfo.icon"/>
                    {{ menuInfo.title }}
                </a-menu-item>
            </a-menu>
<!--            <a-affix :offset-bottom="bottom">-->
<!--                <div v-if="collapsed" class="btn-fold-item btn-fold ">-->
<!--                    <a-button type="primary" icon="menu-fold" @click="collapsed = !collapsed">-->
<!--                    </a-button>-->
<!--                </div>-->
<!--                <div v-if="!collapsed" class="btn-fold-item btn-unfold">-->
<!--                    <a-button type="primary" icon="menu-unfold" @click="collapsed = !collapsed">-->
<!--                    </a-button>-->
<!--                </div>-->
<!--            </a-affix>-->

        </a-layout-sider>


        <div v-if="collapsed" class="btn-fold-item btn-fold ">
            <a-button icon="menu-fold" @click="collapsed = !collapsed">
            </a-button>
        </div>
        <div v-if="!collapsed" class="btn-fold-item btn-unfold">
            <a-button icon="menu-unfold" @click="collapsed = !collapsed">
            </a-button>
        </div>
        <a-layout>
            <a-layout-content class="layout-content">
                <router-view/>
            </a-layout-content>
        </a-layout>
    </a-layout>
</template>
<script>
export default {
    name: 'AppSider',
    data() {
        return {
            collapsed: true,
            default_key: 'menu_100',
            current: '',
            bottom: 10,
            menu: {
                // 'menu_1': {
                //     icon: 'home',
                //     title: '框架',
                //     pageName: 'Base',
                //     params: {},
                // },
                // 'menu_2': {
                //     icon: 'desktop',
                //     title: '其它',
                //     pageName: 'Other',
                //     params: {},
                // },
                // 'menu_3': {
                //     icon: 'book',
                //     title: '阅读',
                //     pageName: 'Reader',
                //     params: {},
                // },
                'menu_100': {
                    icon: 'profile',
                    title: '书架',
                    pageName: 'ReaderBooksIndex',
                    params: {}
                },
                'menu_200': {
                    icon: 'profile',
                    title: '书源',
                    pageName: 'ReaderAnalyseIndex',
                    params: {}
                },
            }
        };
    },
    created() {
    },
    mounted() {
        this.menuHandle()
    },
    methods: {
        menuHandle(e) {
            this.current = e ? e.key : this.default_key;
            const linkInfo = this.menu[this.current]
            console.log('[home] load page:', linkInfo.pageName);
            this.$router.push({name: linkInfo.pageName, params: linkInfo.params})
        },
    },
};
</script>
<style lang="less" scoped>
// 嵌套
#app-layout-sider {
  height: 100%;
    position: relative;

  .logo {
    border-bottom: 1px solid #e8e8e8;
  }

  .pic-logo {
    height: 32px;
    //background: rgba(139, 137, 137, 0.2);
    margin: 10px;
  }

  .layout-sider {
    border-top: 1px solid #e8e8e8;
    border-right: 1px solid #e8e8e8;
  }

  .menu-item {
    .ant-menu-item {
      background-color: #fff;
      margin-top: 0px;
      margin-bottom: 0px;
      padding: 0 0px !important;
    }
  }

  .btn-fold-item {
    position: absolute;
    bottom: 10px;
    left: 20px;
  }

  .layout-content {
    //background-color: #fff;
  }
}
</style>
