import SwiftUI

struct EqualizerView: View {
    @State private var gains: [Float] = Array(repeating: 0, count: 10)
    @State private var rate: Float = 1.0
    @State private var bypass = false

    private let labels = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    private let presets: [(String, [Float])] = [
        ("平坦", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ("流行", [-1, 2, 4, 3, 0, -1, -1, 1, 3, 2]),
        ("摇滚", [5, 4, 2, 0, -1, -1, 1, 3, 4, 5]),
        ("人声", [-3, -2, 0, 3, 5, 5, 3, 1, 0, -2]),
        ("夜听", [4, 3, 1, -1, -2, -1, 1, 2, 3, 4])
    ]
    private let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    presetCard
                    bandCard
                    rateCard
                    Text("音效只在播放本地缓存文件时生效。第一次播放某首歌走网络流，第二次起读本地文件，才会套用这里的 EQ 与倍速。")
                        .font(.system(size: 9.5))
                        .lineSpacing(2)
                        .foregroundStyle(IsleColor.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("音效")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for i in 0..<10 {
                gains[i] = AudioFX.shared.gain(band: i)
            }
            rate = AudioFX.shared.playbackRate
        }
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("预设").font(.system(size: 11, weight: .bold)).tracking(1)
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    bypass.toggle()
                    AudioFX.shared.setBypass(bypass)
                } label: {
                    Text(bypass ? "已关闭" : "已开启")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(bypass ? IsleColor.textFaint : IsleColor.mint)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { name, values in
                        Button {
                            apply(values)
                        } label: {
                            Text(name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(IsleColor.surfaceHi)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bandCard: some View {
        VStack(spacing: 10) {
            ForEach(0..<10, id: \.self) { i in
                HStack(spacing: 10) {
                    Text(labels[i])
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 34, alignment: .leading)

                    Slider(value: Binding(
                        get: { Double(gains[i]) },
                        set: { v in
                            gains[i] = Float(v)
                            AudioFX.shared.setGain(Float(v), band: i)
                        }
                    ), in: -24...24)
                    .tint(IsleColor.pink)

                    Text(String(format: "%+.0f", gains[i]))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(gains[i] == 0 ? IsleColor.textFaint : IsleColor.pinkLight)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("播放速度").font(.system(size: 11, weight: .bold)).tracking(1)
                .foregroundStyle(Color.white.opacity(0.5))

            HStack(spacing: 6) {
                ForEach(rates, id: \.self) { r in
                    Button {
                        rate = r
                        AudioFX.shared.playbackRate = r
                    } label: {
                        Text(r == 1.0 ? "1x" : String(format: "%.2gx", r))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(rate == r ? Color.white : Color.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(rate == r ? AnyView(IsleColor.accent) : AnyView(Color.white.opacity(0.06)))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func apply(_ values: [Float]) {
        for i in 0..<min(10, values.count) {
            gains[i] = values[i]
            AudioFX.shared.setGain(values[i], band: i)
        }
    }
}
