import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct UtilityBillDetailView: View {
    @State var bill:    UtilityBillDTO
    let account:        UtilityAccountDTO

    @Environment(\.dismiss) private var dismiss

    @State private var showMarkPaidSheet = false
    @State private var isMarkingPaid     = false
    @State private var showDocumentPicker = false
    @State private var isUploadingPdf     = false
    @State private var uploadError: String? = nil
    @State private var uploadSuccess       = false
    @State private var showPdfViewer      = false
    @State private var pdfViewerData: Data? = nil
    @State private var isLoadingPdf       = false

    // Extraction state
    @State private var showExtractionPreview  = false
    @State private var extractionResult: BillExtractionResultDTO? = nil
    @State private var isLoadingPreview       = false
    @State private var pollingTimer: Timer?   = nil

    private var billerStyle: BillerStyle { BillerStyle(billerName: bill.billerName) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    amountHero
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    detailsSection
                    if let payments = bill.payments, !payments.isEmpty {
                        Spacer().frame(height: 20)
                        paymentsSection(payments)
                    }
                    uploadPdfSection
                    Spacer().frame(height: 48)
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                billerStyle.tintColor
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
            BillPdfPicker { pdfData in
                Task { await uploadPdf(data: pdfData) }
            }
        }
        .sheet(isPresented: $showPdfViewer) {
            if let data = pdfViewerData {
                StatementPdfViewerSheet(data: data, filename: pdfFilename)
            }
        }
        .sheet(isPresented: $showMarkPaidSheet) {
            MarkUtilityPaidSheet(bill: bill) { date, amount in
                Task { await markPaid(date: date, amount: amount) }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExtractionPreview) {
            if let result = extractionResult {
                BillExtractionPreviewSheet(
                    result:   result,
                    bill:     bill,
                    onApply:  { force in Task { await applyExtraction(force: force) } },
                    onCancel: {}
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onDisappear { pollingTimer?.invalidate() }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            CTBackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(navHeading)
                    .font(.ctTitle)
                    .foregroundColor(.ctTextPrimary)
                Text(billerStyle.displayName)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
            }
            Spacer()
            if bill.isPaid == true {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bill.isPaid)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Amount hero

    private var amountHero: some View {
        VStack(spacing: 6) {
            if let amount = bill.amountDue {
                Text(formatCurrency(amount))
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .foregroundColor(.ctTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.ctTextSecondary)
            }
            Text("Amount Due")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
        }
    }

    // MARK: - Details section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETAILS")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 24)

            VStack(spacing: 0) {
                if let dd = bill.dueDate {
                    BillInfoRow(icon: "calendar",
                                label: "Due Date",
                                value: formatDate(dd),
                                valueColor: dueDateColor)
                    divider
                }

                if let start = bill.billingPeriodStart, let end = bill.billingPeriodEnd {
                    BillInfoRow(icon: "calendar.badge.clock",
                                label: "Billing Period",
                                value: "\(formatDate(start)) – \(formatDate(end))")
                    divider
                }

                if let bd = bill.billDate {
                    BillInfoRow(icon: "doc.text.fill",
                                label: "Bill Date",
                                value: formatDate(bd))
                    divider
                }

                BillInfoRow(icon: "building.2.fill",
                            label: "Provider",
                            value: billerStyle.displayName)
                divider

                BillInfoRow(icon: "number",
                            label: "Account",
                            value: "•••• \(bill.accountLastFour)")

                if bill.isPaid == true, let paid = bill.totalPaid, paid > 0 {
                    divider
                    BillInfoRow(icon: "dollarsign.circle.fill",
                                label: "Total Paid",
                                value: formatCurrency(paid),
                                valueColor: Color(UIColor.NeoPop.State.success300))
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

    // MARK: - Payment history section

    @ViewBuilder
    private func paymentsSection(_ payments: [UtilityPaymentDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PAYMENT HISTORY")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 24)

            VStack(spacing: 0) {
                ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(UIColor.NeoPop.State.success300))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.NeoPop.Black.c200))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Payment")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            if let date = payment.paymentDate {
                                Text(formatDate(date))
                                    .font(.ctBody)
                                    .foregroundColor(.ctTextPrimary)
                            }
                        }
                        Spacer()
                        if let amount = payment.paymentAmount {
                            Text(formatCurrency(amount))
                                .font(.system(.body, design: .default).weight(.semibold))
                                .foregroundColor(Color(UIColor.NeoPop.State.success300))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                    if index < payments.count - 1 {
                        Rectangle()
                            .fill(Color.NeoPop.Black.c200)
                            .frame(height: 0.5)
                            .padding(.leading, 64)
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

    // MARK: - Mark paid

    private func markPaid(date: String, amount: Double?) async {
        isMarkingPaid = true
        do {
            let updated = try await APIClient.shared.markUtilityBillPaid(
                billId:      bill.id,
                paymentDate: date,
                paidAmount:  amount
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                bill = updated
            }
        } catch {
            // Silent — user can retry via the nav bar button
        }
        isMarkingPaid = false
    }

    // MARK: - Upload PDF

    @ViewBuilder
    private var uploadPdfSection: some View {
        VStack(spacing: 10) {
            if bill.hasPdf == true {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(pdfStatusColor)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.NeoPop.Black.c200))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bill PDF")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                            Text(pdfStatusLabel)
                                .font(.ctBody)
                                .foregroundColor(pdfStatusColor)
                        }
                        Spacer()

                        Button {
                            Task { await viewPdf() }
                        } label: {
                            if isLoadingPdf {
                                ProgressView().tint(.ctTextPrimary)
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

                    // Review extraction row — only shown when user action needed
                    if let status = bill.pdfStatus,
                       status == "WRONG_STATEMENT" || status == "FAILED" {
                        Divider().padding(.leading, 64)
                        Button { Task { await loadAndShowPreview() } } label: {
                            HStack {
                                Image(systemName: status == "FAILED" ? "xmark.circle" : "doc.badge.arrow.up")
                                    .font(.system(size: 13))
                                    .foregroundColor(pdfStatusColor)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.NeoPop.Black.c200))
                                Text(status == "FAILED" ? "Extraction Failed — Tap for Details"
                                     : status == "WRONG_STATEMENT" ? "Possible Wrong Bill — Review"
                                     : "Review Extracted Data")
                                    .font(.ctBody)
                                    .foregroundColor(pdfStatusColor)
                                Spacer()
                                if isLoadingPreview {
                                    ProgressView().tint(.ctTextPrimary).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.ctTextSecondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                        }
                    }
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

            if uploadSuccess {
                Label("PDF uploaded successfully", systemImage: "checkmark.circle.fill")
                    .font(.ctMicro)
                    .foregroundColor(Color(UIColor.NeoPop.State.success300))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            if let err = uploadError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.ctMicro)
                    .foregroundColor(Color(UIColor.NeoPop.State.error300))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            NeoPopElevatedButton(
                title:          isUploadingPdf ? "Uploading…" : (bill.hasPdf == true ? "Replace PDF" : "Upload Bill PDF"),
                faceColor:      .white,
                labelColor:     .popDeepBlack,
                superViewColor: .popDeepBlack,
                fontSize:       15
            ) {
                uploadError   = nil
                uploadSuccess = false
                showDocumentPicker = true
            }
            .frame(height: 56)
            .padding(.horizontal, 20)
            .disabled(isUploadingPdf)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bill.hasPdf)
        .animation(.easeInOut(duration: 0.3), value: uploadSuccess)
        .animation(.easeInOut(duration: 0.3), value: uploadError)
        .padding(.top, 12)
    }

    private var pdfStatusLabel: String {
        switch bill.pdfStatus {
        case "PENDING", "EXTRACTING": return "Analysing PDF…"
        case "EXTRACTED":             return "PDF Applied"
        case "WRONG_STATEMENT":       return "Check Required"
        case "FAILED":                return "Extraction Failed"
        default:                      return bill.hasPdf == true ? "PDF Uploaded" : "No PDF"
        }
    }

    private var pdfStatusColor: Color {
        switch bill.pdfStatus {
        case "PENDING", "EXTRACTING": return Color(UIColor.NeoPop.State.warning300)
        case "EXTRACTED":             return Color(UIColor.NeoPop.State.success300)
        case "WRONG_STATEMENT":       return Color(UIColor.NeoPop.State.warning300)
        case "FAILED":                return Color(UIColor.NeoPop.State.error300)
        default:                      return .ctTextSecondary
        }
    }

    private var pdfFilename: String {
        let biller = bill.billerName.replacingOccurrences(of: " ", with: "_")
        let month  = monthYear(bill.billDate ?? bill.dueDate).replacingOccurrences(of: " ", with: "_")
        return "\(biller)_\(month)_bill.pdf"
    }

    private func viewPdf() async {
        isLoadingPdf = true
        do {
            let data = try await APIClient.shared.downloadUtilityBillPdf(billId: bill.id)
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
            let updated = try await APIClient.shared.uploadUtilityBillPdf(billId: bill.id, pdfData: data)
            withAnimation { bill = updated }
            uploadSuccess = true
            startPolling()
            try? await Task.sleep(for: .seconds(3))
            withAnimation { uploadSuccess = false }
        } catch {
            uploadError = "Upload failed. Please try again."
        }
        isUploadingPdf = false
    }

    // MARK: - Extraction

    private func loadAndShowPreview() async {
        isLoadingPreview = true
        do {
            let result = try await APIClient.shared.fetchBillExtractionPreview(billId: bill.id)
            extractionResult = result
            showExtractionPreview = true
        } catch {
            uploadError = "Could not load extraction data."
        }
        isLoadingPreview = false
    }

    private func applyExtraction(force: Bool) async {
        do {
            let updated = try await APIClient.shared.applyBillExtraction(billId: bill.id, force: force)
            withAnimation { bill = updated }
            showExtractionPreview = false
        } catch {
            uploadError = "Failed to apply changes."
        }
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        var tries = 0
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            tries += 1
            if tries > 60 { timer.invalidate(); return }
            Task { @MainActor in
                guard let status = self.bill.pdfStatus,
                      status == "PENDING" || status == "EXTRACTING" else {
                    timer.invalidate()
                    return
                }
                if let updated = try? await APIClient.shared.fetchBill(billId: self.bill.id) {
                    self.bill = updated
                    if let s = updated.pdfStatus, s != "PENDING" && s != "EXTRACTING" {
                        timer.invalidate()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private var dueDateColor: Color? {
        guard let iso = bill.dueDate else { return nil }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let due = p.date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
        if days < 0   { return Color(UIColor.NeoPop.State.error500) }   // overdue
        if days <= 5  { return Color(UIColor.NeoPop.State.error300) }   // due soon
        if days <= 10 { return Color(UIColor.NeoPop.State.warning300) }
        return nil
    }

    private func monthYear(_ iso: String?) -> String {
        guard let iso else { return "Bill" }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateFormat = "MMM yyyy"
        return d.string(from: date)
    }

    /// Nav bar heading: National Grid shows billing period range; Eversource shows bill date month.
    private var navHeading: String {
        let isNatGrid = bill.billerName.uppercased().contains("NATIONAL")
        if isNatGrid,
           let start = bill.billingPeriodStart,
           let end   = bill.billingPeriodEnd {
            let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = Locale(identifier: "en_US_POSIX")
            let mon: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM yyyy"; return d.string(from: date)
            }
            let monNoYear: (String) -> String = { iso in
                guard let date = p.date(from: iso) else { return iso }
                let d = DateFormatter(); d.dateFormat = "MMM"; return d.string(from: date)
            }
            let sY = String(start.prefix(4)), eY = String(end.prefix(4))
            return sY == eY ? "\(monNoYear(start)) – \(mon(end))" : "\(mon(start)) – \(mon(end))"
        }
        return monthYear(bill.billDate ?? bill.dueDate)
    }

    private func formatDate(_ iso: String) -> String {
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd"
        p.locale = Locale(identifier: "en_US_POSIX")
        guard let date = p.date(from: iso) else { return iso }
        let d = DateFormatter()
        d.dateStyle = .medium
        d.timeStyle = .none
        return d.string(from: date)
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.2f", v)
    }
}

// MARK: - Bill Info Row

private struct BillInfoRow: View {
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

// MARK: - Mark Utility Paid Sheet

private struct MarkUtilityPaidSheet: View {
    let bill:      UtilityBillDTO
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
                    TextField(bill.amountDue.map { String(format: "%.2f", $0) } ?? "Optional",
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
            // Pre-fill date with due date (capped at today) if available
            if let iso = bill.dueDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                if let d = f.date(from: iso) { selectedDate = min(d, Date()) }
            }
            // Pre-fill amount with the bill amount
            if let amount = bill.amountDue {
                amountText = String(format: "%.2f", amount)
            }
        }
    }
}

// MARK: - Bill PDF Picker

private struct BillPdfPicker: UIViewControllerRepresentable {
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
