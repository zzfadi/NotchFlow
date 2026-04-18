import SwiftUI

/// Plugin settings — defaults for the installer plus a read-out of
/// currently-installed identities. Hooks for "set preferred install
/// scope" and "cleanup unused plugin caches" land in future passes.
struct PluginsSettingsSection: View {
    @ObservedObject private var configStore = AIConfigStore.shared
    @ObservedObject private var marketplaceStore = MetaMarketplaceStore.shared

    var body: some View {
        Form {
            Section("Installed plugins") {
                if marketplaceStore.installedIdentities.isEmpty {
                    Text("No plugins installed yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(marketplaceStore.installedIdentities), id: \.self) { identity in
                        HStack {
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(identity.pluginName)
                                    .font(.body)
                                Text(identity.canonicalSource)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if configStore.snapshot.enabledIdentities.contains(identity) {
                                Text("enabled")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            Section("About plugin installs") {
                Text("NotchFlow installs Claude Code and Cursor plugins through each tool's native install path. File-copy marketplaces (awesome-copilot style) write a `.notchflow-provenance.json` sidecar next to the copied files so they still appear with a badge on the next scan.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
    }
}

#Preview {
    PluginsSettingsSection()
        .frame(width: 450, height: 400)
}
