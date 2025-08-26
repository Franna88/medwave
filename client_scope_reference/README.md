# MedWave Client Scope Reference Documentation

## Overview
This folder contains comprehensive reference documentation for implementing the Patient Intake Form and Wound Care Motivation Form as specified by the client. These documents serve as the authoritative source for development implementation.

## File Structure

### 📋 Core Form Documentation
- **`patient_intake_form_structure.json`** - Complete breakdown of the patient intake form
- **`wound_care_motivation_form_structure.json`** - Insurance motivation letter form structure
- **`field_mapping_and_validation.json`** - Field mappings and validation requirements
- **`icd10_integration_reference.json`** - ICD-10 AI integration guide for South Africa

## Quick Implementation Guide

### Phase 1: Patient Intake Form (High Priority)
1. **Header & Basic Info** - Static provider details, date picker
2. **Patient Details** - Core patient demographics with SA ID validation
3. **Responsible Person** - Emergency contact and account holder
4. **Medical Aid Details** - Critical for insurance claims
5. **Medical History** - Checkbox grid with conditional logic
6. **Digital Signatures** - Account responsibility and photo consent

### Phase 2: Wound Care Motivation Form (Critical for Business)
1. **Auto-populate from Intake** - Patient name, medical aid, referring doctor
2. **AI ICD-10 Integration** - Core differentiator requiring SA MIT database
3. **Wound Assessment Tools** - Interactive body diagram, TIMES assessment
4. **Treatment Planning** - Categorized product selection
5. **PDF Generation** - Insurance-ready document export

### Phase 3: Advanced Features
1. **Offline Capability** - Critical for clinical environments
2. **Photo Integration** - Wound measurement and progress tracking
3. **Research Link Integration** - Treatment justification
4. **Multi-practitioner Support** - Different signatures/credentials

## Key Implementation Notes

### 🚨 Critical Requirements
- **AI Conversational Report Generator**: Complete motivation letters via guided questions (GAME CHANGER)
- **SA ID Validation**: 13-digit format required
- **ICD-10 AI Integration**: Must use SA MIT 2021 database
- **Digital Signatures**: Required for legal compliance
- **PMB Code Detection**: Automatic medical aid coverage identification
- **Mobile Optimization**: Nurses use tablets/phones in clinical settings

### 🔄 Data Flow
```
Patient Intake → Auto-populate → Wound Care Motivation → PDF Export → Insurance Submission
```

### 🧠 AI Integration Points
1. **Conversational Report Generation** - Complete motivation letters via 5-10 guided questions
2. **ICD-10 Code Suggestion** - Analyze wound description text
3. **PMB Detection** - Identify guaranteed coverage conditions
4. **Research Link Generation** - Treatment justification
5. **Code Validation** - Ensure SA compliance

### 🤖 AI Chatbot Specification (NEW CRITICAL FEATURE)
**Purpose**: Generate complete insurance motivation reports through conversational interface

**Key Features**:
- **5-10 Sequential Questions**: Natural conversation flow
- **Auto-populate from Intake**: Patient demographics pre-filled
- **Real-time ICD-10 Suggestions**: Based on wound description
- **PMB Eligibility Check**: Automatic coverage identification
- **Professional Report Format**: Insurance-ready document
- **Multi-practitioner Support**: Capture nurse names dynamically

**Question Flow**:
1. Patient demographics (auto-populated if available)
2. Wound history and type → Primary ICD-10 code
3. How wound occurred → External cause code (V01-Y98)
4. Comorbidities → Secondary codes + PMB eligibility  
5. Infection status → Additional coding
6. Tests performed → Clinical evidence
7. Wound details → TIMES assessment
8. Treatment plan → Products and procedures
9. Additional information → Complete clinical picture

**Technical Requirements**:
- SA ICD-10 MIT 2021 database integration
- PMB 2022 coded list validation
- Natural language processing for keyword extraction
- Professional report template formatting
- Secure patient data handling

