/*
 * Example of keypair generation. Will only work on phone so it seems.
 */
import UIKit

let chars = [Character]("abcdefghijklmnopqrstuvwxyzABCDED")
let y = chars.count
let r = 2123
let p = chars.index(of: "a")! // This is now calculated in f()
//let x = p - (r % y) // Offset needs be calculated AFTER random values are generated.
let x = 0
print(chars[(r + x) % y])

