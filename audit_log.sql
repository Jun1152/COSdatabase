-- =============================================
-- AUDIT LOG SYSTEM for COS Database
-- Purpose: Track all changes to critical tables for compliance and debugging
-- =============================================

USE COS;

-- =============================================
-- 1. Create AUDIT_LOG Table
-- =============================================
CREATE TABLE AUDIT_LOG (
    LogID             INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    TableName         VARCHAR(100) NOT NULL,
    RecordID          INT NOT NULL,
    Action            ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    OldData           JSON,
    NewData           JSON,
    ChangedByStaffID  INT,
    ChangedAt         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ChangedByStaffID) REFERENCES MEDICAL_STAFF(StaffID)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Index for fast lookup by table + record
CREATE INDEX idx_audit_table_record ON AUDIT_LOG (TableName, RecordID);
CREATE INDEX idx_audit_changed_at ON AUDIT_LOG (ChangedAt);


-- =============================================
-- 2. Trigger: PATIENT table
-- =============================================
DELIMITER $$

CREATE TRIGGER trg_patient_audit_insert
AFTER INSERT ON PATIENT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, NewData, ChangedByStaffID)
    VALUES ('PATIENT', NEW.PatientID, 'INSERT', JSON_OBJECT(
        'FullName', NEW.FullName,
        'IC_Passport', NEW.IC_Passport,
        'DOB', NEW.DOB,
        'Gender', NEW.Gender,
        'BloodType', NEW.BloodType
    ), NULL);
END$$

CREATE TRIGGER trg_patient_audit_update
AFTER UPDATE ON PATIENT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, NewData, ChangedByStaffID)
    VALUES ('PATIENT', NEW.PatientID, 'UPDATE',
        JSON_OBJECT(
            'FullName', OLD.FullName, 'IC_Passport', OLD.IC_Passport,
            'DOB', OLD.DOB, 'Gender', OLD.Gender, 'BloodType', OLD.BloodType
        ),
        JSON_OBJECT(
            'FullName', NEW.FullName, 'IC_Passport', NEW.IC_Passport,
            'DOB', NEW.DOB, 'Gender', NEW.Gender, 'BloodType', NEW.BloodType
        ),
        NULL);
END$$

CREATE TRIGGER trg_patient_audit_delete
AFTER DELETE ON PATIENT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, ChangedByStaffID)
    VALUES ('PATIENT', OLD.PatientID, 'DELETE',
        JSON_OBJECT(
            'FullName', OLD.FullName, 'IC_Passport', OLD.IC_Passport,
            'DOB', OLD.DOB, 'Gender', OLD.Gender, 'BloodType', OLD.BloodType
        ),
        NULL);
END$$

DELIMITER ;


-- =============================================
-- 3. Trigger: VISIT table
-- =============================================
DELIMITER $$

CREATE TRIGGER trg_visit_audit_insert
AFTER INSERT ON VISIT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, NewData, ChangedByStaffID)
    VALUES ('VISIT', NEW.VisitID, 'INSERT', JSON_OBJECT(
        'PatientID', NEW.PatientID,
        'PrimaryDoctorID', NEW.PrimaryDoctorID,
        'VisitDate', NEW.VisitDate,
        'VisitType', NEW.VisitType,
        'Status', NEW.Status
    ), NULL);
END$$

CREATE TRIGGER trg_visit_audit_update
AFTER UPDATE ON VISIT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, NewData, ChangedByStaffID)
    VALUES ('VISIT', NEW.VisitID, 'UPDATE',
        JSON_OBJECT('Status', OLD.Status, 'VisitType', OLD.VisitType),
        JSON_OBJECT('Status', NEW.Status, 'VisitType', NEW.VisitType),
        NULL);
END$$

CREATE TRIGGER trg_visit_audit_delete
AFTER DELETE ON VISIT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, ChangedByStaffID)
    VALUES ('VISIT', OLD.VisitID, 'DELETE',
        JSON_OBJECT(
            'PatientID', OLD.PatientID, 'PrimaryDoctorID', OLD.PrimaryDoctorID,
            'VisitDate', OLD.VisitDate, 'Status', OLD.Status
        ),
        NULL);
END$$

DELIMITER ;


-- =============================================
-- 4. Trigger: MEDICAL_RECORD table (Most Important)
-- =============================================
DELIMITER $$

