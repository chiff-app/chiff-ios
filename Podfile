# Pods are retrieved from from cocoapods.org.
# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# ignore all warnings from all pods
inhibit_all_warnings!

use_frameworks!

def shared_pods
  pod 'MBProgressHUD', '~> 1.0.0'
  pod 'Sodium', :git => 'https://github.com/jedisct1/swift-sodium.git'
  pod 'AWSCognito'
  pod 'AWSSNS'
#  pod 'AWSAPIGateway'
  pod "JustLog"
end

target 'keyn' do
  shared_pods
#  pod 'SmileLock'
end

target 'keynNotificationExtension' do
  shared_pods
end

target 'keynTests' do
  shared_pods
end
