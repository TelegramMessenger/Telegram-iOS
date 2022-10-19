#
# Be sure to run `pod lib lint BaseAPI.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BaseAPI'
  s.version          = '0.2.0'
  s.summary          = 'BaseAPI is a small Swift library wrapper around URLSession.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
'BaseAPI is a small Swift library which helps you to implement any REST API.
The main goal is to simplify sending HTTP request and receiving response.'
                       DESC
                       
  s.tvos.deployment_target = '9.0'
  s.ios.deployment_target = '9.0'

  s.homepage         = 'https://github.com/serhii-londar/BaseAPI'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'serhii-londar' => 'serhii.londar@gmail.com' }
  s.source           = { :git => 'https://github.com/serhii-londar/BaseAPI.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/serhii_londar'
  s.ios.deployment_target = '9.0'
  s.source_files = 'BaseAPI/Classes/**/*'
  s.frameworks = 'Foundation'
  s.swift_version = '5'
end
