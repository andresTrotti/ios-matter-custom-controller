import Security
import Matter
import CryptoKit
import Foundation

class MyRootKeypair: NSObject, MTRKeypair {
    
    private let privateKey: SecKey
    private let defaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller")!

    override init() {
        let keyName = "matter.rootkey.raw"
        var rawKeyData: Data
        
        // 1. Load from App Group or generate new raw bytes
        if let savedKey = defaults.data(forKey: keyName) {
                print("✅ MyRootKeypair: Successfully loaded existing root key from App Group!")
                rawKeyData = savedKey
            } else {
                print("⚠️ MyRootKeypair: No existing root key found in App Group. Generating a new one...")
                let newKey = P256.Signing.PrivateKey()
                rawKeyData = newKey.x963Representation
                defaults.set(rawKeyData, forKey: keyName)
            }
        
        // 2. Convert raw data into an IN-MEMORY SecKey (Bypasses Keychain entirely)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(rawKeyData as CFData, attributes as CFDictionary, &error) else {
            fatalError("Failed to create in-memory SecKey: \(error!.takeRetainedValue())")
        }
        
        self.privateKey = secKey
        super.init()
    }
    
    // MARK: - MTRKeypair
    
    func copyPublicKey() -> SecKey {
        return SecKeyCopyPublicKey(privateKey)!
    }

    func signMessageECDSA_RAW(_ message: Data) -> Data {
        var error: Unmanaged<CFError>?
        guard let derSignature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            message as CFData,
            &error
        ) as Data? else {
            fatalError("Signing failed: \(error!.takeRetainedValue())")
        }
        
        // Convert DER to raw (r||s) format
        let ecdsaSignature = try! P256.Signing.ECDSASignature(derRepresentation: derSignature)
        return ecdsaSignature.rawRepresentation
    }
}
