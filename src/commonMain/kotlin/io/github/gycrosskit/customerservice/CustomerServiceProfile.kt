package io.github.gycrosskit.customerservice

/** 宿主已通过业务准入并取得的凭据；组件不读取业务账号或生成 UserSig。 */
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
