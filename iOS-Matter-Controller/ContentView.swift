import SwiftUI
import Playgrounds

import Matter
import MatterSupport
import Foundation
import Security

/*
 onboarding payload: MT:6FCJ1IRV01J1KM04-00 and commissioningID: 28BAFEC0-3EDC-4BEA-99C3-B1D7ACA7337E and home: Optional(MatterSupport.MatterAddDeviceRequest.Home(displayName: "home 1"))
 */

let qrPayload: String = "MT:6FCJ142C00KA0648G00"

@Observable
class ContentViewState {
    
    var deviceAvailable: Bool = false
    var currentIpk: String = ""
    var controllerCreated: Bool = false
    var deviceController: MTRDeviceController? = nil
    
    static let shared = ContentViewState()
    
    let sharedDefaults = UserDefaults(suiteName: "group.andresing626.ios-matter-controller")
    
    
    @MainActor
    func startMatterParing() async{
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
            print("calling to request.perfom()...")
            
            let result = try await request.perform()
            deviceAvailable = true
            
            print("request.perfom() returned: \(result)")
            
            
        } catch {
            // Handle specific Matter errors.
            print("error: \(error.localizedDescription)")
        }
        
        
    }
    

 
    
   

}



struct ContentView: View {
    
    @State private var state = ContentViewState()
    
    var body: some View {
        Text("Hello, world!")
            .padding()
            
        if state.deviceAvailable{
            Button(action: {
                //readValues()
            }, label: {
                Text("Read sensor values")
            })
        }
        
        if state.controllerCreated {
            
            Button(action: {
                
            }, label: {
                Text("Commisioning")
            })
        }
        
        Button(action: {
            Task {
                await state.startMatterParing()
                
            }
        }, label: {Text("start paring")})
        
    }
}
    
    


#Preview {
    ContentView()
}


#Playground {
    _ = 1 + 2
}
