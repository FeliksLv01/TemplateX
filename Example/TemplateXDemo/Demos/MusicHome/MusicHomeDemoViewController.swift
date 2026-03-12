import UIKit
import TemplateX
import MJRefresh

/// 网易云音乐风格首页 Demo
/// 演示 TemplateX 在复杂列表场景的能力：
/// - 外层 UICollectionView 垂直滚动
/// - 内层通过 DSL 定义横向滚动列表
/// - 首屏数据直出（同步加载），上拉分页加载后续模块
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
        var isSkeleton: Bool = false
        /// Pre-calculated height for skeleton sections (matches real content height)
        var skeletonHeight: CGFloat = 0
    }
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var dataSource: [SectionData] = []
    
    /// All sections parsed from JSON (full dataset)
    private var allSections: [SectionData] = []
    private var horizontalTemplate: [String: Any]?
    private var gridTemplate: [String: Any]?
    
    // MARK: - Pagination
    
    private let pageSize = 5
    private var currentPage = 0
    private var isLoading = false
    private var hasMore: Bool { currentPage * pageSize < allSections.count }
    
    /// Distance from bottom to trigger next page (in points)
    private let paginationThreshold: CGFloat = 800
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        loadTemplates()
        setupCollectionView()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sections = self.loadSectionsFromJSON()
            
            DispatchQueue.main.async {
                self.allSections = sections
                self.dataSource = Array(sections.prefix(self.pageSize))
                self.currentPage = 1
                self.collectionView.reloadData()
                self.setupFooter()
            }
        }
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
        
        for type in [SectionType.horizontal, .grid] {
            collectionView.register(MusicHomeCell.self, forCellWithReuseIdentifier: type.rawValue)
        }
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func setupFooter() {
        let footer = SimpleAutoFooter {}
        footer.isAutomaticallyChangeAlpha = false
        footer.triggerAutomaticallyRefreshPercent = 100
        collectionView.mj_footer = footer
    }
    
    /// 从 music_home_data.json 解析全量 section 数据（同步）
    private func loadSectionsFromJSON() -> [SectionData] {
        guard let jsonDict = loadJSON(named: "music_home_data", inDirectory: "MusicHome"),
              let sectionsArray = jsonDict["sections"] as? [[String: Any]] else {
            print("[MusicHomeDemo] Failed to load music_home_data.json")
            return []
        }
        
        let scale = Int(UIScreen.main.scale)
        
        return sectionsArray.enumerated().compactMap { index, sectionDict -> SectionData? in
            guard let typeStr = sectionDict["type"] as? String,
                  let type = SectionType(jsonValue: typeStr),
                  let title = sectionDict["title"] as? String,
                  let items = sectionDict["items"] as? [[String: Any]] else {
                return nil
            }
            let id = sectionDict["id"] as? String ?? "section_\(index)"
            
            let imagePixelSize: Int = {
                switch type {
                case .horizontal: return 150 * scale
                case .grid:       return 80 * scale
                }
            }()
            let paramSuffix = "?param=\(imagePixelSize)y\(imagePixelSize)"
            
            let processedItems = items.map { item -> [String: Any] in
                guard let coverUrl = item["coverUrl"] as? String,
                      !coverUrl.contains("?param=") else { return item }
                var mutable = item
                mutable["coverUrl"] = coverUrl + paramSuffix
                return mutable
            }
            
            return SectionData(id: id, type: type, title: title, items: processedItems)
        }
    }
    
    // MARK: - Pagination
    
    private func loadNextPage() {
        guard hasMore, !isLoading else { return }
        isLoading = true
        
        let start = currentPage * pageSize
        let end = min(start + pageSize, allSections.count)
        let realSections = Array(allSections[start..<end])
        let width = collectionView.bounds.width
        
        let skeletonStartIndex = dataSource.count
        let skeletonSections = realSections.enumerated().map { i, real in
            let template = real.type == .horizontal ? horizontalTemplate : gridTemplate
            let data: [String: Any] = [
                "section": ["title": real.title, "items": real.items]
            ]
            let height: CGFloat = template.map {
                TemplateXRenderEngine.shared.calculateHeight(
                    json: $0, templateId: real.type.rawValue,
                    data: data, containerWidth: width, useCache: true
                )
            } ?? 210
            
            return SectionData(
                id: "skeleton_\(start + i)",
                type: real.type,
                title: "",
                items: [],
                isSkeleton: true,
                skeletonHeight: height
            )
        }
        dataSource.append(contentsOf: skeletonSections)
        collectionView.reloadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            for i in 0..<realSections.count {
                self.dataSource[skeletonStartIndex + i] = realSections[i]
            }
            self.currentPage += 1
            
            let indexPaths = (0..<realSections.count).map {
                IndexPath(item: skeletonStartIndex + $0, section: 0)
            }
            UIView.performWithoutAnimation {
                self.collectionView.reloadItems(at: indexPaths)
            }
            
            self.isLoading = false
            if !self.hasMore {
                self.collectionView.mj_footer?.endRefreshingWithNoMoreData()
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MusicHomeDemoViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = dataSource[indexPath.item]
        let templateId = section.type.rawValue
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: templateId, for: indexPath) as! MusicHomeCell
        
        if section.isSkeleton {
            cell.showSkeleton()
            return cell
        }
        
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
        
        let width = collectionView.bounds.width
        let height = TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: section.type.rawValue,
            data: data,
            containerWidth: width,
            useCache: true
        )
                
        cell.configure(
            template: template,
            templateId: section.type.rawValue,
            data: data,
            containerWidth: width,
            precomputedHeight: height
        )
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MusicHomeDemoViewController: UICollectionViewDelegateFlowLayout {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let visibleHeight = scrollView.bounds.height
        
        guard contentHeight > 0 else { return }
        
        let distanceToBottom = contentHeight - offsetY - visibleHeight
        if distanceToBottom < paginationThreshold {
            loadNextPage()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let section = dataSource[indexPath.item]
        let width = collectionView.bounds.width
        
        if section.isSkeleton {
            return CGSize(width: width, height: max(section.skeletonHeight, 100))
        }
        
        let template = section.type == .horizontal ? horizontalTemplate : gridTemplate
        
        guard let template = template else {
            return CGSize(width: width, height: 100)
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
            containerWidth: width,
            useCache: true
        )
        
        return CGSize(width: width, height: max(height, 100))
    }
}

// MARK: - SimpleAutoFooter

/// MJRefreshAutoFooter 轻量子类，只有一个 spinner，无状态文本，无 i18n bundle 加载
final class SimpleAutoFooter: MJRefreshAutoFooter {
    
    private let spinner = UIActivityIndicatorView(style: .medium)
    
    override func prepare() {
        super.prepare()
        mj_h = 40
        addSubview(spinner)
        spinner.hidesWhenStopped = true
    }
    
    override func placeSubviews() {
        super.placeSubviews()
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override var state: MJRefreshState {
        didSet {
            switch state {
            case .refreshing:
                spinner.startAnimating()
            default:
                spinner.stopAnimating()
            }
        }
    }
}

