//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

import Foundation

struct BorrowerEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal var commands: [String: Command] {[
        "add borrower" : Command(maxArgs: 3, handler: addBorrower),
        "rm borrower" : Command(maxArgs: 1, handler: removeBorrower),
        "edit borrower" : Command(maxArgs: 3, handler: editBorrower),
        "borrowed by" : Command(maxArgs: 1, handler: borrowedBy),
        "search borrowers" : Command(maxArgs: 2, handler: search)
    ]}

    // MARK: - Methods
    public func getResult(for command: String, with args: [String]) async -> String? {
        if !validateCommand(command) {
            return nil
        }

        return await commands[command]?.handler(commands[command]!.maxArgs, args)
    }
    
    private func addBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are name, username, phone
        guard args.count == argCount else {
            return nil
        }
        
        let borrower = Borrower(args: args)
        let success = await RedisClient.shared.storeObject(withKey: .borrowerKey(for: args[1]), andData: borrower.pairs) // borrower-<username> is the key
        
        // new
        let _ = await RedisClient.shared.addToSet(args[1], atKey: .usernamesKey(for: args[0]))
        
        return success ? "Borrower added successfully!" : "Adding borrower failed! Make sure a borrower with this username doesn't already exist."
    }
    
    private func removeBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username
        guard args.count == argCount else {
            return nil
        }
        
        var success = true
        if let name = await RedisClient.shared.getFromHashSet(withKey: .borrowerKey(for: args[0]), andSubKey: "name") {
            let removeUsernameSuccess = await RedisClient.shared.removeFromSet(args[0], atKey: .usernamesKey(for: name))
            success = success && removeUsernameSuccess
        }
        
        let removalSuccess = await RedisClient.shared.removeObject(withKey: .borrowerKey(for: args[0]))
        success = success && removalSuccess

        // "return" books
        let borrowedBooks = await RedisClient.shared.getAllKeysFromHashSet(withKey: .borrowedByKey(for: args[0]))
        for isbn in borrowedBooks {
            let returnedBookSucceeded = await RedisClient.shared.removeFromHashSet(withKey: .borrowingKey, andSubKey: isbn)
            success = success && returnedBookSucceeded
        }
        if success { // Only remove the list of books this borrower has borrowed if we succeeded at checking out each book. That way in case of a failure we can continuously rerun without any issues
            let removeBorrowedListSuccess = await RedisClient.shared.removeObject(withKey: .borrowedByKey(for: args[0]))
            success = success && removeBorrowedListSuccess
        }
                
        return success ? "Borrower removed successfully!" : "Removing borrower failed!"
    }

    private func editBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username, new name, new phone
        guard args.count == argCount else {
            return nil
        }
        
        let userExists = await RedisClient.shared.objectExists(withKey: .borrowerKey(for: args[0]))
        // Only continue if we don't need a new username or if the new one isn't in use
        if !userExists {
            return "Borrower with username \(args[0]) does not exist."
        }
        
        let _ = await RedisClient.shared.addToSet(args[0], atKey: .usernamesKey(for: args[1])) // Add the username to the new name's username set
        if let name = await RedisClient.shared.getFromHashSet(withKey: .borrowerKey(for: args[0]), andSubKey: "name") { // Get existing name
            let _ = await RedisClient.shared.removeFromSet(args[0], atKey: .usernamesKey(for: name))
        }
        
        let borrower = Borrower(args: [args[1], args[0], args[2]]) // Swap user and new name
        let success = await RedisClient.shared.storeObject(withKey: .borrowerKey(for: args[0]), andData: borrower.pairs, changeExisting: true)
                        
        return success ? "Borrower edited successfully!" : "Editing borrower failed!"
    }
    
    private func borrowedBy(with argCount: Int, and args: [String]) async -> String? { // Args are username
        guard args.count == argCount else {
            return nil
        }
        
        let username = args[0]
        let books = await RedisClient.shared.getAllValuesFromHashSet(withKey: .borrowedByKey(for: username))
        
        return (books.count > 0) ? "Books checkout out by \(username): \(books.joined(separator: ", "))" : "No books found for the borrower with username \(username)."
    }
    
    private func search(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        guard args.count == argCount else {
            return nil
        }
        
        let searchType = args[0]
        let query = args[1]
        
        if searchType == "name" {
            return await printUsernamesForName(query)
        } else if searchType == "username" {
            if await RedisClient.shared.objectExists(withKey: .borrowerKey(for: query)) { // Check if the user exists
                return await printBorrowerWithUsername(query)
            }
            return "User with username \(query) not found."
        }
        
        return "Invalid search type entered. Please use 'name' or 'username'."
    }
    
    // MARK: - Helpers
    private func printUsernamesForName(_ name: String) async -> String {
        let usernames = await RedisClient.shared.getValuesFromSet(withKey: .usernamesKey(for: name))
        
        if usernames.isEmpty {
            return "No usernames found for name \(name)."
        }
        
        var result = ""
        for username in usernames {
            let borrowerText = await printBorrowerWithUsername(username)
            result.append("\(borrowerText)\n")
        }
        return result
    }
    
    private func printBorrowerWithUsername(_ username: String) async -> String {
        let name = await RedisClient.shared.getFromHashSet(withKey: .borrowerKey(for: username), andSubKey: "name")
        let user = await RedisClient.shared.getFromHashSet(withKey: .borrowerKey(for: username), andSubKey: "username")
        let phone = await RedisClient.shared.getFromHashSet(withKey: .borrowerKey(for: username), andSubKey: "phone")
        return "\(name!), \(user!), \(phone!)"
    }
}
