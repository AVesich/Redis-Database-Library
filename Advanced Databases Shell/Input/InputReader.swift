//
//  InputReader.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

import Foundation

struct InputReader {
    
    private var borrowerEngine: BorrowerEngine
    private var bookEngine: BookEngine

    // MARK: - Initialization
    init(borrowerEngine: BorrowerEngine, bookEngine: BookEngine) { // Print instructions
        self.borrowerEngine = borrowerEngine
        self.bookEngine = bookEngine
        
        print("How to use the CLI Libary:")
        
        print("\nBasics ****************************************************************************************")
        print("Quitting:\t\t\t\t \"q\"")
        
        print("\nBooks *****************************************************************************************")
        print("Adding books:\t\t\t\t \"add book <book name> <authors (comma separated)> <ISBN> <# of pages>\"")
        print("Removing books:\t\t\t\t \"rm book <ISBN>\"")
        print("Edit books:\t\t\t\t\t \"edit book <ISBN> <new name> <new authors (comma separated)> <new ISBN (optional)> <# of pages (optional)>\"")
        
        print("\nQuerying Books ********************************************************************************")
        print("Search for books:\t\t\t \"search books <search type (name, author, isbn)> <query>\"")
        print("List all books (sorted):\t \"list books <sort type (name, author, isbn)>\"")
        
        print("\nBorrowing *************************************************************************************")
        print("Add Borrower:\t\t\t\t \"add borrower <name> <username> <phone>\"")
        print("Delete Borrower:\t\t\t \"rm borrower <username>\"")
        print("Edit Borrower:\t\t\t\t \"edit borrower <username> <new name> <new username> <new phone>\"")
        print("Checkout:\t\t\t\t\t \"checkout book <borrower username> <isbn>\"")
        print("View book's borrower:\t\t \"borrower of <isbn>\"")
        print("View # of borrower's books:\t \"borrowed by <username>\"")

        print("\nQuerying Borrowers ****************************************************************************")
        print("Search for borrowers:\t\t \"search borrowers <search type (name, username)> <query>\"\n")
    }
    
    // MARK: - Methods
    // Gets command line input and prints a warning if
    func getInput() -> Bool {
        // Validate input was obtained & we have args beyond the command
        let input = readLine()
        guard input != nil,
              input!.split(separator: " ").count > 2  else {
            if input == "q" {
                return false
            }
            printFail()
            return true
        }
        
        let command = input!.split(separator: " ")[0...1].joined(separator: " ") // Get the first 2 words of the input as the input command
        if !executeCommand(command) {
            printFail()
        }
        
        return true
        
        func printFail() {
            print("Please provide a valid input.\n")
        }
    }
    
    // Tries to execute command, returns success value
    func executeCommand(_ command: String) -> Bool { // Return success
        if command.contains("book") || command == "borrower of" {
            return bookEngine.getResult(for: command) != nil
        } else if command.contains("borrower") || command == "borrowed by" {
            return borrowerEngine.getResult(for: command) != nil
        } else {
            return false
        }
    }
}
