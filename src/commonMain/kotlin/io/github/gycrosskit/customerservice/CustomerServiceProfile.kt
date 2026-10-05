package io.github.gycrosskit.customerservice

/**
 * 宿主通过业务与隐私准入后提供的资料；组件不读取业务账号或生成 UserSig。
 * 不可变值可跨线程传递，凭据只交给厂商 SDK，宿主不得写入日志。
 *
 * @property appId 腾讯 SDKAppID，必须大于 0，且与共用 IM 的其他组件保持一致。
 * @property userId 腾讯用户标识，不得为空白；不会被组件 trim 或转换。
 * @property userSig 宿主取得的签名，不得为空白；有效期与刷新由宿主负责。
 * @property nickname 交给厂商的显示昵称，允许为空；不得用于身份判定。
 * @property avatar 交给厂商的头像地址，允许为空；下载与展示由厂商负责。
 */
data class CustomerServiceProfile(
    val appId: Int,
    val userId: String,
    val userSig: String,
    val nickname: String,
    val avatar: String,
)

internal data class CustomerServiceIdentity(val appId: Int, val userId: String)
internal enum class CustomerServicePreparationAction { REUSE, INITIALIZE, RESET, REJECT }

/** AI Desk 与直播可能共享 IM；只能清理自己已成功准备且仍匹配实际登录用户的身份。 */
internal fun customerServicePreparationAction(
    owned: CustomerServiceIdentity?,
    actualUser: String?,
    target: CustomerServiceIdentity,
    ownsRuntime: Boolean = true,
    sdkReady: Boolean = true,
    configuredSdkAppId: Int = owned?.appId ?: 0,
): CustomerServicePreparationAction {
    val ownsActual = customerServiceOwnsActualIdentity(owned, ownsRuntime, actualUser, configuredSdkAppId)
    return when {
        actualUser != null && actualUser != target.userId && !ownsActual ->
            CustomerServicePreparationAction.REJECT
        configuredSdkAppId > 0 && actualUser != null && configuredSdkAppId != target.appId && !ownsActual ->
            CustomerServicePreparationAction.REJECT
        ownsActual && owned != target -> CustomerServicePreparationAction.RESET
        owned == target && actualUser == target.userId && sdkReady -> CustomerServicePreparationAction.REUSE
        else -> CustomerServicePreparationAction.INITIALIZE
    }
}

internal fun customerServiceOwnsActualIdentity(prepared: CustomerServiceIdentity?, ownsRuntime: Boolean, actualUser: String?,
    configuredSdkAppId: Int = prepared?.appId ?: 0): Boolean =
    ownsRuntime && prepared != null && actualUser == prepared.userId &&
        (configuredSdkAppId <= 0 || configuredSdkAppId == prepared.appId)
