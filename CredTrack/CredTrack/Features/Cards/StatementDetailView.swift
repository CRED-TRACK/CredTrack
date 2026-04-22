import SwiftUI
import UniformTypeIdentifiers

struct StatementDetailView: View {
    @State var statement: CardStatementDTO
    let card:             UserCardDTO

    @Environment(\.dismiss) private var dismiss

    @State private var showMarkPaidSheet  = false
    @State private var isMarkingPaid      = false
    @State private var markPaidError: String? = nil
    @State private var showDocumentPicker = false
    @State private var isUploadingPdf     = false
    @State private var uploadError: String? = nil
    @State private var uploadSuccess       = false
    @State private var showPdfViewer      = false
    @State private var pdfViewerData: Data? = nil
    @State private var isLoadingPdf       = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    balanceHero
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    detailsSection
                    Spacer().frame(height: 32)
                    actionButtons
                    uploadPdfSection
                    Spacer().frame(height: 48)
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                Color(hex: card.faceColor)
                    .opacity(0.12)
                    .frame(height: 260)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color.ctBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Color.ctBackground
            }
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showDocumentPicker) {
            StatementPdfPicker { pdfData in
                Task { await uploadPdf(data: pdfData) }
            }
        }
        .sheet(isPresented: $showPdfViewer) {
            if let data = pdfViewerData {
                StatementPdfViewerSheet(data: data, filename: pdfFilename)
            }
        }
        .sheet(isPresented: $showMarkPaidSheet) {
            MarkPaidSheet(statement: statement) { date, amount in
                Task { await markPaid(date: date, amount: amount) }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            CTBackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(monthYear)
                    .font(.ctTitle)
                    .foregroundColor(.ctTextPrimary)
                Text(card.nickname ?? card.productName)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            // Right slot — paid badge or mark-as-paid button
            if statement.isPaid == true {
                Label("Paid", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.NeoPop.State.success300))
                    .transition(.scale.combined(with: .opacity))
            } else {
                NeoPopElevatedButton(
                    title:          "Mark as Paid",
                    faceColor:      .clear,
                    labelColor:     UIColor.NeoPop.State.success300,
                    superViewColor: .clear,
                    borderColor:    UIColor.NeoPop.State.success300,
                    fontSize:       12
                ) {
                    showMarkPaidSheet = true
                }
                .frame(width: 120, height: 34)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: statement.isPaid)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Balance hero

    private var balanceHero: some View {
        VStack(spacing: 6) {
            if let balance = statement.statementBalance {
                Text(formatCurrency(balance))
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .foregroundColor(.ctTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.ctTextSecondary)
            }
            Text("Statement Balance")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
    }

    // MARK: - Details section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("DETAILS")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .padding(.leading, 4)
                Spacer()
                if let urlStr = statement.viewStatementUrl, let link = URL(string: urlStr) {
                    NeoPopElevatedButton(
                        title:          "View Statement",
                        faceColor:      .white,
                        labelColor:     .black,
                        superViewColor: .popDeepBlack,
                        fontSize:       12
                    ) {
                        UIApplication.shared.open(link)
                    }
                    .frame(width: 140, height: 34)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                if let sd = statement.statementDate {
                    StmtInfoRow(icon: "doc.text.fill",
                                label: "Statement Date",
                                value: formatDate(sd))
                    divider
                }

                if let dd = statement.dueDate {
                    StmtInfoRow(icon: "calendar",
                                label: "Payment Due",
                                value: formatDate(dd),
                                valueColor: dueDateColor)
                    if statement.minimumDue != nil || statement.bank != nil { divider }
                }

                if let md = statement.minimumDue {
                    StmtInfoRow(icon: "exclamationmark.circle.fill",
                                label: "Minimum Due",
                                value: formatCurrency(md))
                    if statement.bank != nil { divider }
                }

                if let bank = statement.bank {
                    StmtInfoRow(icon: "building.columns.fill",
                                label: "Bank",
                                value: bank)
                }

                if statement.isPaid == true {
                    divider
                    if let pd = statement.paymentDate {
                        StmtInfoRow(icon: "checkmark.circle.fill",
                                    label: "Payment Date",
                                    value: formatDate(pd),
                                    valueColor: Color(UIColor.NeoPop.State.success300))
                    }
                    if let pa = statement.paidAmount {
                        divider
                        StmtInfoRow(icon: "dollarsign.circle.fill",
                                    label: "Amount Paid",
                                    value: formatCurrency(pa),
                                    valueColor: Color(UIColor.NeoPop.State.success300))
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Action buttons (Pay Now only — Mark as Paid moved to nav bar)

    @ViewBuilder
    private var actionButtons: some View {
        if statement.isPaid != true,
           let urlStr = statement.makePaymentUrl,
           let link = URL(string: urlStr) {
            NeoPopFloatingButton(
                title:      "Pay Now",
                shimmer:    true,
                faceColor:  UIColor.NeoPop.State.success300,
                labelColor: .white,
                showArrow:  false
            ) {
                UIApplication.shared.open(link)
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
        }
    }

    private func markPaid(date: String, amount: Double?) async {
        isMarkingPaid = true
        do {
            let updated = try await APIClient.shared.markStatementPaid(
                statementId: statement.id,
                paymentDate: date,
                paidAmount:  amount
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                statement = updated
            }
        } catch {
            markPaidError = "Failed to mark paid. Try again."
        }
        isMarkingPaid = false
    }

    // MARK: - Upload PDF

    @ViewBuilder
    private var uploadPdfSection: some View {
        VStack(spacing: 10) {

            // ── Already-uploaded card ─────────────────────────────────────────
            if statement.hasPdf == true {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(pdfStatusColor)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.NeoPop.Black.c200))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Statement PDF")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            Text(pdfStatusLabel)
                                .font(.ctBody)
                                .foregroundColor(pdfStatusColor)
                        }
                        Spacer()

                        // View button
                        Button {
                            Task { await viewPdf() }
                        } label: {
                            if isLoadingPdf {
                                ProgressView()
                                    .tint(.ctTextPrimary)
                            } else {
                                Label("View", systemImage: "doc.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.ctTextPrimary)
                            }
                        }
                        .disabled(isLoadingPdf)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(pdfStatusColor.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            // ── Success flash ─────────────────────────────────────────────────
            if uploadSuccess {
                Label("PDF uploaded successfully", systemImage: "checkmark.circle.fill")
                    .font(.ctMicro)
                    .foregroundColor(Color(UIColor.NeoPop.State.success300))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            // ── Error ─────────────────────────────────────────────────────────
            if let err = uploadError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.ctMicro)
                    .foregroundColor(Color(UIColor.NeoPop.State.error300))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            // ── Upload / Replace button ───────────────────────────────────────
            NeoPopElevatedButton(
                title:          uploadButtonTitle,
                faceColor:      .white,
                labelColor:     .popDeepBlack,
                superViewColor: .popDeepBlack,
                fontSize:       15
            ) {
                uploadError  = nil
                uploadSuccess = false
                showDocumentPicker = true
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
            .disabled(isUploadingPdf)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: statement.hasPdf)
        .animation(.easeInOut(duration: 0.3), value: uploadSuccess)
        .animation(.easeInOut(duration: 0.3), value: uploadError)
        .padding(.top, 12)
    }

    private var uploadButtonTitle: String {
        if isUploadingPdf { return "Uploading…" }
        return statement.hasPdf == true ? "Replace PDF" : "Upload Statement PDF"
    }

    private var pdfStatusLabel: String {
        switch statement.pdfStatus {
        case "PENDING":   return "Processing…"
        case "EXTRACTED": return "Analysed"
        case "FAILED":    return "Processing failed"
        default:          return "Uploaded"
        }
    }

    private var pdfStatusColor: Color {
        switch statement.pdfStatus {
        case "PENDING":   return Color(UIColor.NeoPop.State.warning300)
        case "EXTRACTED": return Color(UIColor.NeoPop.State.success300)
        case "FAILED":    return Color(UIColor.NeoPop.State.error300)
        default:          return .ctTextSecondary
        }
    }

    private func viewPdf() async {
        isLoadingPdf = true
        do {
            let data = try await APIClient.shared.downloadStatementPdf(statementId: statement.id)
            pdfViewerData = data
            showPdfViewer = true
        } catch {
            uploadError = "Could not load PDF. Try again."
        }
        isLoadingPdf = false
    }

    private func uploadPdf(data: Data) async {
        isUploadingPdf = true
        uploadError    = nil
        uploadSuccess  = false
        do {
            let updated = try await APIClient.shared.uploadStatementPdf(
                statementId: statement.id,
                pdfData:     data
            )
            withAnimation { statement = updated }
            uploadSuccess = true
            // Auto-dismiss success message after 3 seconds
            try? await Task.sleep(for: .seconds(3))
            withAnimation { uploadSuccess = false }
        } catch {
            uploadError = "Upload failed. Please try again."
        }
        isUploadingPdf = false
    }

    // MARK: - Helpers

    private var pdfFilename: String {
        let bank = card.issuerName.replacingOccurrences(of: " ", with: "_")
        let month = monthYear.replacingOccurrences(of: " ", with: "_")
        return "\(bank)_\(month)_statement.pdf"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private var monthYear: String {
        guard let iso = statement.statementDate else { return "Statement" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM yyyy"
        return display.string(from: date)
    }

    private var dueDateColor: Color? {
        guard let iso = statement.dueDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let due = parser.date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
        if days < 0  { return Color(UIColor.NeoPop.State.error500) }   // overdue
        if days <= 5 { return Color(UIColor.NeoPop.State.error300) }   // due soon
        if days <= 10 { return Color(UIColor.NeoPop.State.warning300) }
        return nil
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.2f", v)
    }

    private func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}

// MARK: - Statement Info Row

private struct StmtInfoRow: View {
    let icon:       String
    let label:      String
    let value:      String
    var valueColor: Color? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                Text(value)
                    .font(.ctBody)
                    .foregroundColor(valueColor ?? .ctTextPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Mark Paid Sheet

private struct MarkPaidSheet: View {
    let statement: CardStatementDTO
    let onConfirm: (String, Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var amountText   = ""

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.NeoPop.Black.c200)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Mark as Paid")
                .font(.ctTitle)
                .foregroundColor(.ctTextPrimary)
                .padding(.bottom, 24)

            VStack(spacing: 0) {
                // Date picker row
                HStack {
                    Label("Payment Date", systemImage: "calendar")
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color(UIColor.NeoPop.State.success300))
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.NeoPop.Black.c200)
                    .frame(height: 0.5)
                    .padding(.leading, 16)

                // Amount row
                HStack {
                    Label("Amount Paid", systemImage: "dollarsign.circle")
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                    Spacer()
                    TextField(statement.statementBalance.map { String(format: "%.2f", $0) } ?? "Optional",
                              text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.ctBody)
                        .foregroundColor(.ctTextPrimary)
                        .frame(width: 120)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
            .padding(.horizontal, 20)

            Spacer()

            NeoPopFloatingButton(
                title:      "Confirm",
                shimmer:    false,
                faceColor:  UIColor.NeoPop.State.success300,
                labelColor: .white,
                showArrow:  false
            ) {
                let amount = Double(amountText.trimmingCharacters(in: .whitespaces))
                dismiss()
                onConfirm(dateString, amount)
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .onAppear {
            // Pre-fill date with due date if available, else today
            if let iso = statement.dueDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                if let d = f.date(from: iso) { selectedDate = min(d, Date()) }
            }
            // Pre-fill amount with statement balance
            if let bal = statement.statementBalance {
                amountText = String(format: "%.2f", bal)
            }
        }
    }
}


// MARK: - Statement PDF Picker

private struct StatementPdfPicker: UIViewControllerRepresentable {
    let onPicked: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (Data) -> Void
        init(onPicked: @escaping (Data) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource(),
                  let data = try? Data(contentsOf: url) else { return }
            url.stopAccessingSecurityScopedResource()
            onPicked(data)
        }
    }
}
