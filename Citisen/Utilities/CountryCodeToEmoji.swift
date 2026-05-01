import Foundation

extension String {
    func flagEmoji() -> String {
        guard isCountryCode else { return "" }
        let base: UInt32 = 0x1F1E6
        var s = ""
        for v in unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value - 0x41)!)
        }
        return s
    }

    var isCountryCode: Bool {
        count == 2 && range(of: "^[A-Z]{2}$", options: .regularExpression) != nil
    }
}
