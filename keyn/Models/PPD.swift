/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct PPD: Codable {
    let characterSets: [PPDCharacterSet]?
    let properties: PPDProperties? // Required. Represents the properties of the password.
    let service: PPDService? // Holds information related to the service the password is used for.
    let version: String? // The current version of the PPD.
    let timestamp: Date? // Timestamp when this PPD was created/updated. It must include the time, the date, and the offset from the UTC time.
    let url: String // Relative path of the webpage where this PPD will be used. Can this be URL?
    let redirect: String?
    let name: String

    func export() {
        do {
            let jsonData = try JSONEncoder().encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            Logger.shared.warning("PPD could not be decoded", error: error)
        }
    }
    
    static func get(id: String, completionHandler: @escaping (_ ppd: PPD?) -> Void) throws {
        API.shared.request(endpoint: .ppd, path: id, parameters: nil, method: .get) { (dict, error) in
            if let error = error {
                Logger.shared.error("PPD retrieval problem.", error: error)
                return
            }

            guard let dict = dict else {
                Logger.shared.warning("PPD not found")
                completionHandler(nil)
                return
            }

            if let ppd = dict["ppds"] as? [Any] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: ppd[0], options: [])
                    let ppd = try JSONDecoder().decode(PPD.self, from: jsonData)
                    completionHandler(ppd)
                } catch {
                    Logger.shared.error("Failed to decode PPD", error: error)
                    completionHandler(nil)
                }
            } else {
                Logger.shared.error("Failed to decode PPD")
                completionHandler(nil)
            }
        }
    }
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
    let positionRestrictions: [PPDPositionRestriction]? // Restriction element used to restrict the allowed characters for a given character position.

    init(characterSetSettings: [PPDCharacterSetSettings]?, requirementGroups: [PPDRequirementGroup]?, positionRestrictions: [PPDPositionRestriction]?) {
        self.characterSetSettings = characterSetSettings ?? [PPDCharacterSetSettings]()
        self.requirementGroups = requirementGroups
        self.positionRestrictions = positionRestrictions
    }
}

struct PPDCharacterSetSettings: Codable {
    let minOccurs: Int? // Minimum password global occurrences of the character set. Omitted for no restrictions on minimum occurences. This includes the complete password even for positions with restrictions.
    let maxOccurs: Int? // Maximum password global occurrences of the character set. Omitted for no restrictions on maximum occurences. This includes the complete password even for positions with restrictions.
    let name: String
}

struct PPDPositionRestriction: Codable {
    let positions: String // Comma separated list of character positions the restriction is applied to. Each position can be a character position starting with 0. Negative character positions can be used to specify the position beginning from the end of the password. A value in the interval (0,1) can be used to specify a position by ratio. E.g. 0.5 refers to the center position of the password.
    let minOccurs: Int // Minimum occurences of the character set for the given positions. A value of 0 means no restrictions of minimum occurences.
    let maxOccurs: Int?
    let characterSet: String

    init(positions: String, minOccurs: Int = 0, maxOccurs: Int?, characterSet: String) {
        self.positions = positions
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
        self.characterSet = characterSet
    }
}

struct PPDRequirementGroup: Codable {
    let minRules: Int // Minimum number of rules that must be fulfilled.
    let requirementRules: [PPDRequirementRule]

    init(minRules: Int = 1, requirementRules: [PPDRequirementRule]) {
        self.minRules = minRules
        self.requirementRules = requirementRules
    }
}

struct PPDRequirementRule: Codable {
    let positions: String? //List of character positions this rule applies to as defined in the PositionRestriction type.
    let minOccurs: Int // Minimum occurrences of the given character set. A value of 0 means no minimum occurrences.
    let maxOccurs: Int? // Maximum occurrences of the given character set. Ommitted for no maximum occurrences.
    let characterSet: String

    init(positions: String?, minOccurs: Int = 0, maxOccurs: Int?, characterSet: String) {
        self.positions = positions
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
        self.characterSet = characterSet
    }
}

// TODO: Complete Service part.

struct PPDService: Codable {
    let login: PPDLogin
    let passwordChange: PPDPasswordChange?
}

struct PPDLogin: Codable {
    let url: String?
}

struct PPDPasswordChange: Codable {
    let url: String?
}

//struct PPDRegister: Codable {
//    let url: String
//}
//
//struct PPDPasswordReset: Codable {
//    let url: String
//    let maxTries: Int
//    let routines: [PPDPasswordResetRoutines]
//}
