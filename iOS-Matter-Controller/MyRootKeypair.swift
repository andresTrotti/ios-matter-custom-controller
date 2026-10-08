//
//  MyRootKeypair.swift
//  ios-matter-controller
//
//  Created by Andres Trotti on 10/8/26.
//

import Security
import Matter
import CryptoKit

class MyRootKeypair: NSObject, MTRKeypair {
    
    private let privateKey: SecKey
    
    override init() {
        // Updated tag to version 2 to abandon the old cached key without usage flags
        let tag = "com.andresing626.matter.rootkey.v3".data(using: .utf8)! as CFData
        
        // Try to load an existing key first.
        // 2. Add kSecAttrKeyClassPrivate to the lookup query
                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tag,
                    kSecAttrKeyType as String: kSecAttrKeyTypeEC,
                    kSecAttrKeyClass as String: kSecAttrKeyClassPrivate, // <-- THIS IS THE CRITICAL LINE
                    kSecReturnRef as String: true,
                ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            privateKey = item as! SecKey
        }  else {
            
            var error: Unmanaged<CFError>?
            
        
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag
                ]
            ]
            
            guard let newKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                fatalError("Key generation failed: \(error!.takeRetainedValue())")
            }
            privateKey = newKey
        }
        
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
