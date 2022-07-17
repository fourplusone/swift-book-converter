import Foundation
import SwiftSoup
import Markdown

struct XHTMLParser {
    
    let anchors: [String: String]
    
    enum Errors: Error {
        case unexpectedTag(Element?)
    }
    
    func parseBlocks(elements: Elements) throws -> [BlockMarkup] {
        return try elements.flatMap{ try parseBlock(element:$0) }
    }
    
    func parseInline(element: Element) throws -> InlineMarkup {
        switch element.tagName() {
        case "a": return try parseLink(element: element)
        case "img": return try parseImage(element: element)
        default: return try parseRecurringInline(element: element)
        }
    }
    
    func parseRecurringInline(element: Element) throws -> InlineMarkup {
        switch element.tagName() {
        case "em": return Emphasis(try parseBlockInner(element: element))
        case "strong": return Strong(try parseBlockInner(element: element))
        case "code": return InlineCode(try element.text())
        case "sup", "span": return InlineHTML(try element.outerHtml())
        default: throw Errors.unexpectedTag(element)
        }
    }
    
    func parseBlockRecurringInner(element: Element) throws -> [RecurringInlineMarkup] {
        let nodes = element.getChildNodes()
        
        var children : [RecurringInlineMarkup] = .init()
        
        for node in nodes {
            if let node = node as? TextNode {
                children.append(Markdown.Text(node.text()))
            } else if let node = node as? Element {
                children.append(contentsOf: try parseBlockRecurringInner(element: node))
            }
        }
        
        return children
    }
    
    func parseBlockInner(element: Element) throws -> [InlineMarkup] {
        let nodes = element.getChildNodes()
        
        var children : [InlineMarkup] = .init()
        
        for node in nodes {
            if let node = node as? TextNode {
                children.append(Markdown.Text(node.text()))
            } else if let node = node as? Element {
                children.append(try parseInline(element: node))
            }
        }
        
        return children
    }
    
    func parseBlock(element: Element) throws -> [BlockMarkup] {
        switch element.tagName() {
        case "h1": return [try parseHeading(level: 1, element: element)]
        case "h2": return [try parseHeading(level: 2, element: element)]
        case "h3": return [try parseHeading(level: 3, element: element)]
        case "h4": return [try parseHeading(level: 4, element: element)]
        case "h5": return [try parseHeading(level: 5, element: element)]
        case "h6": return [try parseHeading(level: 6, element: element)]
        case "ul": return [try parseList(element: element, type: .unordered)]
        case "ol": return [try parseList(element: element, type: .ordered)]
        case "div":
            if element.hasClass("section") || element.hasClass("body") {
                return try parseBlocks(elements: element.children())
            } else if element.hasClass("highlight-swift") {
                let code = try element
                    .select("ol.code-lines li")
                    .map{ try $0.text(trimAndNormaliseWhitespace: false) }
                    .joined()
                return [CodeBlock(language: "swift", code)]
            } else if let firstChild = element.children().first(),
                 firstChild.hasClass("admonition-title") {
                let elements = element.children()[1...]
                var blocks = try elements.flatMap(parseBlock(element:))
                let quote: BlockQuote
                let prefix = firstChild.ownText() + ": "
                
                if var block = blocks.first?.child(through: [
                    (0, Text.self)
                ]) as? Text {
                    block.string = prefix + block.string
                    blocks[blocks.startIndex] = block.parent! as! BlockMarkup
                    quote = BlockQuote(blocks)
                } else {
                    quote = BlockQuote([Paragraph(Text(prefix))] + blocks)
                }
                
                return [quote]
            }
            
            else {
                return [HTMLBlock(try element.html())]
            }
        case "p":
            return [Paragraph(try parseBlockInner(element: element))]
        
        case "table":
            return try [parseTable(element: element)]
        case "dl":
            return try [parseDefinitionList(element: element)]
        default:
            return [Paragraph(try parseInline(element: element))]
        }
    }
}

// MARK: Headings
extension XHTMLParser {
    func parseHeading(level: Int, element: Element) throws -> some BlockMarkup {
        Heading(level: level, try parseBlockInner(element: element))
    }
}

