import Foundation

extension String {
    func flagEmoji() -> String {
        guard isCountryCode else { return "" }
        let base: UInt32 = 0x1F1E6
        var flag = ""
        for scalar in unicodeScalars {
            guard let regionalScalar = UnicodeScalar(base + scalar.value - 0x41) else { continue }
            flag.unicodeScalars.append(regionalScalar)
        }
        return flag
    }

    var isCountryCode: Bool {
        count == 2 && range(of: "^[A-Z]{2}$", options: .regularExpression) != nil
    }
}
