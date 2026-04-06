-- Seed card products — 47 popular US credit cards
-- Colours are purpose-picked per card brand identity:
--   face_color   = gradient start (top-left)
--   gradient_end = gradient stop  (bottom-right), always darker / shifted
--   text_color   = #FFFFFF for dark cards, #000000 for Apple Card

TRUNCATE card_products RESTART IDENTITY CASCADE;

INSERT INTO card_products
    (issuer_name, bank_key, product_name, official_name, brand, face_color, gradient_end, text_color)
VALUES

-- ─── American Express ──────────────────────────────────────────────────────
('AMERICAN EXPRESS', 'AMEX', 'Blue Business Plus',
 'American Express Blue Business Plus Credit Card',
 'AMEX', '#1A3A6E', '#0C1D3C', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Blue Cash Everyday',
 'American Express Blue Cash Everyday Card',
 'AMEX', '#1E5FAD', '#103880', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Blue Cash Preferred',
 'American Express Blue Cash Preferred Card',
 'AMEX', '#1952A8', '#0E2E6E', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Gold Card',
 'American Express Gold Card',
 'AMEX', '#C9A84C', '#8B6914', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Green Card',
 'American Express Green Card',
 'AMEX', '#006B4F', '#003D2D', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Platinum Card',
 'The Platinum Card from American Express',
 'AMEX', '#8A8A8E', '#4A4A4E', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Business Gold',
 'American Express Business Gold Card',
 'AMEX', '#B8960C', '#7A6408', '#FFFFFF'),

('AMERICAN EXPRESS', 'AMEX', 'Business Platinum',
 'The Business Platinum Card from American Express',
 'AMEX', '#6E6E73', '#3A3A3D', '#FFFFFF'),

-- ─── Chase (JPMorgan Chase Bank N.A.) ─────────────────────────────────────
('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Freedom Flex',
 'Chase Freedom Flex Credit Card',
 'VISA', '#14213D', '#080F1E', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Freedom Unlimited',
 'Chase Freedom Unlimited Credit Card',
 'VISA', '#1C1C2E', '#0E0E17', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Ink Business Cash',
 'Chase Ink Business Cash Credit Card',
 'VISA', '#1A2A4A', '#0D1528', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Ink Business Preferred',
 'Chase Ink Business Preferred Credit Card',
 'VISA', '#0F1F3D', '#070F1E', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Ink Business Unlimited',
 'Chase Ink Business Unlimited Credit Card',
 'VISA', '#1A2A4A', '#0D1528', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Sapphire Preferred',
 'Chase Sapphire Preferred Card',
 'VISA', '#1E3A70', '#0F1E3D', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Sapphire Reserve',
 'Chase Sapphire Reserve Card',
 'VISA', '#1A3373', '#0D1A3C', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'United Explorer',
 'Chase United Explorer Card',
 'VISA', '#14213D', '#080F1E', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Marriott Bonvoy Boundless',
 'Chase Marriott Bonvoy Boundless Credit Card',
 'VISA', '#6B1B3E', '#3D0F24', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Amazon Prime Visa',
 'Amazon Prime Rewards Visa Signature Card',
 'VISA', '#131921', '#080C10', '#FFFFFF'),

('JPMORGAN CHASE BANK N.A.', 'CHASE', 'Southwest Rapid Rewards Plus',
 'Chase Southwest Rapid Rewards Plus Credit Card',
 'VISA', '#304CB2', '#1A2A6B', '#FFFFFF'),

-- ─── Capital One ───────────────────────────────────────────────────────────
('CAPITAL ONE', 'CAPITAL_ONE', 'Quicksilver',
 'Capital One Quicksilver Cash Rewards Credit Card',
 'VISA', '#58585A', '#2E2E2F', '#FFFFFF'),

('CAPITAL ONE', 'CAPITAL_ONE', 'SavorOne',
 'Capital One SavorOne Cash Rewards Credit Card',
 'MASTERCARD', '#1C1C1E', '#0E0E0F', '#FFFFFF'),

('CAPITAL ONE', 'CAPITAL_ONE', 'Savor',
 'Capital One Savor Cash Rewards Credit Card',
 'MASTERCARD', '#1A1A1E', '#0D0D0F', '#FFFFFF'),

('CAPITAL ONE', 'CAPITAL_ONE', 'Venture',
 'Capital One Venture Rewards Credit Card',
 'VISA', '#1A2A5E', '#0D1530', '#FFFFFF'),

('CAPITAL ONE', 'CAPITAL_ONE', 'Venture X',
 'Capital One Venture X Rewards Credit Card',
 'MASTERCARD', '#14213D', '#080F1E', '#FFFFFF'),

('CAPITAL ONE', 'CAPITAL_ONE', 'Spark Cash Plus',
 'Capital One Spark Cash Plus Credit Card',
 'MASTERCARD', '#0A1628', '#050B14', '#FFFFFF'),

-- ─── Citi ──────────────────────────────────────────────────────────────────
('CITIBANK', 'CITI', 'Custom Cash',
 'Citi Custom Cash Card',
 'MASTERCARD', '#1E1E2A', '#0F0F14', '#FFFFFF'),

