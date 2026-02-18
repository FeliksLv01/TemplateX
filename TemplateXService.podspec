Pod::Spec.new do |s|
  s.name             = 'TemplateXService'
  s.version          = '1.0.0'
  s.summary          = 'TemplateX Service Implementations'
  s.description      = <<-DESC
    TemplateX 的 Service 层实现，包括：
    - Image: SDWebImage 图片加载器（支持 WebP）
    - Log: Console 日志实现
  DESC

  s.homepage         = 'https://github.com/FeliksLv01/TemplateX'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FeliksLv' => 'felikslv@163.com' }
  s.source           = { :git => 'https://github.com/FeliksLv01/TemplateX.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.4'
  s.swift_version = '5.7'
  
  # 默认 subspec：Image（SDWebImage 实现）
  s.default_subspec = 'Image'
  
  # MARK: - Image subspec（SDWebImage 图片加载器）
  
  s.subspec 'Image' do |img|
    img.source_files = 'TemplateXService/Image/**/*.swift'
    
    img.dependency 'TemplateX'
    img.dependency 'SDWebImage', '~> 5.15'
    img.dependency 'SDWebImageWebPCoder', '~> 0.14'
  end
  
  # MARK: - Log subspec（Console 日志实现）
  
  s.subspec 'Log' do |log|
    log.source_files = 'TemplateXService/Log/**/*.swift'
    
    log.dependency 'TemplateX'
  end
end
