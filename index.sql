USE COS;

-- Index #1: Fast patient lookup by IC/Passport number
-- (Clinical staff search patients by IC)
CREATE INDEX idxPatientIC ON PATIENT (IC_Passport);

-- Index #2: Optimize date range queries and reports
-- (Monthly/weekly reports, patient history by date)
CREATE INDEX idxVisitDate ON VISIT (VisitDate);

-- Index #3: Composite index for latest medical record version
-- (Non-destructive amendments require filtering by VisitID + Version)
CREATE INDEX idxMedRecordVersion ON MEDICAL_RECORD (VisitID, Version);

-- Index #4: Speed up operational queries for order status
-- (Lab technicians/nurses frequently check 'Pending' or 'In Progress' orders)
CREATE INDEX idxOrderStatus ON MEDICAL_ORDER (Status);

-- Index #5: Quickly find pending referrals
CREATE INDEX idxReferralStatus ON REFERRAL (Status);
