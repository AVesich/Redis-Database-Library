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
        "edit borrower" : Command(maxArgs: 4, handler: editBorrower),
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
        
        return success ? "Borrower added successfully!" : "Adding borrower failed! Make sure a borrower with this username doesn't already exist."
    }
    
    private func removeBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username
        guard args.count == argCount else {
            return nil
        }
        
        let success = await RedisClient.shared.removeObject(withKey: .borrowerKey(for: args[0])) // book-<isbn> is the key
        
        return success ? "Borrower removed successfully!" : "Removing borrower failed!"
    }

    private func editBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username, new name, new user, new phone
        guard args.count == argCount else {
            return nil
        }
        
        let oldUser = args[0]
        let newUser = args[2]
        let newUserExists = await RedisClient.shared.objectExists(withKey: .borrowerKey(for: newUser))
        // Only continue if we don't need a new username or if the new one isn't in use
        if newUserExists && oldUser != newUser {
            return "Borrower with new username already exists."
        }
        
        var success = true
        if oldUser != newUser { // Remove the borrower with the old username if we are changing
            let removeUserSuccess = await RedisClient.shared.removeObject(withKey: .borrowerKey(for: oldUser))
            success = success && removeUserSuccess
        }
        
        let borrower = Borrower(args: Array(args[1...]))
        let storeSuccess = await RedisClient.shared.storeObject(withKey: .borrowerKey(for: newUser), andData: borrower.pairs, changeExisting: oldUser == newUser) // We change the existing only if the user's match. We don't want to overwrite an existing book already using the new isbn
        success = success && storeSuccess // borrower-<new user> is the key
                        
        return success ? "Borrower edited successfully!" : "Editing borrower failed!"
    }
    
    private func borrowedBy(with argCount: Int, and args: [String]) async -> String? { // Args are username
        return ""
    }
    
    private func search(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        return ""
    }
}
