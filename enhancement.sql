-- Enhancement (Alfred Kerk Wei LING) IoT

-- 1. Create the composite index for IoT scale data
CREATE INDEX idx_vital_thresholds ON VITAL_SIGNS (OxygenSaturation, HeartRate);

-- 2. Execute UC-21 real-time alert query
SELECT 
    v.VitalID, 
    p.FullName, 
    v.RecordedAt, 
    v.OxygenSaturation, 
    v.HeartRate, 
    v.BloodPressure,
    'CRITICAL: Immediate Attention Required' AS AlertStatus
FROM VITAL_SIGNS v
JOIN VISIT vi ON v.VisitID = vi.VisitID
JOIN PATIENT p ON vi.PatientID = p.PatientID
WHERE v.OxygenSaturation <= 92 
   OR v.HeartRate >= 100
ORDER BY v.RecordedAt DESC;

-- Enhancement (Vincent Ho Ming Han) AI
CREATE TABLE AI_CLINICAL_INSIGHTS (
    InsightID INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    RecordID INT NOT NULL,                    
    EntityText VARCHAR(150) NOT NULL,         
    EntityType ENUM('Disease', 'Symptom', 'Medication', 'Allergy') NOT NULL, 
    ICD10Code VARCHAR(20),                    
    ConfidenceScore DECIMAL(4,3) NOT NULL,    
    ProcessedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RecordID) REFERENCES MEDICAL_RECORD(RecordID)
        ON UPDATE CASCADE ON DELETE CASCADE   
);

-- Enhancement (Jiangyu QIU) Alerts / Real-Time Analysis Thresholding

-- 1. ALERT_THRESHOLD: configurable normal ranges per metric (editable without touching code)
CREATE TABLE ALERT_THRESHOLD (
    ThresholdID   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    MetricName    VARCHAR(100) NOT NULL UNIQUE,        -- e.g. 'HeartRate', 'OxygenSaturation', 'BodyTemp'
    MinValue      DECIMAL(6,2),                        -- NULL means no lower bound checked
    MaxValue      DECIMAL(6,2),                        -- NULL means no upper bound checked
    Severity      ENUM('Warning', 'Critical')  NOT NULL DEFAULT 'Warning',
    Description   VARCHAR(255)
);

-- 2. Seed thresholds based on clinical reference ranges
INSERT INTO ALERT_THRESHOLD (MetricName, MinValue, MaxValue, Severity, Description) VALUES
    ('HeartRate',         40,   100, 'Warning',  'Normal resting heart rate: 60-100 bpm'),
    ('HeartRate',         NULL, 120, 'Critical', 'Severe tachycardia: >120 bpm'),
    ('OxygenSaturation',  95,   NULL,'Warning',  'SpO2 below 95% indicates hypoxia risk'),
    ('OxygenSaturation',  90,   NULL,'Critical', 'SpO2 below 90% requires immediate intervention'),
    ('BodyTemp',          36.0, 37.5,'Warning',  'Normal body temp: 36.0-37.5 C'),
    ('BodyTemp',          NULL, 39.5,'Critical', 'High fever: >39.5 C');

