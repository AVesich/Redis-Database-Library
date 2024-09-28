//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

// NOTE: - There is not complete error handling here. We track success throughout multi-operation actions to print an accurate response, but undoing failed operations and preventing further mess-ups is out of scope for many operations.

import Foundation

struct BookEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal var commands: [String : Command] {[
        "add book" : Command(maxArgs: 4, handler: addBook),
        "rm book" : Command(maxArgs: 1, handler: removeBook),
        "edit book" : Command(maxArgs: 5, handler: editBook),
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
        
    // Add the new book if possible, then add the authors if the book was added.
    private func addBook(with argCount: Int, and args: [String]) async -> String? { // Args are name, authors, isbn, # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let book = Book(args: args)
        var success = await RedisClient.shared.storeObject(withKey: "book-\(args[args.count-2])", andData: book.bookPairs) // book-<isbn> is the key
        if success {
            for author in book.authors {
                let addSuccess = await RedisClient.shared.addToArray(author, withKey: "authors-\(args[args.count-2])")
                success = success && addSuccess // author-<isbn> is the authors key
            }
        }
        
        return success ? "Book added successfully!" : "Adding book failed! Make sure this book doesn't already exist."
    }
    
    private func removeBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        guard args.count >= argCount else {
            return nil
        }
        
        let success = await RedisClient.shared.removeObject(withKey: "book-\(args[0])") // book-<isbn> is the key
        
        return success ? "Book removed successfully!" : "Removing book failed!"
    }

    // Check if we can use the new isbn. If so, remove the old book & authors, then add the new book & authors (if new book succeeds)
    private func editBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn, new name, new authors, new isbn, new # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let oldIsbn = args[0]
        let newIsbn = args[args.count-2]
        let newIsbnExists = await RedisClient.shared.objectExists(withKey: "book-\(newIsbn)")
        // Only continue if we don't need a new isbn or if the new one isn't in use
        if newIsbnExists && oldIsbn != newIsbn {
            return "Book with new ISBN already exists."
        }
        
        var success = true
        if oldIsbn != newIsbn { // Remove the book with the old isbn if we are changing
            let removeBookSuccess = await RedisClient.shared.removeObject(withKey: "book-\(args[0])")
            let removeAuthorSuccess =  await RedisClient.shared.removeObject(withKey: "authors-\(args[0])")
            success = success && removeBookSuccess && removeAuthorSuccess
        }
        
        let book = Book(args: Array(args[1...]))
        let storeSuccess = await RedisClient.shared.storeObject(withKey: "book-\(newIsbn)", andData: book.bookPairs, changeExisting: oldIsbn == newIsbn) // We change the existing only if the isbn's match. We don't want to overwrite an existing book already using the new isbn
        success = success && storeSuccess // book-<new isbn> is the key
        if success {
            for author in book.authors {
                let addSuccess = await RedisClient.shared.addToArray(author, withKey: "authors-\(newIsbn)")
                success = success && addSuccess // author-<isbn> is the authors key
            }
        }
                        
        return success ? "Book edited successfully!" : "Editing book failed!"

    }
    
    // TODO: - Search & List should be about the same
    private func searchBooks(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        guard args.count == argCount else {
            return nil
        }
        
        var response = "No results were found."
        
//        switch arg[0] {
//        case "name":
//            break
//        case "author":
//            break
//        case "isbn":
//            break
//        default:
//            response = "Invalid search type, please use 'name', 'author', or 'isbn'."
//        }
        
        return response
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
