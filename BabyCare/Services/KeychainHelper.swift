import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.babycare.ai"

    static func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        // Delete existing first
        SecItemDelete(query as CFDictionary)

        let attrs = query.merging([kSecValueData: data]) { $1 }
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            if case .saveFailed(let s) = self { return "Keychain save failed: \(s)" }
            return nil
        }
    }
}
