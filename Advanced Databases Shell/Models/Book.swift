//
//  Book.swift
//  Task 1
//
//  Created by Austin Vesich on 9/27/24.
//

struct Book {
    let args: [String]
    
    var bookPairs: [(String, String)] {
        return [
            ("name", args[0]),
            ("isbn", args[args.count-2]), // Use second to last so we can support multiple authors
            ("pages", args.last!) // Use last so we can support multiple authors
        ]
    }
    
    var authors: [String] {
        Array(args[1..<args.count-2])
    }
    
    init(args: [String]) {
        self.args = args
    }
    
    init(editArgs: [String]) { // When editing, isbn is the first arg. Here, we reorder the args to be name, authors, isbn, pages
        let isbn = editArgs.first!
        var afterFirst = editArgs.dropFirst()
        afterFirst.insert(isbn, at: afterFirst.count)
        self.args = Array(afterFirst)
    }
}
