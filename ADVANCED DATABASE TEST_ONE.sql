----QUESTION 1 - PHARMACYQ1 (a) - Tables + Seed [6

CREATE DATABASE IF NOT EXISTS pharmacy_db;
USE pharmacy_db;

CREATE TABLE medicines (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL UNIQUE,
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0)
);

CREATE TABLE sales (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    sold_on DATE NOT NULL DEFAULT (CURRENT_DATE),
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE stock_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    old_qty INT NOT NULL CHECK (old_qty >= 0),
    new_qty INT NOT NULL CHECK (new_qty >= 0),
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE daily_sales (
    sales_date DATE PRIMARY KEY,
    total_qty INT NOT NULL DEFAULT 0 CHECK (total_qty >= 0),
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0)
);

INSERT INTO medicines (medicine_name, unit_price, stock_qty) VALUES
('Paracetamol 500mg', 5.00, 100),
('Amoxicillin 500mg', 12.50, 50),
('Vitamin C 1000mg', 8.00, 80);

-- Load 6 sales via procedure (full procedure in Q1c below)
-- After (c) is created, run:
CALL pr_record_sale(1, 10, '2026-11-24');
CALL pr_record_sale(2, 5,  '2026-11-24');
CALL pr_record_sale(3, 8,  '2026-11-24');
CALL pr_record_sale(1, 4,  '2026-11-24');
CALL pr_record_sale(2, 2,  '2026-11-25');
CALL pr_record_sale(3, 10, '2026-11-25');

---Q1 (a) - Tables + Seed [6]
CREATE DATABASE IF NOT EXISTS pharmacy_db;
USE pharmacy_db;

CREATE TABLE medicines (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL UNIQUE,
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0)
);

CREATE TABLE sales (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    sold_on DATE NOT NULL DEFAULT (CURRENT_DATE),
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE stock_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    old_qty INT NOT NULL CHECK (old_qty >= 0),
    new_qty INT NOT NULL CHECK (new_qty >= 0),
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE daily_sales (
    sales_date DATE PRIMARY KEY,
    total_qty INT NOT NULL DEFAULT 0 CHECK (total_qty >= 0),
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0)
);

INSERT INTO medicines (medicine_name, unit_price, stock_qty) VALUES
('Paracetamol 500mg', 5.00, 100),
('Amoxicillin 500mg', 12.50, 50),
('Vitamin C 1000mg', 8.00, 80);

-- Load 6 sales via procedure (full procedure in Q1c below)
-- After (c) is created, run:
CALL pr_record_sale(1, 10, '2026-11-24');
CALL pr_record_sale(2, 5,  '2026-11-24');
CALL pr_record_sale(3, 8,  '2026-11-24');
CALL pr_record_sale(1, 4,  '2026-11-24');
CALL pr_record_sale(2, 2,  '2026-11-25');
CALL pr_record_sale(3, 10, '2026-11-25');






----Q1 (b) - Function [6]
DELIMITER //
CREATE FUNCTION fn_sale_value(p_medicine_id INT, p_quantity INT)
RETURNS DECIMAL(12,2) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_price DECIMAL(10,2);
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive';
    END IF;
    SELECT unit_price INTO v_price FROM medicines WHERE medicine_id = p_medicine_id;
    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown medicine';
    END IF;
    RETURN v_price * p_quantity;
END //
DELIMITER ;

SELECT fn_sale_value(1, 10) AS sale_value; -- 50.00
SELECT fn_sale_value(999, 5) AS sale_value; -- error
SELECT fn_sale_value(1, 0) AS sale_value; -- error

--Q1 (c) - Procedure [8]

DELIMITER //
CREATE PROCEDURE pr_record_sale(IN p_medicine_id INT, IN p_quantity INT, IN p_sold_on DATE)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_stock INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive';
    END IF;
    SELECT unit_price, stock_qty INTO v_price, v_stock FROM medicines WHERE medicine_id = p_medicine_id;
    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Medicine not found';
    END IF;
    IF p_quantity > v_stock THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock';
    END IF;
    START TRANSACTION;
        INSERT INTO sales (medicine_id, quantity, unit_price, sold_on)
        VALUES (p_medicine_id, p_quantity, v_price, p_sold_on);
        UPDATE medicines SET stock_qty = stock_qty - p_quantity WHERE medicine_id = p_medicine_id;
    COMMIT;
END //
DELIMITER ;

CALL pr_record_sale(1, 5, '2026-11-24'); -- valid
CALL pr_record_sale(1, 9999, '2026-11-24'); -- invalid, both tables unchanged



--Q1 (d) - Trigger [8]

DELIMITER //
CREATE TRIGGER trg_medicines_stock_audit
AFTER UPDATE ON medicines
FOR EACH ROW
BEGIN
    IF OLD.stock_qty <> NEW.stock_qty THEN
        INSERT INTO stock_audit (medicine_id, old_qty, new_qty)
        VALUES (NEW.medicine_id, OLD.stock_qty, NEW.stock_qty);
    END IF;
END //
DELIMITER ;

UPDATE medicines SET stock_qty = stock_qty - 2 WHERE medicine_id = 1; -- creates 1 audit row
UPDATE medicines SET unit_price = 5.50 WHERE medicine_id = 1; -- creates NO audit row

--Q1 (f) - Index [5]

CREATE INDEX idx_sales_medicine_date ON sales (medicine_id, sold_on);

EXPLAIN SELECT sale_id, medicine_id, quantity, unit_price, sold_on FROM sales
WHERE medicine_id = 1 AND sold_on BETWEEN '2026-11-24' AND '2026-11-25';
-- Justification: medicine_id = equality first, sold_on = range second.
-- Seeks to that medicine, scans only date range, avoids full scan / filesort.
-- Do NOT put sold_on first.

--Q1 (g) - Scheduled Job [6]
DELIMITER //
CREATE PROCEDURE pr_refresh_sales(IN p_day DATE)
BEGIN
    DECLARE v_total_qty INT DEFAULT 0;
    DECLARE v_total_amount DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(quantity),0), COALESCE(SUM(quantity * unit_price),0.00)
    INTO v_total_qty, v_total_amount FROM sales WHERE sold_on = p_day;
    INSERT INTO daily_sales (sales_date, total_qty, total_amount)
    VALUES (p_day, v_total_qty, v_total_amount)
    ON DUPLICATE KEY UPDATE total_qty = v_total_qty, total_amount = v_total_amount;
END //
DELIMITER ;

CALL pr_refresh_sales('2026-11-24');
CALL pr_refresh_sales('2026-11-24'); -- run twice, must NOT double

SET GLOBAL event_scheduler = ON;
CREATE EVENT ev_refresh_daily_sales
ON SCHEDULE EVERY 1 DAY STARTS '2026-11-25 00:15:00'
ON COMPLETION PRESERVE ENABLE
DO CALL pr_refresh_sales(DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY));





























































