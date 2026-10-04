Pod::Spec.new do |s|
  s.name = 'GycCustomerServiceNative'
  s.version = '0.1.3'
  s.summary = '腾讯客服原生会话与展示适配'
  s.homepage = 'https://github.com/gycrosskit/customer-service'
  s.license = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author = 'GY CrossKit'
  s.source = { :git => 'https://github.com/gycrosskit/customer-service.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.9'
  s.static_framework = true
  s.source_files = 'ios/Sources/GycCustomerServiceNative/*.swift'
  s.dependency 'TencentCloudAIDeskCustomer', '1.4.1'
  s.dependency 'TDeskCore', '2.9.141'
  s.dependency 'TDeskCommon', '2.9.141'
  s.dependency 'TDeskChat', '2.9.141'
  s.dependency 'TDeskCustomerServicePlugin', '2.9.141'
  s.dependency 'TXIMSDK_Plus_iOS_XCFramework', '9.1.7818'
end
