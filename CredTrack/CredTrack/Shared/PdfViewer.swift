import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - PDF Viewer Sheet (shared by StatementDetailView & UtilityBillDetailView)

struct StatementPdfViewerSheet: View {
    let data: Data
    let filename: String

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.ctTextPrimary)

                Spacer()

                Text(filename)
                    .font(.ctMicro)
                    .foregroundColor(.ctTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)

                Spacer()

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.ctTextPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.ctBackground)
            .overlay(
                Rectangle()
                    .fill(Color.NeoPop.Black.c200)
                    .frame(height: 0.5),
                alignment: .bottom
            )

            PDFKitView(data: data)
        }
        .background(Color.ctBackground.ignoresSafeArea())
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [pdfTempURL()])
        }
    }

    private func pdfTempURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}

// MARK: - PDFKit wrapper

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = UIColor(named: "ctBackground") ?? .black
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
