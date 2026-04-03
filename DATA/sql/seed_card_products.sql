-- Seed 20 known card products
-- Run after the app has started (Hibernate creates the card_products table)
-- Run from pgAdmin Query Tool connected to credtrack database

INSERT INTO card_products (issuer_name, product_name, official_name, image_filename, brand, link) VALUES
-- American Express
('AMERICAN EXPRESS', 'Blue Business Plus', 'American Express Blue Business Plus Credit Card', 'amex-blue-business-plus.png', 'AMEX', NULL),
('AMERICAN EXPRESS', 'Blue Cash Preferred', 'American Express Blue Cash Preferred Card', 'amex-blue-cash-preferred.png', 'AMEX', NULL),
('AMERICAN EXPRESS', 'Gold Card', 'American Express Gold Card', 'amex-gold.png', 'AMEX', NULL),
('AMERICAN EXPRESS', 'Platinum Card', 'The Platinum Card from American Express', 'amex-platinum.png', 'AMEX', NULL),

-- Chase
('JPMORGAN CHASE BANK N.A.', 'Freedom Flex', 'Chase Freedom Flex Credit Card', 'chase-freedom-flex.png', 'VISA', NULL),
('JPMORGAN CHASE BANK N.A.', 'Freedom Unlimited', 'Chase Freedom Unlimited Credit Card', 'chase-freedom-unlimited.png', 'VISA', NULL),
('JPMORGAN CHASE BANK N.A.', 'Ink Business Preferred', 'Chase Ink Business Preferred Credit Card', 'chase-ink-business-preferred.png', 'VISA', NULL),
('JPMORGAN CHASE BANK N.A.', 'Sapphire Preferred', 'Chase Sapphire Preferred Card', 'chase-sapphire-preferred.png', 'VISA', NULL),
('JPMORGAN CHASE BANK N.A.', 'Sapphire Reserve', 'Chase Sapphire Reserve Card', 'chase-sapphire-reserve.png', 'VISA', NULL),

-- Capital One
('CAPITAL ONE', 'Quicksilver', 'Capital One Quicksilver Cash Rewards Credit Card', 'capital-one-quicksilver.png', 'VISA', NULL),
('CAPITAL ONE', 'Savor', 'Capital One Savor Cash Rewards Credit Card', 'capital-one-savor.png', 'MASTERCARD', NULL),
('CAPITAL ONE', 'Venture', 'Capital One Venture Rewards Credit Card', 'capital-one-venture.png', 'VISA', NULL),
('CAPITAL ONE', 'Venture X', 'Capital One Venture X Rewards Credit Card', 'capital-one-venture-x.png', 'VISA', NULL),

-- Citi
('CITIBANK', 'Custom Cash', 'Citi Custom Cash Card', 'citi-custom-cash.webp', 'MASTERCARD', NULL),
('CITIBANK', 'Double Cash', 'Citi Double Cash Card', 'citi-double-cash.webp', 'MASTERCARD', NULL),

-- Others
('GOLDMAN SACHS BANK USA', 'Apple Card', 'Apple Card', 'apple-card.png', 'MASTERCARD', NULL),
('BANK OF AMERICA, N.A.', 'Customized Cash Rewards', 'Bank of America Customized Cash Rewards Credit Card', 'boa-customized-cash.png', 'VISA', NULL),
('DISCOVER BANK', 'Discover It Cash Back', 'Discover it Cash Back Credit Card', 'discover-it-cash-back.png', 'DISCOVER', NULL),
('U.S. BANK, N.A.', 'Altitude Connect', 'U.S. Bank Altitude Connect Visa Signature Card', 'usbank-altitude-connect.png', 'VISA', NULL),
('WELLS FARGO BANK, N.A.', 'Active Cash', 'Wells Fargo Active Cash Card', 'wells-fargo-active-cash.png', 'VISA', NULL);
