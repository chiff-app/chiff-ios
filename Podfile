# Pods are retrieved from from cocoapods.org.
# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# ignore all warnings from all pods
inhibit_all_warnings!

use_frameworks!

def shared_pods
  pod 'MBProgressHUD', '~> 1.0.0'
  pod 'Sodium', '~> 0.8'
  pod 'JustLog'
  pod 'OneTimePassword', '~> 3.1'
end

target 'keyn' do
  shared_pods
#  pod 'SmileLock'
end

target 'keynNotificationExtension' do
  shared_pods
end

target 'keynCredentialProvider' do
  shared_pods
end


target 'keynTests' do
  shared_pods
end

post_install do |installer_representation|
    installer_representation.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
        end
    end
end

