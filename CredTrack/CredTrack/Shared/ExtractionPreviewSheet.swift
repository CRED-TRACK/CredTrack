import SwiftUI

// MARK: - Shared formatting

private func formatExtractionCurrency(_ v: Double) -> String {
    if v >= 1_000 { return String(format: "$%.1fK", v / 1_000) }
    return String(format: "$%.2f", v)
}

private func formatExtractionDate(_ iso: String) -> String {
    let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.locale = Locale(identifier: "en_US_POSIX")
    guard let date = p.date(from: iso) else { return iso }
    let d = DateFormatter(); d.dateStyle = .medium; d.timeStyle = .none
    return d.string(from: date)
}

// MARK: - Statement Extraction Preview

struct StatementExtractionPreviewSheet: View {
    let result:    StatementExtractionResultDTO
    let statement: CardStatementDTO
    let onApply:   (Bool) -> Void  // force: Bool
    let onCancel:  () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isApplying = false

    private var isWrong: Bool { result.status == "WRONG_STATEMENT" }
    private var isFailed: Bool { result.status == "FAILED" }

    var body: some View {
        VStack(spacing: 0) {
            handle

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header
                    headerSection

                    // Validation issues / warnings
                    if let issues = result.validationIssues, !issues.isEmpty {
                        issuesSection(issues)
                    }

                    // Failure reason
                    if let reason = result.failureReason {
                        failureSection(reason)
                    }

                    // Extracted data diff (only if not failed)
                    if !isFailed {
                        extractedDataSection
                    }

                    // Transaction count
                    if let txns = result.transactions, !txns.isEmpty {
                        transactionCountSection(txns.count)
                    }

                    // Buttons
                    actionButtons

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.ctBackground.ignoresSafeArea())
    }

    // MARK: - Sections

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.NeoPop.Black.c200)
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 20)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: isFailed ? "xmark.circle.fill"
                              : isWrong ? "exclamationmark.triangle.fill"
                              : "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(isFailed ? Color(UIColor.NeoPop.State.error500)
                                 : isWrong ? Color(UIColor.NeoPop.State.warning300)
                                 : Color(UIColor.NeoPop.State.success300))

            Text(isFailed ? "Extraction Failed"
                 : isWrong ? "Wrong Statement Detected"
                 : "Data Extracted Successfully")
                .font(.ctTitle)
                .foregroundColor(.ctTextPrimary)
                .multilineTextAlignment(.center)

            if !isFailed {
                Text(isWrong ? "We think this PDF may not match this statement. Review and confirm if you'd like to apply anyway."
                             : "Review the extracted data below, then apply to update your statement.")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private func issuesSection(_ issues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WARNINGS")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(issues.enumerated()), id: \.offset) { i, issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(UIColor.NeoPop.State.warning300))
                            .frame(width: 20)
                            .padding(.top, 2)
                        Text(issue)
                            .font(.ctBody)
                            .foregroundColor(.ctTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if i < issues.count - 1 {
                        Rectangle().fill(Color.NeoPop.Black.c200).frame(height: 0.5).padding(.leading, 46)
                    }
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(UIColor.NeoPop.State.warning300).opacity(0.4), lineWidth: 1))
        }
    }

    private func failureSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REASON")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 4)
            Text(reason)
                .font(.ctBody)
                .foregroundColor(Color(UIColor.NeoPop.State.error300))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ctSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var extractedDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXTRACTED DATA")
                .font(.ctMicro)
                .foregroundColor(.ctTextSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let bank = result.bank {
                    diffRow(label: "Bank", extracted: bank, stored: statement.bank)
                    divider
                }
                if let last4 = result.cardLastFour {
                    diffRow(label: "Card", extracted: "••••\(last4)", stored: statement.cardLastFour.map { "••••\($0)" })
                    divider
                }
                if let bal = result.statementBalance {
                    diffRow(label: "Balance", extracted: formatCurrency(bal), stored: statement.statementBalance.map { formatCurrency($0) })
                    divider
                }
                if let min = result.minimumDue {
                    diffRow(label: "Min Due", extracted: formatCurrency(min), stored: statement.minimumDue.map { formatCurrency($0) })
                    divider
                }
                if let due = result.dueDate {
                    diffRow(label: "Due Date", extracted: formatDate(due), stored: statement.dueDate.map { formatDate($0) })
                    divider
                }
                if let sd = result.statementDate {
                    diffRow(label: "Statement Date", extracted: formatDate(sd), stored: statement.statementDate.map { formatDate($0) })
                }
            }
            .background(Color.ctSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
        }
    }

    private func transactionCountSection(_ count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ctTextPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.NeoPop.Black.c200))
            VStack(alignment: .leading, spacing: 2) {
                Text("Transactions in PDF")
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                Text("\(count) transaction\(count == 1 ? "" : "s") will replace Gmail-sourced data")
                    .font(.ctBody)
                    .foregroundColor(.ctTextPrimary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.ctSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !isFailed {
                NeoPopFloatingButton(
                    title:      isWrong ? "Apply Anyway" : "Apply Changes",
                    shimmer:    !isWrong,
                    faceColor:  isWrong ? UIColor.NeoPop.State.warning300 : UIColor.NeoPop.State.success300,
                    labelColor: .black,
                    showArrow:  false
                ) {
                    isApplying = true
                    onApply(isWrong)
                    dismiss()
                }
                .frame(height: 56)
            }

            NeoPopElevatedButton(
                title:          "Cancel",
                faceColor:      .clear,
                labelColor:     UIColor.NeoPop.State.error300,
                superViewColor: .clear,
                borderColor:    UIColor.NeoPop.State.error300,
                fontSize:       15
            ) {
                onCancel()
                dismiss()
            }
            .frame(height: 50)
        }
    }

    // MARK: - Row helpers

    private func diffRow(label: String, extracted: String, stored: String?) -> some View {
        let changed = stored != nil && stored != extracted
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                Text(extracted)
                    .font(.ctBody)
                    .foregroundColor(changed ? Color(UIColor.NeoPop.State.success300) : .ctTextPrimary)
            }
            Spacer()
            if let stored, changed {
                Text(stored)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .strikethrough(true, color: .ctTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.NeoPop.Black.c200)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func formatCurrency(_ v: Double) -> String { formatExtractionCurrency(v) }
    private func formatDate(_ iso: String) -> String { formatExtractionDate(iso) }
}

