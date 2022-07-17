import XCTest
import SwiftSoup
import Markdown

@testable import BookConverter

final class BookConverterTests: XCTestCase {
    func testParseContent() throws {
        let rootURL = Bundle.module.url(forResource: "SwiftBook", withExtension: nil)!
        let converter = BookConverter(rootDirectory: rootURL, outputDirectory: rootURL)
        let content = try converter.parseContent()
        
        XCTAssertEqual(content.first, "GuidedTour/GuidedTourPart.xhtml")
        XCTAssertEqual(content.last, "Trademarks.xhtml")
    }
    
    func testGuidedTour() throws {
        let rootURL = Bundle.module.url(forResource: "SwiftBook", withExtension: nil)!
        let url = rootURL.appendingPathComponent("GuidedTour/GuidedTour.xhtml")
        let converter = try XHTMLConverter(xhtml: try String(contentsOf: url))
        // Just test, whether conversion doens't throw any errors
        let _ = try converter.convert(anchors: [:])
    }
    
    func testAnchors() throws {
        let rootURL = Bundle.module.url(forResource: "SwiftBook", withExtension: nil)!
        let url = rootURL.appendingPathComponent("GuidedTour/GuidedTour.xhtml")
        let converter = try XHTMLConverter(xhtml: try String(contentsOf: url))
        XCTAssertEqual(try converter.getAnchors()["ID461"], "Simple-Values")
    }
    
    
    func testLinks() throws {
        let html = """
<a href="foo.xhtml#bar">Demo</a>
"""
        let parser = XHTMLParser(anchors: ["bar":"demo"])
        let document = try SwiftSoup.parse(html)
       
        let element = try document.select("a").first()!
        let result = try parser.parseInline(element: element) as? Link
        XCTAssertEqual(result?.destination, "doc:foo#demo")
    }
    
    func testLinksSameDoc() throws {
        let html = """
<a href="#bar">Demo</a>
"""
        let parser = XHTMLParser(anchors: ["bar":"demo"])
        let document = try SwiftSoup.parse(html)
       
        let element = try document.select("a").first()!
        let result = try parser.parseInline(element: element) as? Link
        XCTAssertEqual(result?.destination, "doc:/#demo")
    }
    
    func testImg() throws {
        let html = """
<img alt="../_images/img_2x.png" class="align-center" src="../_images/img_2x.png" style="width: 330.0px;">
"""
        let parser = XHTMLParser(anchors: [:])
        let document = try SwiftSoup.parse(html)
       
        let element = try document.select("img").first()!
        let result = try parser.parseInline(element: element) as? Image
        
        
        XCTAssertEqual(result?.source, "img")
    }
}
