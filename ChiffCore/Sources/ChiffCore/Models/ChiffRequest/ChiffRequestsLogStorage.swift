//
//  ChiffRequestsLogStorage.swift
//
//
//  Created by Dmitriy Starodubtsev on 27.07.2021.
//

import Foundation

public class ChiffRequestsLogStorage: NSObject {
    public static let sharedStorage = ChiffRequestsLogStorage()
    private var logs: [ChiffRequestLogModel]?

    public func save(log: ChiffRequestLogModel) {
        try? loadLogs(sessionID: log.sessionId)
        do {
            if let logModel = logs?.filter({ $0.browserTab == log.browserTab }).first {
                var tmpArray: [ChiffRequestLogModel] = logs!
                tmpArray.remove(at: (tmpArray.firstIndex(of: logModel))!)
                logs = tmpArray
            }
            if logs?.count ?? 0 < 100 {
                logs?.append(log)
            } else if let logs = logs {
                let mostОldLog = logs.min(by: {
                    $0.date.timeIntervalSinceReferenceDate < $1.date.timeIntervalSinceReferenceDate
                })
                if let mostОldLog = mostОldLog {
                    var tmpArray: [ChiffRequestLogModel] = logs
                    if let index = tmpArray.firstIndex(of: mostОldLog) {
                        tmpArray.remove(at: index)
                    }
                    tmpArray.append(log)
                    self.logs = tmpArray
                }
            }
            let logData = try PropertyListEncoder().encode(logs)
            try logData.write(to: Self.getPath(log.sessionId))
        } catch {
            Logger.shared.warning("Failed to write device logging.", error: error)
        }
    }
    
    public func removeLogsFileForSession(id: String) {
        let fileManager = FileManager.default
        let logFilePath = ChiffRequestsLogStorage.getPath(id)
        do {
            try fileManager.removeItem(at: logFilePath)
        } catch {
            Logger.shared.warning("Failed to delete log file for Session ID \(id)", error: error)
        }
    }

    public func getLogForSession(id: String) throws -> [ChiffRequestLogModel] {
        try loadLogs(sessionID: id)
        return logs ?? []
    }
    
    private func loadLogs(sessionID: String) throws {
        guard let data = try? Data(contentsOf: Self.getPath(sessionID), options: .alwaysMapped) else {
            logs = []
            return
        }
        logs = try PropertyListDecoder().decode([ChiffRequestLogModel].self, from: data)
    }
    
    private static func getPath(_ sessionID: String) -> URL {
        return URL(fileURLWithPath: ChiffRequestsLogStorage.fileName(sessionID), relativeTo: getDocumentsDirectory())
    }
    
    private static func fileName(_ sessionID: String) -> String {
        return "RequestsData_\(sessionID).log"
    }
    
    private static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
