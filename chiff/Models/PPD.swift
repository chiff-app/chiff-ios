//
//  PPD.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

enum PPDBaseCharacterSet: String, Codable {
    case upperLetters = "UpperLetters"
    case lowerLetters = "LowerLetters"
    case letters = "Letters"
    case numbers = "Numbers"
    case specials = "Specials"
    case spaces = "Spaces"

    var characters: String {
        switch self {
        case .upperLetters: return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        case .lowerLetters: return "abcdefghijklmnopqrstuvwxyz"
        case .letters: return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        case .numbers: return "0123456789"
        case .specials: return "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
        case .spaces: return " "
        }
    }
}

enum PPDVersion: String, Codable {
    case v1_0 = "1.0"
    case v1_1 = "1.1"
}

struct PPD: Codable {
    let characterSets: [PPDCharacterSet]?
    /// Required. Represents the properties of the password.
    let properties: PPDProperties?
    /// Holds information related to the service the password is used for.
    let service: PPDService?
    /// The current version of the PPD.
    let version: PPDVersion
    /// Timestamp when this PPD was created/updated.
    let timestamp: Int?
    /// URL of the webpage where this PPD will be used.
    let url: String
    let redirect: String?
    let name: String

    /// Get a PPD for site ID. Return nil if there is not PPD for this site ID.
    /// - Parameters:
    ///   - id: The site ID.
    ///   - organisationKeyPair: Optionnally, an organisation keypair if organisational PPDs should be checked as well.
    /// - Returns: A PPD, if it exists.
    static func get(id: String, organisationKeyPair: KeyPair?) -> Guarantee<PPD?> {
        let parameters = ["v": PPDVersion.v1_1.rawValue]
        return firstly { () -> Promise<JSONObject> in
            if let keyPair = organisationKeyPair {
                return API.shared.signedRequest(path: "organisations/\(keyPair.pubKey.base64)/ppd/\(id)", method: .get, privKey: keyPair.privKey, message: ["id": id], parameters: parameters)
            } else {
                return API.shared.request(path: "ppd/\(id)", method: .get, parameters: parameters)
            }
        }.then { result -> Guarantee<PPD?> in
            guard let ppdData = result["ppds"] as? [Any] else {
                Logger.shared.error("Failed to decode PPD")
                return .value(nil)
            }
            let jsonData = try JSONSerialization.data(withJSONObject: ppdData[0], options: [])
            let ppd = try JSONDecoder().decode(PPD.self, from: jsonData)
            if let redirect = ppd.redirect {
                return PPD.get(id: redirect.sha256, organisationKeyPair: organisationKeyPair)
            } else {
                return .value(ppd)
            }
        }.recover { error in
            guard case APIError.statusCode(404) = error else {
                Logger.shared.error("PPD retrieval problem", error: error)
                return .value(nil)
            }
            return .value(nil)
        }
    }

    enum CodingKeys: CodingKey {
        case characterSets
        case properties
        case service
        case version
        case timestamp
        case url
        case redirect
        case name
    }

    init(characterSets: [PPDCharacterSet]?, properties: PPDProperties?, service: PPDService?, version: PPDVersion?, timestamp: Timestamp?, url: String, redirect: String?, name: String) {
        self.characterSets = characterSets
        self.properties = properties
        self.service = service
        self.version = version ?? .v1_0
        self.timestamp = timestamp
        self.url = url
        self.redirect = redirect
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.characterSets = try values.decodeIfPresent([PPDCharacterSet].self, forKey: .characterSets)
        self.properties = try values.decodeIfPresent(PPDProperties.self, forKey: .properties)
        self.service = try values.decodeIfPresent(PPDService.self, forKey: .service)
        do {
            self.version = try values.decodeIfPresent(PPDVersion.self, forKey: .version) ?? .v1_0
        } catch is DecodingError {
            self.version = .v1_0
        }
        do {
            self.timestamp = try values.decodeIfPresent(Timestamp.self, forKey: .timestamp)
        } catch {
            self.timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp)?.millisSince1970
        }
        self.url = try values.decode(String.self, forKey: .url)
        self.redirect = try values.decodeIfPresent(String.self, forKey: .redirect)
        self.name = try values.decode(String.self, forKey: .name)
    }
}

struct PPDCharacterSet: Codable {
    /// The character set base characters
    let base: PPDBaseCharacterSet?
    /// String containing all characters that will be added to the character set.
    let characters: String?
    /// The name of the character set.
    let name: String

