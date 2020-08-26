#
# Be sure to run `pod lib lint SDWebImageAVIFCoder.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SDWebImageAVIFCoder'
  s.version          = '0.6.1'
  s.summary          = 'A SDWebImage coder plugin to support AVIF(AV1 Image File Format) image'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This is a SDWebImage coder plugin to add AV1 Image File Format (AVIF) support.
Which is built based on the open-sourced libavif codec.
                       DESC

  s.homepage         = 'https://github.com/SDWebImage/SDWebImageAVIFCoder'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DreamPiggy' => 'lizhuoli1126@126.com' }
  s.source           = { :git => 'https://github.com/SDWebImage/SDWebImageAVIFCoder.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'SDWebImageAVIFCoder/Classes/**/*', 'SDWebImageAVIFCoder/Module/SDWebImageAVIFCoder.h'
  s.public_header_files  = 'SDWebImageAVIFCoder/Classes/Public/*.{h,m}', 'SDWebImageAVIFCoder/Module/SDWebImageAVIFCoder.h'
  s.private_header_files = 'SDWebImageAVIFCoder/Classes/Private/*.{h,m}'
  
  s.dependency 'SDWebImage', '~> 5.0'
  s.dependency 'libavif', '>= 0.7.2'
end
