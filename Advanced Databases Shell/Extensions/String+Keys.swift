//
//  String+Keys.swift
//  Task 1
//
//  Created by Austin Vesich on 9/28/24.
//

extension String {
    
    static let isbnKey = "isbns"
    static let borrowingKey = "borrowing"
    static let usernamesKey = "usernames"

    static func bookKey(for isbn: String) -> String {
        return "book-\(isbn)"
    }
    
    static func authorsKey(for isbn: String) -> String {
        return "authors-\(isbn)"
    }

    static func borrowerKey(for username: String) -> String {
        return "borrower-\(username)"
    }
    
    static func borrowedByKey(for username: String) -> String {
        return "borrowed-by-\(username)"
    }
    
    static func usernamesKey(for name: String) -> String {
        return "usernames-\(name)"
    }
    
    static func booksWithNameKey(for name: String) -> String {
        return "books-named-\(name)"
    }
    
    static func booksByAuthorKey(for author: String) -> String {
        return "books-by-\(author)"
    }

    static func booksByPagesKey(for numPages: String) -> String {
        return "books-with-\(numPages)-pages"
    }
}
