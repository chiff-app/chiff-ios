//
//  PPD.swift
//  keyn
//
//  Created by bas on 14/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

struct PPD: Codable {
    let characterSets: [PPDCharacterSet]?
    let properties: PPDProperties? // Required. Represents the properties of the password.
    //let service: PPDService // Holds information related to the service the password is used for. This should be added later
    let version: String? // The current version of the PPD.
    let timestamp: Date? // Timestamp when this PPD was created/updated. It must include the time, the date, and the offset from the UTC time.
    let url: String // Relative path of the webpage where this PPD will be used. Can this be URL?
    let redirect: String?
    let name: String?
}

struct PPDCharacterSet: Codable {
    let base: [String]? // Reference to an already defined character set. All characters from the character set referenced by this element will be added to the character set this element is a child of.
    let characters: String? // String containing all characters that will be added to the character set.
    let name: String
}

struct PPDProperties: Codable {
    let characterSettings: PPDCharacterSettings? // Parent node for character settings. If the node is omitted, all characters defined in the characterSets element are treated as available for use with no restrictions on minimum and maximum ocurrences.
    let maxConsecutive: Int? // Indicates whether consecutive characters are allowed or not. A omitted value or 0 inidaces no limitation on consecutive characters.
    let minLength: Int? // Minimum length of the password.
    let maxLength: Int? // Maximum length of the password. A value of 0 means no maximum length.
    let expires: Int = 0 // Password expiry in days. A value of 0 means no expiry.
}

struct PPDCharacterSettings: Codable {
    let characterSetSettings: [PPDCharacterSetSettings] // Settings element for a globally available character set.
    let requirementGroups: [PPDRequirementGroup]? // Character sets specified in the requirement groups are implicitly added to the available character sets for the given position (or all position if no positions are specified) if they were not allowed previously.
    let positionRestrictions: [PPDPositionRestrictions]? // Restriction element used to restrict the allowed characters for a given character position.
}

struct PPDCharacterSetSettings: Codable {
    let minOccurs: Int? // Minimum password global occurrences of the character set. Omitted for no restrictions on minimum occurences. This includes the complete password even for positions with restrictions.
    let maxOccurs: Int? // Maximum password global occurrences of the character set. Omitted for no restrictions on maximum occurences. This includes the complete password even for positions with restrictions.
    let name: String
}

struct PPDPositionRestrictions: Codable {
    let positions: String // Comma separated list of character positions the restriction is applied to. Each position can be a character position starting with 0. Negative character positions can be used to specify the position beginning from the end of the password. A value in the interval (0,1) can be used to specify a position by ratio. E.g. 0.5 refers to the center position of the password.
    let minOccurs: Int = 0 // Minimum occurences of the character set for the given positions. A value of 0 means no restrictions of minimum occurences.
    let maxOccurs: Int?
    let characterSet: String
}

struct PPDRequirementGroup: Codable {
    let minRules: Int = 1 // Minimum number of rules that must be fulfilled.
    let requirementRules: [PPDRequirementRule]
}

struct PPDRequirementRule: Codable {
    let minOccurs: Int = 0 // Minimum occurrences of the given character set. A value of 0 means no minimum occurrences.
    let maxOccurs: Int? // Maximum occurrences of the given character set. Ommitted for no maximum occurrences.
    let positions: String? //List of character positions this rule applies to as defined in the PositionRestriction type.
}

// TODO: Complete Service part. Perhaps first implement in JS?

//struct PPDService: Codable {
//    let login: PPDLogin
//    let register: PPDRegister
//    let passwordChange: PPDPasswordChange
//    let passwordReset: PPDPasswordReset
//}
//
//struct PPDLogin: Codable {
//    let url: String // Can this be URL?
//    let maxTries: Int
//    let routines: [PPDBaseRoutine]
//}
//
//struct PPDRegister: Codable {
//    let url: String
//}
//
//struct PPDPasswordChange: Codable {
//    let url: String
//    let maxTries: Int
//    let routines: [PPDBaseRoutine]
//}
//
//struct PPDPasswordReset: Codable {
//    let url: String
//    let maxTries: Int
//    let routines: [PPDPasswordResetRoutines]
//}







