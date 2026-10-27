downloads/
========
官网下载目录。

当前下载方式：APK 通过 GitHub Releases 发布（单文件上限 2GB），
官网 `index.html` 的「下载 APK」按钮及 `/download`、`/apk` 短链
均指向 https://github.com/small-rose/MixNotice/releases

维护提示（发布新版本时）：
1. 用 tools/build_apk.ps1 打包，产物自动落在项目根目录
2. 把 APK 上传到 GitHub Releases 对应 tag，并在发布说明补充 SHA-1
3. 如需替换 index.html 的按钮文案 / 版本号 / 体积，同步更新
   _redirects 与 vercel.json（目前两处短链指向 Releases 页，一般无需改）

备选方案：Cloudflare R2 直链（免费 10GB，无出口流量费）、蓝奏云/网盘直链（注意有效期）。
