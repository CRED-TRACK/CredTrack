package com.credtrack.backend.controller;

import com.credtrack.backend.dto.BillExtractionResult;
import com.credtrack.backend.dto.MarkPaidRequest;
import com.credtrack.backend.dto.UtilityBillResponse;
import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.repository.UtilityBillRepository;
import com.credtrack.backend.repository.UtilityPaymentRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.FirebaseStorageService;
import com.credtrack.backend.service.PdfExtractionService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/utility-bills")
public class UtilityBillController {

    private final UtilityBillRepository    billRepo;
    private final UtilityPaymentRepository paymentRepo;
    private final FirebaseService          firebaseService;
    private final FirebaseStorageService   storageService;
    private final PdfExtractionService     extractionService;

    public UtilityBillController(UtilityBillRepository billRepo,
                                 UtilityPaymentRepository paymentRepo,
                                 FirebaseService firebaseService,
                                 FirebaseStorageService storageService,
                                 PdfExtractionService extractionService) {
        this.billRepo          = billRepo;
        this.paymentRepo       = paymentRepo;
        this.firebaseService   = firebaseService;
        this.storageService    = storageService;
        this.extractionService = extractionService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    /** GET /utility-bills?billerName=EVERSOURCE — list all bills, optionally filtered */
    @GetMapping
    public ResponseEntity<List<UtilityBillResponse>> list(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(required = false) String billerName) {
        String userId = resolveUid(authHeader);
        List<UtilityBill> bills = billerName != null
                ? billRepo.findByUser_IdAndBillerNameOrderByDueDateDesc(userId, billerName)
                : billRepo.findByUser_IdOrderByDueDateDesc(userId);
        return ResponseEntity.ok(bills.stream()
                .map(b -> UtilityBillResponse.from(b, paymentRepo.findByBill_Id(b.getId())))
                .toList());
    }

    /** GET /utility-bills/{id} — single bill with payments */
    @GetMapping("/{id}")
    public ResponseEntity<UtilityBillResponse> get(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {
        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }
        return ResponseEntity.ok(
                UtilityBillResponse.from(bill, paymentRepo.findByBill_Id(id)));
    }

    /**
     * POST /utility-bills/{id}/mark-paid
     * Manually marks a utility bill as paid.
     * Body: { "paymentDate": "2026-04-21", "paidAmount": 133.64 }  — both optional.
     * Returns the updated bill.
     */
    @PostMapping("/{id}/mark-paid")
    @Transactional
    public ResponseEntity<UtilityBillResponse> markPaid(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody(required = false) MarkPaidRequest req) {

        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }

        bill.setIsPaid(true);
        if (req != null && req.getPaidAmount() != null) {
            bill.setTotalPaid(req.getPaidAmount());
        }
        billRepo.save(bill);

        return ResponseEntity.ok(
                UtilityBillResponse.from(bill, paymentRepo.findByBill_Id(id)));
    }

    /** POST /utility-bills/{id}/upload-pdf — attach a PDF to an existing bill */
    @PostMapping("/{id}/upload-pdf")
    @Transactional
    public ResponseEntity<UtilityBillResponse> uploadPdf(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {

        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }
        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File is empty");
        }

        try {
            String filename     = UUID.randomUUID() + ".pdf";
            String firebasePath = storageService.uploadUtilityBillPdf(userId, bill.getId(), filename, file.getBytes());
            bill.setFirebasePath(firebasePath);
            bill.setPdfStatus("PENDING");
            billRepo.save(bill);
            return ResponseEntity.ok(UtilityBillResponse.from(bill, paymentRepo.findByBill_Id(id)));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Upload failed: " + e.getMessage());
        }
    }

    /** GET /utility-bills/{id}/pdf — proxy PDF bytes through backend */
    @GetMapping("/{id}/pdf")
    public ResponseEntity<byte[]> downloadPdf(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {

        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }
        if (bill.getFirebasePath() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No PDF attached to this bill");
        }

        byte[] bytes = storageService.downloadPdf(bill.getFirebasePath());
        if (bytes == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PDF not found in storage");
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);
        headers.setContentDispositionFormData("inline", "bill.pdf");
        return new ResponseEntity<>(bytes, headers, HttpStatus.OK);
    }

    /**
     * GET /utility-bills/{id}/extraction-preview
     * Returns extraction result once pdfStatus leaves PENDING/EXTRACTING.
     * Returns 202 Accepted while still processing.
     */
    @GetMapping("/{id}/extraction-preview")
    public ResponseEntity<BillExtractionResult> extractionPreview(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {

        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }

        String status = bill.getPdfStatus();
        if (status == null || "PENDING".equals(status) || "EXTRACTING".equals(status)) {
            return ResponseEntity.accepted()
                    .body(BillExtractionResult.builder().status(status).build());
        }

        if (bill.getExtractedData() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No extraction data available");
        }

        BillExtractionResult result = extractionService.parseBillResult(bill.getExtractedData());
        if (result == null) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Extraction data is corrupted");
        }
        return ResponseEntity.ok(result);
    }

    /**
     * POST /utility-bills/{id}/apply-extraction
     * User confirms extracted data. Updates bill fields, sets pdfStatus=EXTRACTED.
     * Body (optional): { "force": true } — apply even if WRONG_STATEMENT.
     */
    @PostMapping("/{id}/apply-extraction")
    @Transactional
    public ResponseEntity<UtilityBillResponse> applyExtraction(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody(required = false) Map<String, Object> body) {

        String userId = resolveUid(authHeader);
        UtilityBill bill = billRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Utility bill not found"));
        if (!bill.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your bill");
        }

        String status = bill.getPdfStatus();
        boolean force = body != null && Boolean.TRUE.equals(body.get("force"));

        if ("WRONG_STATEMENT".equals(status) && !force) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Extraction detected a potential wrong bill. Send { \"force\": true } to apply anyway.");
        }
        if (!"AWAITING_CONFIRMATION".equals(status) && !"WRONG_STATEMENT".equals(status)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Bill is not ready for confirmation (pdfStatus=" + status + ").");
        }
        if (bill.getExtractedData() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No extraction data to apply");
        }

        BillExtractionResult result = extractionService.parseBillResult(bill.getExtractedData());
        if (result == null) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Extraction data corrupted");
        }

        if (result.getAmountDue() != null) bill.setAmountDue(BigDecimal.valueOf(result.getAmountDue()));
        if (result.getDueDate() != null) try { bill.setDueDate(LocalDate.parse(result.getDueDate())); } catch (Exception ignored) {}
        if (result.getBillDate() != null) try { bill.setBillDate(LocalDate.parse(result.getBillDate())); } catch (Exception ignored) {}
        if (result.getBillingPeriodStart() != null) try { bill.setBillingPeriodStart(LocalDate.parse(result.getBillingPeriodStart())); } catch (Exception ignored) {}
        if (result.getBillingPeriodEnd() != null) try { bill.setBillingPeriodEnd(LocalDate.parse(result.getBillingPeriodEnd())); } catch (Exception ignored) {}

        bill.setPdfStatus("EXTRACTED");
        billRepo.save(bill);
        return ResponseEntity.ok(UtilityBillResponse.from(bill, paymentRepo.findByBill_Id(id)));
    }
}
