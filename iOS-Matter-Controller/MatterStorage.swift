//
//  MatterStorage.swift
//  ios-matter-controller
//
//  Created by Andres Trotti on 10/8/26.
//

import Foundation
import Matter

class MatterStorage: NSObject, MTRStorage {
    
    private let defaults: UserDefaults
    private let storageLock = NSLock() // Crítico para evitar crasheos de concurrencia
    
    override init() {
        // Usa el App Group si necesitas compartir datos con extensiones/widgets
        // Reemplaza "group.com.andresing626.Matter" con el ID de tu App Group en Xcode
        if let appGroupDefaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller") {
            self.defaults = appGroupDefaults
            print("MyStorage: Conectado al contenedor App Group.")
        } else {
            print("MyStorage: App Group no encontrado. Usando UserDefaults estándar.")
            self.defaults = UserDefaults.standard
        }
        super.init()
    }
    
    // MARK: - MTRStorage Protocol
    
    func storageData(forKey key: String) -> Data? {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        let data = defaults.data(forKey: key)
        
        /*
        // Descomenta esto solo para depuración si necesitas ver qué está leyendo Matter
        if let data = data {
            print("MTRStorage Read: \(key) (\(data.count) bytes)")
        } else {
            print("MTRStorage Read: \(key) (nil)")
        }
        */
        
        return data
    }
    
    func setStorageData(_ value: Data, forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        defaults.set(value, forKey: key)
        // print("MTRStorage Write: \(key) (\(value.count) bytes)")
        
        return true
    }
    
    func removeStorageData(forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        
        defaults.removeObject(forKey: key)
        // print("MTRStorage Remove: \(key)")
        
        return true
    }
}
