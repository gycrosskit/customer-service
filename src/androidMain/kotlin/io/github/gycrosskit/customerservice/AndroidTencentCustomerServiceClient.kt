package io.github.gycrosskit.customerservice

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.tencentcloud.tencentcloudcustomer.Callbacks.AIDeskCallback
import com.tencentcloud.tencentcloudcustomer.Callbacks.TencentAiDeskCustomerLoginCallback
import com.tencentcloud.tencentcloudcustomer.Config.TencentAiDeskCustomerThemeConfig
import com.tencentcloud.tencentcloudcustomer.TencentAiDeskCustomer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/** 进程唯一 SDK 适配器。宿主必须串行持有不可取消的 prepare/sync/reset，不能以等待取消重建本实例。 */
class AndroidTencentCustomerServiceClient(
    private val onSdkError: (operation: String, code: Int, message: String?) -> Unit = { _, _, _ -> },
) {
    private var ownedIdentity: CustomerServiceIdentity? = null

    suspend fun prepare(
        context: Context,
        profile: CustomerServiceProfile,
    ): Boolean = withContext(Dispatchers.Main.immediate) {
        require(profile.appId > 0 && profile.userId.isNotBlank() && profile.userSig.isNotBlank())
        val sdk = TencentAiDeskCustomer.getInstance()
        val identity = CustomerServiceIdentity(profile.appId, profile.userId)
        when (customerServicePreparationAction(ownedIdentity, sdkUser(sdk), identity)) {
            CustomerServicePreparationAction.REUSE -> return@withContext true
            CustomerServicePreparationAction.REJECT -> {
                onSdkError("prepare", -1, "Refusing to replace a foreign Tencent identity")
                return@withContext false
            }
            CustomerServicePreparationAction.RESET -> {
                if (!unInit(sdk)) return@withContext false
                ownedIdentity = null
                // 异步清理期间共享 IM 可能被接管，初始化前重新检查实际用户。
                return@withContext prepare(context, profile)
            }
            CustomerServicePreparationAction.INITIALIZE -> Unit
        }
        ownedIdentity = null
        sdk.setTheme(TencentAiDeskCustomerThemeConfig.finance)
        sdk.setShowAvatar(true)
        sdk.setShowHumanService(true)
        sdk.setShowLeaveQueue(true)
        sdk.setShowServiceRating(true)
        sdk.setShowEndHumanService(true)
        sdk.setShowNickName(true)
        val ready = suspendCancellableCoroutine { continuation ->
            sdk.initWithProfile(
                context.applicationContext,
                profile.appId,
                profile.userId,
                profile.userSig,
                profile.nickname,
                profile.avatar,
                object : AIDeskCallback() {
                    override fun onSuccess() {
                        if (continuation.isActive) continuation.resume(true)
                    }
                    override fun onError(code: Int, desc: String?) {
                        onSdkError("initialize", code, desc)
                        if (continuation.isActive) continuation.resume(false)
                    }
                },
            )
        }
        if (ready) ownedIdentity = identity
        ready
    }

    suspend fun syncProfile(
        nickname: String,
        avatar: String,
    ): Boolean = withContext(Dispatchers.Main.immediate) {
        val sdk = TencentAiDeskCustomer.getInstance()
        if (ownedIdentity?.userId != sdkUser(sdk) || ownedIdentity == null) {
            onSdkError("syncProfile", -1, "Customer service identity is no longer owned")
            return@withContext false
        }
        suspendCancellableCoroutine { continuation ->
            sdk.setSelfInfo(
                nickname,
                avatar,
                object : TencentAiDeskCustomerLoginCallback() {
                    override fun onSuccess() {
                        if (continuation.isActive) continuation.resume(true)
                    }
                    override fun onError(code: Int, desc: String?) {
                        onSdkError("syncProfile", code, desc)
                        if (continuation.isActive) continuation.resume(false)
                    }
                },
            )
        }
    }

    /** 只创建厂商原生页面 Intent；真正 Activity Result 及等待由宿主管理。 */
    fun chatIntent(activity: Activity): Intent {
        check(!activity.isFinishing && !activity.isDestroyed)
        val sdk = TencentAiDeskCustomer.getInstance()
        check(ownedIdentity != null && ownedIdentity?.userId == sdkUser(sdk))
        return sdk.getCustomerServiceChatIntent(activity)
    }

    suspend fun reset(): Boolean = withContext(Dispatchers.Main.immediate) {
        // 隐私准入前也可能收到根 reset；没有自有身份时不能触碰 SDK 单例。
        val identity = ownedIdentity ?: return@withContext true
        val sdk = TencentAiDeskCustomer.getInstance()
        if (sdkUser(sdk) == identity.userId && !unInit(sdk)) return@withContext false
        ownedIdentity = null
        true
    }

    private fun sdkUser(sdk: TencentAiDeskCustomer): String? =
        if (sdk.isUserLoggedIn) sdk.loginUser?.takeIf(String::isNotBlank) else null

    private suspend fun unInit(sdk: TencentAiDeskCustomer): Boolean = suspendCancellableCoroutine { continuation ->
        sdk.unInit(object : AIDeskCallback() {
            override fun onSuccess() {
                if (continuation.isActive) continuation.resume(true)
            }
            override fun onError(code: Int, desc: String?) {
                onSdkError("unInit", code, desc)
                if (continuation.isActive) continuation.resume(false)
            }
        })
    }
}
