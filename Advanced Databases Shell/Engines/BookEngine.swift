//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

// NOTE: - There is not complete error handling here. We track success throughout multi-operation actions to print an accurate response, but undoing failed operations and preventing further mess-ups is out of scope for many operations.

/*
 Explanation:
 Books are stored as hashsets with unique keys. For example, 'book-1' is the key for book with isbn 1 and stores data for that book in the hashset under that key.
 Borrowing relationship is stored in a separate hashset with key 'borrowers'. One entry has the isbn as the subkey and the borrower as the value.
*/

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
        
    // Add the new book if possible, then add the authors if the book was added.
    private func addBook(with argCount: Int, and args: [String]) async -> String? { // Args are name, authors, isbn, # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let book = Book(args: args)
        var success = await RedisClient.shared.storeObject(withKey: .bookKey(for: args[args.count-2]), andData: book.bookPairs) // book-<isbn> is the key
        if success {
            let addIsbnSuccess = await RedisClient.shared.
            for author in book.authors {
                let addAuthorSuccess = await RedisClient.shared.addToArray(author, withKey: "authors-\(args[args.count-2])")
                success = success && addAuthorSuccess
            }
        }
        
        return success ? "Book added successfully!" : "Adding book failed! Make sure this book doesn't already exist."
    }
    
    private func removeBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        guard args.count == argCount else {
            return nil
        }
        
        var success = await RedisClient.shared.removeObject(withKey: .bookKey(for: args[0]))
        let removeAuthorsSuccess =  (await RedisClient.shared.removeObject(withKey: .authorsKey(for: args[0])))
        success = success && removeAuthorsSuccess
        
        if let borrower = await RedisClient.shared.getFromHashSet(withKey: .borrowingKey, andSubKey: args[0]) {
            let removedFromBorrowersListSuccess = (await RedisClient.shared.removeFromHashSet(withKey: .borrowedByKey(for: borrower), andSubKey: args[0]))
            let removedFromBorrowedListSuccess = (await RedisClient.shared.removeFromHashSet(withKey: .borrowingKey, andSubKey: args[0]))
            success = success && removedFromBorrowersListSuccess && removedFromBorrowedListSuccess
        }

        return success ? "Book removed successfully!" : "Removing book failed!"
    }

    private func editBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn, new name, new authors, new # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let bookExists = await RedisClient.shared.objectExists(withKey: .bookKey(for: args[0]))
        // Only continue if we don't need a new isbn or if the new one isn't in use
        if !bookExists {
            return "Book with ISBN \(args[0]) does not exist."
        }
        
        let removeAuthorSuccess = await RedisClient.shared.removeObject(withKey: .authorsKey(for: args[0])) // Authors are removed so we don't need to diff
        var success = removeAuthorSuccess
        
        let book = Book(editArgs: args)
        let storeSuccess = await RedisClient.shared.storeObject(withKey: .bookKey(for: args[0]), andData: book.bookPairs, changeExisting: true) // We change the existing only if the isbn's match. We don't want to overwrite an existing book already using the new isbn
        success = success && storeSuccess
        if success {
            for author in book.authors {
                let addSuccess = await RedisClient.shared.addToArray(author, withKey: .authorsKey(for: args[0]))
                success = success && addSuccess
            }
            if let borrowerUsername = await RedisClient.shared.getFromHashSet(withKey: .borrowingKey, andSubKey: args[0]) {
                let updateBorrowedListSuccess = await RedisClient.shared.addToHashSet((args[0], args[1]), withKey: .borrowedByKey(for: borrowerUsername), changeExisting: true)
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
    
    private func checkoutBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn, username
        guard args.count == argCount else {
            return nil
        }
        
        let isbn = args[0]
        let username = args[1]
        
        // Ensure the user & book both exist
        let bookExists = await RedisClient.shared.objectExists(withKey: .bookKey(for: isbn))
        let userExists = await RedisClient.shared.objectExists(withKey: .borrowerKey(for: username))
        var success = bookExists && userExists // We need both the book & borrower to exist to continue

        if success, let bookName = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "name") {
            // This will, by default, fail if we try to change an existing entry. This is desired so we don't add a borrower to a borrowed book
            let addedToBorrowing = await RedisClient.shared.addToHashSet((isbn, username), withKey: .borrowingKey)
            success = success && addedToBorrowing
            if addedToBorrowing { // Prevent double-counting adding to user's list of borrowed books
                let addedToBorrowersList = await RedisClient.shared.addToHashSet((isbn, bookName), withKey: .borrowedByKey(for: username))
                success = success && addedToBorrowersList
            }
        } else {
            return success ? "Book with isbn \(isbn) cannot be found." : "There was a problem checking out the book. Make sure it exists, the user exists, and the book isn't already checked out."
        }
        
        return success ? "Book with ISBN \(isbn) has been checked out to \(username)" : "There was a problem checking out the book. Make sure it exists, the user exists, and the book isn't already checked out."
    }

    private func borrowerOf(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        guard args.count == argCount else {
            return nil
        }
        
        if let borrower = await RedisClient.shared.getFromHashSet(withKey: .borrowingKey, andSubKey: args[0]) {
            return "\(borrower) is the borrower of the book with ISBN \(args[0])."
        }
        
        return "The borrower for the book with ISBN \(args[0]) cannot be found."
    }
}
