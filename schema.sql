-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: bankdb
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `account_holders`
--

DROP TABLE IF EXISTS `account_holders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_holders` (
  `account_id` bigint NOT NULL,
  `customer_id` bigint NOT NULL,
  `role` enum('PRIMARY','JOINT') NOT NULL DEFAULT 'PRIMARY',
  PRIMARY KEY (`account_id`,`customer_id`),
  KEY `fk_ah_customer` (`customer_id`),
  CONSTRAINT `fk_ah_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`account_id`),
  CONSTRAINT `fk_ah_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accounts`
--

DROP TABLE IF EXISTS `accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accounts` (
  `account_id` bigint NOT NULL AUTO_INCREMENT,
  `account_no` char(12) NOT NULL,
  `branch_id` int NOT NULL,
  `account_type` enum('SAVINGS','CURRENT','LOAN') NOT NULL,
  `balance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `overdraft_limit` decimal(15,2) NOT NULL DEFAULT '0.00',
  `status` enum('ACTIVE','FROZEN','CLOSED') NOT NULL DEFAULT 'ACTIVE',
  `opened_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`),
  UNIQUE KEY `account_no` (`account_no`),
  KEY `fk_acc_branch` (`branch_id`),
  CONSTRAINT `fk_acc_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`branch_id`),
  CONSTRAINT `chk_overdraft_nonneg` CHECK ((`overdraft_limit` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_prevent_overdraft` BEFORE UPDATE ON `accounts` FOR EACH ROW BEGIN
    IF NEW.account_type = 'SAVINGS' AND NEW.balance < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overdraft blocked: savings cannot go negative';
    END IF;
    IF NEW.account_type = 'CURRENT' AND NEW.balance < -NEW.overdraft_limit THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overdraft blocked: exceeds overdraft limit';
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_audit_balance` AFTER UPDATE ON `accounts` FOR EACH ROW BEGIN
    IF NEW.balance <> OLD.balance THEN
        INSERT INTO audit_log (account_id, old_balance, new_balance, changed_by)
        VALUES (NEW.account_id, OLD.balance, NEW.balance, CURRENT_USER());
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `audit_log`
--

DROP TABLE IF EXISTS `audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_log` (
  `audit_id` bigint NOT NULL AUTO_INCREMENT,
  `account_id` bigint NOT NULL,
  `old_balance` decimal(15,2) NOT NULL,
  `new_balance` decimal(15,2) NOT NULL,
  `changed_by` varchar(80) NOT NULL,
  `changed_at` timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`audit_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5362 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `branches`
--

