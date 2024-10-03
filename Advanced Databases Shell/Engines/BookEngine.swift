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
        await getBooksSortedByName()
        
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
        
        let isbn = args[args.count-2]
        let book = Book(args: args)
        let addSuccess = await RedisClient.shared.storeObject(withKey: .bookKey(for: isbn), andData: book.bookPairs) // book-<isbn> is the key
        if addSuccess {
            await addNameReference(args[0], forISBN: isbn)
            await addPageCountReference(args.last!, forISBN: isbn)
            let _ = await RedisClient.shared.addToZSet(isbn, atKey: .isbnKey)
            for author in book.authors {
                let _ = await RedisClient.shared.addToArray(author, withKey: "authors-\(isbn)")
                await addAuthorReference(author, forISBN: isbn)
            }
        }
        
        return addSuccess ? "Book added successfully!" : "Adding book failed! Make sure a book with this isbn doesn't already exist."
    }
    
    private func removeBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn
        guard args.count == argCount else {
            return nil
        }
        
        let isbn = args[0]
        
        if let name = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "name"),
           let numPages = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "pages") {
            await removeNameReference(name, forISBN: isbn)
            await removePageCountReference(numPages, forISBN: isbn)
            
            let authors = await RedisClient.shared.getValuesFromArray(withKey: .authorsKey(for: isbn))
            for author in authors {
                await removeAuthorReference(author, forISBN: isbn)
            }
        }

        let _ = await RedisClient.shared.removeObject(withKey: .bookKey(for: isbn))
        let _ = await RedisClient.shared.removeFromZSet(isbn, withKey: .isbnKey)
        let _ =  await RedisClient.shared.removeObject(withKey: .authorsKey(for: isbn))
                
        if let borrower = await RedisClient.shared.getFromHashSet(withKey: .borrowingKey, andSubKey: isbn) {
            let _ = await RedisClient.shared.removeFromHashSet(withKey: .borrowedByKey(for: borrower), andSubKey: isbn)
            let _ = await RedisClient.shared.removeFromHashSet(withKey: .borrowingKey, andSubKey: isbn)
        }

        return "Book removed successfully!"
    }

    private func editBook(with argCount: Int, and args: [String]) async -> String? { // Args are isbn, new name, new authors, new # of pages
        guard args.count >= argCount else {
            return nil
        }
        
        let isbn = args[0]
        let bookExists = await RedisClient.shared.objectExists(withKey: .bookKey(for: isbn))
        // Only continue if we don't need a new isbn or if the new one isn't in use
        if !bookExists {
            return "Book with ISBN \(isbn) does not exist."
        }
        
        // Remove old data
        if let name = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "name"),
           let numPages = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "pages") {
            await removeNameReference(args[1], forISBN: isbn)
            await removePageCountReference(args.last!, forISBN: isbn)

            let authors = await RedisClient.shared.getValuesFromArray(withKey: .authorsKey(for: isbn))
            for author in authors {
                await removeAuthorReference(author, forISBN: isbn)
            }
        }
        let _ = await RedisClient.shared.removeObject(withKey: .authorsKey(for: isbn)) // Authors are removed so we don't need to diff
                
        // Edit/Re-add data
        let book = Book(editArgs: args)
        let editSuccess = await RedisClient.shared.storeObject(withKey: .bookKey(for: isbn), andData: book.bookPairs, changeExisting: true) // We change the existing only if the isbn's match. We don't want to overwrite an existing book already using the new isbn
        if editSuccess {
            await addNameReference(args[1], forISBN: isbn)
            await addPageCountReference(args.last!, forISBN: isbn)
            for author in book.authors {
                let _ = await RedisClient.shared.addToArray(author, withKey: "authors-\(isbn)")
                await addAuthorReference(author, forISBN: isbn)
            }
            
            // Update borrowed
            if let borrowerUsername = await RedisClient.shared.getFromHashSet(withKey: .borrowingKey, andSubKey: isbn) {
                let _ = await RedisClient.shared.addToHashSet((isbn, args[1]), withKey: .borrowedByKey(for: borrowerUsername), changeExisting: true)
            }
        }
                        
        return "Book edited successfully!"
    }
    
    // TODO: - Search & List should be about the same
    private func searchBooks(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        guard args.count == argCount else {
            return nil
        }
        
        let query = args[1]
        
        switch args[0] {
        case "name":
            return await getBooksStoredAtKey(.booksWithNameKey(for: query)) ?? "No books with name \(query) were found."
        case "author":
            return await getBooksStoredAtKey(.booksByAuthorKey(for: query)) ?? "No books by author \(query) were found."
        case "isbn":
            if await RedisClient.shared.objectExists(withKey: .bookKey(for: query)) { // Check if the book exists
                return await printBookWithISBN(query)
            }
            return "Book with isbn \(query) not found."
        default:
            return "Invalid search type, please use 'name', 'author', or 'isbn'."
        }
    }
    
    private func listBooks(with argCount: Int, and args: [String]) async -> String? { // Args are sort type
        guard args.count == argCount else {
            return nil
        }
                
        switch args[0] {
        case "name":
            return await getBooksSortedByName()
        case "author":
            return await getBooksSortedByAuthor()
        case "page count":
            return await getBooksSortedByPageCount()
        case "isbn":
            return await getBooksSortedByISBN()
        default:
            return "Invalid search type, please use 'name', 'author', 'page count', or 'isbn'."
        }

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
        let bookAndUserFound = bookExists && userExists // We need both the book & borrower to exist to continue

        if bookAndUserFound, let bookName = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "name") {
            // This will, by default, fail if we try to change an existing entry. This is desired so we don't add a borrower to a borrowed book
            let addedToBorrowing = await RedisClient.shared.addToHashSet((isbn, username), withKey: .borrowingKey)
            if addedToBorrowing { // Prevent double-counting adding to user's list of borrowed books
                let _ = await RedisClient.shared.addToHashSet((isbn, bookName), withKey: .borrowedByKey(for: username))
            } else {
                return "There was a problem checking out the book. Make sure the book isn't already checked out."
            }
        } else {
            return "There was a problem checking out the book. Make sure it exists, the user exists, and the book isn't already checked out."
        }
        
        return "Book with ISBN \(isbn) has been checked out to \(username)"
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
    
    // MARK: - Helpers
    private func getBooksSortedByName() async -> String {
        let bookNames = await RedisClient.shared.getSortedZSetValues(atKey: .bookNamesKey)

        var result = ""
        for name in bookNames {
            let isbns = await RedisClient.shared.getValuesFromSet(withKey: .booksWithNameKey(for: name))
            for isbn in isbns {
                let bookText = await printBookWithISBN(isbn)
                result.append("\(bookText)\n")
            }
        }
                
        return (result != "") ? result : "No books found."
    }
        
    private func getBooksSortedByAuthor() async -> String {
        let authors = await RedisClient.shared.getSortedZSetValues(atKey: .authorsKey)

        var result = ""
        for author in authors {
            result.append("\nAuthor: \(author)\n")
            let isbns = await RedisClient.shared.getValuesFromSet(withKey: .booksByAuthorKey(for: author))
            for isbn in isbns {
                let bookText = await printBookWithISBN(isbn)
                result.append("\(bookText)\n")
            }
        }
                
        return (result != "") ? result : "No books found."
    }

    
    private func getBooksSortedByPageCount() async -> String {
        let pageCounts = await RedisClient.shared.getSortedZSetValues(atKey: .pageCountsKey)

        var result = ""
        for pageCount in pageCounts {
            result.append("\nPage count: \(pageCount)\n")
            let isbns = await RedisClient.shared.getValuesFromSet(withKey: .booksByPagesKey(for: pageCount))
            for isbn in isbns {
                let bookText = await printBookWithISBN(isbn)
                result.append("\(bookText)\n")
            }
        }
                
        return (result != "") ? result : "No books found."
    }
    
    private func getBooksSortedByISBN() async -> String {
        let isbns = await RedisClient.shared.getSortedZSetValues(atKey: .isbnKey)

        var result = ""
        for isbn in isbns {
            let bookText = await printBookWithISBN(isbn)
            result.append("\(bookText)\n")
        }
        
        return result
    }
    
    private func getBooksStoredAtKey(_ key: String) async -> String? {
        let booksWithName = await RedisClient.shared.getValuesFromSet(withKey: key)
        
        if booksWithName.isEmpty {
            return nil
        }
        
        var result = ""
        for isbn in booksWithName {
            let bookText = await printBookWithISBN(isbn)
            result.append("\(bookText)\n")
        }
        return result
    }
    
    private func printBookWithISBN(_ isbn: String) async -> String {
        let name = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "name")
        let bookIsbn = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "isbn")
        let authors = await RedisClient.shared.getValuesFromArray(withKey: .authorsKey(for: isbn))
        let numPages = await RedisClient.shared.getFromHashSet(withKey: .bookKey(for: isbn), andSubKey: "pages")
        return "\(name!), \(bookIsbn!), \(authors.isEmpty ? "No authors" : authors.joined(separator: ", ")), \(numPages!)"
    }
    
    // MARK: - Reference counting helpers
    private func addNameReference(_ name: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.addToSet(isbn, atKey: .booksWithNameKey(for: name))
        let _ = await RedisClient.shared.addToZSet(name, atKey: .bookNamesKey)
    }
    
    private func removeNameReference(_ name: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.removeFromSet(isbn, atKey: .booksWithNameKey(for: name))
        
        let nameCount = await RedisClient.shared.getSetSize(withKey: .booksWithNameKey(for: name))
        if nameCount <= 0 { // If no references, remove the name from the list used for searching
            let _ = await RedisClient.shared.removeFromZSet(name, withKey: .bookNamesKey)
        }
    }
    
    private func addPageCountReference(_ pageCount: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.addToSet(isbn, atKey: .booksByPagesKey(for: pageCount))
        let _ = await RedisClient.shared.addToZSet(pageCount, atKey: .pageCountsKey)
    }
    
    private func removePageCountReference(_ pageCount: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.removeFromSet(isbn, atKey: .booksByPagesKey(for: pageCount))
        
        let pageNumCount = await RedisClient.shared.getSetSize(withKey: .booksByPagesKey(for: pageCount))
        if pageNumCount <= 0 { // If no references, remove the name from the list used for searching
            let _ = await RedisClient.shared.removeFromZSet(pageCount, withKey: .pageCountsKey)
        }
    }
    
    private func addAuthorReference(_ authorName: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.addToSet(isbn, atKey: .booksByAuthorKey(for: authorName))
        let _ = await RedisClient.shared.addToZSet(authorName, atKey: .authorsKey)
    }
    
    private func removeAuthorReference(_ authorName: String, forISBN isbn: String) async {
        let _ = await RedisClient.shared.removeFromSet(isbn, atKey: .booksByAuthorKey(for: authorName))
        
        let authorBooksCount = await RedisClient.shared.getSetSize(withKey: .booksByAuthorKey(for: authorName))
        if authorBooksCount <= 0 { // If no references, remove the name from the list used for searching
            let _ = await RedisClient.shared.removeFromZSet(authorName, withKey: .authorsKey)
        }
    }
}

/*
 Zset of book names for lexical sorting
 Set of isbns stored for each book name
 
 Zset of page counts for lexical sorting
 Set of isbns stored for each page count
 
 Zset of isbs for lexical sorting
 */
