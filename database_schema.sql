-- ============================================================================
-- Medical Transcription API Database Schema
-- ============================================================================
-- This file contains the complete database schema for the Flask-based
-- Medical Transcription API system using PostgreSQL.
--
-- Key Features:
-- - User management with medical specialties
-- - Patient records with demographics and medical record numbers
-- - Visit tracking with transcription and analysis
-- - AI-powered clinical insights and differential diagnosis
-- - Document management and billing code analysis
-- - Customer settings and subscription tiers
-- ============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENUMS AND CUSTOM TYPES
-- ============================================================================

-- Settings type enumeration for customer settings
DO $$ BEGIN
    CREATE TYPE settings_type_enum AS ENUM ('emr', 'communication', 'database');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Tier status enumeration for subscription tiers
DO $$ BEGIN
    CREATE TYPE tier_status_enum AS ENUM ('active', 'inactive', 'deprecated');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Users table - Stores doctor/healthcare provider information
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    idp_id TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    medical_specialty TEXT DEFAULT 'PRIMARYCARE',
    preferred_language TEXT DEFAULT 'en',
    phone_number TEXT,
    gender TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Patients table - Stores patient information
CREATE TABLE IF NOT EXISTS patients (
    patient_id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    phone_number TEXT,
    email TEXT,
    gender TEXT,
    medical_record_number TEXT,
    records TEXT, -- Additional patient record data
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_patients_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Visits table - Stores medical visit records
CREATE TABLE IF NOT EXISTS visits (
    visit_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    visit_date TIMESTAMP NOT NULL,
    visit_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_visits_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_visits_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Jobs table - Tracks transcription job processing
CREATE TABLE IF NOT EXISTS jobs (
    job_id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    status TEXT NOT NULL,
    status_message TEXT,
    s3_url TEXT,
    patient_id TEXT,
    doctor_id TEXT,
    visit_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_jobs_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_jobs_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_jobs_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE
);

-- ============================================================================
-- TRANSCRIPTION AND AI ANALYSIS TABLES
-- ============================================================================

-- Transcriptions table - Stores transcription results and summaries
CREATE TABLE IF NOT EXISTS transcriptions (
    job_id TEXT PRIMARY KEY,
    transcript TEXT,
    summary TEXT,
    original_transcript TEXT,
    aws_transcript TEXT,
    aws_summary TEXT,
    dictated_notes TEXT,
    dictated_audio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_transcriptions_job FOREIGN KEY (job_id) REFERENCES jobs(job_id) ON DELETE CASCADE
);

-- AWS Transcribe Jobs table - Tracks AWS transcription service jobs
CREATE TABLE IF NOT EXISTS aws_transcribe_jobs (
    job_id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    status_message TEXT,
    s3_url TEXT,
    patient_id TEXT,
    doctor_id TEXT,
    visit_id TEXT,
    visit_job_id TEXT,
    transcript_uri TEXT,
    soap_notes_uri TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_aws_transcribe_jobs_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_aws_transcribe_jobs_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_aws_transcribe_jobs_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE,
    CONSTRAINT fk_aws_transcribe_jobs_visit_job FOREIGN KEY (visit_job_id) REFERENCES jobs(job_id) ON DELETE CASCADE
);

-- Clinical Insights table - Stores AI-generated clinical analysis
CREATE TABLE IF NOT EXISTS clinical_insights (
    id SERIAL PRIMARY KEY,
    job_id TEXT NOT NULL,
    patient_id TEXT NOT NULL,
    transcription_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    primary_insights TEXT,
    mental_health_risk TEXT,
    sdoh_extractor TEXT,
    real_world_evidence TEXT,
    msk_plan_builder TEXT,
    ambient_sdoh_reconciliation TEXT,
    mental_health_triage_notes TEXT,
    trial_intake_summary TEXT,
    rx_confusion_annotator TEXT,
    emotional_insights TEXT,
    preop_risk_notetaker TEXT,
    burnout_monitor TEXT,
    employer_visit_summary TEXT,
    clinical_auditor TEXT,
    care_access_layer TEXT,
    chronic_behavior_mapper TEXT,
    chronic_msk_triage TEXT,
    ambient_audit_trail TEXT,
    medication_safety TEXT,
    neuro_drug_predictor TEXT,
    care_coordination_copilot TEXT,
    real_world_pharma TEXT,
    sdoh_navigator TEXT,
    spectral_skin_cancer TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_clinical_insights_job FOREIGN KEY (job_id) REFERENCES jobs(job_id) ON DELETE CASCADE,
    CONSTRAINT fk_clinical_insights_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_clinical_insights_transcription FOREIGN KEY (transcription_id) REFERENCES transcriptions(job_id) ON DELETE CASCADE,
    CONSTRAINT fk_clinical_insights_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ============================================================================
-- DOCUMENT MANAGEMENT TABLES
-- ============================================================================

-- Documents table - Stores uploaded documents and their processing status
CREATE TABLE IF NOT EXISTS documents (
    document_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    document_source TEXT NOT NULL,
    extracted_data TEXT,
    status TEXT DEFAULT 'pending',
    category TEXT,
    file_size INTEGER,
    content_type TEXT,
    original_filename TEXT,
    s3_key TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_documents_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_documents_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ============================================================================
-- MEDICAL ANALYSIS TABLES
-- ============================================================================

-- Differential Diagnosis table - Stores AI-generated differential diagnoses
CREATE TABLE IF NOT EXISTS differential_diagnosis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    visit_id TEXT,
    differential_diagnosis JSONB NOT NULL,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_differential_diagnosis_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_differential_diagnosis_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_differential_diagnosis_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE SET NULL
);

-- Billing Codes Analysis table - Stores billing code suggestions
CREATE TABLE IF NOT EXISTS billing_codes_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visit_id TEXT NOT NULL,
    patient_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    created_by TEXT NOT NULL,
    analysis_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_billing_codes_visit_id FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE,
    CONSTRAINT fk_billing_codes_patient_id FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_billing_codes_doctor_id FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Visit Billing Code table - Stores specific billing codes per visit
CREATE TABLE IF NOT EXISTS visit_billing_code (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    doctor_id TEXT NOT NULL,
    visit_id TEXT NOT NULL,
    raw_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by TEXT,
    CONSTRAINT fk_visit_billing_code_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_billing_code_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_billing_code_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_billing_code_created_by FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_billing_code_updated_by FOREIGN KEY (updated_by) REFERENCES users(user_id) ON DELETE SET NULL
);

-- ============================================================================
-- SUBSCRIPTION AND SETTINGS TABLES
-- ============================================================================

-- Tiers table - Defines subscription tiers and pricing
CREATE TABLE IF NOT EXISTS tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    status tier_status_enum DEFAULT 'active' NOT NULL,
    max_transcriptions_per_month INTEGER,
    max_storage_gb INTEGER,
    max_users INTEGER DEFAULT 1,
    features JSONB DEFAULT '{}' NOT NULL,
    price_usd_cents INTEGER DEFAULT 0 NOT NULL,
    billing_period VARCHAR(20) DEFAULT 'monthly' NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_trial BOOLEAN DEFAULT FALSE NOT NULL,
    trial_duration_days INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_by TEXT,
    updated_by TEXT,
    CONSTRAINT chk_tiers_price_non_negative CHECK (price_usd_cents >= 0),
    CONSTRAINT chk_tiers_billing_period CHECK (billing_period IN ('monthly', 'yearly', 'one_time')),
    CONSTRAINT chk_tiers_trial_duration CHECK (trial_duration_days IS NULL OR trial_duration_days > 0)
);

-- User Tiers table - Links users to their subscription tiers
CREATE TABLE IF NOT EXISTS user_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    tier_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    assigned_by TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT fk_user_tiers_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_tiers_tier FOREIGN KEY (tier_id) REFERENCES tiers(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_tiers_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Customer Settings table - Stores user-specific configuration settings
-- create function buttons in the UI to access and modify tenant settings (do not know what the settings are)
CREATE TABLE IF NOT EXISTS customer_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    settings JSONB NOT NULL,
    type settings_type_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_by UUID NOT NULL,
    updated_by UUID NOT NULL
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_user_idp_id ON users(idp_id);

-- Patients table indexes
CREATE INDEX IF NOT EXISTS idx_patients_email ON patients(email);
CREATE INDEX IF NOT EXISTS idx_patients_mrn ON patients(medical_record_number);

-- Documents table indexes
CREATE INDEX IF NOT EXISTS idx_documents_patient_id ON documents(patient_id);
CREATE INDEX IF NOT EXISTS idx_documents_doctor_id ON documents(doctor_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);

-- Clinical insights table indexes
CREATE INDEX IF NOT EXISTS idx_clinical_insights_job_id ON clinical_insights(job_id);
CREATE INDEX IF NOT EXISTS idx_clinical_insights_patient_id ON clinical_insights(patient_id);
CREATE INDEX IF NOT EXISTS idx_clinical_insights_doctor_id ON clinical_insights(doctor_id);
CREATE INDEX IF NOT EXISTS idx_clinical_insights_created_at ON clinical_insights(created_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_clinical_insights_unique_job ON clinical_insights(job_id);

-- Differential diagnosis table indexes
CREATE INDEX IF NOT EXISTS idx_differential_diagnosis_patient_id ON differential_diagnosis(patient_id);
CREATE INDEX IF NOT EXISTS idx_differential_diagnosis_doctor_id ON differential_diagnosis(doctor_id);
CREATE INDEX IF NOT EXISTS idx_differential_diagnosis_visit_id ON differential_diagnosis(visit_id);
CREATE INDEX IF NOT EXISTS idx_differential_diagnosis_created_at ON differential_diagnosis(created_at);
CREATE INDEX IF NOT EXISTS idx_differential_diagnosis_jsonb ON differential_diagnosis USING GIN (differential_diagnosis);

-- Billing codes analysis table indexes
CREATE INDEX IF NOT EXISTS idx_billing_codes_visit_id ON billing_codes_analysis(visit_id);
CREATE INDEX IF NOT EXISTS idx_billing_codes_patient_id ON billing_codes_analysis(patient_id);
CREATE INDEX IF NOT EXISTS idx_billing_codes_doctor_id ON billing_codes_analysis(doctor_id);
CREATE INDEX IF NOT EXISTS idx_billing_codes_created_at ON billing_codes_analysis(created_at);

-- Visit billing code table indexes
CREATE INDEX IF NOT EXISTS idx_visit_billing_code_patient_id ON visit_billing_code(patient_id);
CREATE INDEX IF NOT EXISTS idx_visit_billing_code_doctor_id ON visit_billing_code(doctor_id);
CREATE INDEX IF NOT EXISTS idx_visit_billing_code_visit_id ON visit_billing_code(visit_id);
CREATE INDEX IF NOT EXISTS idx_visit_billing_code_created_at ON visit_billing_code(created_at);
CREATE INDEX IF NOT EXISTS idx_visit_billing_code_jsonb ON visit_billing_code USING GIN (raw_data);
CREATE UNIQUE INDEX IF NOT EXISTS idx_visit_billing_code_unique_visit ON visit_billing_code(visit_id);

-- Tiers table indexes
CREATE INDEX IF NOT EXISTS idx_tiers_name ON tiers(name);
CREATE INDEX IF NOT EXISTS idx_tiers_status ON tiers(status);
CREATE INDEX IF NOT EXISTS idx_tiers_sort_order ON tiers(sort_order);
CREATE INDEX IF NOT EXISTS idx_tiers_is_trial ON tiers(is_trial);
CREATE INDEX IF NOT EXISTS idx_tiers_updated_at ON tiers(updated_at);

-- User tiers table indexes
-- A user can only have one tier record, enforced by a unique constraint on user_id.
ALTER TABLE user_tiers ADD CONSTRAINT user_tiers_user_id_key UNIQUE (user_id);
CREATE INDEX IF NOT EXISTS idx_user_tiers_tier_id ON user_tiers(tier_id);
CREATE INDEX IF NOT EXISTS idx_user_tiers_is_active ON user_tiers(is_active);
CREATE INDEX IF NOT EXISTS idx_user_tiers_assigned_at ON user_tiers(assigned_at);

-- Customer settings table indexes
-- {{ ... }}
CREATE INDEX IF NOT EXISTS idx_customer_settings_type ON customer_settings(type);
CREATE INDEX IF NOT EXISTS idx_customer_settings_updated_at ON customer_settings(updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_settings_user_type_unique ON customer_settings(user_id, type);

-- ============================================================================
-- TABLE COMMENTS AND DOCUMENTATION
-- ============================================================================

-- Users table comments
COMMENT ON TABLE users IS 'Healthcare providers and doctors using the transcription system';
COMMENT ON COLUMN users.user_id IS 'Unique identifier for the user';
COMMENT ON COLUMN users.idp_id IS 'Identity provider ID from AWS Cognito';
COMMENT ON COLUMN users.medical_specialty IS 'Medical specialty for specialized AI summaries';
COMMENT ON COLUMN users.preferred_language IS 'Preferred language for transcriptions (en/tamil)';

-- Patients table comments
COMMENT ON TABLE patients IS 'Patient information linked to healthcare providers';
COMMENT ON COLUMN patients.medical_record_number IS 'Patient medical record number (MRN) for hospital/clinic identification';

-- Documents table comments
COMMENT ON TABLE documents IS 'Uploaded documents and their processing status';
COMMENT ON COLUMN documents.status IS 'Processing status: pending, completed, failed';
COMMENT ON COLUMN documents.category IS 'Document category classification';

-- Clinical insights table comments
COMMENT ON TABLE clinical_insights IS 'AI-generated clinical insights and analysis from transcriptions';

-- Differential diagnosis table comments
COMMENT ON TABLE differential_diagnosis IS 'AI-generated differential diagnoses stored as JSONB';

-- Billing codes analysis table comments
COMMENT ON TABLE billing_codes_analysis IS 'AI-generated billing code suggestions for visits';

-- Tiers table comments
COMMENT ON TABLE tiers IS 'Defines subscription tiers with pricing and feature limits';
COMMENT ON COLUMN tiers.price_usd_cents IS 'Price in USD cents (e.g., 999 = $9.99)';
COMMENT ON COLUMN tiers.features IS 'JSON object defining available features for this tier';

-- User tiers table comments
COMMENT ON TABLE user_tiers IS 'Links users to their subscription tiers';
COMMENT ON COLUMN user_tiers.expires_at IS 'When this tier assignment expires (NULL = never)';

-- Customer settings table comments
COMMENT ON TABLE customer_settings IS 'Stores user-specific configuration settings for EMR, communication, and database integrations';
COMMENT ON COLUMN customer_settings.settings IS 'JSON object containing the settings configuration';

-- ============================================================================
-- DEFAULT DATA INSERTION
-- ============================================================================

-- Insert default tier configurations
INSERT INTO tiers (name, description, status, max_transcriptions_per_month, max_storage_gb, max_users, 
                  features, price_usd_cents, billing_period, sort_order, is_trial, trial_duration_days)
VALUES 
('Free Trial', 'Free trial with limited features', 'active', 5, 1, 1, 
 '{"basic_transcription": true, "summary": false, "insights": false}'::jsonb, 0, 'one_time', 1, true, 14),
('Basic', 'Basic plan for individual practitioners', 'active', 100, 10, 1,
 '{"basic_transcription": true, "summary": true, "insights": false}'::jsonb, 1999, 'monthly', 2, false, null),
('Professional', 'Professional plan for small practices', 'active', 500, 50, 5,
 '{"basic_transcription": true, "summary": true, "insights": true, "api_access": true}'::jsonb, 4999, 'monthly', 3, false, null),
('Enterprise', 'Enterprise plan for large organizations', 'active', null, null, 50,
 '{"basic_transcription": true, "summary": true, "insights": true, "api_access": true, "custom_integration": true}'::jsonb, 9999, 'monthly', 4, false, null)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- SCHEMA VERSION AND METADATA
-- ============================================================================

-- Create a metadata table to track schema version
CREATE TABLE IF NOT EXISTS schema_metadata (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert schema version information
INSERT INTO schema_metadata (key, value) 
VALUES 
    ('version', '1.0.0'),
    ('created_date', NOW()::text),
    ('description', 'Medical Transcription API Database Schema')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value, 
    updated_at = NOW();

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================