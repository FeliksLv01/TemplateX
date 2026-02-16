import Foundation

// MARK: - TemplateX CLI 编译器

/// 命令行编译器工具
/// 用法: templatex-compiler compile input.xml -o output.json [options]
public struct TemplateXCLI {
    
    // MARK: - 命令
    
    public enum Command {
        case compile(input: String, output: String?, options: CompileOptions)
        case validate(input: String)
        case version
        case help
    }
    
    public struct CompileOptions {
        var minify: Bool = false
        var debug: Bool = false
        var recursive: Bool = false
        var format: OutputFormat = .json
    }
    
    public enum OutputFormat: String {
        case json
        case binary
    }
    
    // MARK: - Main
    
    public static func main(_ arguments: [String]) {
        let cli = TemplateXCLI()
        
        do {
            let command = try cli.parseArguments(arguments)
            try cli.execute(command)
        } catch {
            printError(error.localizedDescription)
            exit(1)
        }
    }
    
    // MARK: - 参数解析
    
    func parseArguments(_ args: [String]) throws -> Command {
        guard args.count > 1 else {
            return .help
        }
        
        let command = args[1]
        
        switch command {
        case "compile":
            return try parseCompileCommand(Array(args.dropFirst(2)))
            
        case "validate":
            guard args.count > 2 else {
                throw CLIError.missingInput
            }
            return .validate(input: args[2])
            
        case "version", "-v", "--version":
            return .version
            
        case "help", "-h", "--help":
            return .help
            
        default:
            // 假设是文件路径，默认编译
            return try parseCompileCommand(Array(args.dropFirst(1)))
        }
    }
    
    func parseCompileCommand(_ args: [String]) throws -> Command {
        guard !args.isEmpty else {
            throw CLIError.missingInput
        }
        
        var input: String?
        var output: String?
        var options = CompileOptions()
        
        var i = 0
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "-o", "--output":
                i += 1
                guard i < args.count else {
                    throw CLIError.missingArgument(arg)
                }
                output = args[i]
                
            case "-m", "--minify":
                options.minify = true
                
            case "-d", "--debug":
                options.debug = true
                
            case "-r", "--recursive":
                options.recursive = true
                
            case "-f", "--format":
                i += 1
                guard i < args.count else {
                    throw CLIError.missingArgument(arg)
                }
                guard let format = OutputFormat(rawValue: args[i]) else {
                    throw CLIError.invalidFormat(args[i])
                }
                options.format = format
                
            default:
                if arg.hasPrefix("-") {
                    throw CLIError.unknownOption(arg)
                }
                input = arg
            }
            
