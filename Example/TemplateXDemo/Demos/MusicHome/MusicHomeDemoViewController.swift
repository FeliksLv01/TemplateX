import UIKit
import TemplateX

/// 网易云音乐风格首页 Demo
/// 演示 TemplateX 在复杂列表场景的能力：
/// - 外层 UICollectionView 垂直滚动
/// - 内层通过 DSL 定义横向滚动列表
/// - 支持分页滚动的网格布局
/// - 数据从 JSON 文件异步加载，模拟网络请求
class MusicHomeDemoViewController: UIViewController {
    
    // MARK: - Types
    
    enum SectionType: String {
        case horizontal = "horizontal_section"
        case grid = "grid_section"
        
        init?(jsonValue: String) {
            switch jsonValue {
            case "horizontal", "horizontal_section": self = .horizontal
            case "grid", "grid_section":             self = .grid
            default: return nil
            }
        }
    }
    
    struct SectionData {
        let id: String
        let type: SectionType
        let title: String
        let items: [[String: Any]]
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var dataSource: [SectionData] = []
    private var loadingIndicator: UIActivityIndicatorView!
    
    /// 模板缓存
    private var horizontalTemplate: [String: Any]?
    private var gridTemplate: [String: Any]?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // 加载模板
        loadTemplates()
        
        // 设置 UI
        setupCollectionView()
        setupLoadingIndicator()
        
        // 异步加载数据（模拟网络请求）
        loadDataAsync()
    }
    
    // MARK: - Setup
    
    private func loadTemplates() {
        horizontalTemplate = loadJSON(named: "horizontal_section", inDirectory: "MusicHome")
        gridTemplate = loadJSON(named: "grid_section", inDirectory: "MusicHome")
    }
    
    private func loadJSON(named fileName: String, inDirectory directory: String? = nil) -> [String: Any]? {
        let bundle = Bundle.main
        
        // 尝试直接查找
        if let url = bundle.url(forResource: fileName, withExtension: "json") {
            return parseJSON(at: url)
        }
        
        // 尝试在子目录查找
        if let directory = directory,
           let resourcePath = bundle.resourcePath {
            let fullPath = "\(resourcePath)/\(directory)/\(fileName).json"
            let url = URL(fileURLWithPath: fullPath)
            if FileManager.default.fileExists(atPath: fullPath) {
                return parseJSON(at: url)
            }
        }
        
        print("[MusicHomeDemo] JSON file not found: \(fileName).json")
        return nil
    }
    
    private func parseJSON(at url: URL) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("[MusicHomeDemo] Failed to parse JSON: \(error)")
            return nil
        }
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MusicHomeCell.self, forCellWithReuseIdentifier: MusicHomeCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        // 数据加载前隐藏
        collectionView.isHidden = true
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .systemGray
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    // MARK: - Data Loading
    
    /// 异步加载 music_home_data.json，模拟网络请求延迟
    private func loadDataAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 模拟网络延迟 0.5s
            Thread.sleep(forTimeInterval: 0.5)
            
            guard let self = self else { return }
            
            // 加载并解析 JSON 数据文件
            let sections = self.loadSectionsFromJSON()
            
            DispatchQueue.main.async {
                self.dataSource = sections
                self.loadingIndicator.stopAnimating()
                self.collectionView.isHidden = false
                self.collectionView.reloadData()
            }
        }
    }
    
    /// 从 music_home_data.json 解析 section 数据
    private func loadSectionsFromJSON() -> [SectionData] {
        guard let jsonDict = loadJSON(named: "music_home_data", inDirectory: "MusicHome"),
              let sectionsArray = jsonDict["sections"] as? [[String: Any]] else {
            print("[MusicHomeDemo] Failed to load music_home_data.json")
            return []
        }
        
        return sectionsArray.enumerated().compactMap { index, sectionDict -> SectionData? in
            guard let typeStr = sectionDict["type"] as? String,
                  let type = SectionType(jsonValue: typeStr),
                  let title = sectionDict["title"] as? String,
                  let items = sectionDict["items"] as? [[String: Any]] else {
                return nil
            }
            let id = sectionDict["id"] as? String ?? "section_\(index)"
            return SectionData(id: id, type: type, title: title, items: items)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MusicHomeDemoViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MusicHomeCell.reuseIdentifier, for: indexPath) as! MusicHomeCell
        
        let section = dataSource[indexPath.item]
        let template = section.type == .horizontal ? horizontalTemplate : gridTemplate
        
        guard let template = template else {
            return cell
        }
        
        let data: [String: Any] = [
            "section": [
                "title": section.title,
                "items": section.items
            ]
        ]
                
        cell.configure(
            template: template,
            templateId: section.type.rawValue,
            data: data,
            containerWidth: collectionView.bounds.width
        )
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MusicHomeDemoViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let section = dataSource[indexPath.item]
        let template = section.type == .horizontal ? horizontalTemplate : gridTemplate
        
        guard let template = template else {
            return CGSize(width: collectionView.bounds.width, height: 100)
        }
        
        let data: [String: Any] = [
            "section": [
                "title": section.title,
                "items": section.items
            ]
        ]
        
        let height = TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: section.type.rawValue,
            data: data,
            containerWidth: collectionView.bounds.width,
            useCache: true
        )
        
        return CGSize(width: collectionView.bounds.width, height: max(height, 100))
    }
}
