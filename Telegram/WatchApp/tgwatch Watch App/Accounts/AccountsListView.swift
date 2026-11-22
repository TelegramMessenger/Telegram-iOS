import SwiftUI

struct AccountsListView: View {
    @Environment(AccountManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false
    @State private var pendingRemoval: UUID?

    private var rows: [AccountListRow] {
        AccountListProjection.rows(
            accounts: manager.accounts,
            activeAccountId: manager.activeAccountId
        )
    }

    var body: some View {
        List {
            if let err = manager.lastError {
                Section {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("accountManagerError")
                }
            }
            ForEach(rows) { row in
                accountRow(row)
                    .accessibilityIdentifier("accountRow.\(row.id.uuidString)")
            }
            Section {
                HStack {
                    Text("+ Add account")
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        await manager.addAccount(useTestDc: false)
                        dismiss()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) { showAddSheet = true }
                .accessibilityIdentifier("addAccountButton")
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Choose server",
            isPresented: $showAddSheet,
            titleVisibility: .visible
        ) {
            Button("Production") {
                Task {
                    await manager.addAccount(useTestDc: false)
                    dismiss()
                }
            }
            Button("Test (developers)") {
                Task {
                    await manager.addAccount(useTestDc: true)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Remove this account?",
            isPresented: removalBinding,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let id = pendingRemoval {
                    Task {
                        if id == manager.activeAccountId {
                            await manager.removeActive()
                        } else {
                            await manager.remove(accountId: id)
                        }
                    }
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )
    }

    @ViewBuilder
    private func accountRow(_ row: AccountListRow) -> some View {
        // Plain HStack + explicit gestures. A SwiftUI `Button` paired with
        // `onLongPressGesture` swallows the long press on watchOS — the
        // button's tap fires on touch-down regardless of duration. Splitting
        // tap and long-press into peer gestures lets both fire independently.
        HStack(spacing: 8) {
            Image(systemName: row.isActive ? "circle.inset.filled" : "circle")
                .foregroundStyle(row.isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.body)
                    .lineLimit(1)
                if row.showsTestPill {
                    Text("TEST")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.25), in: Capsule())
                        .foregroundStyle(.yellow)
                        .accessibilityIdentifier("dcTestBadge")
                }
            }
            Spacer()
            if row.isActive {
                Text("active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard row.id != manager.activeAccountId else { return }
            Task {
                await manager.switchTo(accountId: row.id)
                dismiss()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            pendingRemoval = row.id
        }
    }
}
