import Foundation
import Combine

enum ZapretMode: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case compatible
    case aggressive

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fast:
            return "Быстрый"
        case .balanced:
            return "Баланс"
        case .compatible:
            return "Совместимый"
        case .aggressive:
            return "Агрессивный"
        }
    }

    var description: String {
        switch self {
        case .fast:
            return "Минимальное вмешательство. Может дать лучшую скорость."
        case .balanced:
            return "Средний режим. Хороший вариант для первого запуска."
        case .compatible:
            return "Мягкий режим для стабильности, если другие не работают."
        case .aggressive:
            return "Сильный режим обхода. Может помочь, но иногда снижает скорость."
        }
    }

    var tpwsArguments: String {
        switch self {
        case .fast:
            return "--split-pos=sni"
        case .balanced:
            return "--split-pos=midsld --split-any-protocol"
        case .compatible:
            return "--split-pos=2"
        case .aggressive:
            return "--split-pos=midsld --split-any-protocol --oob"
        }
    }
}

final class ZapretEngine: ObservableObject {
    @Published var isRunning = false
    @Published var isQuicBlocked = false
    @Published var log = "Готов к запуску...\n"
    @Published var selectedMode: ZapretMode = .balanced

    private var process: Process?

    private let proxyHost = "127.0.0.1"
    private let proxyPort = "8081"

    private var activeNetworkService: String {
        detectActiveNetworkService() ?? "Wi-Fi"
    }

    func start() {
        guard !isRunning else {
            appendLog("tpws уже запущен.\n")
            return
        }

        guard let tpwsPath = Bundle.main.path(forResource: "tpws", ofType: nil) else {
            appendLog("Ошибка: встроенный tpws не найден в приложении.\n")
            appendLog("Проверь, что файл tpws добавлен в Copy Bundle Resources.\n")
            return
        }

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: tpwsPath
        )

        let command = """
        \(tpwsPath) --bind-addr=\(proxyHost) --port=\(proxyPort) --socks \(selectedMode.tpwsArguments)
        """

