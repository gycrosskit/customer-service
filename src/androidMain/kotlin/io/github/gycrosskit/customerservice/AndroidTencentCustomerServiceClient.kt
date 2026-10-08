package io.github.gycrosskit.customerservice

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.tencent.imsdk.v2.V2TIMManager
import com.tencent.qcloud.deskcore.TUILogin
import com.tencentcloud.tencentcloudcustomer.Callbacks.AIDeskCallback
import com.tencentcloud.tencentcloudcustomer.Callbacks.TencentAiDeskCustomerLoginCallback
import com.tencentcloud.tencentcloudcustomer.TencentAiDeskCustomer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/**
 * 进程唯一 SDK 适配器，宿主与 Live 共用串行屏障，不能以等待取消重建本实例。
 * prepare/sync/reset 切到 Main 并等待不可取消的厂商操作；chatIntent 必须在 Main 调用。
 * reset 只释放仍属于本组件的 runtime，不注销借用或被外部接管的身份。
 * @param onSdkError 厂商失败回调，可能在厂商回调线程执行；宿主负责安全记录，勿记录凭据。
 */
class AndroidTencentCustomerServiceClient(
    private val onSdkError: (operation: String, code: Int, message: String?) -> Unit = { _, _, _ -> },
) {
    private var ownedIdentity: CustomerServiceIdentity? = null
    private var ownsRuntime = false
    private var operationSerial = 0L

    /**
     * 校验凭据并准备厂商 facade；同身份可复用，共用 IM 的 foreign 身份不会被覆盖。
     * 调用方取消仍等真实 callback；宿主必须持有串行屏障到返回。false 表示 SDK 拒绝/失败。
     * @param context 只将 applicationContext 交给 SDK，不持有 Activity。
     * @param profile 已通过隐私准入的资料；无效 appId/空白凭据抛出 IllegalArgumentException。
     */
    suspend fun prepare(
        context: Context,
        profile: CustomerServiceProfile,
    ): Boolean = withContext(Dispatchers.Main.immediate + NonCancellable) {
        require(profile.appId > 0 && profile.userId.isNotBlank() && profile.userSig.isNotBlank())
        val sdk = TencentAiDeskCustomer.getInstance()
        val identity = CustomerServiceIdentity(profile.appId, profile.userId)
        if (V2TIMManager.getInstance().loginStatus == V2TIMManager.V2TIM_STATUS_LOGINING) return@withContext false
        val actual = runtimeUser()
        when (customerServicePreparationAction(ownedIdentity, actual, identity, ownsRuntime, sdkUser(sdk) == profile.userId, TUILogin.getSdkAppId())) {
            CustomerServicePreparationAction.REUSE -> return@withContext true
            CustomerServicePreparationAction.REJECT -> {
                onSdkError("prepare", -1, "Refusing to replace a foreign Tencent identity")
                return@withContext false
            }
            CustomerServicePreparationAction.RESET -> {
                if (!reset()) return@withContext false
                // 异步清理期间共享 IM 可能被接管，初始化前重新检查实际用户。
                return@withContext prepare(context, profile)
            }
            CustomerServicePreparationAction.INITIALIZE -> Unit
        }
        val serial = ++operationSerial
        val previousIdentity = ownedIdentity
        val previouslyOwned = customerServiceOwnsActualIdentity(previousIdentity, ownsRuntime, actual, TUILogin.getSdkAppId())
        val mayOwn = actual == null || previouslyOwned
        ownedIdentity = null; ownsRuntime = false
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
        val configuredAppId = TUILogin.getSdkAppId()
        if (ready && serial == operationSerial && runtimeUser() == identity.userId && sdkUser(sdk) == identity.userId &&
            (configuredAppId <= 0 || configuredAppId == identity.appId)) {
            ownedIdentity = identity; ownsRuntime = mayOwn
            true
        } else {
            if (serial == operationSerial && customerServiceOwnsActualIdentity(previousIdentity, previouslyOwned, runtimeUser(), TUILogin.getSdkAppId())) {
                ownedIdentity = previousIdentity; ownsRuntime = true
            }
            false
        }
    }

    /**
     * 更新当前准备身份的昵称/头像；空字符串按厂商语义透传，身份失效或 SDK 失败返回 false。
     * 在 Main 等真实 callback，调用方取消不提前释放宿主串行屏障。
     */
    suspend fun syncProfile(
        nickname: String,
        avatar: String,
    ): Boolean = withContext(Dispatchers.Main.immediate + NonCancellable) {
        val sdk = TencentAiDeskCustomer.getInstance()
        val identity = ownedIdentity
        val configuredAppId = TUILogin.getSdkAppId()
        if (identity == null || identity.userId != runtimeUser() || identity.userId != sdkUser(sdk) ||
            (configuredAppId > 0 && configuredAppId != identity.appId)) {
            onSdkError("syncProfile", -1, "Customer service identity is no longer owned")
            return@withContext false
        }
        val serial = operationSerial
        val updated = suspendCancellableCoroutine { continuation ->
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
        // SDK 成功不证明旧身份仍有效；外部接管或 reset 后不能结算为旧资料同步成功。
        val actualAppId = TUILogin.getSdkAppId()
        updated && serial == operationSerial && ownedIdentity == identity && runtimeUser() == identity.userId &&
            sdkUser(sdk) == identity.userId && (actualAppId <= 0 || actualAppId == identity.appId)
    }

    /**
     * 在 Main 为有效、未销毁的 activity 创建厂商 Intent；Activity Result 与重复打开等待由宿主管理。
     * 未准备、身份/AppId 变化或 Activity 已结束时抛出 IllegalStateException。
     */
    fun chatIntent(activity: Activity): Intent {
        check(!activity.isFinishing && !activity.isDestroyed)
        val sdk = TencentAiDeskCustomer.getInstance()
        val identity = ownedIdentity
        val configuredAppId = TUILogin.getSdkAppId()
        check(identity != null && identity.userId == runtimeUser() && identity.userId == sdkUser(sdk) &&
            (configuredAppId <= 0 || configuredAppId == identity.appId))
        return sdk.getCustomerServiceChatIntent(activity)
    }

    /**
     * 清除本地准备身份；仅仍自有的 runtime 才执行 unInit，不访问未准备的 SDK。
     * 在 Main 等不可取消 callback；失败且仍自有时返回 false 并保留权限供重试。
     */
    suspend fun reset(): Boolean = withContext(Dispatchers.Main.immediate + NonCancellable) {
        // 隐私准入前也可能收到根 reset；没有自有身份时不能触碰 SDK 单例。
        val serial = ++operationSerial
        val identity = ownedIdentity ?: return@withContext true
        if (!ownsRuntime) { ownedIdentity = null; return@withContext true }
        if (V2TIMManager.getInstance().loginStatus == V2TIMManager.V2TIM_STATUS_LOGINING || !customerServiceOwnsActualIdentity(identity, ownsRuntime, runtimeUser(), TUILogin.getSdkAppId())) {
            ownedIdentity = null; ownsRuntime = false; return@withContext true
        }
        val sdk = TencentAiDeskCustomer.getInstance()
        val reset = suspendCancellableCoroutine { continuation ->
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
        if (serial != operationSerial) return@withContext false
        if (!reset && customerServiceOwnsActualIdentity(identity, true, runtimeUser(), TUILogin.getSdkAppId())) return@withContext false
        ownedIdentity = null; ownsRuntime = false
        true
    }

    private fun runtimeUser(): String? = V2TIMManager.getInstance().loginUser?.takeIf(String::isNotBlank)

    private fun sdkUser(sdk: TencentAiDeskCustomer): String? =
        if (sdk.isUserLoggedIn) sdk.loginUser?.takeIf(String::isNotBlank) else null
}
