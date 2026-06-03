# ICP 备案通过后的操作清单

> **前提**：域名 `zaine.love` 已完成 ICP 备案，DNS 可正常解析
> **目标**：守护卡扫码 → 下载 App → 自动绑定守护关系，完整链路打通

---

## 第一步：DNS 解析配置（阿里云域名控制台）

1. 登录 [阿里云域名控制台](https://dc.console.aliyun.com/)
2. 找到域名 `zaine.love` → 点击「解析」
3. 添加以下记录：

| 记录类型 | 主机记录 | 记录值 | 说明 |
|---------|---------|--------|------|
| CNAME | @ | `zaine-api-skhntjskvp.cn-hangzhou.fcapp.run` | 将根域名指向阿里云 FC |

> 💡 如果阿里云 FC 控制台给了你专属的自定义域名 CNAME 地址，优先用那个

4. 等待 DNS 生效（通常 5-30 分钟）
5. 验证：`ping zaine.love` 能看到 FC 的 IP 或域名即生效

---

## 第二步：后端部署

1. 打开终端，进入后端目录：
```bash
cd /Users/meixulin/WorkBuddy/20260421164027/zaine-backend
```

2. 执行部署：
```bash
s deploy
```

3. 确认部署成功（看到 "Deploy success" 或类似提示）

---

## 第三步：验证 AASA 文件

部署完成后，立即验证：

```bash
curl -I https://zaine.love/.well-known/apple-app-site-association
```

预期结果：
- HTTP 状态码：`200 OK`
- Content-Type：`application/json`

再验证内容：
```bash
curl https://zaine.love/.well-known/apple-app-site-association
```

预期返回：
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "KK27TYK93U.com.zaine.app",
        "paths": ["/landing/*", "/i/*", "/download*"]
      }
    ]
  }
}
```

---

## 第四步：验证落地页

1. 访问任意落地页测试：
```
https://zaine.love/landing/test123
```
预期：显示正常的守护卡落地页（不是 404）

2. 验证 share_url 格式：
   - 打开 App，发一张守护卡
   - 检查后端返回的 `shareUrl` 是否是 `https://zaine.love/landing/xxx` 格式

---

## 第五步：真机测试 Universal Link

1. 在 iPhone 上打开 Safari，访问：
```
https://zaine.love/landing/test123
```
2. 预期：页面顶部出现 "打开「在呢」App" 的横幅（这是 iOS 系统识别的 Universal Link）
3. 点击横幅，App 应被唤起
4. 如果没看到横幅，说明 AASA 还未被 iOS 缓存，等 1-2 分钟再试

> ⚠️ **注意**：iOS 只在第一次访问域名时下载 AASA 文件。如果之前访问过 `zaine.love` 且返回了空内容，iOS 会缓存"此域名不支持 Universal Link"的结论。**解决方案**：修改 AASA 文件内容（加/删一个路径）或等 24 小时缓存过期。

---

## 第六步：完整链路测试（守护卡扫码→绑定）

| 步骤 | 操作 | 预期结果 |
|------|------|---------|
| 1 | 用户A在App中发一张守护卡给B | 卡片上的二维码 = `https://zaine.love/landing/xxx` |
| 2 | B用微信扫描二维码 | 打开落地页，显示 "下载App" 按钮 |
| 3 | B点击下载，安装并打开App | App 通过 Universal Link 唤起，提取 `card_code` |
| 4 | B完成注册/登录 | DeepLinkService 自动调用 `verify-and-link` |
| 5 | 绑定完成 | B 成为 A 的守护对象，A 自动解锁 +1 张守护卡 |

---

## 如果出现问题

### 问题1：curl AASA 返回 404
- 检查 DNS 是否生效：`nslookup zaine.love`
- 检查后端部署是否成功：`s deploy` 重试
- 检查 landing_router 是否正确挂载（无 prefix）

### 问题2：iPhone 不显示 "打开App" 横幅
- 确认 AASA Content-Type 是 `application/json`（不是 text/html）
- 确认 AASA 文件没有重定向（301/302）
- 确认域名是 HTTPS
- 尝试修改 AASA 文件内容后重新部署（触发 iOS 重新下载）
- 清除 Safari 缓存：设置 → Safari → 清除历史记录与网站数据

### 问题3：App 被唤起但没有绑定关系
- 检查 DeepLinkService 日志：`[DeepLink] 提取到 card_code: xxx`
- 检查注册/登录时是否调用了 `processPendingCardCode()`
- 检查后端 `verify-and-link` 接口是否返回 success

---

## 相关文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| AASA endpoint | `zaine-backend/routes/landing.py:32-59` | 后端返回 AASA JSON |
| 后端部署配置 | `zaine-backend/s.yaml:62-69` | 自定义域名配置 |
| 后端域名常量 | `zaine-backend/config.py:46-53` | SHARE_BASE_URL |
| iOS entitlements | `ios/Runner/Runner.entitlements` | Associated Domains |
| Xcode 工程配置 | `ios/Runner.xcodeproj/project.pbxproj` | CODE_SIGN_ENTITLEMENTS |
| URL Scheme | `ios/Runner/Info.plist` | zaine:// fallback |
| Deep Link 服务 | `lib/services/deep_link_service.dart` | 处理 /landing/{code} |
| 守护卡页面 | `lib/pages/guardian_card_page.dart` | 二维码生成 |

---

**记录时间**：2026-05-11
**最后更新**：v1.9.63
