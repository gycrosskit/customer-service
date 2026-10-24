# 更新记录

## 1.0.0（未发布候选）

- Maven、Git Pod、导出脚本与独立 consumer 默认版本统一为 `1.0.0`，公共 Kotlin 工具链为 `2.2.21-1.0.0`。
- 构建、回归、打包与发布消费以 Jenkins 为迁移目标，待本轮实跑验收；候选私有 Maven 消费与既有公开 `0.1.6` 兼容检查分别记录。
- 本次版本准备不改公共 API、厂商 SDK 或宿主接线；历史发布与设备/业务验收边界保留，候选尚待 Jenkins 与发布验收。

## 0.1.5（已发布）

- Android/Swift syncProfile真实callback后复核owner、operationSerial、runtime/facade user与已知AppId。
- 拒绝外部接管或reset后的旧success，保留合法borrow与未知AppId宿主边界。
- 新增迟到profile回归；[完整源码审查](verification/完整源码审查.md)列全部5个生产文件与验证结果。
- 核实AI Desk的Harmony uni-app/公开IM协议路线，不虚构原生HAR。不可变发布、远程文件、Git Pod真实SDK/App link及新目录Maven最终消费通过；设备业务未验证。
