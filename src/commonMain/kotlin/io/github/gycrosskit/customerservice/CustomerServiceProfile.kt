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
): CustomerServicePreparationAction = when {
    owned == target && actualUser == target.userId -> CustomerServicePreparationAction.REUSE
    actualUser != null && actualUser != target.userId && actualUser != owned?.userId ->
        CustomerServicePreparationAction.REJECT
    owned != null && actualUser == owned.userId && owned != target -> CustomerServicePreparationAction.RESET
    else -> CustomerServicePreparationAction.INITIALIZE
}
