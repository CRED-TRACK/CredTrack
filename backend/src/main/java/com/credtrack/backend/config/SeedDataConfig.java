package com.credtrack.backend.config;

import com.credtrack.backend.entity.BinRecord;
import com.credtrack.backend.entity.CardProduct;
import com.credtrack.backend.entity.Issuer;
import com.credtrack.backend.repository.BinRecordRepository;
import com.credtrack.backend.repository.CardProductRepository;
import com.credtrack.backend.repository.CardRewardRuleRepository;
import com.credtrack.backend.repository.CategoryAliasRepository;
import com.credtrack.backend.repository.IssuerRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
public class SeedDataConfig implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SeedDataConfig.class);
    private static final int BATCH_SIZE = 1000;

    private final IssuerRepository issuerRepository;
    private final BinRecordRepository binRecordRepository;
    private final CardProductRepository cardProductRepository;
    private final CategoryAliasRepository categoryAliasRepository;
    private final CardRewardRuleRepository cardRewardRuleRepository;
    private final DataSource dataSource;

    public SeedDataConfig(IssuerRepository issuerRepository,
                          BinRecordRepository binRecordRepository,
                          CardProductRepository cardProductRepository,
                          CategoryAliasRepository categoryAliasRepository,
                          CardRewardRuleRepository cardRewardRuleRepository,
                          DataSource dataSource) {
        this.issuerRepository = issuerRepository;
        this.binRecordRepository = binRecordRepository;
        this.cardProductRepository = cardProductRepository;
        this.categoryAliasRepository = categoryAliasRepository;
        this.cardRewardRuleRepository = cardRewardRuleRepository;
        this.dataSource = dataSource;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        seedIssuersIfNeeded();
        seedBinRecordsIfNeeded();
        seedCardProductsIfNeeded();
        seedCategoryAliasesIfNeeded();
        seedCardRewardRulesIfNeeded();
    }

    private void seedIssuersIfNeeded() throws Exception {
        if (issuerRepository.count() > 0) {
            log.info("Issuer seed skipped: {} row(s) already present", issuerRepository.count());
            return;
        }

        Resource resource = new ClassPathResource("seed/bin-list-data-US-credit-issuers.csv");
        List<Issuer> batch = new ArrayList<>(BATCH_SIZE);
        long inserted = 0;

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8));
             CSVParser parser = CSVFormat.DEFAULT.builder().setHeader().setSkipHeaderRecord(true).get().parse(reader)) {
            for (CSVRecord record : parser) {
                batch.add(Issuer.builder()
                        .issuerName(value(record, "Issuer"))
                        .issuerPhone(emptyToNull(value(record, "IssuerPhone")))
                        .issuerUrl(emptyToNull(value(record, "IssuerUrl")))
                        .color(emptyToNull(value(record, "Color")))
                        .build());

                if (batch.size() >= BATCH_SIZE) {
                    issuerRepository.saveAll(batch);
                    inserted += batch.size();
                    batch.clear();
                }
            }
        }

        if (!batch.isEmpty()) {
            issuerRepository.saveAll(batch);
            inserted += batch.size();
        }

        log.info("Issuer seed completed: inserted {} row(s)", inserted);
    }

    private void seedBinRecordsIfNeeded() throws Exception {
        if (binRecordRepository.count() > 0) {
            log.info("BIN seed skipped: {} row(s) already present", binRecordRepository.count());
            return;
        }

        Resource resource = new ClassPathResource("seed/bin-list-data-US-credit.csv");
        Map<String, Issuer> issuersByName = new HashMap<>();
        issuerRepository.findAll().forEach(issuer -> issuersByName.put(issuer.getIssuerName(), issuer));

        List<BinRecord> batch = new ArrayList<>(BATCH_SIZE);
        long inserted = 0;

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8));
             CSVParser parser = CSVFormat.DEFAULT.builder().setHeader().setSkipHeaderRecord(true).get().parse(reader)) {
            for (CSVRecord record : parser) {
                String issuerName = value(record, "Issuer");
                batch.add(BinRecord.builder()
                        .bin(Long.parseLong(value(record, "BIN")))
                        .brand(emptyToNull(value(record, "Brand")))
                        .type(emptyToNull(value(record, "Type")))
                        .category(emptyToNull(value(record, "Category")))
                        .issuer(issuersByName.get(issuerName))
                        .issuerPhone(emptyToNull(value(record, "IssuerPhone")))
                        .issuerUrl(emptyToNull(value(record, "IssuerUrl")))
                        .isoCode2(emptyToNull(value(record, "isoCode2")))
                        .isoCode3(emptyToNull(value(record, "isoCode3")))
                        .countryName(emptyToNull(value(record, "CountryName")))
                        .color(emptyToNull(value(record, "Color")))
                        .build());

                if (batch.size() >= BATCH_SIZE) {
                    binRecordRepository.saveAll(batch);
                    inserted += batch.size();
                    batch.clear();
                }
            }
        }

        if (!batch.isEmpty()) {
            binRecordRepository.saveAll(batch);
            inserted += batch.size();
        }

        log.info("BIN seed completed: inserted {} row(s)", inserted);
    }

    private void seedCardProductsIfNeeded() {
        if (cardProductRepository.count() > 0) {
            log.info("Card product seed skipped: {} row(s) already present", cardProductRepository.count());
            return;
        }

        ResourceDatabasePopulator populator =
                new ResourceDatabasePopulator(new ClassPathResource("seed/seed_card_products.sql"));
        populator.execute(dataSource);

        log.info("Card product seed completed: inserted {} row(s)", cardProductRepository.count());
    }

    private void seedCategoryAliasesIfNeeded() {
        if (categoryAliasRepository.count() > 0) {
            log.info("Category alias seed skipped: {} row(s) already present", categoryAliasRepository.count());
            return;
        }
        ResourceDatabasePopulator populator =
                new ResourceDatabasePopulator(new ClassPathResource("seed/seed_category_aliases.sql"));
        populator.execute(dataSource);
        log.info("Category alias seed completed: inserted {} row(s)", categoryAliasRepository.count());
    }

    private void seedCardRewardRulesIfNeeded() {
        if (cardRewardRuleRepository.count() > 0) {
            log.info("Card reward rule seed skipped: {} row(s) already present", cardRewardRuleRepository.count());
            return;
        }
        ResourceDatabasePopulator populator =
                new ResourceDatabasePopulator(new ClassPathResource("seed/seed_card_reward_rules.sql"));
        populator.execute(dataSource);
        log.info("Card reward rule seed completed: inserted {} row(s)", cardRewardRuleRepository.count());
    }

    private String value(CSVRecord record, String key) {
        return record.get(key).trim();
    }

    private String emptyToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
