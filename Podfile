# Pods are retrieved from from cocoapods.org.
# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

use_frameworks!

def shared_pods
  pod 'MBProgressHUD', '~> 1.0.0'
  pod 'Sodium', '~> 0.6'
  pod 'AWSCognito'
  pod 'AWSSNS'
  pod 'AWSSQS'
  pod 'AWSLambda'
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
