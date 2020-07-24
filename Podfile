# Pods are retrieved from from cocoapods.org.
# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# ignore all warnings from all pods
inhibit_all_warnings!

use_frameworks!

def shared_pods
  pod 'MBProgressHUD', '~> 1.0.0'
  pod 'Sodium', '~> 0.8'
  pod 'OneTimePassword', '~> 3.1'
  pod 'TrustKit'
  pod 'Firebase/Core'
  pod 'Amplitude', '~> 5.1'
  pod 'SwiftLint'
  pod "PromiseKit", "~> 6.8"
  pod "PromiseKit/Foundation"
  pod "TrueTime"
  pod 'DataCompression'
end

target 'keyn' do
  shared_pods
  pod 'Firebase/Crashlytics'
  pod 'Down'
end

target 'keynNotificationExtension' do
  shared_pods
  pod 'Firebase/Crashlytics'
end

target 'keynCredentialProvider' do
  shared_pods
  pod 'Firebase/Crashlytics'
end


target 'keynTests' do
  shared_pods
end

post_install do |installer_representation|
    installer_representation.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
            config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'AMPLITUDE_SSL_PINNING=1']
        end
    end
end
