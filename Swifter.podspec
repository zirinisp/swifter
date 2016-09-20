Pod::Spec.new do |s|

  s.name                  = "Swifter"
  s.version               = "3.0.1"
  s.summary               = "Tiny http server engine written in Swift programming language."
  s.homepage              = "https://github.com/glock45/swifter"
  s.license               = { :type => 'Copyright', :file => 'LICENSE' }
  s.author                = { "Damian Kołakowski" => "kolakowski.damian@gmail.com" }
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.tvos.deployment_target = "9.0"
  s.source                = { :git => "https://github.com/pvzig/swifter.git", :tag => "3.0.1" }
  s.source_files          = 'Sources/*.{h,m,swift}'

end
