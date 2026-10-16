import SwiftUI

@main
struct ConsumerApp: App {
  init() {
    initializeTelemetry()
    Probe.run(id: UserDefaults.standard.string(forKey: "probe_id") ?? "manual")
  }

  var body: some Scene {
    WindowGroup {
      Text("Package consumer")
    }
  }
}