        appendLog("Запуск zapret/tpws...\n")
        appendLog("Режим: \(selectedMode.title)\n")
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
                self?.appendLog("tpws остановлен.\n")
            }
        }

        do {
            try newProcess.run()
            process = newProcess
            isRunning = true

            appendLog("tpws запущен.\n")
            appendLog("SOCKS5-прокси: \(proxyHost):\(proxyPort)\n")

            enableSystemSocksProxy()
            enableQuicBlock()
        } catch {
            appendLog("Ошибка запуска: \(error.localizedDescription)\n")
        }
    }

    func stop() {
        guard let process else {
            appendLog("Процесс уже остановлен.\n")
            isRunning = false
            disableSystemSocksProxy()
            disableQuicBlock()
            return
        }

        process.terminate()
        self.process = nil
        isRunning = false

        appendLog("Остановка tpws...\n")
        disableSystemSocksProxy()
        disableQuicBlock()
    }

    func startAndOpenYouTube() {
        if !isRunning {
            start()
        }

        appendLog("Открываю YouTube...\n")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.openYouTubeInSafari()
        }
    }

    func openYouTubeInSafari() {
        let openProcess = Process()
        openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProcess.arguments = [
            "-a",
            "Safari",
            "https://www.youtube.com"
        ]

        do {
            try openProcess.run()
            appendLog("YouTube открыт в Safari.\n")
        } catch {
            appendLog("Ошибка открытия Safari: \(error.localizedDescription)\n")
        }
    }

    func checkProxy() {
        appendLog("Проверка прокси...\n")

        checkURL("https://google.com", name: "Google") { [weak self] googleWorks in
            guard let self else { return }

            if googleWorks {
                self.appendLog("Google через tpws работает ✅\n")
            } else {
                self.appendLog("Google через tpws не отвечает ❌\n")
            }

            self.checkURL("https://www.youtube.com", name: "YouTube") { youtubeWorks in
                if youtubeWorks {
                    self.appendLog("YouTube через tpws работает ✅\n")
                } else {
                    self.appendLog("YouTube через tpws не отвечает ❌\n")
                }
            }
        }
    }

    private func checkURL(_ url: String, name: String, completion: @escaping (Bool) -> Void) {
        appendLog("Проверяю \(name)...\n")

        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        checkProcess.arguments = [
            "-sS",
            "-L",
            "-I",
            "--proxy",
            "socks5h://\(proxyHost):\(proxyPort)",
            "--max-time",
            "20",
            url
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        checkProcess.standardOutput = outputPipe
        checkProcess.standardError = errorPipe

        checkProcess.terminationHandler = { [weak self] process in
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let outputText = String(data: outputData, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                if process.terminationStatus == 0 && outputText.contains("HTTP/") {
                    completion(true)
                } else {
                    self?.appendLog("\(name): код curl \(process.terminationStatus)\n")

                    if !errorText.isEmpty {
                        self?.appendLog("Ошибка \(name): \(errorText)\n")
                    }

                    completion(false)
                }
            }
        }

        do {
            try checkProcess.run()
        } catch {
            appendLog("Ошибка запуска проверки \(name): \(error.localizedDescription)\n")
            completion(false)
        }
    }

    func enableSystemSocksProxy() {
        let service = activeNetworkService

        appendLog("Включаю системный SOCKS-прокси macOS...\n")
        appendLog("Активная сеть: \(service)\n")

        let script = """
        do shell script "networksetup -setsocksfirewallproxy '\(service)' \(proxyHost) \(proxyPort) && networksetup -setsocksfirewallproxystate '\(service)' on" with administrator privileges
        """

        runAppleScript(script) { [weak self] success in
            if success {
                self?.appendLog("Системный SOCKS-прокси включён ✅\n")
            } else {
                self?.appendLog("Не удалось включить системный SOCKS-прокси ❌\n")
                self?.appendLog("Проверь активное сетевое подключение.\n")
            }
        }
    }

    func disableSystemSocksProxy() {
        let service = activeNetworkService

        appendLog("Выключаю системный SOCKS-прокси macOS...\n")
        appendLog("Активная сеть: \(service)\n")

        let script = """
        do shell script "networksetup -setsocksfirewallproxystate '\(service)' off" with administrator privileges
        """

        runAppleScript(script) { [weak self] success in
            if success {
                self?.appendLog("Системный SOCKS-прокси выключен ✅\n")
            } else {
                self?.appendLog("Не удалось выключить системный SOCKS-прокси ❌\n")
            }
        }
    }

    func enableQuicBlock() {
        appendLog("Включаю блокировку QUIC / HTTP3...\n")

        let script = """
        do shell script "echo 'block drop out quick proto udp from any to any port 443' > /tmp/macbyedpi_quic.conf && /sbin/pfctl -a com.apple/macbyedpi -f /tmp/macbyedpi_quic.conf && /sbin/pfctl -E >/dev/null 2>&1 || true" with administrator privileges
        """

        runAppleScript(script) { [weak self] success in
            if success {
                self?.isQuicBlocked = true
                self?.appendLog("QUIC / HTTP3 заблокирован ✅\n")
            } else {
                self?.appendLog("Не удалось заблокировать QUIC ❌\n")
            }
        }
    }

    func disableQuicBlock() {
        appendLog("Выключаю блокировку QUIC / HTTP3...\n")

        let script = """
        do shell script "/sbin/pfctl -a com.apple/macbyedpi -F all >/dev/null 2>&1 || true" with administrator privileges
        """

        runAppleScript(script) { [weak self] success in
            if success {
                self?.isQuicBlocked = false
                self?.appendLog("QUIC / HTTP3 разблокирован ✅\n")
            } else {
                self?.appendLog("Не удалось разблокировать QUIC ❌\n")
            }
        }
    }

    private func detectActiveNetworkService() -> String? {
        guard let interfaceName = getDefaultNetworkInterface() else {
            appendLog("Не удалось определить активный сетевой интерфейс.\n")
            return nil
        }

        appendLog("Активный интерфейс: \(interfaceName)\n")

        guard let serviceName = getNetworkServiceName(for: interfaceName) else {
            appendLog("Не удалось определить имя сетевой службы для \(interfaceName).\n")
            return nil
        }

        return serviceName
    }

    private func getDefaultNetworkInterface() -> String? {
        let output = runShellCommand(
            "/sbin/route",
            arguments: ["get", "default"]
        )

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("interface:") {
                return trimmed
                    .replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    private func getNetworkServiceName(for interfaceName: String) -> String? {
        let output = runShellCommand(
            "/usr/sbin/networksetup",
            arguments: ["-listallhardwareports"]
        )

        let lines = output.components(separatedBy: .newlines)

        var currentHardwarePort: String?

        for line in lines {
            if line.hasPrefix("Hardware Port:") {
                currentHardwarePort = line
                    .replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            if line.hasPrefix("Device:") {
                let device = line
                    .replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if device == interfaceName {
                    return currentHardwarePort
                }
            }
        }

        return nil
    }

    private func runShellCommand(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func runAppleScript(_ source: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var error: NSDictionary?

            guard let script = NSAppleScript(source: source) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            script.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let error {
                    self.appendLog("AppleScript error: \(error)\n")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    func clearLog() {
        log = "Лог очищен.\n"
    }

    private func appendLog(_ message: String) {
        log += message
    }
}
