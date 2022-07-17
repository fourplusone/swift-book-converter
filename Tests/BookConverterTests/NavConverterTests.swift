import XCTest
@testable import BookConverter

final class NavConverterTests: XCTestCase {
    func testParseNav() throws {
        let rootURL = Bundle.module.url(forResource: "SwiftBook", withExtension: nil)!
        let url = rootURL.appendingPathComponent("nav.xhtml")
        
        let converter = NavConverter(xhtml: try String(contentsOf: url))
        let content = try converter.parseSections()
        
        XCTAssertEqual(content.first?.name, "Welcome to Swift")
        XCTAssertEqual(content.first?.items.first?.name, "About Swift")
        XCTAssertEqual(content.first?.items.first?.href, "AboutSwift")
    }
}
