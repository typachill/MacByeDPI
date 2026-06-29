import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SpoofDPIEngine()

    var body: some View {
        VStack(spacing: 20) {
            Text("MacByeDPI")
                .font(.largeTitle)
                .bold()

            Text(engine.isRunning ? "Статус: работает" : "Статус: выключено")
                .font(.headline)
                .foregroundStyle(engine.isRunning ? .green : .secondary)

            Picker("DNS mode", selection: $engine.selectedDNSMode) {
                ForEach(DNSMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(engine.isRunning)
            .frame(width: 360)

            HStack(spacing: 12) {
                Button(engine.isRunning ? "Выключить" : "Включить") {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.start()
                    }
                }
                .frame(width: 160, height: 36)

                Button("Проверить") {
                    engine.checkProxy()
                }
                .disabled(!engine.isRunning)
                .frame(width: 120, height: 36)
            }

            Divider()

            ScrollView {
                Text(engine.log)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 170)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(24)
        .frame(width: 560, height: 400)
    }
}
