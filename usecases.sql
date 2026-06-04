-- Use Case #1: Insert information for a new Patient and their Emergency Contact
START TRANSACTION;

INSERT INTO PATIENT (FullName, IC_Passport, DOB, Gender, BloodType, AllergyHistory)
VALUES ('John Doe', 'A12345678', '1990-01-01', 'Male', 'O+', 'None');

SET @newPatientID = LAST_INSERT_ID();

INSERT INTO EMERGENCY_CONTACT (PatientID, Name, Relationship, Phone)
VALUES (@newPatientID, 'Jane Doe', 'Wife', '555-1234');

COMMIT;


-- Use Case #2: Schedule a routine check-up appointment
INSERT INTO APPOINTMENT (PatientID, StaffID, ScheduledTime, Reason, Status)
VALUES (1, 2, '2026-05-15 10:00:00', 'Routine check-up', 'Scheduled');


-- Use Case #3: Update appointment status and create a visit record
START TRANSACTION;

UPDATE APPOINTMENT
SET Status = 'Completed'
WHERE AppointmentID = 1;

INSERT INTO VISIT (PatientID, AppointmentID, PrimaryDoctorID, VisitType, Status)
VALUES (1, 1, 2, 'Routine', 'In Progress');

COMMIT;


-- Use Case #4: Create a medical order for vitals and record the vital signs
START TRANSACTION;

INSERT INTO MEDICAL_ORDER (VisitID, IssuedByID, OrderType, Priority, Status)
VALUES (1, 3, 'Vitals Check', 'Routine', 'Completed');

SET @vitalsOrderID = LAST_INSERT_ID();

INSERT INTO VITAL_SIGNS (VisitID, OrderID, RecordedByID, BodyTemp, HeartRate, BloodPressure, OxygenSaturation)
VALUES (1, @vitalsOrderID, 3, 37.2, 80, '120/80', 98.5);

COMMIT;


-- Use Case #5: Insert initial medical record notes
INSERT INTO MEDICAL_RECORD (VisitID, AuthorID, RecordType, Content, Version)
VALUES (1, 2, 'Initial Assessment', 'Patient complained of mild fatigue.', 1);


-- Use Case #6: Amend the medical record by submitting a new version
START TRANSACTION;

SELECT @nextVersion := COALESCE(MAX(Version), 0) + 1
FROM MEDICAL_RECORD
WHERE VisitID = 1
FOR UPDATE;

INSERT INTO MEDICAL_RECORD (VisitID, AuthorID, RecordType, Content, Version)
VALUES (1, 2, 'Amended Notes', 'Patient also complained of mild headaches.', @nextVersion);

COMMIT;


-- Use Case #7: Insert a new prescription for pain relief
INSERT INTO PRESCRIPTION (VisitID, DoctorID, MedicineName, Dosage, Frequency, DurationDays)
VALUES (1, 2, 'Paracetamol', '500mg', 'Twice a day', 5);


-- Use Case #8: Issue an urgent lab order for a blood test
INSERT INTO MEDICAL_ORDER (VisitID, IssuedByID, OrderType, Instructions, Priority, Status)
VALUES (1, 2, 'Blood Test', 'Check for underlying issues related to headaches', 'Urgent', 'Pending');


-- Use Case #9: Update lab order status and input results
START TRANSACTION;

UPDATE MEDICAL_ORDER
SET Status = 'Completed'
WHERE OrderID = 2;

INSERT INTO LAB_RESULT (OrderID, AuthorizedByID, TestName, Findings, ResultValue)
VALUES (2, 4, 'Blood Test', 'Normal ranges observed', 'Negative');

COMMIT;


-- Use Case #10: Create a referral to an external institution
INSERT INTO REFERRAL (VisitID, FromStaffID, ToInstitutionID, TargetSpecialty, ClinicalReason, Status)
VALUES (1, 2, 5, 'Neurology', 'Persistent mild headaches, further investigation needed', 'Pending');


-- Use Case #11: Retrieve pending referrals for a specific institution
SELECT 
    ReferralID,
    VisitID,
    FromStaffID,
    TargetSpecialty,
    ClinicalReason
FROM REFERRAL
WHERE ToInstitutionID = 5 
  AND Status = 'Pending';


-- Use Case #12: Retrieve full summary of a patient's previous visit
SELECT 
    P.FullName,
    V.VisitDate,
    VS.BodyTemp,
    VS.BloodPressure,
    MR.Content AS LatestMedicalNotes
FROM PATIENT P
JOIN VISIT V ON P.PatientID = V.PatientID
LEFT JOIN VITAL_SIGNS VS ON V.VisitID = VS.VisitID
LEFT JOIN MEDICAL_RECORD MR ON V.VisitID = MR.VisitID
WHERE P.IC_Passport = 'A12345678' 
  AND MR.Version = (
      SELECT MAX(Version) 
      FROM MEDICAL_RECORD 
      WHERE VisitID = V.VisitID
  );


-- Use Case #13: Generate a report of visits per doctor in May 2026
SELECT 
    PrimaryDoctorID,
    COUNT(VisitID) AS TotalVisits
FROM VISIT
WHERE VisitDate >= '2026-05-01 00:00:00' 
  AND VisitDate < '2026-06-01 00:00:00'
GROUP BY PrimaryDoctorID;


-- Use Case #14: Cancel an appointment and any associated pre-emptive visit
START TRANSACTION;

UPDATE APPOINTMENT
SET Status = 'Cancelled'
WHERE AppointmentID = 3;

UPDATE VISIT
SET Status = 'Cancelled'
WHERE AppointmentID = 3 
  AND Status = 'In Progress';

COMMIT;


-- Use Case #15: Search for surgeons at a specific neighboring institution
SELECT 
    StaffID,
    Name,
    Specialization,
    Phone
FROM MEDICAL_STAFF
WHERE InstitutionID = 2 
  AND Specialization = 'Surgery';


-- Use Case #16: Delete incorrect prescription and insert a corrected one
START TRANSACTION;

DELETE FROM PRESCRIPTION 
WHERE PrescriptionID = 4;

INSERT INTO PRESCRIPTION (VisitID, DoctorID, MedicineName, Dosage, Frequency, DurationDays)
VALUES (1, 2, 'Ibuprofen', '400mg', 'Once a day', 5);

COMMIT;


-- Use Case #17: Retrieve patient blood type and emergency contact by IC
SELECT 
    P.FullName,
    P.BloodType,
    P.AllergyHistory,
    EC.Name AS EmergencyContactName,
    EC.Relationship,
    EC.Phone
FROM PATIENT P
LEFT JOIN EMERGENCY_CONTACT EC ON P.PatientID = EC.PatientID
WHERE P.IC_Passport = 'A12345678';


-- Use Case #18: Calculate average wait time for lab results
SELECT 
    AVG(TIMESTAMPDIFF(MINUTE, MO.CreatedAt, LR.ResultDate)) AS AvgWaitTimeMinutes
FROM MEDICAL_ORDER MO
JOIN LAB_RESULT LR ON MO.OrderID = LR.OrderID;


-- Use Case #19: Identify the top 5 most prescribed medications
SELECT 
    MedicineName,
    COUNT(*) AS PrescribedCount
FROM PRESCRIPTION
GROUP BY MedicineName
ORDER BY PrescribedCount DESC
LIMIT 5;


-- Use Case #20: Retrieve all historical versions of a medical record for a visit
SELECT 
    RecordID,
    AuthorID,
    RecordType,
    Content,
    Version,
    UpdatedAt
FROM MEDICAL_RECORD
WHERE VisitID = 1
ORDER BY Version ASC;