### 📱 UI Components Needed
- `DigitalSignaturePad` - For legal signatures
- `SAIDValidationField` - South African ID format
- `ConditionalCheckboxGrid` - Medical history with specify fields
- `InteractiveBodyDiagram` - Wound location mapping
- `ICD10CodeSuggestionWidget` - AI-powered code suggestions
- `TIMESAssessmentTable` - Clinical wound assessment
- `CalendarMultiDatePicker` - Treatment scheduling
- `BilingualLabel` - English/Afrikaans support

### 🔗 Integration Requirements
- **Firebase Storage** - Signatures and photos
- **SA ICD-10 MIT Database** - Local or cloud integration
- **PDF Generation** - Insurance document formatting
- **Research Link API** - Treatment justification studies
- **Medical Aid Validation** - Scheme verification

### 📊 Validation Rules
- **Required Fields**: Highlighted before submission
- **Format Validation**: SA ID, phone, email patterns
- **Conditional Logic**: Show/hide fields based on selections
- **Clinical Validation**: TIMES percentages = 100%, positive measurements
- **Code Validation**: Verify against SA MIT database

### 🏥 Clinical Workflow Considerations
- **Mobile-First Design** - Nurses use in clinical settings
- **Quick Data Entry** - Minimize typing, maximize dropdowns/selections
- **Save Draft Functionality** - Prevent data loss during long assessments
- **Offline Capability** - Function without internet connectivity
- **Progress Tracking** - Visual indicators across multi-section forms

## Database Models Required

### Patient Model
```json
{
  "basicInfo": "From intake section 2",
  "responsiblePerson": "From intake section 3",
  "medicalAid": "From intake section 4", 
  "referringDoctor": "From intake section 5",
  "medicalHistory": "From intake section 7",
  "consents": "From intake sections 6 & 8",
  "intakeCompletedAt": "timestamp",
  "motivationForms": "array of motivation form IDs"
}
```

### Wound Care Motivation Model
```json
{
  "patientId": "reference to patient",
  "headerDetails": "auto-populated from intake",
  "treatmentDates": "nurse selected",
  "woundHistory": "clinical narrative",
  "woundDetails": "type, size, location, TIMES assessment",
  "treatmentPlan": "clinical decisions",
  "icd10Codes": "AI suggested + validated",
  "submittedAt": "timestamp",
  "pdfUrl": "generated document"
}
```

## Testing Checklist

### Patient Intake Form
- [ ] SA ID validation (13 digits)
- [ ] Conditional medical history fields
- [ ] Digital signature capture
- [ ] Bilingual label support
- [ ] Required field validation
- [ ] PDF generation

### Wound Care Motivation Form  
- [ ] Auto-populate from intake
- [ ] AI ICD-10 code suggestions
- [ ] TIMES assessment percentages = 100%
- [ ] Interactive wound location diagram
- [ ] Treatment date calendar
- [ ] Insurance-ready PDF export

### Integration
- [ ] Intake → Motivation data flow
- [ ] ICD-10 code validation against SA MIT
- [ ] PMB code detection
- [ ] Research link generation
- [ ] Mobile responsiveness
- [ ] Offline functionality

## Development Priority

1. **MVP (Weeks 1-2)**: Basic intake form with validation
2. **Core Features (Weeks 3-4)**: Motivation form with auto-populate
3. **AI Integration (Weeks 5-6)**: ICD-10 code suggestions
4. **Advanced Features (Weeks 7-8)**: Photo integration, research links
5. **Polish (Weeks 9-10)**: Offline capability, performance optimization

## Notes for Implementation
- Start with patient intake form as foundation
- Build reusable validation components early
- Implement AI ICD-10 integration as core differentiator
- Focus on mobile UX throughout development
- Test with real clinical workflows
- Ensure POPIA/HIPAA compliance for patient data

This documentation provides everything needed to implement the client's vision for comprehensive patient intake and wound care motivation forms.
