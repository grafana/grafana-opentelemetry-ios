import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension

func initializeTelemetry() {
  let resource = DefaultResources().get().merging(
    other: Resource(attributes: ["service.name": .string("package-consumer")])
  )
  OpenTelemetry.registerTracerProvider(
    tracerProvider: TracerProviderBuilder()
      .with(resource: resource)
      .add(spanProcessor: BatchSpanProcessor(
        spanExporter: OtlpHttpTraceExporter(endpoint: URL(string: "http://127.0.0.1:4318/v1/traces")!)
      ))
      .build()
  )
  OpenTelemetry.registerLoggerProvider(
    loggerProvider: LoggerProviderBuilder()
      .with(resource: resource)
      .with(processors: [BatchLogRecordProcessor(
        logRecordExporter: OtlpHttpLogExporter(endpoint: URL(string: "http://127.0.0.1:4318/v1/logs")!)
      )])
      .build()
  )
}
