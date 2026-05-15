import CryptoKit
import Foundation

extension UUID {
    static let citisenPlacesNamespace = UUID(uuidString: "1B671A64-40D5-491E-99B0-DA01FF1F3341")!

    static func v5(namespace: UUID, name: String) -> UUID {
        var bytes = [UInt8]()
        bytes.reserveCapacity(16 + name.utf8.count)
        withUnsafeBytes(of: namespace.uuid) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: name.utf8)

        let digest = Insecure.SHA1.hash(data: bytes)
        var hash = Array(digest.prefix(16))

        hash[6] = (hash[6] & 0x0F) | 0x50  // version 5
        hash[8] = (hash[8] & 0x3F) | 0x80  // RFC 4122 variant

        let tuple: uuid_t = (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        )
        return UUID(uuid: tuple)
    }
}
