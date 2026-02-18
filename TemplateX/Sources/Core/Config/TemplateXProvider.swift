import UIKit

// MARK: - TemplateXTemplateProvider

/// 模板提供者协议
///
/// 用于加载模板 JSON，可以从网络、本地文件、Bundle 等来源加载。
///
/// 使用示例：
/// ```swift
/// class MyTemplateProvider: TemplateXTemplateProvider {
///     func loadTemplate(url: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
///         // 从网络或本地加载模板
///     }
/// }
/// ```
public protocol TemplateXTemplateProvider: AnyObject {
    
    /// 加载模板（异步）
    func loadTemplate(url: String, completion: @escaping (Result<[String: Any], Error>) -> Void)
    
    /// 加载模板（同步，可选实现）
    func loadTemplateSync(url: String) -> [String: Any]?
    
    /// 预加载模板（可选实现）
    func preloadTemplates(urls: [String])
}

public extension TemplateXTemplateProvider {
    func loadTemplateSync(url: String) -> [String: Any]? { nil }
    func preloadTemplates(urls: [String]) {}
}

// MARK: - TemplateXResourceProvider

/// 通用资源提供者协议
public protocol TemplateXResourceProvider: AnyObject {
    var resourceType: String { get }
    func loadResource(url: String, completion: @escaping (Result<Data, Error>) -> Void)
}

// MARK: - BundleTemplateProvider

/// Bundle 模板提供者（加载 Bundle 中的 JSON 文件）
public class BundleTemplateProvider: TemplateXTemplateProvider {
    
    public let bundle: Bundle
    
    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }
    
    public func loadTemplate(url: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(TemplateXProviderError.providerDeallocated))
                return
            }
            
            if let json = self.loadTemplateSync(url: url) {
                DispatchQueue.main.async { completion(.success(json)) }
            } else {
                DispatchQueue.main.async { completion(.failure(TemplateXProviderError.templateNotFound(url))) }
            }
        }
    }
    
    public func loadTemplateSync(url: String) -> [String: Any]? {
        let name = url.hasSuffix(".json") ? String(url.dropLast(5)) : url
        
        guard let path = bundle.path(forResource: name, ofType: "json"),
              let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
}

// MARK: - 错误类型

public enum TemplateXProviderError: Error, LocalizedError {
    case templateNotFound(String)
    case parseError
    case networkError(Error)
    case providerDeallocated
    
    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let url): return "Template not found: \(url)"
        case .parseError: return "Failed to parse template JSON"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .providerDeallocated: return "Provider was deallocated"
        }
    }
}
