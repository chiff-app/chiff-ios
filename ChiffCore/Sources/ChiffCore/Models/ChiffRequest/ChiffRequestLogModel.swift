//
//  File.swift
//
//
//  Created by Dmitriy Starodubtsev on 27.07.2021.
//

import Foundation

public struct ChiffRequestLogModel: Codable {
    public let param: String
    public let sessionId: String
    public let type: ChiffMessageType
    public let browserTab: Int
    public var isRejected: Bool
    public let date: Date

    public var logString: String {
        return  "\(dateString)\t\(accountString) \(isRejected ? "(declined)" : "")"
    }
    
    private var dateString: String {
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "dd-MM-yyyy HH:mm:ss"
        return dateFormatterGet.string(from: date)
    }

    private var accountString: String {
        switch self.type {
        case .login, .webauthnLogin:
            return String(format: "logs.login".localized, param)
        case .change:
            return String(format: "logs.change".localized, param)
        case .add, .register, .addAndLogin, .webauthnCreate:
            return String(format: "logs.add".localized, param)
        case .addBulk:
            return String(format: "logs.add_bulk".localized, param)
        case .fill:
            return String(format: "logs.fill".localized, param)
        case .addToExisting:
            return String(format: "logs.add_to_existing".localized, param)
        case .adminLogin:
            return String(format: "logs.team_login".localized, param)
        case .addWebauthnToExisting:
            return String(format: "logs.add_webauthn".localized, param)
        case .bulkLogin:
            return String(format: "logs.add_webauthn".localized, param)
        case .getDetails:
            return String(format: "logs.get_details".localized, param)
        case .updateAccount:
            return String(format: "logs.update_account".localized, param)
        case .createOrganisation:
            return String(format: "logs.team_created".localized, param)
        case .sshCreate:
            return String(format: "logs.ssh_created".localized, param)
        case .sshLogin:
            return String(format: "logs.ssh_login".localized, param)
        case .export:
            return "logs.export".localized
        default:
           return "logs.unknown".localized
        }
    }

    public init(sessionId: String, param: String, type: ChiffMessageType, browserTab: Int, isRejected: Bool) {
        self.sessionId = sessionId
        self.param = param
        self.type = type
        self.browserTab = browserTab
        self.isRejected = isRejected
        self.date = Date()
    }

}

extension ChiffRequestLogModel: Equatable {

    public static func == (lhs: ChiffRequestLogModel, rhs: ChiffRequestLogModel) -> Bool {
        return lhs.sessionId == rhs.sessionId &&
            lhs.param == rhs.param &&
            lhs.browserTab == rhs.browserTab
    }

}
