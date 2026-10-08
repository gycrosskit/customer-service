"""替换厂商/Android入口，直接编译生产客服client；不访问真实凭据或登录。"""
from pathlib import Path
sources = {
'Android.kt': '''package android.content
open class Context { val applicationContext get()=this }
class Intent
''',
'Activity.kt': '''package android.app
class Activity:android.content.Context() { var isFinishing=false;var isDestroyed=false }
''',
'IM.kt': '''package com.tencent.imsdk.v2
class V2TIMManager { var loginUser:String?=null;var loginStatus=0
 companion object {const val V2TIM_STATUS_LOGINING=1;private val instance=V2TIMManager();fun getInstance()=instance} }
''',
'Login.kt': '''package com.tencent.qcloud.deskcore
object TUILogin { var appId=100;fun getSdkAppId()=appId }
''',
'Callbacks.kt': '''package com.tencentcloud.tencentcloudcustomer.Callbacks
open class AIDeskCallback { open fun onSuccess(){};open fun onError(code:Int,desc:String?){} }
open class TencentAiDeskCustomerLoginCallback {open fun onSuccess(){};open fun onError(code:Int,desc:String?){} }
''',
'Theme.kt': '''package com.tencentcloud.tencentcloudcustomer.Config
enum class TencentAiDeskCustomerThemeConfig {business, finance, service}
''',
'Desk.kt': '''package com.tencentcloud.tencentcloudcustomer
import android.content.*
import android.app.Activity
import com.tencentcloud.tencentcloudcustomer.Callbacks.*
import com.tencent.imsdk.v2.V2TIMManager
import com.tencent.qcloud.deskcore.TUILogin
import com.tencentcloud.tencentcloudcustomer.Config.TencentAiDeskCustomerThemeConfig
class TencentAiDeskCustomer {
 var isUserLoggedIn=false;var loginUser:String?=null;var updates=0;var pages=0;var cleanups=0
 var deferProfile=false;var profile: TencentAiDeskCustomerLoginCallback?=null
 var initializeCalls=0;var deferInitialization=false;var deferCleanup=false;var initialization:AIDeskCallback?=null;var cleanup:AIDeskCallback?=null
 var themeCalls=0;var currentTheme=TencentAiDeskCustomerThemeConfig.business
 fun setTheme(value:TencentAiDeskCustomerThemeConfig){themeCalls++;currentTheme=value};fun setShowAvatar(value:Boolean){};fun setShowHumanService(value:Boolean){};fun setShowLeaveQueue(value:Boolean){};fun setShowServiceRating(value:Boolean){};fun setShowEndHumanService(value:Boolean){};fun setShowNickName(value:Boolean){}
 fun initWithProfile(context:Context,appId:Int,userId:String,userSig:String,nickname:String,avatar:String,callback:AIDeskCallback) {currentTheme=TencentAiDeskCustomerThemeConfig.business;initializeCalls++;TUILogin.appId=appId;V2TIMManager.getInstance().loginUser=userId;loginUser=userId;isUserLoggedIn=true;if(deferInitialization) initialization=callback else callback.onSuccess()}
 fun setSelfInfo(nickname:String,avatar:String,callback:TencentAiDeskCustomerLoginCallback){updates++;if(deferProfile) profile=callback else callback.onSuccess()}
 fun getCustomerServiceChatIntent(activity:Activity):Intent {pages++;return Intent()}
 fun unInit(callback:AIDeskCallback){cleanups++;if(deferCleanup) cleanup=callback else callback.onSuccess()}
 companion object {private val instance=TencentAiDeskCustomer();fun getInstance()=instance}
}
''',
}
root=Path('build/remote-library-review/android-fixture');root.mkdir(parents=True,exist_ok=True)
for name,source in sources.items():(root/name).write_text(source)
