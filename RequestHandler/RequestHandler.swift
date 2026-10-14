//
//  RequestHandler.swift
//  RequestHandler
//

import MatterSupport
import OSLog
import Matter
import Security

class RequestHandler: MatterAddDeviceExtensionRequestHandler, MTRDeviceControllerDelegate {
    
    private var cachedController: MTRDeviceController?

    private var deviceController: MTRDeviceController?
        private var commissioningContinuation: CheckedContinuation<Void, Error>?
        private var currentNodeID: NSNumber? // <-- Add this to remember the ID between steps
        

    private let logger = Logger(subsystem: "ios-matter-controller", category: "DeviceSetup")

    nonisolated override init() {
        super.init()
        logger.debug("MatterAddDeviceExtensionRequestHandler initialized")
    }

    // MARK: - Required overrides

    override func validateDeviceCredential(
        _ deviceCredential: MatterAddDeviceExtensionRequestHandler.DeviceCredential
    ) async throws {
        // Attestation hooks if needed
    }

    override func selectWiFiNetwork(
        from wifiScanResults: [MatterAddDeviceExtensionRequestHandler.WiFiScanResult]
    ) async throws -> MatterAddDeviceExtensionRequestHandler.WiFiNetworkAssociation {
        return .defaultSystemNetwork
    }

    override func selectThreadNetwork(
        from threadScanResults: [MatterAddDeviceExtensionRequestHandler.ThreadScanResult]
    ) async throws -> MatterAddDeviceExtensionRequestHandler.ThreadNetworkAssociation {
        return .defaultSystemNetwork
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        return [.init(displayName: "Living Room")]
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
        logger.info("Device '\(name)' successfully configured")
    }

    // MARK: - Commissioning

    override func commissionDevice(
        in home: MatterAddDeviceRequest.Home?,
        onboardingPayload: String,
        commissioningID: UUID
    ) async throws {

        logger.debug("Commissioning device with payload: \(onboardingPayload)")

        // 1. Persistir payload en el App Group (por si la app lo necesita)
        UserDefaults(suiteName: "group.andresing626.ios-matter-controller")?
            .set(onboardingPayload, forKey: "onboardingPayload")

        // 2. Crear/obtener el controller (esto puede lanzar)
        let controller = try createOrLoadController()

        // 3. IMPORTANTE: registrar el delegate ANTES de comisionar
        controller.setDeviceControllerDelegate(self, queue: .main)
        self.deviceController = controller

        guard let setupPayload = try? MTRSetupPayload(payload: onboardingPayload) else {
                    throw NSError(domain: "RequestHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid onboarding payload"])
                }

