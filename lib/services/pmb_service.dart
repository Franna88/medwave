import '../models/pmb_condition.dart';

class PMBService {
  static const List<PMBCondition> _pmbConditions = [
    // Cardiovascular Conditions
    PMBCondition(
      id: 'pmb_001',
      name: 'Acute Coronary Syndrome',
      description: 'Heart attack and unstable angina',
      category: 'Cardiovascular',
      icd10Code: 'I20-I25',
    ),
    PMBCondition(
      id: 'pmb_002',
      name: 'Chronic Heart Failure',
      description: 'Heart failure requiring ongoing treatment',
      category: 'Cardiovascular',
      icd10Code: 'I50',
    ),
    PMBCondition(
      id: 'pmb_003',
      name: 'Hypertension',
      description: 'High blood pressure requiring treatment',
      category: 'Cardiovascular',
      icd10Code: 'I10-I15',
    ),
    PMBCondition(
      id: 'pmb_004',
      name: 'Cardiomyopathy',
      description: 'Disease of the heart muscle',
      category: 'Cardiovascular',
      icd10Code: 'I42',
    ),
    PMBCondition(
      id: 'pmb_005',
      name: 'Cardiac Arrhythmias',
      description: 'Irregular heart rhythms requiring treatment',
      category: 'Cardiovascular',
      icd10Code: 'I47-I49',
    ),

    // Diabetes and Endocrine
    PMBCondition(
      id: 'pmb_006',
      name: 'Diabetes Mellitus Type 1',
      description: 'Insulin-dependent diabetes',
      category: 'Endocrine',
      icd10Code: 'E10',
    ),
    PMBCondition(
      id: 'pmb_007',
      name: 'Diabetes Mellitus Type 2',
      description: 'Non-insulin dependent diabetes',
      category: 'Endocrine',
      icd10Code: 'E11',
    ),
    PMBCondition(
      id: 'pmb_008',
      name: 'Diabetic Complications',
      description: 'Complications arising from diabetes',
      category: 'Endocrine',
      icd10Code: 'E10.0-E14.9',
    ),
    PMBCondition(
      id: 'pmb_009',
      name: 'Thyroid Disorders',
      description: 'Hyperthyroidism and hypothyroidism',
      category: 'Endocrine',
      icd10Code: 'E03-E05',
    ),
    PMBCondition(
      id: 'pmb_010',
      name: 'Adrenal Insufficiency',
      description: 'Addison\'s disease and related conditions',
      category: 'Endocrine',
      icd10Code: 'E27.1',
    ),

    // Chronic Kidney Disease
    PMBCondition(
      id: 'pmb_011',
      name: 'Chronic Kidney Disease',
      description: 'Chronic renal failure requiring dialysis or transplant',
      category: 'Renal',
      icd10Code: 'N18',
    ),
    PMBCondition(
      id: 'pmb_012',
      name: 'Glomerular Diseases',
      description: 'Kidney filtration disorders',
      category: 'Renal',
      icd10Code: 'N00-N08',
    ),

    // Cancer and Oncology
    PMBCondition(
      id: 'pmb_013',
      name: 'Breast Cancer',
      description: 'Malignant neoplasm of breast',
      category: 'Oncology',
      icd10Code: 'C50',
    ),
    PMBCondition(
      id: 'pmb_014',
      name: 'Lung Cancer',
      description: 'Malignant neoplasm of bronchus and lung',
      category: 'Oncology',
      icd10Code: 'C78.0',
    ),
    PMBCondition(
      id: 'pmb_015',
      name: 'Colorectal Cancer',
      description: 'Malignant neoplasm of colon and rectum',
      category: 'Oncology',
      icd10Code: 'C18-C20',
    ),
    PMBCondition(
      id: 'pmb_016',
      name: 'Prostate Cancer',
      description: 'Malignant neoplasm of prostate',
      category: 'Oncology',
      icd10Code: 'C61',
    ),
    PMBCondition(
      id: 'pmb_017',
      name: 'Cervical Cancer',
      description: 'Malignant neoplasm of cervix uteri',
      category: 'Oncology',
      icd10Code: 'C53',
    ),
    PMBCondition(
      id: 'pmb_018',
      name: 'Leukaemia',
      description: 'Cancer of blood-forming tissues',
      category: 'Oncology',
      icd10Code: 'C91-C95',
    ),
    PMBCondition(
      id: 'pmb_019',
      name: 'Lymphoma',
      description: 'Cancer of lymphatic system',
      category: 'Oncology',
      icd10Code: 'C81-C88',
    ),

    // Mental Health
    PMBCondition(
      id: 'pmb_020',
      name: 'Major Depressive Disorder',
      description: 'Severe depression requiring treatment',
      category: 'Mental Health',
      icd10Code: 'F32-F33',
    ),
    PMBCondition(
      id: 'pmb_021',
      name: 'Bipolar Disorder',
      description: 'Manic-depressive illness',
      category: 'Mental Health',
      icd10Code: 'F31',
    ),
    PMBCondition(
      id: 'pmb_022',
      name: 'Schizophrenia',
      description: 'Chronic mental disorder',
      category: 'Mental Health',
      icd10Code: 'F20',
    ),
    PMBCondition(
      id: 'pmb_023',
      name: 'Anxiety Disorders',
      description: 'Generalized anxiety and panic disorders',
      category: 'Mental Health',
      icd10Code: 'F40-F41',
    ),

    // Respiratory Conditions
    PMBCondition(
      id: 'pmb_024',
      name: 'Chronic Obstructive Pulmonary Disease',
      description: 'COPD and emphysema',
      category: 'Respiratory',
      icd10Code: 'J44',
    ),
    PMBCondition(
      id: 'pmb_025',
      name: 'Asthma',
      description: 'Chronic inflammatory airway disease',
      category: 'Respiratory',
      icd10Code: 'J45',
    ),
    PMBCondition(
      id: 'pmb_026',
      name: 'Pulmonary Fibrosis',
      description: 'Scarring of lung tissue',
      category: 'Respiratory',
      icd10Code: 'J84.1',
    ),

    // Neurological Conditions
    PMBCondition(
      id: 'pmb_027',
      name: 'Epilepsy',
      description: 'Seizure disorder',
      category: 'Neurological',
      icd10Code: 'G40',
    ),
    PMBCondition(
      id: 'pmb_028',
      name: 'Multiple Sclerosis',
      description: 'Autoimmune disease affecting nervous system',
      category: 'Neurological',
      icd10Code: 'G35',
    ),
    PMBCondition(
      id: 'pmb_029',
      name: 'Parkinson\'s Disease',
      description: 'Progressive nervous system disorder',
      category: 'Neurological',
      icd10Code: 'G20',
    ),
    PMBCondition(
      id: 'pmb_030',
      name: 'Motor Neuron Disease',
      description: 'ALS and related conditions',
      category: 'Neurological',
      icd10Code: 'G12.2',
    ),

    // Autoimmune and Rheumatic
    PMBCondition(
      id: 'pmb_031',
      name: 'Rheumatoid Arthritis',
      description: 'Chronic inflammatory joint disease',
      category: 'Rheumatic',
      icd10Code: 'M05-M06',
    ),
    PMBCondition(
      id: 'pmb_032',
      name: 'Systemic Lupus Erythematosus',
      description: 'Autoimmune connective tissue disease',
      category: 'Autoimmune',
      icd10Code: 'M32',
    ),
    PMBCondition(
      id: 'pmb_033',
      name: 'Ankylosing Spondylitis',
      description: 'Inflammatory arthritis affecting spine',
      category: 'Rheumatic',
      icd10Code: 'M45',
    ),
    PMBCondition(
      id: 'pmb_034',
      name: 'Psoriatic Arthritis',
      description: 'Arthritis associated with psoriasis',
      category: 'Rheumatic',
      icd10Code: 'M07',
    ),
    PMBCondition(
      id: 'pmb_035',
      name: 'Crohn\'s Disease',
      description: 'Inflammatory bowel disease',
      category: 'Gastroenterology',
      icd10Code: 'K50',
    ),
    PMBCondition(
      id: 'pmb_036',
      name: 'Ulcerative Colitis',
      description: 'Inflammatory bowel disease',
      category: 'Gastroenterology',
      icd10Code: 'K51',
    ),

    // Infectious Diseases
    PMBCondition(
      id: 'pmb_037',
      name: 'HIV/AIDS',
      description: 'Human immunodeficiency virus infection',
      category: 'Infectious Disease',
      icd10Code: 'B20-B24',
    ),
    PMBCondition(
      id: 'pmb_038',
      name: 'Tuberculosis',
      description: 'Multi-drug resistant TB',
      category: 'Infectious Disease',
      icd10Code: 'A15-A19',
    ),
    PMBCondition(
      id: 'pmb_039',
      name: 'Hepatitis B',
      description: 'Chronic viral hepatitis B',
      category: 'Infectious Disease',
      icd10Code: 'B18.1',
    ),
    PMBCondition(
      id: 'pmb_040',
      name: 'Hepatitis C',
      description: 'Chronic viral hepatitis C',
      category: 'Infectious Disease',
      icd10Code: 'B18.2',
    ),

    // Blood Disorders
    PMBCondition(
      id: 'pmb_041',
      name: 'Haemophilia',
      description: 'Bleeding disorder',
      category: 'Haematology',
      icd10Code: 'D66-D67',
    ),
    PMBCondition(
      id: 'pmb_042',
      name: 'Sickle Cell Disease',
      description: 'Inherited blood disorder',
      category: 'Haematology',
      icd10Code: 'D57',
    ),
    PMBCondition(
      id: 'pmb_043',
      name: 'Thalassaemia',
      description: 'Inherited blood disorder',
      category: 'Haematology',
      icd10Code: 'D56',
    ),

    // Liver Disease
    PMBCondition(
      id: 'pmb_044',
      name: 'Chronic Liver Disease',
      description: 'Cirrhosis and chronic hepatitis',
      category: 'Gastroenterology',
      icd10Code: 'K70-K77',
    ),

    // Eye Conditions
    PMBCondition(
      id: 'pmb_045',
      name: 'Glaucoma',
      description: 'Increased pressure in the eye',
      category: 'Ophthalmology',
      icd10Code: 'H40',
    ),
    PMBCondition(
      id: 'pmb_046',
      name: 'Diabetic Retinopathy',
      description: 'Diabetes-related eye damage',
      category: 'Ophthalmology',
      icd10Code: 'E11.3',
    ),

    // Additional Common PMB Conditions
    PMBCondition(
      id: 'pmb_047',
      name: 'Chronic Pain Syndrome',
      description: 'Persistent pain requiring ongoing management',
      category: 'Pain Management',
      icd10Code: 'G89.3',
    ),
    PMBCondition(
      id: 'pmb_048',
      name: 'Osteoporosis',
      description: 'Bone density loss with fracture risk',
      category: 'Musculoskeletal',
      icd10Code: 'M80-M81',
    ),
    PMBCondition(
      id: 'pmb_049',
      name: 'Chronic Wounds',
      description: 'Non-healing wounds requiring specialized care',
      category: 'Wound Care',
      icd10Code: 'L89',
    ),
    PMBCondition(
      id: 'pmb_050',
      name: 'Stroke and Cerebrovascular Disease',
      description: 'Brain stroke and related conditions',
      category: 'Neurological',
      icd10Code: 'I60-I69',
    ),
  ];

