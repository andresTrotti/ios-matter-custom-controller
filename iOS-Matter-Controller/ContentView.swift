import SwiftUI
import Playgrounds

import Matter
import MatterSupport
import Foundation
import Security
import OSLog

let qrPayload: String = "MT:6FCJ142C00KA0648G00"

@Observable
class ContentViewState {
    
    var deviceAvailable: Bool = false
    var currentIpk: String = ""
    var controllerCreated: Bool = false
    var deviceController: MTRDeviceController? = nil
    var nodeID: UInt64? = nil
    let logger: Logger = Logger(subsystem: "com.andresing626.ios-matter-controller", category: "main")
    
    static let shared = ContentViewState()
    
    private var cachedController: MTRDeviceController?
    
    let sharedDefaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller")
    
    func getSavedNodeID() -> UInt64? {
        if let defaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller"),
           let savedNodeID = defaults.object(forKey: "savedNodeID") as? UInt64 {
            return savedNodeID
        }
        return nil
    }
    
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
            cachedController = controller
            return controller
        } catch {
            logger.info("No existing fabric (\(error.localizedDescription)); creating new one.")
            let controller = try factory.createController(onNewFabric: params)
            logger.info("Created new controller for fabric \(fabricID)")
            cachedController = controller
            return controller
        }
    }
    
    @MainActor
    func startMatterParing() async {
        deviceAvailable = false
        var statusMessage = "Preparing to start pairing..."
        
        let homes = [MatterAddDeviceRequest.Home(displayName: "home 1")]
        let topology = MatterAddDeviceRequest.Topology(ecosystemName: "My ecosistema", homes: homes)
        
        guard let setupPayload = MTRSetupPayload(payload: qrPayload) else {
            statusMessage = "Invalid QR code string..."
            print("Error: Invalid QR code string...")
            return
        }
        
        let request = MatterAddDeviceRequest(
            topology: topology,
            setupPayload: setupPayload
        )
        
        do {
            statusMessage = "Presenting commissioning UI..."
            print("calling to request.perform()...")
            
            let result = try await request.perform()
            deviceAvailable = true
            
            print("request.perform() returned: \(result)")
            
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }
    
    func readSensors() {
        do {
            let controller = try createOrLoadController()

            guard let nodeID = getSavedNodeID() else {
                print("❌ No saved node ID found in App Group")
                return
            }
            print("✅ Saved node ID: \(nodeID)")

            let device = MTRBaseDevice(nodeID: NSNumber(value: nodeID), controller: controller)
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

            readGroup.notify(queue: .main) {
                print("✅ Consulta de sensores completada.")
            }
            
        } catch {
            print("Failed to read sensors: \(error)")
        }
    }
}

struct ContentView: View {
    
    @State private var state = ContentViewState()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, world!")
                .padding()
            
            Button(action: {
                print("reading sensors...")
                state.readSensors()
            }, label: {
                Text("Read sensor values")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            })
            
            if state.controllerCreated {
                Button(action: {
                    // Logic for Commissioning explicitly if needed
                }, label: {
                    Text("Commissioning")
                })
            }
            
            Button(action: {
                Task {
                    await state.startMatterParing()
                }
            }, label: {
                Text("Start pairing")
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            })
        }
    }
}

#Preview {
    ContentView()
}