    init(base: PPDBaseCharacterSet?, characters: String?, name: String) {
        self.base = base
        self.characters = characters
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case base
        case characters
        case name
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        do {
            self.base = try values.decodeIfPresent(PPDBaseCharacterSet.self, forKey: .base)
        } catch is DecodingError {
            self.base = nil
        }
        self.characters = try values.decodeIfPresent(String.self, forKey: .characters)
        self.name = try values.decode(String.self, forKey: .name)
    }
}

struct PPDProperties: Codable {
    /// Parent node for character settings. If the node is omitted,
    /// all characters defined in the characterSets element are treated
    /// as available for use with no restrictions on minimum and maximum occurrences.
    let characterSettings: PPDCharacterSettings?
    /// Indicates whether consecutive characters are allowed or not.
    /// A omitted value or 0 inidaces no limitation on consecutive characters.
    let maxConsecutive: Int?
    /// Minimum length of the password.
    let minLength: Int?
    /// Maximum length of the password. A value of 0 means no maximum length.
    let maxLength: Int?
    /// Password expiry in days. A value of 0 means no expiry.
    var expires: Int = 0
}

struct PPDCharacterSettings: Codable {
    /// Settings element for a globally available character set.
    let characterSetSettings: [PPDCharacterSetSettings]
    /// Character sets specified in the requirement groups are implicitly added
    /// to the available character sets for the given position
    /// (or all position if no positions are specified) if they were not allowed previously.
    let requirementGroups: [PPDRequirementGroup]?
    /// Restriction element used to restrict the allowed characters for a given character position.
    let positionRestrictions: [PPDPositionRestriction]?

    init(characterSetSettings: [PPDCharacterSetSettings]?, requirementGroups: [PPDRequirementGroup]?, positionRestrictions: [PPDPositionRestriction]?) {
        self.characterSetSettings = characterSetSettings ?? [PPDCharacterSetSettings]()
        self.requirementGroups = requirementGroups
        self.positionRestrictions = positionRestrictions
    }
}

struct PPDCharacterSetSettings: Codable {
    /// Minimum password global occurrences of the character set. Omitted for no restrictions on minimum occurences. This includes the complete password even for positions with restrictions.
    let minOccurs: Int?
    /// Maximum password global occurrences of the character set. Omitted for no restrictions on maximum occurences. This includes the complete password even for positions with restrictions.
    let maxOccurs: Int?
    let name: String
}

struct PPDPositionRestriction: Codable {
    /**
     * Comma separated list of character positions the restriction is applied to.
     * Each position can be a character position starting with 0.
     * Negative character positions can be used to specify the position beginning from the end of the password.
     * A value in the interval (0,1) can be used to specify a position by ratio. E.g. 0.5 refers to the center position of the password.
     */
    let positions: String
    /// Minimum occurrences of the character set for the given positions. A value of 0 means no restrictions of minimum occurrences.
    let minOccurs: Int
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
    /// Minimum number of rules that must be fulfilled.
    let minRules: Int
    /// A list of requirement rules.
    let requirementRules: [PPDRequirementRule]

    init(minRules: Int = 1, requirementRules: [PPDRequirementRule]) {
        self.minRules = minRules
        self.requirementRules = requirementRules
    }
}

struct PPDRequirementRule: Codable {
    /// List of character positions this rule applies to as defined in the PositionRestriction type.
    let positions: String?
    /// Minimum occurrences of the given character set. A value of 0 means no minimum occurrences.
    let minOccurs: Int
    /// Maximum occurrences of the given character set. Ommitted for no maximum occurrences.
    let maxOccurs: Int?
    /// A reference to the character set this rule applies to.
    let characterSet: String

    init(positions: String?, minOccurs: Int = 0, maxOccurs: Int?, characterSet: String) {
        self.positions = positions
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
        self.characterSet = characterSet
    }
}

struct PPDService: Codable {
    /// PPD login service, not implemented here.
    let login: PPDLogin
    /// PPD password change service, not implemented here.
    let passwordChange: PPDPasswordChange?
}

struct PPDLogin: Codable {
    let url: String?
}

struct PPDPasswordChange: Codable {
    let url: String?
}

extension PPD: Equatable {

    static func == (lhs: PPD, rhs: PPD) -> Bool {
        let encoder = JSONEncoder()
        guard let lhHash = try? encoder.encode(lhs).hash,
              let rhHash = try? encoder.encode(rhs).hash else {
            return false
        }
        return Crypto.shared.equals(first: lhHash, second: rhHash)
    }

}
