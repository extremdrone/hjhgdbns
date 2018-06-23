Pod::Spec.new do |s|
  s.name                = "DotzuX"
  s.summary             = "DotzuX"
  s.description         = <<-DESC
                              Next Generation of Dotzu (iOS Debugging Tool)
                             DESC
  s.homepage            = "http://DotzuX.com"
  s.author              = { "DotzuX" => "DotzuX@gmail.com" }
  s.license             = "MIT"
  s.source_files        = "Sources", "Sources/**/*.{h,m,swift}"
  s.public_header_files = "Sources/**/*.h"
  s.resources           = "Sources/**/*.{png,xib,storyboard}"
  s.frameworks          = 'UIKit', 'Foundation'
  s.requires_arc        = true
  s.swift_version       = '4.0'
  s.platform            = :ios, "8.0"
  s.source              = { :git => "https://github.com/DotzuX/DotzuX.git", :branch => 'master', :tag => '0.3.2' }
  s.version             = '0.3.2'
end
