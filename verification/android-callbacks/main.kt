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
  println("PASS 4 actual Android customer client cases: own/borrow foreign-AppId blocked; known/unknown borrowed runtime usable without cleanup")
 }finally{Dispatchers.resetMain()}
}
