import Foundation
import Combine
import SwiftUI

@MainActor
final class AddCardViewModel: ObservableObject {

    enum Step {
        case entry
        case lookingUp
        case picking(issuerName: String, products: [CardProductDTO])
        case saving
        case done
        case failed(String)
    }

    @Published private(set) var step: Step = .entry
    @Published var shouldDismiss = false
    @Published var toast: CTToastMessage? = nil

    // Entry fields
    @Published var rawNumber   = ""
    @Published var holderName  = ""

    // Picker fields
    @Published var selectedIndex = 0
    @Published var limitText     = ""

    // MARK: - Computed

    /// Detects card network from BIN prefix as the user types.
    /// Visa: 4x, Amex: 34/37, Mastercard: 51-55 / 2221-2720, Discover: 6011/65/644-649
    var detectedNetwork: CardNetwork {
        let d = rawNumber.filter(\.isNumber)
        guard !d.isEmpty else { return .unknown }

        if d.hasPrefix("4") { return .visa }
        if d.hasPrefix("34") || d.hasPrefix("37") { return .amex }

        if d.count >= 2, let p2 = Int(String(d.prefix(2))), (51...55).contains(p2) { return .mastercard }
        if d.count >= 4, let p4 = Int(String(d.prefix(4))), (2221...2720).contains(p4) { return .mastercard }

        if d.hasPrefix("6011") || d.hasPrefix("65") { return .discover }
        if d.count >= 3, let p3 = Int(String(d.prefix(3))), (644...649).contains(p3) { return .discover }

        return .unknown
    }

    /// Network logo image for the card number field.
    /// Amex uses "amex-brand" asset; all other networks use their standard asset name.
    var networkLogoImage: UIImage? {
        guard detectedNetwork != .unknown else { return nil }
        let assetName = detectedNetwork == .amex ? "amex-brand" : detectedNetwork.assetName
        return UIImage(named: assetName)
    }

    /// Amex cards start with 34 or 37 and have 15 digits; all others are 16.
    var isAmex: Bool { detectedNetwork == .amex }

    var maxDigits: Int { isAmex ? 15 : 16 }

    /// Amex format: XXXX  XXXXXX  XXXXX (4-6-5)
    /// Standard format: XXXX  XXXX  XXXX  XXXX (4-4-4-4)
    var formattedNumber: String {
        let digits = rawNumber.filter(\.isNumber).prefix(maxDigits)
        var out = ""
        for (i, ch) in digits.enumerated() {
            if isAmex {
                if i == 4 || i == 10 { out += "  " }
            } else {
                if i > 0 && i % 4 == 0 { out += "  " }
            }
            out.append(ch)
        }
        return out
    }

    var cardNumberPlaceholder: String {
        isAmex ? "XXXX  XXXXXX  XXXXX" : "XXXX  XXXX  XXXX  XXXX"
    }

    var lastFour: String {
        String(rawNumber.filter(\.isNumber).suffix(4))
    }

    // MARK: - Validation

    /// Luhn algorithm — works for both 15-digit Amex and 16-digit standard cards.
    var isCardNumberValid: Bool {
        let digits = rawNumber.filter(\.isNumber)
        guard digits.count == maxDigits else { return false }
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard var d = ch.wholeNumberValue else { return false }
            if i % 2 == 1 {
                d *= 2
                if d > 9 { d -= 9 }
            }
            sum += d
        }
        return sum % 10 == 0
    }

    /// Name must be non-empty and must NOT start with a digit or special character.
    var isNameValid: Bool {
        let trimmed = holderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let first = trimmed.unicodeScalars.first else { return false }
        return CharacterSet.letters.union(.whitespaces).isSuperset(of: CharacterSet(charactersIn: String(first)))
    }

    var canContinue: Bool {
        isCardNumberValid &&
        !holderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    func lookupAndFetch() async {
        let digits = rawNumber.filter(\.isNumber)
        step = .lookingUp
        do {
            let bin      = try await APIClient.shared.lookupBIN(digits)
            let issuer   = bin.issuerName ?? ""
            let products = try await APIClient.shared.fetchCardProducts(issuer: issuer)
            guard !products.isEmpty else {
                step = .failed("No cards found for this issuer.\nTry a different card number.")
                return
            }
            selectedIndex = 0
            step = .picking(issuerName: issuer, products: products)
        } catch APIError.serverError(404) {
            step = .failed("Card number not recognised.\nPlease check and try again.")
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func addCard(product: CardProductDTO) async {
        let limit = Double(limitText.filter { $0.isNumber || $0 == "." })
        guard (limit ?? 0) > 0 else {
            withAnimation { toast = CTToastMessage(text: "Enter a credit limit greater than $0.", style: .warning) }
            return
        }
        step = .saving
        do {
            // Duplicate check — same last four digits already in wallet
            let existing = try await APIClient.shared.fetchUserCards()
            if existing.contains(where: { $0.lastFour == lastFour }) {
                step = .entry
                withAnimation { toast = CTToastMessage(text: "A card ending in \(lastFour) is already in your wallet.", style: .error) }
                return
            }
            let req = AddCardRequest(
                cardProductId:  product.id,
                cardHolderName: holderName.trimmingCharacters(in: .whitespaces),
                lastFour:       lastFour,
                creditLimit:    limit
            )
            _ = try await APIClient.shared.addUserCard(req)
            step = .done
            shouldDismiss = true
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func back()  { step = .entry }
    func retry() { step = .entry }
}
