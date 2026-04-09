import SwiftUI
import UIKit
import Synth

struct ProfileView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var gmailManager: GmailConnectionManager
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                Spacer().frame(height: 36)
                statsSection
                Spacer().frame(height: 36)
                accountSection
                Spacer().frame(height: 36)
                integrationsSection
                Spacer().frame(height: 40)
                signOutButton
                Spacer().frame(height: 56)
            }
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .task { await vm.load() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 52)

            // Avatar ring + Synth neumorphic circle
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.ctGold, Color.ctGold.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 96, height: 96)

                SynthAvatarView(initials: vm.userInitials)
                    .frame(width: 88, height: 88)
            }

            Spacer().frame(height: 20)

            Text(vm.userName)
                .font(.ctDisplay)
                .foregroundColor(.ctTextPrimary)

            Spacer().frame(height: 6)

            Text(vm.userEmail)
                .font(.ctCaption)
                .foregroundColor(.ctTextSecondary)

            Spacer().frame(height: 18)

            // Member-since badge
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("SINCE \(vm.memberSince.uppercased())")
                    .font(.ctMicro)
                    .kerning(0.5)
            }
            .foregroundColor(.ctGold)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.ctGold.opacity(0.10))
                    .overlay(Capsule().strokeBorder(Color.ctGold.opacity(0.30), lineWidth: 1))
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatTileView(
                value: vm.isLoadingStats ? "–" : "\(vm.stats?.totalCards ?? 0)",
                label: "CARDS"
            )
            .frame(maxWidth: .infinity, minHeight: 84)

            StatTileView(
                value: vm.isLoadingStats ? "–" : limitString(vm.stats?.totalLimit),
                label: "LIMIT"
            )
            .frame(maxWidth: .infinity, minHeight: 84)

            StatTileView(
                value: vm.isLoadingStats ? "–" : "\(vm.stats?.activeCards ?? 0)",
                label: "ACTIVE"
            )
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .padding(.horizontal, 20)
    }

    private func limitString(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.1fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    // MARK: - Account section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ACCOUNT")
            VStack(spacing: 0) {
                ProfileRow(icon: "person.fill",   label: "Display Name", value: vm.userName)
                rowDivider
                ProfileRow(icon: "envelope.fill", label: "Email",        value: vm.userEmail)
                rowDivider
                ProfileRow(icon: "calendar",      label: "Member Since", value: vm.memberSince)
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Integrations

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("INTEGRATIONS")
            VStack(spacing: 0) {
                GmailIntegrationRow(manager: gmailManager)
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .alert("Gmail Connection", isPresented: .constant(gmailManager.connectError != nil)) {
            Button("OK") { gmailManager.connectError = nil }
        } message: {
            Text(gmailManager.connectError ?? "")
        }
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        NeoPopElevatedButton(
            title:      "Sign Out",
            faceColor:  UIColor.NeoPop.State.error300,
            labelColor: .white
        ) {
            appState.signOut()
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.ctMicro)
            .foregroundColor(.ctTextSecondary)
            .padding(.leading, 4)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let icon:        String
    let label:       String
    let value:       String
    var showChevron: Bool       = false
    var action:      (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.ctGold)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.ctGold.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.ctMicro)
                        .foregroundColor(.ctTextSecondary)
                    if !value.isEmpty {
                        Text(value)
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if showChevron {
                    NeoPopIcons.chevron
                        .renderingMode(.template)
                        .foregroundColor(.ctTextSecondary)
                        .frame(width: 8, height: 11)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Gmail Integration Row

private struct GmailIntegrationRow: View {
    @ObservedObject var manager: GmailConnectionManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(manager.isConnected ? Color.green : .ctGold)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        manager.isConnected
                            ? Color.green.opacity(0.12)
                            : Color.ctGold.opacity(0.12)
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Gmail")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                Text(manager.isConnected
                     ? (manager.gmailAddress ?? "Connected")
                     : "Not connected")
                    .font(.ctBody)
                    .foregroundColor(manager.isConnected ? .ctTextPrimary : .ctTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if manager.isConnecting {
                ProgressView()
                    .tint(.ctGold)
                    .scaleEffect(0.8)
            } else if manager.isConnected {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                        Text("Connected")
                            .font(.ctMicro)
                            .foregroundColor(.green)
                    }
                    Button {
                        manager.startOAuth()
                    } label: {
                        Text("Reconnect")
                            .font(.ctMicro)
                            .foregroundColor(.ctGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.ctGold.opacity(0.10))
                                    .overlay(Capsule().strokeBorder(Color.ctGold.opacity(0.40), lineWidth: 1))
                            )
                    }
                }
            } else {
                Button {
                    manager.startOAuth()
                } label: {
                    Text("Connect")
                        .font(.ctMicro)
                        .foregroundColor(.ctGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.ctGold.opacity(0.10))
                                .overlay(Capsule().strokeBorder(Color.ctGold.opacity(0.40), lineWidth: 1))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Synth Avatar

private struct SynthAvatarView: UIViewRepresentable {
    let initials: String
    func makeUIView(context: Context) -> SynthAvatarUIView { SynthAvatarUIView(initials: initials) }
    func updateUIView(_ uiView: SynthAvatarUIView, context: Context) { uiView.setInitials(initials) }
}

private final class SynthAvatarUIView: UIView {
    private let label      = UILabel()
    private var neuApplied = false

    init(initials: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor.NeoPop.Black.c300
        clipsToBounds   = false
        label.font          = .gilroy(.bold, size: 26)
        label.textColor     = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setInitials(initials)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setInitials(_ text: String) { label.text = text }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        layer.cornerRadius = bounds.width / 2
        guard !neuApplied else { return }
        neuApplied = true
        var neu = NeuConstants.NeuViewModel(baseColor: UIColor.NeoPop.Black.c300)
        neu.lightShadowModel = NeuConstants.NeuShadowModel(
            xOffset: -8, yOffset: -8, blur: 20, spread: -2,
            color: UIColor.NeoPop.Black.c200, opacity: 0.25
        )
        neu.darkShadowModel = NeuConstants.NeuShadowModel(
            xOffset: 8, yOffset: 8, blur: 20, spread: -1,
            color: .black, opacity: 0.90
        )
        applyNeuStyle(model: neu)
    }
}

// MARK: - Stat Tile

private struct StatTileView: UIViewRepresentable {
    let value: String
    let label: String
    func makeUIView(context: Context) -> StatTileUIView { StatTileUIView(value: value, label: label) }
    func updateUIView(_ uiView: StatTileUIView, context: Context) { uiView.update(value: value, label: label) }
}

private final class StatTileUIView: UIView {
    private let valueLabel = UILabel()
    private let nameLabel  = UILabel()
    private var neuApplied = false

    init(value: String, label: String) {
        super.init(frame: .zero)
        backgroundColor    = UIColor.NeoPop.Black.c300
        layer.cornerRadius = 14
        clipsToBounds      = false

        valueLabel.font      = .gilroy(.bold, size: 20)
        valueLabel.textColor = .white
        valueLabel.textAlignment            = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor       = 0.7

        nameLabel.font          = .gilroy(.medium, size: 10)
        nameLabel.textColor     = UIColor.NeoPop.Black.c100
        nameLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, nameLabel])
        stack.axis      = .vertical
        stack.spacing   = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
        update(value: value, label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(value: String, label: String) {
        valueLabel.text = value
        nameLabel.text  = label
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty, !neuApplied else { return }
        neuApplied = true
        var neu = NeuConstants.NeuViewModel(baseColor: UIColor.NeoPop.Black.c300)
        neu.lightShadowModel = NeuConstants.NeuShadowModel(
            xOffset: -4, yOffset: -4, blur: 12, spread: -1,
            color: UIColor.NeoPop.Black.c200, opacity: 0.20
        )
        neu.darkShadowModel = NeuConstants.NeuShadowModel(
            xOffset: 4, yOffset: 4, blur: 12, spread: -1,
            color: .black, opacity: 0.85
        )
        applyNeuStyle(model: neu)
    }
}

