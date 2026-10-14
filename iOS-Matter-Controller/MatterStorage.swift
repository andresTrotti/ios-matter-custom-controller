//
//  MatterStorage.swift
//  ios-matter-controller
//
//  Created by Andres Trotti on 10/8/26.
//

import Foundation
import Matter

class MatterStorage: NSObject, MTRStorage {
    
    private let storageDirectory: URL
    private let storageLock = NSLock()
    
    override init() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.andresing626.ios-matter-controller"
        ) else {
            fatalError("App Group container not available — check entitlements")
        }
        
        self.storageDirectory = containerURL.appendingPathComponent("MatterStorage", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
        
        print("MatterStorage: Using container at \(storageDirectory.path)")
        super.init()
    }
    
    private func url(forKey key: String) -> URL {
        // Encode key so it's a valid filename (keys contain '/')
        let safe = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return storageDirectory.appendingPathComponent(safe)
    }
    
    // MARK: - MTRStorage
    
    func storageData(forKey key: String) -> Data? {
        storageLock.lock()
        defer { storageLock.unlock() }
        let data = try? Data(contentsOf: url(forKey: key))
        print("MTRStorage Read: \(key) (\(data?.count ?? 0) bytes)")
        return data
    }
    
    func setStorageData(_ value: Data, forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        do {
            try value.write(to: url(forKey: key), options: .atomic)
            print("MTRStorage Write: \(key) (\(value.count) bytes)")
            return true
        } catch {
            print("MTRStorage Write FAILED: \(key): \(error)")
            return false
        }
    }
    
    func removeStorageData(forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        try? FileManager.default.removeItem(at: url(forKey: key))
        print("MTRStorage Remove: \(key)")
        return true
    }
}