-- 3. CLINICAL_ALERT: stores every triggered alert with resolution tracking
CREATE TABLE CLINICAL_ALERT (
    AlertID       INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    VitalID       INT          NOT NULL,
    ThresholdID   INT          NOT NULL,
    PatientID     INT          NOT NULL,
    MetricName    VARCHAR(100) NOT NULL,
    ActualValue   DECIMAL(6,2) NOT NULL,
    Severity      ENUM('Warning', 'Critical') NOT NULL,
    AlertMessage  VARCHAR(255) NOT NULL,
    TriggeredAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    IsResolved    TINYINT(1)   NOT NULL DEFAULT 0,
    ResolvedAt    DATETIME,
    ResolvedByID  INT,
    FOREIGN KEY (VitalID)      REFERENCES VITAL_SIGNS(VitalID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (ThresholdID)  REFERENCES ALERT_THRESHOLD(ThresholdID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (PatientID)    REFERENCES PATIENT(PatientID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (ResolvedByID) REFERENCES MEDICAL_STAFF(StaffID)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 4. Index: fast lookup of unresolved critical alerts per patient
CREATE INDEX idx_alert_patient_severity ON CLINICAL_ALERT (PatientID, Severity, IsResolved);

-- 5. TRIGGER: auto-evaluate thresholds on every new VITAL_SIGNS insert
DELIMITER $$

CREATE TRIGGER trg_vital_signs_alert
AFTER INSERT ON VITAL_SIGNS
FOR EACH ROW
BEGIN
    DECLARE v_patient_id INT;

    -- Resolve PatientID from the linked visit
    SELECT PatientID INTO v_patient_id
    FROM VISIT WHERE VisitID = NEW.VisitID;

    -- HeartRate checks
    IF NEW.HeartRate > 120 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'HeartRate', NEW.HeartRate, 'Critical',
               CONCAT('CRITICAL: Heart rate ', NEW.HeartRate, ' bpm exceeds 120 bpm')
        FROM ALERT_THRESHOLD WHERE MetricName = 'HeartRate' AND Severity = 'Critical' LIMIT 1;
    ELSEIF NEW.HeartRate > 100 OR NEW.HeartRate < 40 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'HeartRate', NEW.HeartRate, 'Warning',
               CONCAT('WARNING: Heart rate ', NEW.HeartRate, ' bpm is outside normal range (40-100 bpm)')
        FROM ALERT_THRESHOLD WHERE MetricName = 'HeartRate' AND Severity = 'Warning' LIMIT 1;
    END IF;

    -- OxygenSaturation checks
    IF NEW.OxygenSaturation < 90 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'OxygenSaturation', NEW.OxygenSaturation, 'Critical',
               CONCAT('CRITICAL: SpO2 at ', NEW.OxygenSaturation, '% — immediate intervention required')
        FROM ALERT_THRESHOLD WHERE MetricName = 'OxygenSaturation' AND Severity = 'Critical' LIMIT 1;
    ELSEIF NEW.OxygenSaturation < 95 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'OxygenSaturation', NEW.OxygenSaturation, 'Warning',
               CONCAT('WARNING: SpO2 at ', NEW.OxygenSaturation, '% is below safe threshold (95%)')
        FROM ALERT_THRESHOLD WHERE MetricName = 'OxygenSaturation' AND Severity = 'Warning' LIMIT 1;
    END IF;

    -- BodyTemp checks
    IF NEW.BodyTemp > 39.5 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'BodyTemp', NEW.BodyTemp, 'Critical',
               CONCAT('CRITICAL: Body temperature ', NEW.BodyTemp, ' C — high fever alert')
        FROM ALERT_THRESHOLD WHERE MetricName = 'BodyTemp' AND Severity = 'Critical' LIMIT 1;
    ELSEIF NEW.BodyTemp > 37.5 OR NEW.BodyTemp < 36.0 THEN
        INSERT INTO CLINICAL_ALERT (VitalID, ThresholdID, PatientID, MetricName, ActualValue, Severity, AlertMessage)
        SELECT NEW.VitalID, ThresholdID, v_patient_id,
               'BodyTemp', NEW.BodyTemp, 'Warning',
               CONCAT('WARNING: Body temperature ', NEW.BodyTemp, ' C is outside normal range (36.0-37.5 C)')
        FROM ALERT_THRESHOLD WHERE MetricName = 'BodyTemp' AND Severity = 'Warning' LIMIT 1;
    END IF;
END$$

DELIMITER ;

-- 6. STORED PROCEDURE: fetch all unresolved alerts, optionally filtered by severity
DELIMITER $$

CREATE PROCEDURE GetUnresolvedAlerts(
    IN p_severity ENUM('Warning', 'Critical')   -- pass NULL to get all severities
)
BEGIN
    SELECT
        ca.AlertID,
        p.FullName        AS PatientName,
        ca.MetricName,
        ca.ActualValue,
        ca.Severity,
        ca.AlertMessage,
        ca.TriggeredAt,
        vi.VisitID,
        vs.RecordedAt
    FROM CLINICAL_ALERT ca
    JOIN PATIENT     p  ON ca.PatientID = p.PatientID
    JOIN VITAL_SIGNS vs ON ca.VitalID   = vs.VitalID
    JOIN VISIT       vi ON vs.VisitID   = vi.VisitID
    WHERE ca.IsResolved = 0
      AND (p_severity IS NULL OR ca.Severity = p_severity)
    ORDER BY
        FIELD(ca.Severity, 'Critical', 'Warning'),  -- Critical first
        ca.TriggeredAt DESC;
END$$

DELIMITER ;

-- 7. STORED PROCEDURE: resolve an alert (staff acknowledges and closes it)
DELIMITER $$

CREATE PROCEDURE ResolveAlert(
    IN p_alert_id     INT,
    IN p_staff_id     INT
)
BEGIN
    UPDATE CLINICAL_ALERT
    SET    IsResolved   = 1,
           ResolvedAt   = NOW(),
           ResolvedByID = p_staff_id
    WHERE  AlertID      = p_alert_id
      AND  IsResolved   = 0;

    SELECT ROW_COUNT() AS AlertsResolved;
END$$

DELIMITER ;

-- 8. Sample calls (uncomment to test)
-- CALL GetUnresolvedAlerts(NULL);           -- all unresolved
-- CALL GetUnresolvedAlerts('Critical');     -- only critical
-- CALL ResolveAlert(1, 5);                  -- staff ID 5 resolves alert ID 1

--Jeff's Enhancement--
-- 1. Create AUDIT_LOG Table

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


-- 2. Trigger: PATIENT table

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


-- 3. Trigger: VISIT table
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

-- 4. Trigger: MEDICAL_RECORD table

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

-- 5. Trigger: PRESCRIPTION table

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


-- 6. Helper Stored Procedure: View Audit Logs

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