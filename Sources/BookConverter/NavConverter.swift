import Foundation
import Markdown
import SwiftSoup

struct NavConverter {
    let xhtml: String
    
    enum Errors: Error {
        case elementNotFound
    }
    
    struct Item {
        let name: String
        let href: String
    }
    
    struct Section {
        let name: String
        let items: [Item]
    }
    
    func convert() throws -> Markup {
        let sections = try parseSections()
        
        var topics : [BlockMarkup] = [
            Heading(level: 1, SymbolLink(destination: "Swift")),
            Heading(level: 2, Text("Topics"))
        ]
        
        for section in sections {
            
            let children = section.items.map { item in
                ListItem(Paragraph(Link(destination: "doc:\(item.href)", Text(item.name))))
            }
            topics.append(Markdown.Heading(level: 3, Text(section.name)))
            topics.append(UnorderedList(children))
        }
        
        return Document(topics)
        
    }
    
    func parseSections() throws -> [Section] {
        let document = try SwiftSoup.parse(xhtml)
        
        guard let navOL = try document.select("nav ol").first() else {
            throw Errors.elementNotFound
        }
        
        
        
        return try navOL.select(">li").map { section in
            guard let name = try section.select(">a").first()?.text() else {
                throw Errors.elementNotFound
            }
            
            let items = try section.select(">ol>li>a").map { a -> Item in
                let href = try a.attr("href")
                let start = href.index(after: href.lastIndex(of: "/")!)
                
                let ref = href[start ..< href.lastIndex(of: ".")!]
                return Item(name: a.ownText(), href: String(ref))
            }
            
            return Section(name: name, items: items)
        }
    }
    
}
