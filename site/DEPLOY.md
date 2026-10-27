# MixNotice 官网部署指南

域名：`mix.zhangxiaocai.cn`（纯静态，`site/` 目录即整站，零构建）

## 一、Cloudflare Pages（推荐）

### 方式 A：连接 Git 仓库
1. 把项目推到 GitHub/GitLab，仓库根目录或 Site 设置中：
   - **Build output directory**: `site`
   - **Build command**: 留空（纯静态）
2. 部署成功后得到 `xxx.pages.dev`
3. 项目 → **Custom domains** → 添加 `mix.zhangxiaocai.cn`
4. 到 `zhangxiaocai.cn` 的 DNS 处添加：
   ```
   CNAME  mix  ->  <你的项目>.pages.dev
   ```
   （若域名 DNS 已托管在 Cloudflare，添加自定义域时会自动建 CNAME）

### 方式 B：Wrangler 直接上传
```bash
npm i -g wrangler
wrangler login
wrangler pages deploy site --project-name=mixnotice
```

## 二、Vercel

```bash
npm i -g vercel
cd site
vercel --prod
```
- Framework Preset 选 **Other**（无需构建）
- 控制台 → 项目 → **Domains** → 添加 `mix.zhangxiaocai.cn`
- 按提示在 DNS 添加：
  ```
  CNAME  mix  ->  cname.vercel-dns.com
  ```

> 注意：Vercel 免费版要求域名 NS 不在中国大陆注册商锁定状态即可，一般直接生效；
> .cn 域名托管在境外平台访问国内速度一般，如需加速可后续加国内 CDN（需备案）。

## 三、DNS 配置（任选其一托管方）

| 主机记录 | 类型 | 指向 |
|---|---|---|
| mix | CNAME | `<项目>.pages.dev`（CF Pages） |
| mix | CNAME | `cname.vercel-dns.com`（Vercel） |

## 四、上线前检查清单

- [ ] 替换 `index.html` 页脚的 ICP 备案号占位（`.cn` 域名解析到境外服务器暂不强制备案，但建议完成备案）
- [x] 下载链接指向 GitHub Releases（`index.html` 的 `#dlBtn`、`_redirects`、`vercel.json` 均已指向 `https://github.com/small-rose/MixNotice/releases`）
- [ ] 发布新版本时：APK 传到 Releases 对应 tag，并补充 SHA-1 到发布说明（见 `downloads/README.txt`）
- [ ] 把 `docs/音频素材授权清单.csv` 上传并在首页「素材授权」链接指向它
- [ ] 确认 `https://mix.zhangxiaocai.cn/robots.txt`、`sitemap.xml` 可访问
- [ ] 深浅色切换、移动端布局、试听按钮各过一遍

## 五、目录说明

```
site/
├── index.html        # 单页官网（内联 CSS/JS，无依赖）
├── privacy.html      # 隐私政策
├── 404.html
├── robots.txt / sitemap.xml
├── _headers          # Cloudflare Pages 缓存与安全头
├── _redirects        # Cloudflare Pages 短链（/download、/apk）
├── vercel.json       # Vercel 等效配置
├── assets/
│   ├── favicon.svg   # 品牌标记「三叠浪·萤火一点」
│   ├── icon-1024.png # OG 分享图
│   └── audio/        # 网页试听音源（CC 授权，~2.7MB）
└── downloads/        # 下载托管说明（APK 走 GitHub Releases）
```
