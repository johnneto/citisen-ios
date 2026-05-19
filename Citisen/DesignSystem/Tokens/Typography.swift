import SwiftUI

extension Font {
    static let displayLarge = Font.system(size: 40, weight: .bold, design: .default)
    static let title1 = Font.system(size: 28, weight: .semibold, design: .default)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline17 = Font.system(size: 17, weight: .semibold, design: .default)
    static let body17 = Font.system(size: 17, weight: .regular, design: .default)
    static let callout16 = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline15 = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote13 = Font.system(size: 13, weight: .regular, design: .default)
    static let caption12 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption11Bold = Font.system(size: 11, weight: .semibold, design: .default)
    static let numeric = Font.system(size: 17, weight: .regular, design: .rounded).monospacedDigit()
}
