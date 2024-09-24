//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

struct BorrowerEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal let commands = [
        "add borrower" : 3,
        "rm borrower" : 1,
        "edit borrower" : 4,
        "borrowed by" : 1,
        "search borrowers" : 2
    ]

    // MARK: - Methods
    public func getResult(for command: String) -> String? {
        if !validateCommand(command) {
            return nil
        }
        // TODO: - todo
        return ""
    }
}
