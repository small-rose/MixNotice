downloads/
========
官网下载目录。

注意：Vercel / Cloudflare Pages 单文件上限均为 25 MB，
而 MixNotice APK 约 110 MB，**无法直接放进静态站点托管**。

推荐做法（Cloudflare R2，免费 10GB，无出口流量费）：
1. Cloudflare 控制台 → R2 → 创建桶，例如 `dl.zhangxiaocai.cn`
2. 绑定自定义域（R2 → Settings → Public access → Custom domain）
3. 上传 APK：`mixnotice/MixNotice-v1.0.0-fix10-arm64-debug.apk`
4. 修改两处下载地址指向真实 URL：
   - index.html 中 `id="dlBtn"` 的 href
   - _redirects / vercel.json 中 `/download`、`/apk` 的目标

备选：GitHub Releases、蓝奏云/网盘直链（注意有效期）。
