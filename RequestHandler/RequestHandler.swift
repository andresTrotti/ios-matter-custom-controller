//
//  RequestHandler.swift
//  RequestHandler
//
//  Created by Andres Trotti on 10/8/26.
//

import MatterSupport
import OSLog
import Matter



// The extension is launched in response to `MatterAddDeviceRequest.perform()` and this class is the entry point
// for the extension operations.
class RequestHandler: MatterAddDeviceExtensionRequestHandler {
    
    var deviceController: MTRDeviceController? = nil
  
    
    // Use OSLog to log debugging information.
       private let logger = Logger(subsystem: "ios-matter-controller", category: "DeviceSetup")

nonisolated
       override init() {
           super.init()
           logger.debug("MatterAddDeviceExtensionRequestHandler initialized")
       }
    
    override func validateDeviceCredential(_ deviceCredential: MatterAddDeviceExtensionRequestHandler.DeviceCredential) async throws {
        // Use this function to perform additional attestation checks if that is useful for your ecosystem.
    }

    override func selectWiFiNetwork(from wifiScanResults: [MatterAddDeviceExtensionRequestHandler.WiFiScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.WiFiNetworkAssociation {
        // Use this function to select a Wi-Fi network for the device if your ecosystem has special requirements.
        // Or, return `.defaultSystemNetwork` to use the iOS device's current network.
        return .defaultSystemNetwork
    }

    override func selectThreadNetwork(from threadScanResults: [MatterAddDeviceExtensionRequestHandler.ThreadScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.ThreadNetworkAssociation {
        // Use this function to select a Thread network for the device if your ecosystem has special requirements.
        // Or, return `.defaultSystemNetwork` to use the default Thread network.
        return .defaultSystemNetwork
    }

    override func commissionDevice(in home: MatterAddDeviceRequest.Home?, onboardingPayload: String, commissioningID: UUID) async throws {
        // Use this function to commission the device with your Matter stack.
        print("onboarding payload: \(onboardingPayload) and commissioningID: \(commissioningID) and home: \(home.debugDescription )")
        let sharedDefaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller")
        sharedDefaults?.set(onboardingPayload, forKey: "onboardingPayload")
        sharedDefaults?.synchronize()
        
        logger.debug("Commissioning device in home '\(String(describing: home.debugDescription))' with payload: \(onboardingPayload).")


                do {
                    // Parse the onboarding payload and commission the device to your app using the Matter framework APIs.
                    logger.info("Successfully commissioned device with ID: \(commissioningID)")


                    // Make sure that your application returns from this method when it finished pairing the accessory with your application.
                    // Returning from this method indicates to the MatterSupport framework that the pairing process is completed,


                    // and the system displays a view to indicate that the pairing process is completed.
                } catch {
                    logger.error("Failed to commission device: \(error.localizedDescription)")
                    
                }
        
        // Get the controller (create if needed)
        createController()
        
        
        // Commission the device
        let nodeID = NSNumber(value: 1)
        let params = MTRCommissioningParameters()
        
        try deviceController?.commissionNode(withID: nodeID, commissioningParams: params)
        
        
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        // Use this function to return the rooms your ecosystem manages.
        // If your ecosystem manages multiple homes, ensure you are returning rooms that belong to the provided home.
        return [.init(displayName: "Living Room")]
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
          logger.debug("Configuring device '\(name)' in room: \(String(describing: room?.displayName))")


          // Retrieve and configure the newly paired device in your ecosystem;
          // for example, find the device, set its name or room, apply default configurations, and save information in your database.
          logger.info("Device '\(name)' successfully configured")
      }
    
    
    
    func getOrGenerateIPK() -> Data? {
        let keychainKey = "com.andresing626.matter.ipk"
        
        // 1. Try to load an existing IPK from the Keychain
        if let existingData = loadFromKeychain(key: keychainKey) {
            print("IPK loaded successfully from Keychain.")
            return existingData
        }
        
        // 2. If it doesn't exist (first app launch), generate a new 16-byte random IPK
        var keyBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, keyBytes.count, &keyBytes)
        
        guard status == errSecSuccess else {
            print("Error generating random bytes for IPK")
            return nil
        }
        
        let newIPKData = Data(keyBytes)
        
        // 3. Save it to the Keychain so it persists across app launches/reinstalls
        saveToKeychain(data: newIPKData, for: keychainKey)
        print("New IPK generated and saved to Keychain.")
        
        return newIPKData
    }

    
    func createController() {
        // Obtain the controller factory.
        let factory = MTRDeviceControllerFactory.sharedInstance()


        let storage = MatterStorage()
        let factoryParams = MTRDeviceControllerFactoryParams(storage: storage)


        // Set `factoryParams.productAttestationAuthorityCertificates` to an
        // array of trusted Matter PAA certificates.


        do {
            // Start the controller factory.
            try factory.start(factoryParams)
            
            let ipk = getOrGenerateIPK()
            

            let fabricID = NSNumber(value: 1)
            
            let params = MTRDeviceControllerStartupParams(ipk: ipk!,
                                                          fabricID: fabricID,
                                                          nocSigner: MyRootKeypair())
            
            params.vendorID = NSNumber(value: 0xFFF1)
            
            
            
            
            // Check if the fabric is already known in storage
            let existingFabrics = factory.knownFabrics ?? []
            let fabricExists = existingFabrics.contains { $0.fabricID == fabricID }
            
            if fabricExists {
                // If it already exists on disk, load it instead of creating a new one
                deviceController = try factory.createController(onExistingFabric: params)
                print("Successfully loaded existing Matter controller for fabric \(fabricID)")
                
            } else {
                // First time initialization
                deviceController = try factory.createController(onNewFabric: params)
                print("Successfully created new Matter controller for fabric \(fabricID)")
                
            }
            
          
            
        } catch {
            let nsError = error as NSError
                print("❌ Controller Setup Failed!")
                print("Error Domain: \(nsError.domain)")
                print("Error Code: \(nsError.code)")
                print("Description: \(nsError.localizedDescription)")
                print("UserInfo: \(nsError.userInfo)")
            
        }
    }
    
    
    func saveToKeychain(data: Data, for key: String) -> Bool {
        // 1. Convertir la clave de texto a un identificador binario (Access Control Tag)
        let encodedKey = key.data(using: .utf8)!
        
        // 2. Definir los atributos del ítem que vamos a guardar
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encodedKey,
            kSecValueData as String: data,
            // kSecAttrAccessibleAfterFirstUnlock asegura que esté disponible
            // incluso en segundo plano si el dispositivo está desbloqueado
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // 3. Eliminar cualquier registro previo con la misma clave para evitar duplicados
        SecItemDelete(query as CFDictionary)
        
        // 4. Guardar el nuevo dato en el Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Error al guardar en Keychain. Código de error: \(status)")
            return false
        }
        
        return true
    }

    func loadFromKeychain(key: String) -> Data? {
        let encodedKey = key.data(using: .utf8)!
        
        // 1. Configurar la consulta para buscar el ítem binario
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encodedKey,
            kSecReturnData as String: true,        // Queremos que devuelva los datos
            kSecMatchLimit as String: kSecMatchLimitOne // Solo necesitamos la primera coincidencia
        ]
        
        var item: CFTypeRef?
        
        // 2. Ejecutar la búsqueda en el Keychain
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        // 3. Verificar si se encontró y devolver los datos de tipo Data
        if status == errSecSuccess {
            return item as? Data
        }
        
        // Si no existe (primer inicio de la app), devuelve nil de forma silenciosa
        return nil
    }

}




