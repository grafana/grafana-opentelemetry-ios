import Foundation
import OpenTelemetryApi

// Both variants use this exact instrumentation. Only startup and dependencies differ.
enum Probe {
  // The query is there to check that the Grafana variant removes it from recorded URLs.
  static let url = URL(string: "http://127.0.0.1:8089/probe?probe_query=removed")!

  static func run(id: String) {
    DispatchQueue.global().async {
      let telemetry = OpenTelemetry.instance
      let span = telemetry.tracerProvider
        .get(instrumentationName: "package-consumer", instrumentationVersion: nil)
        .spanBuilder(spanName: "package-consumer.request")
        .setSpanKind(spanKind: .client)
        .setAttribute(key: "test.run_id", value: id)
        .startSpan()
      defer { span.end() }

      telemetry.contextProvider.withActiveSpan(span) {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue(id, forHTTPHeaderField: "X-Test-Run")
        var headers: [String: String] = [:]
        telemetry.propagators.textMapPropagator.inject(
          spanContext: span.context,
          carrier: &headers,
          setter: HeaderSetter()
        )
        for (name, value) in headers {
          request.setValue(value, forHTTPHeaderField: name)
        }

        guard let statusCode = send(request) else {
          span.status = .error(description: "Probe request failed")
          return
        }
        span.setAttribute(key: "http.response.status_code", value: statusCode)
        telemetry.loggerProvider
          .get(instrumentationScopeName: "package-consumer")
          .logRecordBuilder()
          .setSpanContext(span.context)
          .setBody(.string("package-consumer.completed"))
          .setAttributes(["test.run_id": .string(id)])
          .emit()
      }
    }
  }

  private static func send(_ request: URLRequest) -> Int? {
    let completed = DispatchSemaphore(value: 0)
    var statusCode: Int?
    URLSession.shared.dataTask(with: request) { _, response, error in
      if error == nil {
        statusCode = (response as? HTTPURLResponse)?.statusCode
      }
      completed.signal()
    }.resume()
    completed.wait()
    return statusCode
  }

  private struct HeaderSetter: Setter {
    func set(carrier: inout [String: String], key: String, value: String) {
      carrier[key] = value
    }
  }
}
