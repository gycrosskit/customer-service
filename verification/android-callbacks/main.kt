package io.github.gycrosskit.customerservice
import android.app.Activity
import com.tencent.imsdk.v2.V2TIMManager
import com.tencent.qcloud.deskcore.TUILogin
import com.tencentcloud.tencentcloudcustomer.TencentAiDeskCustomer
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
@OptIn(ExperimentalCoroutinesApi::class)
fun main()=runBlocking {
 Dispatchers.setMain(UnconfinedTestDispatcher())
 try {
  val im=V2TIMManager.getInstance();val sdk=TencentAiDeskCustomer.getInstance();val profile=CustomerServiceProfile(100,"member","mock-sig",""," ")
  for(borrow in listOf(false,true)) {
   im.loginUser=if(borrow)"member" else null;sdk.isUserLoggedIn=false;sdk.loginUser=null;TUILogin.appId=100
   val client=AndroidTencentCustomerServiceClient();check(client.prepare(Activity(),profile))
   val updates=sdk.updates;val pages=sdk.pages;val cleanups=sdk.cleanups
   TUILogin.appId=101
   check(!client.syncProfile("foreign","avatar")) {"same user foreign AppId updated profile"}
   check(runCatching{client.chatIntent(Activity())}.isFailure) {"same user foreign AppId opened chat"}
   check(sdk.updates==updates&&sdk.pages==pages)
   check(client.reset()&&sdk.cleanups==cleanups)
  }
  for(appId in listOf(100,0)) {
   im.loginUser="member";sdk.isUserLoggedIn=false;sdk.loginUser=null;TUILogin.appId=100
   val client=AndroidTencentCustomerServiceClient();check(client.prepare(Activity(),profile));TUILogin.appId=appId
   val updates=sdk.updates;val pages=sdk.pages;val cleanups=sdk.cleanups
   check(client.syncProfile("borrow","avatar"));client.chatIntent(Activity())
   check(sdk.updates==updates+1&&sdk.pages==pages+1)
   check(client.reset()&&sdk.cleanups==cleanups) {"borrowed runtime was unInit"}
  }
  // 无效输入、正在登录及销毁容器不能触发厂商动作。
  val invalidClient=AndroidTencentCustomerServiceClient()
  val initializationsBeforeInvalid=sdk.initializeCalls
  for(invalid in listOf(profile.copy(appId=0),profile.copy(userId=" \t"),profile.copy(userSig="\n"))) {
   check(runCatching { invalidClient.prepare(Activity(),invalid) }.exceptionOrNull() is IllegalArgumentException)
  }
  im.loginStatus=V2TIMManager.V2TIM_STATUS_LOGINING
  check(!invalidClient.prepare(Activity(),profile));im.loginStatus=0
  check(sdk.initializeCalls==initializationsBeforeInvalid)
  im.loginUser=null;sdk.isUserLoggedIn=false;sdk.loginUser=null;TUILogin.appId=100
  check(invalidClient.prepare(Activity(),profile))
  for(activity in listOf(Activity().apply{isFinishing=true},Activity().apply{isDestroyed=true})) {
   check(runCatching { invalidClient.chatIntent(activity) }.exceptionOrNull() is IllegalStateException)
  }
  check(invalidClient.reset())

  // 等待被取消也必须等厂商真实 callback，避免宿主提前释放共享 SDK 串行屏障。
  im.loginUser=null;sdk.isUserLoggedIn=false;sdk.loginUser=null;TUILogin.appId=100
  sdk.deferInitialization=true
  val cancelledClient=AndroidTencentCustomerServiceClient()
  val preparing=launch(start=CoroutineStart.UNDISPATCHED){cancelledClient.prepare(Activity(),profile)}
  check(sdk.initialization!=null && !preparing.isCompleted)
  preparing.cancel();check(!preparing.isCompleted)
  sdk.initialization!!.onSuccess();sdk.initialization=null;sdk.deferInitialization=false
  preparing.join()
  sdk.deferCleanup=true
  val resetting=launch(start=CoroutineStart.UNDISPATCHED){cancelledClient.reset()}
  check(sdk.cleanup!=null && !resetting.isCompleted)
  resetting.cancel();check(!resetting.isCompleted)
  sdk.cleanup!!.onError(17,"mock cleanup failed");sdk.cleanup=null
  resetting.join()
  val cleanupsBeforeRetry=sdk.cleanups
  val retry=async(start=CoroutineStart.UNDISPATCHED){cancelledClient.reset()}
  check(sdk.cleanups==cleanupsBeforeRetry+1 && !retry.isCompleted)
  sdk.cleanup!!.onSuccess();sdk.cleanup=null;sdk.deferCleanup=false
  check(retry.await())
  println("PASS Android production callback contracts: AppId/borrow, invalid input, login pending, destroyed Activity, cancellation and cleanup retry")
 }finally{Dispatchers.resetMain()}
}
