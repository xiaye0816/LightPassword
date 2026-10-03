# 轻密码

轻密码是一个最低支持 iOS 18 的本地密码管理 App。首版专注于密码的安全保存、搜索、收藏、快速复制、回收站、密码生成和加密备份，不包含自动填充、账号系统、云同步或联网服务。

## 已实现功能

- 首次创建主密码，支持 Face ID 快速解锁
- Face ID 验证期间隐藏主密码输入，失败后静默回退到主密码并支持手动重试
- 密码增删改查、搜索、排序、收藏和同一服务多个账号
- 列表快捷复制用户名和密码，复制内容仅限本机并按 15、30 或 60 秒到期
- 详情页默认隐藏密码，进入后台立即隐藏内容并显示隐私遮罩
- 12–64 位安全密码生成器，默认 16 位且不含符号，并记住长度和字符偏好
- 主屏长按 App 图标可选择“快捷录入密码”，解锁后直接打开新增页
- 删除条目保留在回收站 30 天，可恢复或永久删除
- `.vaultbackup` 加密备份导出、预览和完整恢复
- 从 1Password 7 CSV 预览并合并导入；空密码行会跳过，不支持的非空字段会明确提示
- 修改主密码、自动锁定和本地密码库删除

## 安全设计

- `swift-sodium 0.11.0`，Argon2id 派生包装密钥，XChaCha20-Poly1305 认证加密
- 条目内容全部位于认证密文中；主密码只用于解包随机 256 位保险库密钥
- 保险库原子写入，文件保护等级为 `NSFileProtectionComplete`，并排除自动 iCloud 备份
- Face ID 密钥使用 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly + biometryCurrentSet`
- App 锁定时对内存中的密钥字节执行 best-effort 清零
- 无分析、广告、远程图标、崩溃上传或敏感日志
- 导入时不复制或保存原始明文 CSV，确认后一次性加密并原子写入密码库

## 构建与测试

使用 Xcode 26.6 打开 `LightPassword.xcodeproj`，选择 `LightPassword` Scheme。默认 Bundle ID 为 `com.shaoguoqing.lightpassword`。

模拟器回归命令：

```sh
xcodebuild -project LightPassword.xcodeproj \
  -scheme LightPassword \
  -destination 'platform=iOS Simulator,id=6F74F43B-DB7C-4EEF-B746-7FCA1FCA500A' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  test
```

项目包含 Swift Testing 单元测试和 XCUITest UI 测试。测试覆盖加解密、错误主密码、密文篡改、原子写入、搜索、生成规则、备份恢复、CSV 解析和导入失败回滚、后台锁定，以及首次设置、新建、快捷复制、明文显示/隐藏、回收站恢复的完整界面路径。

## 真机发布前

Face ID、真实 Keychain 行为、签名和覆盖安装的数据保留必须在真机验证。存入真实密码前，还应完成一次独立安全审计；本项目不是已经过第三方审计的商业密码管理器。
