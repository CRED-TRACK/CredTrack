import SwiftUI

struct AdvisorView: View {
    @StateObject private var vm = AdvisorViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ctBackground.ignoresSafeArea()

                switch vm.state {
                case .idle, .loading:
                    loadingView
                case .failed(let msg):
                    errorView(msg)
                case .loaded:
                    loadedScroll
                }
            }
            .navigationTitle("Advisor")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.chatSheetVisible = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.ctTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $vm.chatSheetVisible) {
                AdvisorChatPlaceholderSheet { vm.chatSheetVisible = false }
                    .presentationDetents([.height(360)])
            }
            .sheet(isPresented: $vm.categoryPickerVisible) {
                CategoryPickerSheet(
                    title: "Pick a category",
                    categories: vm.categories,
                    selected: vm.selectedCategory,
                    onSelect: { vm.selectedCategory = $0.code }
                )
            }
            .sheet(isPresented: $vm.bofaSheetVisible) {
                if let bofa = vm.bofaSection {
                    BofaCategoryChoiceSheet(
                        userCardId: bofa.userCardId,
                        currentChoice: vm.currentBofaChoice(),
                        onSave: { try await vm.saveBofaChoice($0) }
                    )
                }
            }
            .task { await vm.load() }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .tint(.ctTextPrimary)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(msg)
                .font(.ctBody)
                .foregroundColor(.ctTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            SynthButton(title: "Retry") { vm.reload() }
                .frame(height: 56)
                .padding(.horizontal, 30)
        }
    }

    private var loadedScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                bofaWarningBannerIfAny
                categoryChips
                categoryGroups
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private var bofaWarningBannerIfAny: some View {
        if let bofa = vm.bofaSection,
           bofa.warnings.contains(where: { $0.code == "BOA_3PCT_CHOICE_MISSING" }) {
            Button { vm.bofaSheetVisible = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pick your BofA 3% category")
                            .font(.ctCaption)
                            .foregroundColor(.ctTextPrimary)
                        Text("Unlock the bonus on Customized Cash Rewards")
                            .font(.ctMicro)
                            .foregroundColor(.ctTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.ctTextSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }

    private var categoryGroups: some View {
        let groups = vm.categoryGroups()
        return VStack(spacing: 10) {
            if groups.isEmpty {
                emptyState
                    .padding(.horizontal)
                    .padding(.top, 20)
            } else {
                ForEach(groups) { group in
                    CategoryRankingRow(group: group)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", code: nil)
                ForEach(activeCategoryList(), id: \.self) { code in
                    let name = vm.categories.first(where: { $0.code == code })?.displayName ?? code
                    chip(label: name, code: code)
                }
                Button {
                    vm.categoryPickerVisible = true
                } label: {
                    Text("More…")
                        .font(.ctCaption)
                        .foregroundColor(.ctTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ctSurface)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(label: String, code: String?) -> some View {
        let active = vm.selectedCategory == code
        return Button {
            vm.selectedCategory = code
        } label: {
            Text(label)
                .font(.ctCaption)
                .foregroundColor(active ? .black : .ctTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(active ? Color.NeoPop.NeoPaccha.c500 : Color.ctSurface)
                .clipShape(Capsule())
        }
    }

    private func activeCategoryList() -> [String] {
        if case .loaded(let dash) = vm.state { return dash.categoriesActive }
        return []
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.ctTextSecondary)
            Text(vm.selectedCategory == nil
                 ? "No cards yet. Add one in the Cards tab to see recommendations."
                 : "None of your cards reward this category. Try another.")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }
}
