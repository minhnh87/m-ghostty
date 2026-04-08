import Foundation
import Security

enum SSHKeychainError: Error {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData
}

class SSHKeychainManager {
    private let serviceName = "com.mitchellh.ghostty.ssh"
    
    /// Save a password for a profile ID to the Keychain
    func savePassword(profileId: String, password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw SSHKeychainError.unexpectedData
        }
        
        // First, try to delete any existing password
        try? deletePassword(profileId: profileId)
        
        // Add new password
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileId,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SSHKeychainError.saveFailed(status)
        }
    }
    
    /// Get a password for a profile ID from the Keychain
    func getPassword(profileId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    /// Delete a password for a profile ID from the Keychain
    func deletePassword(profileId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SSHKeychainError.deleteFailed(status)
        }
    }
    
    /// Check if a password exists for a profile ID in the Keychain
    func hasPassword(profileId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileId,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

