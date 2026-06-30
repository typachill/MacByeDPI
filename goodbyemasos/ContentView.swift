import SwiftUI

struct ContentView: View {
    @StateObject private var engine = ZapretEngine()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.13),
                    Color(red: 0.12, green: 0.13, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                statusCard
                modePicker
                mainPowerButton
                actionButtons
                logView
            }
            .padding(28)
        }
        .frame(width: 640, height: 640)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("MacByeDPI")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("zapret / tpws для macOS")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(engine.isRunning ? Color.green : Color.gray)
                .frame(width: 14, height: 14)
                .shadow(
                    color: engine.isRunning ? .green.opacity(0.8) : .clear,
                    radius: 8
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(engine.isRunning ? "Работает" : "Выключено")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text("SOCKS5: 127.0.0.1:8081")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text("Режим: \(engine.selectedMode.title)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text(engine.isQuicBlocked ? "QUIC / HTTP3: заблокирован" : "QUIC / HTTP3: выключен")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(engine.isQuicBlocked ? .green.opacity(0.85) : .white.opacity(0.45))
            }

            Spacer()

            Text(engine.isRunning ? "ACTIVE" : "OFF")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(engine.isRunning ? .green : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(engine.isRunning ? Color.green.opacity(0.13) : Color.gray.opacity(0.15))
                )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var modePicker: some View {
        VStack(spacing: 8) {
            Text("Режим обхода")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            Picker("Режим", selection: $engine.selectedMode) {
                ForEach(ZapretMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(engine.isRunning)
            .frame(width: 520)

            Text(engine.selectedMode.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(width: 520)
        }
    }

    private var mainPowerButton: some View {
        Button {
            if engine.isRunning {
                engine.stop()
            } else {
                engine.start()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(engine.isRunning ? Color.red.opacity(0.20) : Color.blue.opacity(0.22))
                    .frame(width: 116, height: 116)
                    .shadow(
                        color: engine.isRunning ? .red.opacity(0.35) : .blue.opacity(0.35),
                        radius: 24
                    )

                Circle()
                    .fill(engine.isRunning ? Color.red.opacity(0.85) : Color.blue.opacity(0.85))
                    .frame(width: 84, height: 84)

                Image(systemName: "power")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                engine.startAndOpenYouTube()
            } label: {
                Label("Открыть YouTube", systemImage: "play.rectangle.fill")
                    .frame(width: 190, height: 40)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                engine.checkProxy()
            } label: {
                Label("Проверить", systemImage: "checkmark.shield.fill")
                    .frame(width: 150, height: 40)
            }
            .disabled(!engine.isRunning)
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Лог")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button("Очистить") {
                    engine.clearLog()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
            }

            ScrollView {
                Text(engine.log)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.65) : Color.blue.opacity(0.9))
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.65 : 0.9))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12))
            )
    }
}