                // 5. Iniciar la sesión PASE y ESPERAR al delegate
                let nodeID = NSNumber(value: UInt64.random(in: 2...0xFFFF_FFF0_0000_0000))
                self.currentNodeID = nodeID // Save it so the delegate can use it
                
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.commissioningContinuation = cont
                    do {
                        // STEP 1: Connect to the device using the payload!
                        try controller.setupCommissioningSession(with: setupPayload, newNodeID: nodeID)
                        // The flow will now jump to `commissioningSessionEstablishmentDone`
                    } catch {
                        self.commissioningContinuation = nil
                        cont.resume(throwing: error)
                    }
                }

                logger.info("Commissioning completed for node \(nodeID)")

        logger.info("Commissioning completed for node \(nodeID)")
    }

    // MARK: - MTRDeviceControllerDelegate
        
    // MARK: - MTRDeviceControllerDelegate

    func controller(
        _ controller: MTRDeviceController,
        commissioningComplete error: Error?,
        nodeID: NSNumber?
    ) {
        if let error = error {
            logger.error("Commissioning failed: \(error.localizedDescription)")
            commissioningContinuation?.resume(throwing: error)
            commissioningContinuation = nil
            return
        }

        logger.info("Commissioning completed successfully for node \(String(describing: nodeID))")
        
        if let actualNodeID = nodeID {
            // 1. Guardar en UserDefaults
            if let defaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller") {
                defaults.set(actualNodeID, forKey: "savedNodeID")
            }

            // 2. ⚡️ INTENTO DE LECTURA DE LOS 3 SENSORES EN PARALELO
            let device = MTRBaseDevice(nodeID: actualNodeID, controller: controller)
            
            // Creamos un DispatchGroup para esperar a que los 3 respondan
            let readGroup = DispatchGroup()

            // --- ENDPOINT 1: OCUPACIÓN (Cluster 1030) ---
            let occCluster = MTRBaseClusterOccupancySensing(device: device, endpointID: NSNumber(value: 1), queue: DispatchQueue.main)
            readGroup.enter()
            occCluster?.readAttributeOccupancy { value, readError in
                if let readError = readError {
                    print("⚠️ Falló lectura de Ocupación: \(readError.localizedDescription)")
                } else if let occValue = value {
                    print("🚶‍♂️ ¡Ocupación leída!: \(occValue) (1=Detectado, 0=Libre)")
                }
                readGroup.leave()
            }

            // --- ENDPOINT 2: TEMPERATURA (Cluster 1026) ---
            let tempCluster = MTRBaseClusterTemperatureMeasurement(device: device, endpointID: NSNumber(value: 2), queue: DispatchQueue.main)
            readGroup.enter()
            tempCluster?.readAttributeMeasuredValue { value, readError in
                if let readError = readError {
                    print("⚠️ Falló lectura de Temperatura: \(readError.localizedDescription)")
                } else if let tempValue = value {
                    print("🌡️ ¡Temperatura leída!: \(tempValue) (\(Double(truncating: tempValue) / 100.0) °C)")
                }
                readGroup.leave()
            }

            // --- ENDPOINT 3: HUMEDAD RELATIVA (Cluster 1029) ---
            let humCluster = MTRBaseClusterRelativeHumidityMeasurement(device: device, endpointID: NSNumber(value: 3), queue: DispatchQueue.main)
            readGroup.enter()
            humCluster?.readAttributeMeasuredValue { value, readError in
                if let readError = readError {
                    print("⚠️ Falló lectura de Humedad: \(readError.localizedDescription)")
                } else if let humValue = value {
                    print("💧 ¡Humedad leída!: \(humValue) (\(Double(truncating: humValue) / 100.0) %)")
                }
                readGroup.leave()
            }

            // 3. Resume continuation SOLO cuando los 3 sensores hayan terminado de responder
            readGroup.notify(queue: .main) {
                self.commissioningContinuation?.resume(returning: ())
                self.commissioningContinuation = nil
                self.currentNodeID = nil
            }
            
        } else {
            commissioningContinuation?.resume(returning: ())
            commissioningContinuation = nil
            self.currentNodeID = nil
        }
    }
            
        // STEP 2: PASE Session established, now we can commission!
        func controller(_ controller: MTRDeviceController, commissioningSessionEstablishmentDone error: Error?) {
            if let error = error {
                logger.error("Session establishment failed: \(error.localizedDescription)")
                commissioningContinuation?.resume(throwing: error)
                commissioningContinuation = nil
                return
            }
            
            guard let nodeID = self.currentNodeID else {
                logger.error("Node ID missing in session establishment")
                return
            }
            
            logger.info("Session established successfully! Proceeding to commission...")
            
            // Remove the `skipNetworkProvisioning` line entirely.
            // Leaving the parameters blank automatically skips Wi-Fi provisioning.
            let params = MTRCommissioningParameters()
            
            do {
                // STEP 3: Actually commission the node and exchange certificates
                try controller.commissionNode(withID: nodeID, commissioningParams: params)
                
                // IMPORTANT: Do NOT set commissioningContinuation = nil here!
                // We must leave it alive so `commissioningComplete` can call `.resume()` on it.
                
            } catch {
                logger.error("Failed to call commissionNode: \(error.localizedDescription)")
                commissioningContinuation?.resume(throwing: error)
                commissioningContinuation = nil
            }
        }

    // MARK: - Controller setup

    private func createOrLoadController() throws -> MTRDeviceController {

        if let existing = cachedController, existing.isRunning {
            print("Reusing cached controller")
            return existing
        }


        let factory = MTRDeviceControllerFactory.sharedInstance()
        let storage = MatterStorage()
        let factoryParams = MTRDeviceControllerFactoryParams(storage: storage)
        

        do {
            try factory.start(factoryParams)
        } catch {
            // Ya estaba arrancado — OK
            logger.debug("factory.start threw (likely already started): \(error)")
        }

        let ipk = try getOrGenerateIPK()
        let fabricID: NSNumber = 1

        let params = MTRDeviceControllerStartupParams(
            ipk: ipk,
            fabricID: fabricID,
            nocSigner: MyRootKeypair()
        )
        params.vendorID = NSNumber(value: 0x1384)
        

        // Intenta cargar la fabric existente; si no existe, créala.
        do {
            let controller = try factory.createController(onExistingFabric: params)
            logger.info("Loaded existing controller for fabric \(fabricID)")
            return controller
        } catch {
            logger.info("No existing fabric (\(error.localizedDescription)); creating new one.")
            let controller = try factory.createController(onNewFabric: params)
            logger.info("Created new controller for fabric \(fabricID)")
            return controller
        }
    }
    
    // MARK: - IPK

    
    private func getOrGenerateIPK() throws -> Data {
        guard let defaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller") else {
            fatalError("App Group not found")
        }
        
        let ipkKey = "matter.ipk.raw"
        
        if let existing = defaults.data(forKey: ipkKey) {
            return existing
        }
        
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw NSError(domain: "IPKError", code: 1, userInfo: nil)
        }
        
        let data = Data(bytes)
        defaults.set(data, forKey: ipkKey)
        return data
    }

    // MARK: - Keychain helpers

    // Replace "TEAMID" with your actual Apple Team ID prefix shown in Xcode's Keychain Sharing capability
        private let sharedKeychainGroup = "7C8Q4538WG.group.andresing.ios-matter-controller-keySharing"

        // MARK: - Keychain helpers

        @discardableResult
        private func saveToKeychain(data: Data, for key: String) -> Bool {
            let encodedKey = key.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: encodedKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecAttrAccessGroup as String: sharedKeychainGroup // <-- CRITICAL FIX
            ]
            SecItemDelete(query as CFDictionary)
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        }

        private func loadFromKeychain(key: String) -> Data? {
            let encodedKey = key.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: encodedKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecAttrAccessGroup as String: sharedKeychainGroup // <-- CRITICAL FIX
            ]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
                return nil
            }
            return item as? Data
        }
}