CREATE TRIGGER trg_medicalrecord_audit_insert
AFTER INSERT ON MEDICAL_RECORD
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, NewData, ChangedByStaffID)
    VALUES ('MEDICAL_RECORD', NEW.RecordID, 'INSERT', JSON_OBJECT(
        'VisitID', NEW.VisitID,
        'AuthorID', NEW.AuthorID,
        'RecordType', NEW.RecordType,
        'Content', NEW.Content,
        'Version', NEW.Version
    ), NULL);
END$$

CREATE TRIGGER trg_medicalrecord_audit_update
AFTER UPDATE ON MEDICAL_RECORD
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, NewData, ChangedByStaffID)
    VALUES ('MEDICAL_RECORD', NEW.RecordID, 'UPDATE',
        JSON_OBJECT('Content', OLD.Content, 'Version', OLD.Version),
        JSON_OBJECT('Content', NEW.Content, 'Version', NEW.Version),
        NULL);
END$$

CREATE TRIGGER trg_medicalrecord_audit_delete
AFTER DELETE ON MEDICAL_RECORD
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, ChangedByStaffID)
    VALUES ('MEDICAL_RECORD', OLD.RecordID, 'DELETE',
        JSON_OBJECT(
            'VisitID', OLD.VisitID, 'AuthorID', OLD.AuthorID,
            'RecordType', OLD.RecordType, 'Content', OLD.Content
        ),
        NULL);
END$$

DELIMITER ;


-- =============================================
-- 5. Trigger: PRESCRIPTION table
-- =============================================
DELIMITER $$

CREATE TRIGGER trg_prescription_audit_insert
AFTER INSERT ON PRESCRIPTION
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, NewData, ChangedByStaffID)
    VALUES ('PRESCRIPTION', NEW.PrescriptionID, 'INSERT', JSON_OBJECT(
        'VisitID', NEW.VisitID,
        'DoctorID', NEW.DoctorID,
        'MedicineName', NEW.MedicineName,
        'Dosage', NEW.Dosage,
        'Frequency', NEW.Frequency
    ), NULL);
END$$

CREATE TRIGGER trg_prescription_audit_update
AFTER UPDATE ON PRESCRIPTION
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, NewData, ChangedByStaffID)
    VALUES ('PRESCRIPTION', NEW.PrescriptionID, 'UPDATE',
        JSON_OBJECT('Dosage', OLD.Dosage, 'Frequency', OLD.Frequency),
        JSON_OBJECT('Dosage', NEW.Dosage, 'Frequency', NEW.Frequency),
        NULL);
END$$

CREATE TRIGGER trg_prescription_audit_delete
AFTER DELETE ON PRESCRIPTION
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (TableName, RecordID, Action, OldData, ChangedByStaffID)
    VALUES ('PRESCRIPTION', OLD.PrescriptionID, 'DELETE',
        JSON_OBJECT(
            'VisitID', OLD.VisitID, 'DoctorID', OLD.DoctorID,
            'MedicineName', OLD.MedicineName
        ),
        NULL);
END$$

DELIMITER ;


-- =============================================
-- 6. Helper Stored Procedure: View Audit Logs
-- =============================================
DELIMITER $$

CREATE PROCEDURE GetAuditLog(
    IN p_table_name VARCHAR(100),
    IN p_record_id INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        al.LogID,
        al.TableName,
        al.RecordID,
        al.Action,
        al.OldData,
        al.NewData,
        al.ChangedAt,
        ms.Name AS ChangedBy
    FROM AUDIT_LOG al
    LEFT JOIN MEDICAL_STAFF ms ON al.ChangedByStaffID = ms.StaffID
    WHERE (p_table_name IS NULL OR al.TableName = p_table_name)
      AND (p_record_id IS NULL OR al.RecordID = p_record_id)
    ORDER BY al.ChangedAt DESC
    LIMIT p_limit;
END$$

DELIMITER ;

-- Example usage:
-- CALL GetAuditLog('MEDICAL_RECORD', NULL, 50);     -- Last 50 changes to Medical Records
-- CALL GetAuditLog('PATIENT', 5, 20);                 -- All changes to Patient ID 5
-- CALL GetAuditLog(NULL, NULL, 100);                  -- Last 100 changes overall
