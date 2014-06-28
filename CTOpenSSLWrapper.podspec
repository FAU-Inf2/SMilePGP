Pod::Spec.new do |spec|
  spec.name          = 'CTOpenSSLWrapper'
  spec.version       = '1.2.1'
  spec.platform      = :ios, '6.0'
  spec.license       = 'MIT'
  spec.source        = { :git => 'https://github.com/ebf/CTOpenSSLWrapper.git', :tag => spec.version.to_s }
  spec.source_files  = 'CTOpenSSLWrapper/CTOpenSSLWrapper/*.{h,m}', 'CTOpenSSLWrapper/CTOpenSSLWrapper/Framework Additions/**/**/*.{h,m}', 'CTOpenSSLWrapper/CTOpenSSLWrapper/**/*.{h,m}'
  spec.frameworks    = 'Foundation'
  spec.requires_arc  = true
  spec.homepage      = 'https://github.com/ebf/CTOpenSSLWrapper'
  spec.summary       = 'Objc OpenSSL wrapper.'
  spec.author        = { 'Oliver Letterer' => 'oliver.letterer@gmail.com' }
  
  spec.dependency 'OpenSSL-Universal', '1.0.1.h'
end
