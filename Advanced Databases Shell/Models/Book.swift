//
//  Book.swift
//  Task 1
//
//  Created by Austin Vesich on 9/27/24.
//

struct Book {
    let args: [String]
    
    var pairs: [(String, String)] {
        return [
            ("name", args[0]),
            ("author", args[1]),
            ("isbn", args[args.count-2]), // Use second to last so we can support multiple authors
            ("pages", args.last!) // Use last so we can support multiple authors
        ]
    }
}
