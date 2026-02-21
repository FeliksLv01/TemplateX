import UIKit
import TemplateX

/// 网易云音乐风格首页 Demo
/// 演示 TemplateX 在复杂列表场景的能力：
/// - 外层 UICollectionView 垂直滚动
/// - 内层通过 DSL 定义横向滚动列表
/// - 支持分页滚动的网格布局
class MusicHomeDemoViewController: UIViewController {
    
    // MARK: - Types
    
    enum SectionType: String {
        case horizontal = "horizontal_section"
        case grid = "grid_section"
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
    
    /// 模板缓存
    private var horizontalTemplate: [String: Any]?
    private var gridTemplate: [String: Any]?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // 加载模板
        loadTemplates()
        
        // 生成 Mock 数据
        generateMockData()
        
        // 设置 UI
        setupCollectionView()
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
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Mock Data
    
    private func generateMockData() {
        let horizontalTitles = [
            "推荐歌单", "新歌推荐", "热门歌手", "精选专辑",
            "私人FM", "每日推荐", "排行榜", "最新MV"
        ]
        
        let gridTitles = [
            "热门歌曲", "飙升榜", "新歌榜", "原创榜"
        ]
        
        let songTitles = [
            "晴天", "七里香", "稻香", "反方向的钟", "夜曲",
            "青花瓷", "告白气球", "等你下课", "说好不哭", "Mojito",
            "给我一首歌的时间-魔杰座", "以父之名", "夜的第七章", "最伟大的作品",
            "漂移", "本草纲目", "双截棍", "龙卷风", "黑色幽默", "安静",
            "回到过去", "轨迹", "东风破", "发如雪", "菊花台",
            "千里之外", "霍元甲", "红尘客栈", "明明就", "手写的从前"
        ]
        
        var sections: [SectionData] = []
        
        for i in 0..<24 {
            // 每 3 个 section 中有 1 个是网格类型
            let isGrid = i % 3 == 0
            let type: SectionType = isGrid ? .grid : .horizontal
            
            let title = isGrid 
                ? gridTitles[i / 3 % gridTitles.count]
                : horizontalTitles[i % horizontalTitles.count]
            
            // 生成 items
            let itemCount = isGrid ? 9 : 8  // 网格 3x3，横向 8 个
            var items: [[String: Any]] = []
            
            for j in 0..<itemCount {
                let songIndex = (i * 10 + j) % songTitles.count
                
                var item: [String: Any] = [
                    "id": "item_\(i)_\(j)",
                    "title": songTitles[songIndex],
                    "coverUrl": "https://picsum.photos/200/200?random=\(i * 100 + j)"
                ]
                
                // 网格类型需要 subtitle
                if isGrid {
                    item["subtitle"] = "周杰伦"
                }
                
                items.append(item)
            }
            
            sections.append(SectionData(
                id: "section_\(i)",
                type: type,
                title: title,
                items: items
            ))
        }
        
        dataSource = sections
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
