import Foundation
import Combine

enum DNSMode: String, CaseIterable, Identifiable {
    case auto
    case system
    case https
    case udp

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .system:
            return "System"
        case .https:
            return "HTTPS"
        case .udp:
            return "UDP"
        }
    }

    var spoofDPIValue: String {
        switch self {
        case .auto:
            return "system"
        case .system:
            return "system"
        case .https:
            return "https"
        case .udp:
            return "udp"
        }
    }
}

final class SpoofDPIEngine: ObservableObject {
    @Published var isRunning = false
    @Published var log = "Готов к запуску...\n"
    @Published var selectedDNSMode: DNSMode = .auto

    private var process: Process?

    func start() {
        guard !isRunning else { return }

        guard let spoofDPIPath = Bundle.main.path(forResource: "spoofdpi", ofType: nil) else {
            appendLog("Ошибка: встроенный spoofdpi не найден в приложении\n")
            return
        }

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: spoofDPIPath
        )

        let dnsMode = selectedDNSMode.spoofDPIValue

        let command = "\(spoofDPIPath) --dns-mode \(dnsMode) --listen-addr 127.0.0.1:8080 --auto-configure-network true --no-tui true"

        appendLog("Запуск с DNS mode: \(selectedDNSMode.title)\n")
        appendLog("Команда: \(command)\n")

        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        newProcess.arguments = [
            "-lc",
            command
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        newProcess.standardOutput = outputPipe
        newProcess.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }

            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }

            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        newProcess.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.appendLog("SpoofDPI остановлен.\n")
            }
        }

        do {
            try newProcess.run()
            process = newProcess
            isRunning = true
            appendLog("SpoofDPI запущен.\n")
        } catch {
            appendLog("Ошибка запуска: \(error.localizedDescription)\n")
        }
    }

    func stop() {
        guard let process else {
            appendLog("Процесс уже остановлен.\n")
            isRunning = false
            return
        }

        process.terminate()
        self.process = nil
        isRunning = false
        appendLog("Остановка SpoofDPI...\n")
    }

    func checkProxy() {
        appendLog("Проверка прокси...\n")

        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        checkProcess.arguments = [
            "-I",
            "-x",
            "http://127.0.0.1:8080",
            "https://google.com",
            "--max-time",
            "8"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        checkProcess.standardOutput = outputPipe
        checkProcess.standardError = errorPipe

        checkProcess.terminationHandler = { [weak self] _ in
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let outputText = String(data: outputData, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                if outputText.contains("HTTP/1.1 200 Connection Established") ||
                    outputText.contains("HTTP/2 301") ||
                    outputText.contains("HTTP/2 200") ||
                    outputText.contains("HTTP/1.1 301") ||
                    outputText.contains("HTTP/1.1 200") {
                    self?.appendLog("Прокси работает ✅\n")
                } else {
                    self?.appendLog("Прокси не отвечает ❌\n")
                    self?.appendLog(outputText)
                    self?.appendLog(errorText)
                }
            }
        }

        do {
            try checkProcess.run()
        } catch {
            appendLog("Ошибка проверки: \(error.localizedDescription)\n")
        }
    }

    private func appendLog(_ message: String) {
        log += message
    }
}
