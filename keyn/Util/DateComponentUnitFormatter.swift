/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct DateComponentUnitFormatter {
    
    private struct DateComponentUnitFormat {
        let unit: Calendar.Component
        let localizationKey: String

        var singularUnit: String {
            return "date_components.\(localizationKey).singular_unit".localized
        }
        var pluralUnit: String {
            return "date_components.\(localizationKey).plural_unit".localized
        }

        var futureSingular: String {
            return "date_components.\(localizationKey).future_singular".localized
        }
        var pastSingular: String {
            return "date_components.\(localizationKey).past_singular".localized
        }

    }

    private let formats: [DateComponentUnitFormat] = [
        DateComponentUnitFormat(unit: .year, localizationKey: "year"),
        DateComponentUnitFormat(unit: .month, localizationKey: "month"),
        DateComponentUnitFormat(unit: .weekOfYear, localizationKey: "week"),
        DateComponentUnitFormat(unit: .day, localizationKey: "day"),
        DateComponentUnitFormat(unit: .hour, localizationKey: "hour"),
        DateComponentUnitFormat(unit: .minute, localizationKey: "minute"),
        DateComponentUnitFormat(unit: .second, localizationKey: "second"),
        ]

    func string(forDateComponents dateComponents: DateComponents, useNumericDates: Bool) -> String {
        for format in self.formats {
            let unitValue: Int

            switch format.unit {
            case .year:
                unitValue = dateComponents.year ?? 0
            case .month:
                unitValue = dateComponents.month ?? 0
            case .weekOfYear:
                unitValue = dateComponents.weekOfYear ?? 0
            case .day:
                unitValue = dateComponents.day ?? 0
            case .hour:
                unitValue = dateComponents.hour ?? 0
            case .minute:
                unitValue = dateComponents.minute ?? 0
            case .second:
                return "date_components.less_than_minute".localized
            default:
                assertionFailure("Date does not have requried components")
                return ""
            }

            switch unitValue {
            case 2 ..< Int.max:
                return "\(unitValue) \(format.pluralUnit) \("date_components.ago".localized)"
            case 1:
                return useNumericDates ? "\(unitValue) \(format.singularUnit) \("date_components.ago".localized)" : format.pastSingular
            case -1:
                return useNumericDates ? "\("date_components.in".localized.capitalizedFirstLetter) \(-unitValue) \(format.singularUnit)" : format.futureSingular
            case Int.min ..< -1:
                return "\("date_components.in".localized.capitalizedFirstLetter) \(-unitValue) \(format.pluralUnit)"
            default:
                break
            }
        }

        return "date_components.just_now".localized
    }
}