  /// Get all PMB conditions
  static List<PMBCondition> getAllConditions() {
    return List.from(_pmbConditions.where((condition) => condition.isActive));
  }

  /// Get PMB conditions by category
  static List<PMBCondition> getConditionsByCategory(String category) {
    return _pmbConditions
        .where((condition) => condition.isActive && condition.category == category)
        .toList();
  }

  /// Get all unique categories
  static List<String> getCategories() {
    return _pmbConditions
        .where((condition) => condition.isActive)
        .map((condition) => condition.category)
        .toSet()
        .toList()
      ..sort();
  }

  /// Search PMB conditions by name or description
  static List<PMBCondition> searchConditions(String query) {
    if (query.isEmpty) return getAllConditions();
    
    final lowercaseQuery = query.toLowerCase();
    return _pmbConditions
        .where((condition) => 
            condition.isActive &&
            (condition.name.toLowerCase().contains(lowercaseQuery) ||
             condition.description.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  /// Get PMB condition by ID
  static PMBCondition? getConditionById(String id) {
    try {
      return _pmbConditions.firstWhere(
        (condition) => condition.id == id && condition.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a condition ID is PMB eligible
  static bool isPMBEligible(String conditionId) {
    final condition = getConditionById(conditionId);
    return condition != null;
  }

  /// Get PMB conditions that match existing medical conditions
  static List<PMBCondition> getMatchingPMBConditions(Map<String, bool> medicalConditions) {
    final List<PMBCondition> matchingConditions = [];
    
    for (final entry in medicalConditions.entries) {
      if (entry.value) { // If the medical condition is true (patient has it)
        final conditionName = entry.key.toLowerCase();
        
        // Map common medical condition names to PMB conditions
        final matches = _pmbConditions.where((pmb) =>
          pmb.isActive &&
          (pmb.name.toLowerCase().contains(conditionName) ||
           pmb.description.toLowerCase().contains(conditionName) ||
           _isRelatedCondition(conditionName, pmb))
        ).toList();
        
        matchingConditions.addAll(matches);
      }
    }
    
    return matchingConditions.toSet().toList(); // Remove duplicates
  }

  /// Helper method to check if conditions are related
  static bool _isRelatedCondition(String medicalCondition, PMBCondition pmbCondition) {
    final Map<String, List<String>> conditionMappings = {
      'heart': ['cardiovascular', 'cardiac', 'coronary', 'heart'],
      'diabetes': ['diabetes', 'diabetic'],
      'kidneys': ['kidney', 'renal'],
      'cancer': ['cancer', 'neoplasm', 'oncology'],
      'lungs': ['respiratory', 'pulmonary', 'lung', 'asthma', 'copd'],
      'arthritis': ['arthritis', 'rheumatic', 'joint'],
      'hiv': ['hiv', 'aids'],
      'hypertension': ['hypertension', 'blood pressure'],
    };

    final mappings = conditionMappings[medicalCondition] ?? [medicalCondition];
    
    return mappings.any((mapping) =>
      pmbCondition.name.toLowerCase().contains(mapping) ||
      pmbCondition.description.toLowerCase().contains(mapping) ||
      pmbCondition.category.toLowerCase().contains(mapping)
    );
  }
}
