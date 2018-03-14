//
//  PPD.swift
//  keyn
//
//  Created by bas on 14/03/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

struct PPD: Codable {
    let characterSets: [PPDCharacterSet]
    let properties: PPDProperties
    let service: PPDService
    let version: String
    let timestamp: Date
    let url: String // Can this be URL?
    let redirect: String
    let name: String
}

struct PPDCharacterSet: Codable {
    let base: [String]
    let characters: String
    let name: String
}

struct PPDProperties: Codable {
    let characterSettings: PPDCharacterSettings
    let maxConsecutive: Int
    let minLength: Int
    let maxLength: Int
    let expires: Int
}

struct PPDCharacterSettings: Codable {
    let characterSetSettings: [PPDCharacterSetSettings]
    let requirementGroups: [PPDRequirementGroup]
    let positionRestrictions: [PPDPositionRestrictions]
}

struct PPDPositionRestrictions: Codable {
    let positions: String
    let minOccurs: Int = 0
    let maxOccurs: Int
    let characterSet: String
}

struct PPDCharacterSetSettings: Codable {
    let minOccurs: Int
    let maxOccurs: Int
    let name: String
}

struct PPDRequirementGroup: Codable {
    let minRules: Int = 1
    let requirementRule: [PPDRequirementRule]
}

struct PPDRequirementRule: Codable {
    let minOccurs: Int
    let maxOccurs: Int
    let positions: String
}


// TODO: Complete Service part. Perhaps first implement in JS?

struct PPDService: Codable {
    let login: PPDLogin
    let register: PPDRegister
    let passwordChange: PPDPasswordChange
    let passwordReset: PPDPasswordReset
}

struct PPDLogin: Codable {
    let url: String // Can this be URL?
    let maxTries: Int
    let routines: [PPDBaseRoutine]
}

struct PPDRegister: Codable {
    let url: String
}

struct PPDPasswordChange: Codable {
    let url: String
    let maxTries: Int
    let routines: [PPDBaseRoutine]
}

struct PPDPasswordReset: Codable {
    let url: String
    let maxTries: Int
    let routines: [PPDPasswordResetRoutines]
}








