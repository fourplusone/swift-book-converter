//
//  File.swift
//  
//
//  Created by Matthias Bartelmeß on 12.07.22.
//

import BookConverter
import ArgumentParser


@main
struct CLI : ParsableCommand {
    @Argument
    var rootDirectory: String
    
    @Option
    var output: String = "."
    
    func run() throws {
        try BookConverter.processBook(rootPath: rootDirectory,
                                      outputPath: output)
        
    }
    
}
