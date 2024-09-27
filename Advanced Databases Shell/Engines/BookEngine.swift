//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

import Foundation

struct BookEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal var commands: [String : Command] {[
        "add book" : Command(maxArgs: 4, handler: addBook),
        "rm book" : Command(maxArgs: 1, handler: removeBook),
        "edit book" : Command(maxArgs: 4, handler: editBook),
        "search books" : Command(maxArgs: 2, handler: searchBooks),
        "list books" : Command(maxArgs: 1, handler: listBooks),
        "checkout book" : Command(maxArgs: 2, handler: checkoutBook),
        "borrower of" : Command(maxArgs: 1, handler: borrowerOf)
    ]}
    

    // MARK: - Methods
    public func getResult(for command: String, with args: [String]) async -> String? {
        if !validateCommand(command) {
            return nil
        }
        
        return await commands[command]?.handler(commands[command]!.maxArgs, args)
    }
        
    private func addBook(with argCount: Int, and args: [String]) async -> String? { // Args are name, authors, isbn, # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let book = Book(args: args)
        let success = await RedisClient.shared.storeObject(withName: "book-\(args[args.count-2])", andData: book.pairs) // book-<isbn> is the key
        
        return success ? "Book added successfully!" : "Adding book failed! Make sure this book doesn't already exist."
    }
    
    private func removeBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        return ""
    }

    private func editBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn, new name, new authors, new isbn, new # of pages
        return ""
    }
    
    private func searchBooks(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        return ""
    }
    
    private func listBooks(with argCount: Int, and args: [String]) async -> String? { // Args are sort type
        return ""
    }
    
    private func checkoutBook(with argCount: Int, and args: [String]) async -> String? { // Args are username, book
        return ""
    }

    private func borrowerOf(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        return ""
    }
}
