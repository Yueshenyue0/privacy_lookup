# 信息工具

一个基于 Flutter 的信息查询工具，包含两个功能模块（底部 Tab 切换）：

## 1. 信息查询
支持查询：
- QQ号
- 手机号
- 证件号
- 邮箱
- 微博uid（前面加 @）

使用 [苏青API](https://sucyan.top) 的 Privacy 接口：
`https://sucyan.top/api/privacy.php?value=<查询值>`

## 2. 二要素核验
通过 姓名 + 身份证号 核验实名信息是否一致。

使用接口：
`https://ryapi.sbs/API/eys.php?name=&idcard=&key=ranyu888`

### 构建

本仓库配置了 GitHub Actions，push 到 `main` 分支即自动构建 APK 并上传 artifact。