DROP TABLE IF EXISTS `branches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `branches` (
  `branch_id` int NOT NULL AUTO_INCREMENT,
  `ifsc_code` char(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `city` varchar(60) NOT NULL,
  PRIMARY KEY (`branch_id`),
  UNIQUE KEY `ifsc_code` (`ifsc_code`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers` (
  `customer_id` bigint NOT NULL AUTO_INCREMENT,
  `branch_id` int NOT NULL,
  `full_name` varchar(120) NOT NULL,
  `email` varchar(120) NOT NULL,
  `phone` varchar(15) NOT NULL,
  `dob` date NOT NULL,
  `kyc_status` enum('PENDING','VERIFIED') NOT NULL DEFAULT 'PENDING',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `password_hash` char(64) DEFAULT NULL,
  PRIMARY KEY (`customer_id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone` (`phone`),
  KEY `fk_cust_branch` (`branch_id`),
  CONSTRAINT `fk_cust_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`branch_id`)
) ENGINE=InnoDB AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `daily_branch_summary`
--

DROP TABLE IF EXISTS `daily_branch_summary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `daily_branch_summary` (
  `branch_id` int NOT NULL,
  `summary_date` date NOT NULL,
  `total_deposits` decimal(18,2) NOT NULL DEFAULT '0.00',
  `total_withdrawals` decimal(18,2) NOT NULL DEFAULT '0.00',
  `flagged_count` int NOT NULL DEFAULT '0',
  `refreshed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`branch_id`,`summary_date`),
  CONSTRAINT `fk_dbs_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `loan_schedule`
--

DROP TABLE IF EXISTS `loan_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `loan_schedule` (
  `loan_id` bigint NOT NULL,
  `installment_no` smallint NOT NULL,
  `due_date` date NOT NULL,
  `principal_part` decimal(15,2) NOT NULL,
  `interest_part` decimal(15,2) NOT NULL,
  `status` enum('PENDING','PAID','MISSED') NOT NULL DEFAULT 'PENDING',
  `paid_txn_id` bigint DEFAULT NULL,
  PRIMARY KEY (`loan_id`,`installment_no`),
  KEY `fk_ls_txn` (`paid_txn_id`),
  KEY `idx_ls_due` (`due_date`,`status`),
  CONSTRAINT `fk_ls_loan` FOREIGN KEY (`loan_id`) REFERENCES `loans` (`loan_id`),
  CONSTRAINT `fk_ls_txn` FOREIGN KEY (`paid_txn_id`) REFERENCES `transactions` (`txn_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_loan_default` AFTER UPDATE ON `loan_schedule` FOR EACH ROW BEGIN
    IF NEW.status = 'MISSED' AND OLD.status <> 'MISSED' THEN
        IF (SELECT COUNT(*) FROM loan_schedule
             WHERE loan_id = NEW.loan_id AND status = 'MISSED') >= 3 THEN
            UPDATE loans SET status = 'DEFAULT' WHERE loan_id = NEW.loan_id;
        END IF;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `loans`
--

DROP TABLE IF EXISTS `loans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `loans` (
  `loan_id` bigint NOT NULL AUTO_INCREMENT,
  `account_id` bigint NOT NULL,
  `principal` decimal(15,2) NOT NULL,
  `annual_rate` decimal(5,2) NOT NULL,
  `tenure_months` smallint NOT NULL,
  `emi_amount` decimal(15,2) NOT NULL,
  `status` enum('ACTIVE','CLOSED','DEFAULT') NOT NULL DEFAULT 'ACTIVE',
  `disbursed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`loan_id`),
  UNIQUE KEY `account_id` (`account_id`),
  CONSTRAINT `fk_loan_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`account_id`),
  CONSTRAINT `chk_principal_pos` CHECK ((`principal` > 0)),
  CONSTRAINT `chk_rate_pos` CHECK ((`annual_rate` > 0)),
  CONSTRAINT `chk_tenure_range` CHECK ((`tenure_months` between 6 and 360))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `txn_id` bigint NOT NULL AUTO_INCREMENT,
  `account_id` bigint NOT NULL,
  `txn_type` enum('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT','EMI','FEE') NOT NULL,
  `amount` decimal(15,2) NOT NULL,
  `balance_after` decimal(15,2) NOT NULL,
  `transfer_group` char(36) DEFAULT NULL,
  `narration` varchar(200) DEFAULT NULL,
  `flagged` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`txn_id`),
  KEY `idx_txn_acct_time` (`account_id`,`created_at`),
  KEY `idx_txn_group` (`transfer_group`),
  KEY `idx_txn_flagged` (`flagged`,`created_at`),
  CONSTRAINT `fk_txn_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`account_id`),
  CONSTRAINT `chk_amount_pos` CHECK ((`amount` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=5005387 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_flag_large_txn` BEFORE INSERT ON `transactions` FOR EACH ROW BEGIN
    IF NEW.amount > 50000 THEN
        SET NEW.flagged = TRUE;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_block_ledger_update` BEFORE UPDATE ON `transactions` FOR EACH ROW BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ledger is immutable: UPDATE forbidden';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_block_ledger_delete` BEFORE DELETE ON `transactions` FOR EACH ROW BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ledger is immutable: DELETE forbidden';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Temporary view structure for view `v_account_statement`
--

DROP TABLE IF EXISTS `v_account_statement`;
/*!50001 DROP VIEW IF EXISTS `v_account_statement`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_account_statement` AS SELECT 
 1 AS `txn_id`,
 1 AS `account_no`,
 1 AS `full_name`,
 1 AS `txn_type`,
 1 AS `amount`,
 1 AS `balance_after`,
 1 AS `narration`,
 1 AS `flagged`,
 1 AS `created_at`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_branch_summary`
--

DROP TABLE IF EXISTS `v_branch_summary`;
/*!50001 DROP VIEW IF EXISTS `v_branch_summary`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_branch_summary` AS SELECT 
 1 AS `branch_id`,
 1 AS `branch_name`,
 1 AS `total_in`,
 1 AS `total_out`,
 1 AS `flagged_count`*/;
SET character_set_client = @saved_cs_client;

--
-- Dumping routines for database 'bankdb'
--
/*!50003 DROP PROCEDURE IF EXISTS `create_loan` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_loan`(IN p_customer BIGINT, IN p_principal DECIMAL(15,2),
                              IN p_rate DECIMAL(5,2), IN p_tenure SMALLINT)
BEGIN
    DECLARE v_savings_acc BIGINT;
    DECLARE v_savings_bal DECIMAL(15,2);
    DECLARE v_branch      INT;
    DECLARE v_loan_acc    BIGINT;
    DECLARE v_loan_id     BIGINT;
    DECLARE v_r           DECIMAL(20,10);
    DECLARE v_factor      DECIMAL(30,10);
    DECLARE v_emi         DECIMAL(15,2);
    DECLARE v_outstanding DECIMAL(15,2);
    DECLARE v_interest    DECIMAL(15,2);
    DECLARE v_princ_part  DECIMAL(15,2);
    DECLARE v_i           SMALLINT DEFAULT 1;
    DECLARE v_group       CHAR(36);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_principal IS NULL OR p_principal <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Principal must be positive';
    END IF;
    IF p_tenure NOT BETWEEN 6 AND 360 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenure must be 6..360 months';
    END IF;

    START TRANSACTION;

    SELECT a.account_id, a.balance, a.branch_id
      INTO v_savings_acc, v_savings_bal, v_branch
      FROM accounts a
      JOIN account_holders ah ON ah.account_id = a.account_id
     WHERE ah.customer_id = p_customer AND ah.role = 'PRIMARY'
       AND a.account_type = 'SAVINGS' AND a.status = 'ACTIVE'
     LIMIT 1 FOR UPDATE;

    IF v_savings_acc IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No active primary savings account';
    END IF;

    
    INSERT INTO accounts (account_no, branch_id, account_type, balance, status)
    VALUES (LPAD(FLOOR(RAND() * 1e12), 12, '0'), v_branch, 'LOAN', -p_principal, 'ACTIVE');
    SET v_loan_acc = LAST_INSERT_ID();
    INSERT INTO account_holders VALUES (v_loan_acc, p_customer, 'PRIMARY');

    
    SET v_r      = p_rate / 1200;
    SET v_factor = POW(1 + v_r, p_tenure);
    SET v_emi    = ROUND(p_principal * v_r * v_factor / (v_factor - 1), 2);

    INSERT INTO loans (account_id, principal, annual_rate, tenure_months, emi_amount)
    VALUES (v_loan_acc, p_principal, p_rate, p_tenure, v_emi);
    SET v_loan_id = LAST_INSERT_ID();

    SET v_outstanding = p_principal;
    WHILE v_i <= p_tenure DO
        SET v_interest = ROUND(v_outstanding * v_r, 2);
        IF v_i < p_tenure THEN
            SET v_princ_part = v_emi - v_interest;
        ELSE
            SET v_princ_part = v_outstanding;   
        END IF;
        INSERT INTO loan_schedule (loan_id, installment_no, due_date, principal_part, interest_part)
        VALUES (v_loan_id, v_i, DATE_ADD(CURDATE(), INTERVAL v_i MONTH), v_princ_part, v_interest);
        SET v_outstanding = v_outstanding - v_princ_part;
        SET v_i = v_i + 1;
    END WHILE;

    
    SET v_group = UUID();
    UPDATE accounts SET balance = balance + p_principal WHERE account_id = v_savings_acc;
    INSERT INTO transactions (account_id, txn_type, amount, balance_after, transfer_group, narration)
    VALUES (v_savings_acc, 'TRANSFER_IN',  p_principal, v_savings_bal + p_principal, v_group, CONCAT('Loan disbursal #', v_loan_id)),
           (v_loan_acc,    'TRANSFER_OUT', p_principal, -p_principal,                v_group, CONCAT('Loan disbursal #', v_loan_id));

    COMMIT;
    SELECT v_loan_id AS loan_id, v_loan_acc AS loan_account_id, v_emi AS emi_amount;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `deposit` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `deposit`(IN p_acc BIGINT, IN p_amount DECIMAL(15,2), IN p_narration VARCHAR(200))
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_status  VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit amount must be positive';
    END IF;

    START TRANSACTION;

    SELECT balance, status INTO v_balance, v_status
      FROM accounts WHERE account_id = p_acc FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
    END IF;
    IF v_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is not ACTIVE';
    END IF;

    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_acc;
    INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration)
    VALUES (p_acc, 'DEPOSIT', p_amount, v_balance + p_amount, p_narration);

    COMMIT;
    SELECT v_balance + p_amount AS new_balance;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_statement` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_statement`(IN p_acc BIGINT, IN p_from DATE, IN p_to DATE)
BEGIN
    SELECT txn_id, txn_type, amount, balance_after, narration, created_at
      FROM transactions
     WHERE account_id = p_acc
       AND created_at >= p_from
       AND created_at < DATE_ADD(p_to, INTERVAL 1 DAY)
     ORDER BY created_at, txn_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `post_emi_batch` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `post_emi_batch`()
BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE v_loan_id BIGINT; DECLARE v_inst_no SMALLINT; DECLARE v_emi DECIMAL(15,2);
    DECLARE v_loan_acc BIGINT; DECLARE v_customer BIGINT;
    DECLARE v_savings_acc BIGINT; DECLARE v_savings_bal DECIMAL(15,2);
    DECLARE v_loan_bal DECIMAL(15,2); DECLARE v_txn_id BIGINT;

    DECLARE cur CURSOR FOR
        SELECT ls.loan_id, ls.installment_no, ls.principal_part + ls.interest_part,
               l.account_id, ah.customer_id
          FROM loan_schedule ls
          JOIN loans l            ON l.loan_id = ls.loan_id
          JOIN account_holders ah ON ah.account_id = l.account_id AND ah.role = 'PRIMARY'
         WHERE ls.due_date <= CURDATE() AND ls.status = 'PENDING' AND l.status = 'ACTIVE';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur;
    batch_loop: LOOP
        FETCH cur INTO v_loan_id, v_inst_no, v_emi, v_loan_acc, v_customer;
        IF v_done = 1 THEN LEAVE batch_loop; END IF;

        BEGIN
            
            
            DECLARE v_inner_nf INT DEFAULT 0;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_inner_nf = 1;
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                UPDATE loan_schedule SET status = 'MISSED'
                 WHERE loan_id = v_loan_id AND installment_no = v_inst_no;
            END;

            START TRANSACTION;

            SET v_savings_acc = NULL;
            SELECT a.account_id, a.balance INTO v_savings_acc, v_savings_bal
              FROM accounts a
              JOIN account_holders ah ON ah.account_id = a.account_id
             WHERE ah.customer_id = v_customer AND ah.role = 'PRIMARY'
               AND a.account_type = 'SAVINGS' AND a.status = 'ACTIVE'
             LIMIT 1 FOR UPDATE;

            IF v_savings_acc IS NULL OR v_savings_bal < v_emi THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'EMI: insufficient funds';
            END IF;

            SELECT balance INTO v_loan_bal FROM accounts WHERE account_id = v_loan_acc FOR UPDATE;

            UPDATE accounts SET balance = balance - v_emi WHERE account_id = v_savings_acc;
            UPDATE accounts SET balance = balance + v_emi WHERE account_id = v_loan_acc;

            INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration)
            VALUES (v_savings_acc, 'EMI', v_emi, v_savings_bal - v_emi,
                    CONCAT('EMI ', v_inst_no, ' loan #', v_loan_id));
            SET v_txn_id = LAST_INSERT_ID();

            INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration)
            VALUES (v_loan_acc, 'TRANSFER_IN', v_emi, v_loan_bal + v_emi,
                    CONCAT('EMI ', v_inst_no, ' loan #', v_loan_id));

            UPDATE loan_schedule SET status = 'PAID', paid_txn_id = v_txn_id
             WHERE loan_id = v_loan_id AND installment_no = v_inst_no;

            UPDATE loans SET status = 'CLOSED'
             WHERE loan_id = v_loan_id
               AND NOT EXISTS (SELECT 1 FROM loan_schedule
                                WHERE loan_id = v_loan_id AND status = 'PENDING');

            COMMIT;
        END;
    END LOOP;
    CLOSE cur;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `transfer_funds` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `transfer_funds`(IN p_from BIGINT, IN p_to BIGINT, IN p_amount DECIMAL(15,2), IN p_narration VARCHAR(200))
BEGIN
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE v_from_type    VARCHAR(10);
    DECLARE v_from_status  VARCHAR(10);
    DECLARE v_from_od      DECIMAL(15,2);
    DECLARE v_to_balance   DECIMAL(15,2);
    DECLARE v_to_status    VARCHAR(10);
    DECLARE v_group        CHAR(36);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transfer amount must be positive';
    END IF;
    IF p_from = p_to THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot transfer to the same account';
    END IF;

    START TRANSACTION;

    
    IF p_from < p_to THEN
        SELECT balance, account_type, status, overdraft_limit
          INTO v_from_balance, v_from_type, v_from_status, v_from_od
          FROM accounts WHERE account_id = p_from FOR UPDATE;
        SELECT balance, status INTO v_to_balance, v_to_status
          FROM accounts WHERE account_id = p_to FOR UPDATE;
    ELSE
        SELECT balance, status INTO v_to_balance, v_to_status
          FROM accounts WHERE account_id = p_to FOR UPDATE;
        SELECT balance, account_type, status, overdraft_limit
          INTO v_from_balance, v_from_type, v_from_status, v_from_od
          FROM accounts WHERE account_id = p_from FOR UPDATE;
    END IF;

    IF v_from_status IS NULL OR v_to_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
    END IF;
    IF v_from_status <> 'ACTIVE' OR v_to_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Both accounts must be ACTIVE';
    END IF;
    IF v_from_balance + IF(v_from_type = 'CURRENT', v_from_od, 0) < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
    END IF;

    SET v_group = UUID();

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;

    INSERT INTO transactions (account_id, txn_type, amount, balance_after, transfer_group, narration)
    VALUES (p_from, 'TRANSFER_OUT', p_amount, v_from_balance - p_amount, v_group, p_narration),
           (p_to,   'TRANSFER_IN',  p_amount, v_to_balance   + p_amount, v_group, p_narration);

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `withdraw` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = cp850 */ ;
/*!50003 SET character_set_results = cp850 */ ;
/*!50003 SET collation_connection  = cp850_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `withdraw`(IN p_acc BIGINT, IN p_amount DECIMAL(15,2), IN p_narration VARCHAR(200), IN p_txn_type VARCHAR(12))
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_type    VARCHAR(10);
    DECLARE v_status  VARCHAR(10);
    DECLARE v_od      DECIMAL(15,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Withdrawal amount must be positive';
    END IF;
    IF p_txn_type NOT IN ('WITHDRAWAL','EMI','FEE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid txn type for withdraw';
    END IF;

    START TRANSACTION;

    SELECT balance, account_type, status, overdraft_limit
      INTO v_balance, v_type, v_status, v_od
      FROM accounts WHERE account_id = p_acc FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
    END IF;
    IF v_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is not ACTIVE';
    END IF;
    IF v_balance + IF(v_type = 'CURRENT', v_od, 0) < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_acc;
    INSERT INTO transactions (account_id, txn_type, amount, balance_after, narration)
    VALUES (p_acc, p_txn_type, p_amount, v_balance - p_amount, p_narration);

    COMMIT;
    SELECT v_balance - p_amount AS new_balance;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `v_account_statement`
--

/*!50001 DROP VIEW IF EXISTS `v_account_statement`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = cp850 */;
/*!50001 SET character_set_results     = cp850 */;
/*!50001 SET collation_connection      = cp850_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_account_statement` AS select `t`.`txn_id` AS `txn_id`,`a`.`account_no` AS `account_no`,`c`.`full_name` AS `full_name`,`t`.`txn_type` AS `txn_type`,`t`.`amount` AS `amount`,`t`.`balance_after` AS `balance_after`,`t`.`narration` AS `narration`,`t`.`flagged` AS `flagged`,`t`.`created_at` AS `created_at` from (((`transactions` `t` join `accounts` `a` on((`a`.`account_id` = `t`.`account_id`))) join `account_holders` `ah` on(((`ah`.`account_id` = `a`.`account_id`) and (`ah`.`role` = 'PRIMARY')))) join `customers` `c` on((`c`.`customer_id` = `ah`.`customer_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_branch_summary`
--

/*!50001 DROP VIEW IF EXISTS `v_branch_summary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = cp850 */;
/*!50001 SET character_set_results     = cp850 */;
/*!50001 SET collation_connection      = cp850_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_branch_summary` AS select `b`.`branch_id` AS `branch_id`,`b`.`name` AS `branch_name`,sum((case when (`t`.`txn_type` in ('DEPOSIT','TRANSFER_IN')) then `t`.`amount` else 0 end)) AS `total_in`,sum((case when (`t`.`txn_type` in ('WITHDRAWAL','TRANSFER_OUT','EMI','FEE')) then `t`.`amount` else 0 end)) AS `total_out`,sum(`t`.`flagged`) AS `flagged_count` from ((`branches` `b` join `accounts` `a` on((`a`.`branch_id` = `b`.`branch_id`))) join `transactions` `t` on((`t`.`account_id` = `a`.`account_id`))) group by `b`.`branch_id`,`b`.`name` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed
