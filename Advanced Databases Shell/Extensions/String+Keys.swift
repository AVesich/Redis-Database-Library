//
//  String+Keys.swift
//  Task 1
//
//  Created by Austin Vesich on 9/28/24.
//

extension String {
    
    static let borrowingKey = "borrowing"

    static func bookKey(for isbn: String) -> String {
        return "book-\(isbn)"
    }
    
    static func authorsKey(for isbn: String) -> String {
        return "authors-\(isbn)"
    }

    static func borrowerKey(for username: String) -> String {
        return "borrower-\(username)"
    }
}
