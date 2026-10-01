package io.github.gycrosskit.customerservice.consumer
import android.app.Activity
import android.content.Context
import io.github.gycrosskit.customerservice.AndroidTencentCustomerServiceClient
// 只做编译契约消费，不在验证进程调用真实厂商账号。
class AndroidCustomerServiceConsumer {
    private val client = AndroidTencentCustomerServiceClient { _, _, _ -> }
    suspend fun prepare(context: Context) = client.prepare(context, profile())
    suspend fun sync() = client.syncProfile("nickname", "avatar")
    fun intent(activity: Activity) = client.chatIntent(activity)
    suspend fun reset() = client.reset()
}
