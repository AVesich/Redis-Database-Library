//
//  main.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

import Foundation

let borrowerEngine = BorrowerEngine()
let bookEngine = BookEngine()
let inputReader = InputReader(borrowerEngine: borrowerEngine,
                              bookEngine: bookEngine)

// Ping to redis to validate connection
RedisClient.shared.ping()

// getInput returns a bool representing if the app should continue
while (true) {
    let input = await inputReader.getInputAndRespond()
    if !input {
        exit(0)
    }
}
