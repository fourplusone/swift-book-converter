import SwiftSoup
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

func assetName(for baseName: String) -> (name: String, isHiRes:Bool) {
    let components = baseName.split(separator: "_")
    if components.last == "2x" {
        return (components.dropLast().joined(separator: "_"), true)
    } else {
        return (components.joined(separator: "_"), false)
    }
}

public struct BookConverter {
    
    let rootDirectory: URL
    let outputDirectory: URL
    
    private var imagesDirectory : URL {
        rootDirectory.appendingPathComponent("_images")
    }
    
    private var outputAssetsDirectory : URL {
        outputDirectory.appendingPathComponent("Assets")
    }
    
    private var outputInfoPlist : URL {
        outputDirectory.appendingPathComponent("Info.plist")
    }
    
    private var outputDocumentationSymbolsJson : URL {
        outputDirectory.appendingPathComponent("Documentation.symbols.json")
    }
    
    
    enum Errors : Error {
        case parseContent(message: String)
    }
    
    func processBook() throws {
        
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputAssetsDirectory, withIntermediateDirectories: true)
        
        try createStaticFiles()
        try copyAssets()
        
        try processNav()
        
        let chapters = try parseContent()
        
        let anchorDicts = try chapters.map { try converter(for: $0).getAnchors() }
        var anchors = [String: String]()
        for anchorDict in anchorDicts {
            anchors.merge(anchorDict, uniquingKeysWith: { current, _ in current })
        }
        
        for chapter in chapters {
            try processChapter(path: chapter, anchors: anchors)
        }
    }
    
    private func converter(for chapter: String) throws -> XHTMLConverter{
        let url = rootDirectory.appendingPathComponent(chapter)
        return try XHTMLConverter(xhtml: try String(contentsOf: url))
        
    }
    
    func createStaticFiles() throws {
        try """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CDDefaultModuleKind</key>
    <string>Programming Language</string>
</dict>
</plist>
""".write(to: outputInfoPlist, atomically: false, encoding: .utf8)
        
    try """
{"metadata":{"formatVersion":{"major":0,"minor":5,"patch":3},"generator":"Apple Swift version 5.6.1 (swiftlang-5.6.0.323.66 clang-1316.0.20.12)"},"module":{"name":"Swift","platform":{"architecture":"arm64","vendor":"apple"}},"symbols":[],"relationships":[]}
""".write(to: outputDocumentationSymbolsJson, atomically: false, encoding: .utf8)
    
    }
    
    func copyAssets() throws {
        let images = try FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
        
        for image in images {
            
            let (assetName, isHiRes) = assetName(for: image.deletingPathExtension().lastPathComponent)
            
            let destination = outputAssetsDirectory
                .appendingPathComponent(assetName + (isHiRes ? "@2x" : ""))
                .appendingPathExtension(image.pathExtension)
            
            try FileManager.default.copyItem(at: image, to: destination)
        }
    }
    
    func processNav() throws {
        let url = rootDirectory.appendingPathComponent("nav.xhtml")
        let outputURL = outputDirectory.appendingPathComponent("SwiftBook.md")
        
        
        let converter = NavConverter(xhtml: try String(contentsOf: url))
        let markup = try converter.convert()
        
        let data = markup.format().data(using: .utf8)!
        try data.write(to: outputURL)
    }
    
    func parseContent() throws -> [String] {
        return try BookConverter.parseContent(url: rootDirectory.appendingPathComponent("content.opf"))
    }
    
    static func parseContent(url: URL) throws -> [String] {
        
        let document = try XMLDocument(contentsOf: url)
        
        guard let root = document.rootElement() else {
            throw Errors.parseContent(message: "Root not found")
        }
        
        guard let manifest = root.elements(forName: "manifest").first else {
            throw Errors.parseContent(message: "<manifest> not found")
        }
        
        guard let spine = root.elements(forName: "spine").first else {
            throw Errors.parseContent(message: "<spine> not found")
        }
        
        let manifestItems = Dictionary<String, String>(uniqueKeysWithValues: manifest.elements(forName: "item").compactMap { item in
            guard let id = item.attribute(forName: "id")?.stringValue else { return nil }
            guard let href = item.attribute(forName: "href")?.stringValue else { return nil }
            
            return (id, href)
        })
        
        return spine.elements(forName: "itemref").compactMap { itemref in
            guard let idref = itemref.attribute(forName: "idref")?.stringValue else { return nil }
            return manifestItems[idref]
        }
    }
    
    func processChapter(path: String, anchors: [String: String]) throws {
        let url = rootDirectory.appendingPathComponent(path)
        let outputURL = outputDirectory
            .appendingPathComponent(url.lastPathComponent)
            .deletingPathExtension()
            .appendingPathExtension("md")
        
        
        let converter = try converter(for: path)
        let markup = try converter.convert(anchors: anchors)
        
        let data = markup.format().data(using: .utf8)!
        try data.write(to: outputURL)
        
    }
    
    public static func processBook(rootPath: String, outputPath: String) throws {
        let converter = BookConverter(
            rootDirectory: URL(fileURLWithPath: rootPath),
            outputDirectory: URL(fileURLWithPath: outputPath)
        )
        try converter.processBook()
    }
}
