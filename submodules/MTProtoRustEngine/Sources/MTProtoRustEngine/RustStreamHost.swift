import Foundation
import Network
import MTProtoEngineFFI

/// TLS and TCP streams for the engine over Network.framework's C API. Not the Swift overlay: an x86_64
/// build for macOS 10.13 binds the overlay's symbols to Network.framework, which has them only from
/// macOS 14, so on Intel Macs with 10.14-13 every overlay call jumps to a null pointer.
@available(macOS 10.14, iOS 12.0, *)
final class RustStreamHost {
    private let engine: OpaquePointer
    private let queue = DispatchQueue(label: "org.telegram.MTProtoRust.streams")
    private var connections: [UInt64: nw_connection_t] = [:]
    private var paused = Set<UInt64>()

    init(engine: OpaquePointer) {
        self.engine = engine
    }

    func open(stream: UInt64, host: String, port: UInt16, serverName: String?, alpn: [String]) {
        self.queue.async { [self] in
            guard port != 0 else {
                self.report(stream: stream, error: "bad port \(port)")
                return
            }
            let queue = self.queue
            let configureTcp: nw_parameters_configure_protocol_block_t = { options in
                nw_tcp_options_set_no_delay(options, true)
                nw_tcp_options_set_connection_timeout(options, 15)
            }
            let parameters: nw_parameters_t
            if let serverName = serverName {
                parameters = nw_parameters_create_secure_tcp({ options in
                    let security = nw_tls_copy_sec_protocol_options(options)
                    sec_protocol_options_set_tls_server_name(security, serverName)
                    sec_protocol_options_set_tls_false_start_enabled(security, true)
                    for name in alpn {
                        sec_protocol_options_add_tls_application_protocol(security, name)
                    }
                    sec_protocol_options_set_verify_block(security, { _, _, complete in
                        complete(true)
                    }, queue)
                }, configureTcp)
            } else {
                parameters = nw_parameters_create()
                let tcp = nw_tcp_create_options()
                configureTcp(tcp)
                nw_protocol_stack_set_transport_protocol(nw_parameters_copy_default_protocol_stack(parameters), tcp)
            }
            let endpoint = nw_endpoint_create_host(host, "\(port)")
            let connection = nw_connection_create(endpoint, parameters)
            self.connections[stream] = connection
            nw_connection_set_queue(connection, queue)
            nw_connection_set_state_changed_handler(connection) { [weak self] state, error in
                self?.stateChanged(stream: stream, connection: connection, state: state, error: error)
            }
            nw_connection_start(connection)
        }
    }

    func write(stream: UInt64, data: Data) {
        self.queue.async { [self] in
            guard let connection = self.connections[stream] else {
                return
            }
            let count = data.count
            let content = data.withUnsafeBytes { DispatchData(bytes: $0) }
            nw_connection_send(connection, content as __DispatchData, _nw_content_context_default_message, true) { [weak self] error in
                guard let self = self, self.connections[stream] === connection else {
                    return
                }
                if let error = error {
                    self.fail(stream: stream, error: rustStreamErrorText(error))
                } else {
                    mt_stream_sent(self.engine, stream, count)
                }
            }
        }
    }

    func close(stream: UInt64) {
        self.queue.async {
            self.paused.remove(stream)
            if let connection = self.connections.removeValue(forKey: stream) {
                nw_connection_cancel(connection)
            }
        }
    }

    func resume(stream: UInt64) {
        self.queue.async {
            if self.paused.remove(stream) != nil, let connection = self.connections[stream] {
                self.receive(stream: stream, connection: connection)
            }
        }
    }

    private func stateChanged(stream: UInt64, connection: nw_connection_t, state: nw_connection_state_t, error: nw_error_t?) {
        guard self.connections[stream] === connection else {
            return
        }
        switch state {
        case nw_connection_state_ready:
            mt_stream_opened(self.engine, stream)
            self.receive(stream: stream, connection: connection)
        case nw_connection_state_waiting, nw_connection_state_failed:
            self.fail(stream: stream, error: error.map(rustStreamErrorText) ?? "connection failed")
        default:
            break
        }
    }

    private func receive(stream: UInt64, connection: nw_connection_t) {
        nw_connection_receive(connection, 1, 256 * 1024) { [weak self] content, _, isComplete, error in
            guard let self = self, self.connections[stream] === connection else {
                return
            }
            var more = true
            if let content = content {
                let data = content as DispatchData
                if !data.isEmpty {
                    more = Data(data).withUnsafeBytes { bytes -> Bool in
                        return mt_stream_received(self.engine, stream, MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count)) != 0
                    }
                }
            }
            if let error = error {
                self.fail(stream: stream, error: rustStreamErrorText(error))
            } else if isComplete {
                if let connection = self.connections.removeValue(forKey: stream) {
                    nw_connection_cancel(connection)
                }
                self.paused.remove(stream)
                self.report(stream: stream, error: nil)
            } else if more {
                self.receive(stream: stream, connection: connection)
            } else {
                self.paused.insert(stream)
            }
        }
    }

    private func fail(stream: UInt64, error: String) {
        if let connection = self.connections.removeValue(forKey: stream) {
            nw_connection_cancel(connection)
        }
        self.paused.remove(stream)
        self.report(stream: stream, error: error)
    }

    private func report(stream: UInt64, error: String?) {
        let text = error ?? ""
        text.withCString { pointer in
            mt_stream_closed(self.engine, stream, MTString(data: pointer, length: strlen(pointer)))
        }
    }
}

@available(macOS 10.14, iOS 12.0, *)
private func rustStreamErrorText(_ error: nw_error_t) -> String {
    let description = CFErrorCopyDescription(nw_error_copy_cf_error(error).takeRetainedValue()) as String
    return "nw error \(nw_error_get_error_domain(error).rawValue)/\(nw_error_get_error_code(error)): \(description)"
}

func rustStreamHostCallbacks() -> MTStreamHost {
    return MTStreamHost(
        open: { context, stream, target in
            guard let context = context, let target = target else {
                return
            }
            let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
            let alpn = rustEngineString(target.pointee.alpn).split(separator: ",").map(String.init)
            runtime.openStream(stream, host: rustEngineString(target.pointee.host), port: target.pointee.port, serverName: target.pointee.tls != 0 ? rustEngineString(target.pointee.server_name) : nil, alpn: alpn, carrier: target.pointee.carrier != 0)
        },
        write: { context, stream, bytes in
            guard let context = context, let data = bytes.data, bytes.length > 0 else {
                return
            }
            let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
            runtime.writeStream(stream, data: Data(bytes: data, count: bytes.length))
        },
        close: { context, stream in
            guard let context = context else {
                return
            }
            Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue().closeStream(stream)
        },
        resume: { context, stream in
            guard let context = context else {
                return
            }
            Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue().resumeStream(stream)
        }
    )
}