('CITIBANK', 'CITI', 'Double Cash',
 'Citi Double Cash Card',
 'MASTERCARD', '#1C1C1E', '#0E0E0F', '#FFFFFF'),

('CITIBANK', 'CITI', 'Strata Premier',
 'Citi Strata Premier Card',
 'MASTERCARD', '#1E3070', '#0F1840', '#FFFFFF'),

('CITIBANK', 'CITI', 'AAdvantage Platinum Select',
 'Citi AAdvantage Platinum Select World Elite Mastercard',
 'MASTERCARD', '#1A2A5E', '#0D1530', '#FFFFFF'),

-- ─── Goldman Sachs ─────────────────────────────────────────────────────────
('GOLDMAN SACHS BANK USA', 'GOLDMAN', 'Apple Card',
 'Apple Card',
 'MASTERCARD', '#E8E8ED', '#C0C0C5', '#000000'),

-- ─── Bank of America ───────────────────────────────────────────────────────
('BANK OF AMERICA, N.A.', 'BOA', 'Customized Cash Rewards',
 'Bank of America Customized Cash Rewards Credit Card',
 'VISA', '#8B0000', '#4D0000', '#FFFFFF'),

('BANK OF AMERICA, N.A.', 'BOA', 'Premium Rewards',
 'Bank of America Premium Rewards Credit Card',
 'VISA', '#1A2A4A', '#0D1528', '#FFFFFF'),

('BANK OF AMERICA, N.A.', 'BOA', 'Travel Rewards',
 'Bank of America Travel Rewards Credit Card',
 'VISA', '#1A3A6E', '#0D1D3C', '#FFFFFF'),

('BANK OF AMERICA, N.A.', 'BOA', 'Alaska Airlines Visa',
 'Bank of America Alaska Airlines Visa Signature Credit Card',
 'VISA', '#005E6B', '#003040', '#FFFFFF'),

-- ─── Discover ──────────────────────────────────────────────────────────────
('DISCOVER BANK', 'DISCOVER', 'Discover It Cash Back',
 'Discover it Cash Back Credit Card',
 'DISCOVER', '#B22222', '#6B1414', '#FFFFFF'),

('DISCOVER BANK', 'DISCOVER', 'Discover It Miles',
 'Discover it Miles Credit Card',
 'DISCOVER', '#1A2040', '#0D1020', '#FFFFFF'),

('DISCOVER BANK', 'DISCOVER', 'Discover It Chrome',
 'Discover it Chrome Credit Card',
 'DISCOVER', '#2C2C2E', '#1A1A1C', '#FFFFFF'),

-- ─── U.S. Bank ─────────────────────────────────────────────────────────────
('U.S. BANK, N.A.', 'US_BANK', 'Altitude Connect',
 'U.S. Bank Altitude Connect Visa Signature Card',
 'VISA', '#0A1628', '#050B14', '#FFFFFF'),

('U.S. BANK, N.A.', 'US_BANK', 'Altitude Reserve',
 'U.S. Bank Altitude Reserve Visa Infinite Card',
 'VISA', '#1A2A3A', '#0D1520', '#FFFFFF'),

('U.S. BANK, N.A.', 'US_BANK', 'Cash+ Visa Signature',
 'U.S. Bank Cash+ Visa Signature Card',
 'VISA', '#2A1648', '#150B24', '#FFFFFF'),

-- ─── Wells Fargo ───────────────────────────────────────────────────────────
('WELLS FARGO BANK, N.A.', 'WELLS_FARGO', 'Active Cash',
 'Wells Fargo Active Cash Card',
 'VISA', '#4A2E04', '#261802', '#FFFFFF'),

('WELLS FARGO BANK, N.A.', 'WELLS_FARGO', 'Autograph',
 'Wells Fargo Autograph Card',
 'VISA', '#1A2A4A', '#0D1528', '#FFFFFF'),

('WELLS FARGO BANK, N.A.', 'WELLS_FARGO', 'Reflect',
 'Wells Fargo Reflect Card',
 'VISA', '#6E6E73', '#3A3A3D', '#FFFFFF'),

-- ─── Barclays ──────────────────────────────────────────────────────────────
('BARCLAYS BANK DELAWARE', 'BARCLAYS', 'JetBlue Plus',
 'Barclays JetBlue Plus Card',
 'MASTERCARD', '#003087', '#001842', '#FFFFFF'),

('BARCLAYS BANK DELAWARE', 'BARCLAYS', 'AAdvantage Aviator Red',
 'Barclays AAdvantage Aviator Red World Elite Mastercard',
 'MASTERCARD', '#8B0000', '#4D0000', '#FFFFFF'),

-- ─── Navy Federal Credit Union ─────────────────────────────────────────────
('NAVY FEDERAL CREDIT UNION', 'NAVY_FEDERAL', 'More Rewards Amex',
 'Navy Federal Credit Union More Rewards American Express Card',
 'AMEX', '#0F4471', '#072238', '#FFFFFF'),

-- ─── Synchrony ─────────────────────────────────────────────────────────────
('SYNCHRONY BANK', 'SYNCHRONY', 'Amazon Store Card',
 'Amazon Store Card',
 'MASTERCARD', '#131921', '#080C10', '#FFFFFF');
