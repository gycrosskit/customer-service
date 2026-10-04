# GY CrossKit 腾讯客服适配

Android/iOS 腾讯 AI Desk 的最小原生适配：配置厂商 UI、准备账号、同步资料、取得或展示厂商聊天页面、清理自有身份。
聊天 UI 与资源全部使用厂商依赖，组件不复制 vendor 源码或资源。OHOS 没有实现，宿主继续报告 unsupported。

## 安装与消费

包装代码使用 [Apache-2.0](LICENSE)；[GitHub 仓库](https://github.com/gycrosskit/customer-service) 通过不可变标签和 Release 发布。
KMP 坐标是 `com.github.gycrosskit.customer-service:customer-service:0.1.1`；Android 最低 API 24、iOS 原生最低 15.0。
KMP root 提供数据类型与 Android 原生适配器；iOS Swift 客户端单独用 `GycCustomerServiceNative` Pod，不要求宿主再导出未消费的 KMP Bridge。

```kotlin
// 在 dependencyResolutionManagement.repositories 中添加 maven("https://jitpack.io")。
implementation("com.github.gycrosskit.customer-service:customer-service:0.1.1")
```

```ruby
pod 'GycCustomerServiceNative', :git => 'https://github.com/gycrosskit/customer-service.git', :tag => '0.1.0'
```

本地验证先执行 `bash scripts/export-artifacts.sh`，解包 `build/release/customer-service-maven-0.1.1.tar.gz`
到独立临时 Maven 仓库，通过仓库外的 init script 对候选模块做精确 exclusiveContent；不用 `includeBuild`、源码替换或永久 `mavenLocal`。
iOS 正式验证从上面的 Git/tag Pod 下载 Swift 源码并编译独立消费工程；不使用本地 path。
Maven 0.1.1 只修复 JitPack metadata，Swift API 未变，原生 Pod 继续使用已验证的 0.1.0。
`jitpack-install.sh` 从同版本 GitHub Release 下载 Maven 归档并校验 SHA-256，供 JitPack 安装 macOS 产物。
归档不是宿主 Maven 地址；正式消费仍使用上面的 JitPack 坐标。

## 宿主边界

宿主先校验隐私、功能、门店绑定、账号、动态 AppId 与品牌回退，并提供 UserSig、客服昵称和头像。
Android 的进程唯一 `AndroidTencentCustomerServiceClient` 接收 `CustomerServiceProfile`，在主线程执行 SDK 操作；
`onSdkError` 交回 operation/code/message 供宿主原 Logger 记录，组件不引入日志框架。
组件检查自己已准备的 identity 与 SDK 实际用户：同目标用户不先 unInit，拒绝覆盖其他所有者的账号；仅释放仍匹配的自有账号，清理失败保留归属。
未准备身份的 reset 直接成功，不访问厂商单例；iOS 仍先关闭本组件拥有的模态页，再决定是否需要 SDK 清理。
两端在异步 reset 成功后重新判定 SDK 实际用户，避免等待期间外部接管的账号被覆盖。

prepare、syncProfile、reset 是不可取消的厂商操作。宿主必须用进程级串行任务持有至 SDK 真正回调，
调用方超时或取消只结束自身等待，不能通过重建 client、创建第二 scope 或新会话绕过旧操作。
Android `chatIntent` 只取得原生页面，Activity Result 与重复打开等待由宿主持有。
iOS 唯一 `GycTencentCustomerServiceClient.shared` 接收最终活动容器的 `presenterResolver`，
展示厂商 ViewController，并在真实 dismiss 后回调；照片等全屏子页不提前解锁。
宿主只转发 native completion，继续负责业务结果、等待及直播资料恢复。

## 固定厂商依赖与来源

Android `com.tencentcloud.desk:aideskcustomer:2.6.0` 及其 Desk 2.6.0 组件；IM 固定 `imsdk-plus:9.1.7818`。
iOS `TencentCloudAIDeskCustomer:1.4.1`、TDesk 四组件 `2.9.141`、IM `TXIMSDK_Plus_iOS_XCFramework:9.1.7818`。
厂商通过 Maven/CocoaPods 原坐标取得，不嵌入归档，不替换聊天 UI。
Android 缓存 POM 的许可证字段是 Apache-2.0；iOS Podspec 与原 LICENSE 是 MIT。
本仓库包装代码使用 Apache-2.0；厂商依赖继续使用其原许可证及服务条款。
Release Maven 归档仅含本组件的 AAR/KLIB/metadata；Native 0.1.0 归档仅含本组件 Swift 源码、Podspec、README 和 LICENSE。

## 验证

```bash
bash gradlew testDebugUnitTest compileKotlinIosSimulatorArm64 publishAllPublicationsToStagingRepository
mkdir -p build/verification
swiftc ios/Sources/GycCustomerServiceNative/CustomerServiceOwnership.swift ios/Sources/GycCustomerServiceNative/CustomerServicePresentationCompletion.swift verification/main.swift -o build/verification/ownership-check
build/verification/ownership-check
```

独立消费工程见 `verification/gradle`，正式验证通过 exclusiveContent 仅从 JitPack 消费本组件。
本地候选已通过组件 Android ownership 单测、三种 iOS KLIB 打包、Swift ownership/模态完成检查、
解包 AAR/KLIB 的独立 Android/iOS 编译与 Framework 链接；宿主 27 项客服/会话定向测试（不含认证 8 项）、
充和 Debug Kotlin 编译通过。iOS Simulator Shared Framework 与完整 App 链接在最后身份 guard 补丁前通过；
补丁后重新验证 Swift ownership/模态完成检查、Android ownership 单测与原生 Pod 编译，未重复完整 App 链接。
Maven 0.1.1 已从 JitPack 实际下载并核验五个 module/POM 和 API/runtime 产物的 URL、大小与 SHA；
全新独立消费工程完成 Android、三种 iOS 编译及 Simulator Framework 链接。
原生 Pod 继续使用已从 Git/tag 实际安装并完成 Swift consumer arm64 Simulator 编译与链接的 0.1.0。
发布提交、归档 SHA-256、命令及边界记录在 [发布验收](verification/发布验收.md)。
单测与编译不能替代实际登录、聊天、同 IM 直播账号共存、账号切换和真机生命周期验收。
