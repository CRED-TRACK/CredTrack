package com.credtrack.backend.dto;

import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.entity.UtilityPayment;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class UtilityBillResponse {
    private Long          id;
    private String        billerName;
    private String        accountLastFour;
    private LocalDate     billDate;
    private LocalDate     billingPeriodStart;
    private LocalDate     billingPeriodEnd;
    private BigDecimal    amountDue;
    private LocalDate     dueDate;
    private Boolean       isPaid;
    private BigDecimal    totalPaid;
    private LocalDateTime createdAt;
    private List<PaymentSummary> payments;

    @Data @Builder
    public static class PaymentSummary {
        private Long       id;
        private BigDecimal paymentAmount;
        private LocalDate  paymentDate;
    }

    public static UtilityBillResponse from(UtilityBill b, List<UtilityPayment> payments) {
        return UtilityBillResponse.builder()
                .id(b.getId())
                .billerName(b.getBillerName())
                .accountLastFour(b.getAccountLastFour())
                .billDate(b.getBillDate())
                .billingPeriodStart(b.getBillingPeriodStart())
                .billingPeriodEnd(b.getBillingPeriodEnd())
                .amountDue(b.getAmountDue())
                .dueDate(b.getDueDate())
                .isPaid(b.getIsPaid())
                .totalPaid(b.getTotalPaid())
                .createdAt(b.getCreatedAt())
                .payments(payments.stream()
                        .map(p -> PaymentSummary.builder()
                                .id(p.getId())
                                .paymentAmount(p.getPaymentAmount())
                                .paymentDate(p.getPaymentDate())
                                .build())
                        .toList())
                .build();
    }
}