// MARK: - Bill Extraction Preview

struct BillExtractionPreviewSheet: View {
    let result:  BillExtractionResultDTO
    let bill:    UtilityBillDTO
    let onApply: (Bool) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isWrong: Bool { result.status == "WRONG_STATEMENT" }
    private var isFailed: Bool { result.status == "FAILED" }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.NeoPop.Black.c200)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header icon + title
                    VStack(spacing: 8) {
                        Image(systemName: isFailed ? "xmark.circle.fill"
                                          : isWrong ? "exclamationmark.triangle.fill"
                                          : "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(isFailed ? Color(UIColor.NeoPop.State.error500)
                                             : isWrong ? Color(UIColor.NeoPop.State.warning300)
                                             : Color(UIColor.NeoPop.State.success300))

                        Text(isFailed ? "Extraction Failed"
                             : isWrong ? "Wrong Bill Detected"
                             : "Bill Data Extracted")
                            .font(.ctTitle)
                            .foregroundColor(.ctTextPrimary)
                    }
                    .padding(.top, 4)

                    // Warnings
                    if let issues = result.validationIssues, !issues.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WARNINGS")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                                .padding(.leading, 4)
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(issues.enumerated()), id: \.offset) { i, issue in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(UIColor.NeoPop.State.warning300))
                                            .frame(width: 20)
                                            .padding(.top, 2)
                                        Text(issue).font(.ctBody).foregroundColor(.ctTextPrimary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    if i < issues.count - 1 {
                                        Rectangle().fill(Color.NeoPop.Black.c200).frame(height: 0.5).padding(.leading, 46)
                                    }
                                }
                            }
                            .background(Color.ctSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(UIColor.NeoPop.State.warning300).opacity(0.4), lineWidth: 1))
                        }
                    }

                    // Failure reason
                    if let reason = result.failureReason {
                        Text(reason).font(.ctBody).foregroundColor(Color(UIColor.NeoPop.State.error300))
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.ctSurface).clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Extracted data
                    if !isFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXTRACTED DATA")
                                .font(.ctMicro)
                                .foregroundColor(.ctTextSecondary)
                                .padding(.leading, 4)
                            VStack(spacing: 0) {
                                if let amt = result.amountDue {
                                    billDiffRow(label: "Amount Due",
                                               extracted: formatCurrency(amt),
                                               stored: bill.amountDue.map { formatCurrency($0) })
                                    divider
                                }
                                if let due = result.dueDate {
                                    billDiffRow(label: "Due Date",
                                               extracted: formatDate(due),
                                               stored: bill.dueDate.map { formatDate($0) })
                                    divider
                                }
                                if let bd = result.billDate {
                                    billDiffRow(label: "Bill Date", extracted: formatDate(bd), stored: nil)
                                    divider
                                }
                                if let start = result.billingPeriodStart, let end = result.billingPeriodEnd {
                                    billDiffRow(label: "Billing Period",
                                               extracted: "\(formatDate(start)) – \(formatDate(end))",
                                               stored: nil)
                                }
                            }
                            .background(Color.ctSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.NeoPop.Black.c200, lineWidth: 1))
                        }
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        if !isFailed {
                            NeoPopFloatingButton(
                                title:      isWrong ? "Apply Anyway" : "Apply Changes",
                                shimmer:    !isWrong,
                                faceColor:  isWrong ? UIColor.NeoPop.State.warning300 : UIColor.NeoPop.State.success300,
                                labelColor: .black,
                                showArrow:  false
                            ) {
                                onApply(isWrong)
                                dismiss()
                            }
                            .frame(height: 56)
                        }
                        NeoPopElevatedButton(
                            title:          "Cancel",
                            faceColor:      .clear,
                            labelColor:     UIColor.NeoPop.State.error300,
                            superViewColor: .clear,
                            borderColor:    UIColor.NeoPop.State.error300,
                            fontSize:       15
                        ) {
                            onCancel()
                            dismiss()
                        }
                        .frame(height: 50)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.ctBackground.ignoresSafeArea())
    }

    private func billDiffRow(label: String, extracted: String, stored: String?) -> some View {
        let changed = stored != nil && stored != extracted
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.ctMicro).foregroundColor(.ctTextSecondary)
                Text(extracted).font(.ctBody)
                    .foregroundColor(changed ? Color(UIColor.NeoPop.State.success300) : .ctTextPrimary)
            }
            Spacer()
            if let stored, changed {
                Text(stored).font(.ctMicro).foregroundColor(.ctTextSecondary)
                    .strikethrough(true, color: .ctTextSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private var divider: some View {
        Rectangle().fill(Color.NeoPop.Black.c200).frame(height: 0.5).padding(.leading, 16)
    }

    private func formatCurrency(_ v: Double) -> String { formatExtractionCurrency(v) }
    private func formatDate(_ iso: String) -> String { formatExtractionDate(iso) }
}
