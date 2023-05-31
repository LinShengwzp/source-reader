# Tauri + Vue 3 + TypeScript

https://tauri.app/zh-cn/v1/guides/faq

https://juejin.cn/post/7067342513920540686

## 项目启动

```shell
# 安装依赖
yarn
# 查看 tauri 环境
yarn tauri info 
# 启动项目
yarn tauri dev
```

## 项目调试

```shell
# 启动前端服务
yarn vite dev
```

启动后端服务
cargo
[Debugging in CLion](https://tauri.app/zh-cn/v1/guides/debugging/clion)

## 数据库文件

```shell
${USER}/AppData/Roaming/com.anmi.reader/reader.db
```

## 打包问题

+ wix311-binaries.zip

手动下载文件放到 ``C:\Users\用户\AppData\Local\tauri\WixTools``

+ nsis-3.zip

需要找一个能用的包，否则放上去会被删掉……
