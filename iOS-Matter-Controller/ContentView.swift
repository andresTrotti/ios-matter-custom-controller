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
    
    // MARK: - Added UI State Variables
    var occupancyValue: String = "--"
    var temperatureValue: String = "-- °C"
    var humidityValue: String = "-- %"
    
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
                    print("🚶‍♂️ ¡Ocupación leída!: \(occValue) (1=Working, 0=free)")
                    self.occupancyValue = occValue.intValue == 1 ? "Working" : "Not working"
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
                    let calcTemp = Double(truncating: tempValue) / 100.0
                    print("🌡️ ¡Temperatura leída!: \(tempValue) (\(calcTemp) °C)")
                    self.temperatureValue = String(format: "%.2f °C", calcTemp)
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
                    let calcHum = Double(truncating: humValue) / 100.0
                    print("💧 ¡Humedad leída!: \(humValue) (\(calcHum) %)")
                    self.humidityValue = String(format: "%.1f %%", calcHum)
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

// MARK: - Reusable Card Component
struct SensorCard: View {
    var icon: String
    var iconColor: Color
    var value: String
    var label: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 20, weight: .medium))
                )
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(height: 160)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    
    @State private var state = ContentViewState()
    
    // Theme Colors based on screenshot
    let bgColor = Color(red: 0.95, green: 0.96, blue: 0.98)
    let brandGreen = Color(red: 0.11, green: 0.72, blue: 0.54)
    let darkGreenGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.08, green: 0.52, blue: 0.35), Color(red: 0.12, green: 0.65, blue: 0.46)]),
        startPoint: .leading, endPoint: .trailing
    )
    
    var body: some View {
        ZStack {
            bgColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Krasamo: Custom matter controller")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: {
                        // Using the menu to trigger pairing instead of a generic list
                        Task { await state.startMatterParing() }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.03), radius: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                // Top Banner
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sensor Status")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text("Keep track of your environment\nreadings seamlessly.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: {
                        state.readSensors()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(darkGreenGradient)
                )
                .padding(.horizontal, 24)
                
                // Category Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        Button(action: {
                            // Empty action for UI placeholder
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.gray)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.02), radius: 5)
                        }
                        
                        Text("Living room")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(brandGreen)
                            .cornerRadius(16)
                        
                        Text("Bedroom")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.02), radius: 5)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Selection Bar Placeholder
                HStack {
                    Text("Multisensor")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .padding(.trailing, 16)
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .foregroundColor(.gray)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.02), radius: 5)
                    }
                }
                .padding(.horizontal, 24)
                
                // Sensor Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    SensorCard(icon: "thermometer", iconColor: Color.pink, value: state.temperatureValue, label: "Temperature")
                    SensorCard(icon: "drop.fill", iconColor: Color.blue, value: state.humidityValue, label: "Moisture")
                    SensorCard(icon: "person.fill", iconColor: Color.orange, value: state.occupancyValue, label: "Occupancy")
                    SensorCard(icon: "network", iconColor: brandGreen, value: state.deviceAvailable ? "Online" : "Ready", label: "Status")
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        Task { await state.startMatterParing() }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(brandGreen)
                            .clipShape(Circle())
                            .shadow(color: brandGreen.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
