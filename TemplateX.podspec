Pod::Spec.new do |s|
  s.name             = 'TemplateX'
  s.version          = '1.0.0'
  s.summary          = '高性能 iOS DSL 动态渲染框架'
  s.description      = <<-DESC
    TemplateX 是一个高性能的 iOS 动态化模板渲染引擎，支持：
    - Yoga Flexbox 布局（直接使用 C API，支持子线程计算）
    - ANTLR4 表达式引擎
    - 视图树 Diff 和复用
    - XML 开发态编译为 JSON 运行态
    - 事件系统和数据绑定
  DESC

  s.homepage         = 'https://github.com/FeliksLv01/TemplateX'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FeliksLv' => 'felikslv@163.com' }
  s.source           = { :git => 'https://github.com/FeliksLv01/TemplateX.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.4'
  s.swift_version = '5.7'
  
  s.static_framework = true

  # 源文件
  s.source_files = 'Sources/**/*.swift'
  
  # 排除 ANTLR4 语法文件
  s.exclude_files = 'Sources/Core/Expression/Grammar/*.g4'

  s.dependency 'Yoga', '~> 3.0'
  s.dependency 'Antlr4', '~> 4.13'
  
  s.frameworks = 'UIKit', 'Foundation'
end
