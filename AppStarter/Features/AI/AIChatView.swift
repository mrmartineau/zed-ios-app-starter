import SwiftUI

/// A streaming chat screen over `AnthropicClient`.
///
/// The key field at the bottom exists so the module can be tried out in a
/// simulator without a backend. Delete it — and switch `AnthropicClient` to a
/// `.proxy` configuration — before shipping; see the warning at the top of
/// `AnthropicClient.swift`.
struct AIChatView: View {
    @State private var model = ChatModel()
    @State private var showingKeySheet = false

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            composer
        }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Clear conversation", systemImage: "trash", role: .destructive) {
                        model.clear()
                    }
                    Button("API key", systemImage: "key") {
                        showingKeySheet = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingKeySheet) {
            APIKeySheet()
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if model.messages.isEmpty {
                        ContentUnavailableView(
                            "Ask something",
                            systemImage: "sparkles",
                            description: Text("Replies stream in as they're generated.")
                        )
                        .padding(.top, Theme.Spacing.xl)
                    }

                    ForEach(Array(model.messages.enumerated()), id: \.offset) { index, message in
                        Bubble(message: message)
                            .id(index)
                    }

                    if model.wasRefused {
                        Notice(
                            symbol: "hand.raised",
                            text: "The assistant declined to answer that.",
                            tint: .orange
                        )
                    }

                    if let error = model.errorMessage {
                        Notice(symbol: "exclamationmark.triangle", text: error, tint: .red)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            // Follow the tail as text streams in. Keyed on the character count
            // of the last message so it fires on every chunk, not just new turns.
            .onChange(of: model.messages.last?.text.count) { _, _ in
                guard let last = model.messages.indices.last else { return }
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            TextField("Message", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            if model.isStreaming {
                Button("Stop", systemImage: "stop.circle.fill") { model.stop() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill") { model.send() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(!model.canSend)
            }
        }
        .padding(Theme.Spacing.md)
    }
}

private struct Bubble: View {
    let message: AnthropicClient.Message

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: Theme.Spacing.xl) }

            Text(message.text.isEmpty ? "…" : message.text)
                .padding(Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(isUser ? Theme.accent.opacity(0.15) : Color(uiColor: .secondarySystemBackground))
                )
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                .textSelection(.enabled)

            if !isUser { Spacer(minLength: Theme.Spacing.xl) }
        }
        .accessibilityLabel(isUser ? "You said" : "Assistant said")
        .accessibilityValue(message.text)
    }
}

private struct Notice: View {
    var symbol: String
    var text: String
    var tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Development-only key entry. See the file header.
private struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("For trying this out on your own device. A key inside a shipped app can be extracted — route production traffic through your own server instead.")
                }

                Section {
                    Button("Remove stored key", role: .destructive) {
                        KeychainStore.set(nil, for: AnthropicClient.apiKeyKeychainKey)
                        key = ""
                        dismiss()
                    }
                }
            }
            .navigationTitle("API key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainStore.set(key, for: AnthropicClient.apiKeyKeychainKey)
                        dismiss()
                    }
                    .disabled(key.isEmpty)
                }
            }
            .onAppear {
                key = KeychainStore.string(for: AnthropicClient.apiKeyKeychainKey) ?? ""
            }
        }
    }
}

#Preview {
    NavigationStack { AIChatView() }
}