// MARK: Images
extension XHTMLParser {
    func parseImage(element: Element) throws -> InlineMarkup {
        guard let src = URL(string: try element.attr("src")) else {
            return Image()
        }
        
        let baseName = src.deletingPathExtension().lastPathComponent
        
        return Image(source: assetName(for: baseName).name)
    }
}


// MARK: Definition List
extension XHTMLParser {
    func parseDefinitionList(element: Element) throws -> UnorderedList {
        guard element.tagName() == "dl" else { throw Errors.unexpectedTag(element) }
        var iterator =  element.children().makeIterator()
        var listItems : [ListItem] = .init()
        
        while let dt = iterator.next() {
            guard dt.tagName() == "dt" else { throw Errors.unexpectedTag(dt) }
            let term = try parseBlockInner(element: stripParagraph(dt))
            
            guard let dd = iterator.next(), dd.tagName() == "dd" else { throw Errors.unexpectedTag(nil) }
            
            let description = try parseBlocks(elements: dd.children())
            
            let item: ListItem
            
            var termParagraph = Paragraph([Text("term ")] + term + [Text(": ")])
            if let firstP = description.first as? Paragraph {
                
                termParagraph.setInlineChildren(
                    Array(termParagraph.inlineChildren) +
                    Array(firstP.inlineChildren)
                )
                
                item = ListItem([termParagraph] + description[1...])
            } else {
                item = ListItem([termParagraph] + description)
            }
            
            listItems.append(item)
            
        }
        
        
        return UnorderedList(listItems)
    }
}

func stripParagraph(_ element: Element) -> Element {
    let children = element.children()
    if children.count == 1 && children.first()?.tagName() == "p" {
        let inner = children.first()!
        return inner
    } else {
        return element
    }
}

// MARK: Tables
extension XHTMLParser {
    func parseTableCells(element: Element) throws -> [Table.Cell] {
        return try element.children().map { element in
            guard ["td", "th"].contains(element.tagName()) else { throw Errors.unexpectedTag(element) }
            return try Table.Cell(parseBlockInner(element: stripParagraph(element)))
            
        }
    }
    
    func parseTableRow(element: Element) throws -> Table.Row {
        guard element.tagName() == "tr" else { throw Errors.unexpectedTag(element) }
        return try Table.Row(parseTableCells(element: element))
    }
    
    func parseTable(element: Element) throws -> Table {
        
        var head : Table.Head = .init([])
        var body : Table.Body = .init()
        
        for child in element.children() {
            switch child.tagName() {
            case "thead":
                guard let row = child.children().first() else { continue }
                head = .init(try parseTableRow(element: row).cells)
            case "tbody":
                for row in child.children() {
                    body.appendRow(try parseTableRow(element: row))
                }
            default:
                break
            }
        }
        
        return Table(header: head, body: body)
    }
}

// MARK: Lists
extension XHTMLParser {
    enum ListType {
        case ordered
        case unordered
    }
    
    func parseList(element: Element, type: ListType) throws -> BlockMarkup{
        
        let items : [ListItem] = try element.children().map { el  in
            if el.tagName() == "li" {
                return ListItem(try parseBlocks(elements: el.children()))
            } else {
                throw Errors.unexpectedTag(el)
            }
        }
        
        switch type {
        case .ordered:
            return OrderedList(items)
        case .unordered:
            return UnorderedList(items)
        }
    }
}

// MARK: Links
extension XHTMLParser {
    func parseLink(element: Element) throws -> InlineMarkup {
        let href = try element.attr("href")
        let children = try parseBlockRecurringInner(element: element)
        
        if let url = URL(string: href), url.host == nil {
            var component = url.deletingPathExtension().lastPathComponent
            
            if component == "." || component == "" {
                component = "/"
            }
            
            if let fragment = url.fragment, let anchor = anchors[fragment]  {
                
                return Markdown.Link(destination: "doc:\(component)#\(anchor)", children)
            }
            
            return Markdown.Link(destination: "doc:\(component)", children)
        }
        
        return Markdown.Link(destination: href, children)
    }
}