            i += 1
        }
        
        guard let inputPath = input else {
            throw CLIError.missingInput
        }
        
        return .compile(input: inputPath, output: output, options: options)
    }
    
    // MARK: - 执行
    
    func execute(_ command: Command) throws {
        switch command {
        case .compile(let input, let output, let options):
            try executeCompile(input: input, output: output, options: options)
            
        case .validate(let input):
            try executeValidate(input: input)
            
        case .version:
            printVersion()
            
        case .help:
            printHelp()
        }
    }
    
    func executeCompile(input: String, output: String?, options: CompileOptions) throws {
        let inputURL = URL(fileURLWithPath: input)
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: input, isDirectory: &isDirectory) else {
            throw CLIError.fileNotFound(input)
        }
        
        if isDirectory.boolValue {
            // 编译目录
            try compileDirectory(inputURL, output: output, options: options)
        } else {
            // 编译单个文件
            try compileFile(inputURL, output: output, options: options)
        }
    }
    
    func compileFile(_ inputURL: URL, output: String?, options: CompileOptions) throws {
        let compiler = XMLToJSONCompiler()
        compiler.options.minify = options.minify
        compiler.options.debug = options.debug
        
        print("Compiling: \(inputURL.lastPathComponent)")
        
        // 读取输入文件
        let xmlString = try String(contentsOf: inputURL, encoding: .utf8)
        
        // 编译
        let json = try compiler.compile(xmlString)
        
        // 确定输出路径
        let outputURL: URL
        if let output = output {
            outputURL = URL(fileURLWithPath: output)
        } else {
            outputURL = inputURL.deletingPathExtension().appendingPathExtension("json")
        }
        
        // 输出 JSON
        let jsonOptions: JSONSerialization.WritingOptions = options.minify 
            ? [] 
            : [.prettyPrinted, .sortedKeys]
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: jsonOptions)
        try jsonData.write(to: outputURL)
        
        print("Output: \(outputURL.lastPathComponent) (\(jsonData.count) bytes)")
    }
    
    func compileDirectory(_ inputURL: URL, output: String?, options: CompileOptions) throws {
        let fileManager = FileManager.default
        
        // 确定输出目录
        let outputDir: URL
        if let output = output {
            outputDir = URL(fileURLWithPath: output)
        } else {
            outputDir = inputURL.appendingPathComponent("output")
        }
        
        // 创建输出目录
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // 枚举 XML 文件
        let enumerator = fileManager.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options.recursive ? [] : [.skipsSubdirectoryDescendants]
        )
        
        var compiledCount = 0
        var errorCount = 0
        
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "xml" else { continue }
            
            // 计算相对路径
            let relativePath = fileURL.path.replacingOccurrences(of: inputURL.path, with: "")
            var outputPath = outputDir.path + relativePath
            outputPath = outputPath.replacingOccurrences(of: ".xml", with: ".json")
            
            do {
                try compileFile(fileURL, output: outputPath, options: options)
                compiledCount += 1
            } catch {
                Self.printError("Error compiling \(fileURL.lastPathComponent): \(error.localizedDescription)")
                errorCount += 1
            }
        }
        
        print("\nCompiled \(compiledCount) files, \(errorCount) errors")
    }
    
    func executeValidate(input: String) throws {
        let inputURL = URL(fileURLWithPath: input)
        
        print("Validating: \(inputURL.lastPathComponent)")
        
        let xmlString = try String(contentsOf: inputURL, encoding: .utf8)
        let parser = TemplateXMLParser()
        _ = try parser.parse(xmlString)
        
        print("✓ Valid XML")
    }
    
    // MARK: - 输出
    
    func printVersion() {
        print("TemplateX Compiler v1.0.0")
        print("Part of TemplateX DSL Framework")
    }
    
    func printHelp() {
        print("""
        TemplateX Compiler - XML to JSON Template Compiler
        
        USAGE:
            templatex-compiler <command> [options]
        
        COMMANDS:
            compile <input>     Compile XML template to JSON
            validate <input>    Validate XML template syntax
            version             Show version information
            help                Show this help message
        
        OPTIONS:
            -o, --output <path>     Output file or directory
            -m, --minify            Minify output JSON
            -d, --debug             Include debug information
            -r, --recursive         Process directories recursively
            -f, --format <format>   Output format: json (default), binary
        
        EXAMPLES:
            templatex-compiler compile home_card.xml
            templatex-compiler compile home_card.xml -o output.json -m
            templatex-compiler compile ./templates -o ./output -r
            templatex-compiler validate home_card.xml
        
        """)
    }
    
    static func printError(_ message: String) {
        fputs("Error: \(message)\n", stderr)
    }
}

// MARK: - 错误类型

enum CLIError: Error, LocalizedError {
    case missingInput
    case missingArgument(String)
    case unknownOption(String)
    case invalidFormat(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "Missing input file or directory"
        case .missingArgument(let option):
            return "Missing argument for option '\(option)'"
        case .unknownOption(let option):
            return "Unknown option '\(option)'"
        case .invalidFormat(let format):
            return "Invalid format '\(format)'. Use 'json' or 'binary'"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// MARK: - 便捷函数

/// 编译 XML 字符串
public func compileTemplate(_ xml: String, minify: Bool = false) throws -> String {
    let compiler = XMLToJSONCompiler()
    compiler.options.minify = minify
    return try compiler.compileToString(xml)
}

/// 编译 XML 文件
public func compileTemplateFile(_ path: String, output: String? = nil, minify: Bool = false) throws {
    let compiler = XMLToJSONCompiler()
    compiler.options.minify = minify
    
    let inputURL = URL(fileURLWithPath: path)
    let xmlString = try String(contentsOf: inputURL, encoding: .utf8)
    
    let outputURL: URL
    if let output = output {
        outputURL = URL(fileURLWithPath: output)
    } else {
        outputURL = inputURL.deletingPathExtension().appendingPathExtension("json")
    }
    
    try compiler.compile(xmlString, outputURL: outputURL)
}
