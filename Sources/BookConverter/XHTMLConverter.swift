//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 13.07.22.
//

import Foundation
import SwiftSoup
import Markdown

struct XHTMLConverter {
    let xhtml: String
    private let document : SwiftSoup.Document
    
    enum Errors: Error {
        case bodyNotFound
    }
    
    init(xhtml: String) throws {
        self.xhtml = xhtml
        document = try SwiftSoup.parse(xhtml)
    }
    
    func getAnchors() throws -> [String: String] {
        guard let body = document.body() else {
            throw Errors.bodyNotFound
        }
        
        let sections = try body.select("div.section")
        
        let sectionIDs = try sections.compactMap { section -> (String, String)? in
            if section.hasAttr("id"),
               let headline = section.children().first(),
               ["h2", "h3"].contains(headline.tagName()) {
                
                let text = headline.ownText()
                return (try section.attr("id"), urlReadableFragment(text))
            }
            return nil
        }
        
        return Dictionary(uniqueKeysWithValues: sectionIDs)
    }
    
    func convert(anchors: [String: String]) throws -> Markup {
        guard let body = document.body() else {
            throw Errors.bodyNotFound
        }
        
        let parser = XHTMLParser(anchors: anchors)
        
        guard let mainElement = try body.select("div.body").first() else { throw Errors.bodyNotFound }
        return Markdown.Document(try parser.parseBlock(element: mainElement))
    }
}

private extension CharacterSet {
    static let fragmentCharactersToRemove = CharacterSet.punctuationCharacters // Remove punctuation from fragments
        .union(CharacterSet(charactersIn: "`"))       // Also consider back-ticks as punctuation. They are used as quotes around symbols or other code.
        .subtracting(CharacterSet(charactersIn: "-")) // Don't remove hyphens. They are used as a whitespace replacement.
    static let whitespaceAndDashes = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "-–—")) // hyphen, en dash, em dash
}

/// Creates a more readable version of a fragment by replacing characters that are not allowed in the fragment of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded, which is less readable.
/// For example, a fragment like `"#hello world"` is converted to `"#hello-world"` instead of `"#hello%20world"`.
fileprivate func urlReadableFragment(_ fragment: String) -> String {
    var fragment = fragment
        // Trim leading/trailing whitespace
        .trimmingCharacters(in: .whitespaces)
    
        // Replace continuous whitespace and dashes
        .components(separatedBy: .whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
    
    // Remove invalid characters
    fragment.unicodeScalars.removeAll(where: CharacterSet.fragmentCharactersToRemove.contains)
    
    return fragment
}
