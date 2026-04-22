package com.credtrack.backend.controller;

import com.credtrack.backend.dto.MarkPaidRequest;
import com.credtrack.backend.dto.UtilityBillResponse;
import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.repository.UtilityBillRepository;
import com.credtrack.backend.repository.UtilityPaymentRepository;
import com.credtrack.backend.service.FirebaseService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/utility-bills")
public class UtilityBillController {

    private final UtilityBillRepository    billRepo;
    private final UtilityPaymentRepository paymentRepo;
    private final FirebaseService          firebaseService;

    public UtilityBillController(UtilityBillRepository billRepo,
                                 UtilityPaymentRepository paymentRepo,
                                 FirebaseService firebaseService) {
        this.billRepo        = billRepo;
        this.paymentRepo     = paymentRepo;
        this.firebaseService = firebaseService;
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
}
