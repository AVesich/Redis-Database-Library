//
//  Borrower.swift
//  Task 1
//
//  Created by Austin Vesich on 9/27/24.
//

struct Borrower {
    let args: [String]
    
    var pairs: [(String, String)] {
        return [
            ("name", args[0]),
            ("username", args[1]),
            ("phone", args[2])
    ]}
}
