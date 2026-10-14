import Foundation
import GrafanaOpenTelemetryIOS

func initializeTelemetry() {
  do {
    try GrafanaOtel.initialize(
      configuration: GrafanaOtelConfiguration(
        otlpEndpoint: URL(string: "http://127.0.0.1:4318")!,
        firstPartyHosts: ["127.0.0.1"],
        resourceAttributes: ["service.name": "package-consumer"],
        diskBuffering: .disabled
      )
    )
  } catch {
    fatalError("Grafana OpenTelemetry iOS did not start: \(error)")
  }
}
