enum Language {
  english('en'),
  afrikaans('af');
  
  const Language(this.code);
  final String code;
}

class AppLocalizations {
  static Language _currentLanguage = Language.english;
  
  static Language get currentLanguage => _currentLanguage;
  
  static void setLanguage(Language language) {
    _currentLanguage = language;
  }
  
  static String get(String key) {
    return _localizedStrings[key]?[_currentLanguage.code] ?? key;
  }
  
  // Localized strings for the patient intake form
  static const Map<String, Map<String, String>> _localizedStrings = {
    // Form titles and headers
    'patient_intake_form': {
      'en': 'Patient Intake Form',
      'af': 'Pasient Inname Vorm'
    },
    'patient_details': {
      'en': 'Patient Details',
      'af': 'Pasient Inligting'
    },
    'person_responsible': {
      'en': 'Person Responsible for Account (Main Member)',
      'af': 'Persoon Verantwoordelik vir die Rekening (Hooflid)'
    },
    'medical_aid_details': {
      'en': 'Medical Aid Details',
      'af': 'Mediese Fonds Besonderhede'
    },
    'referring_doctor': {
      'en': 'Referring Dr/Specialist',
      'af': 'Verwysende Dr/Spesialis'
    },
    'medical_history': {
      'en': 'Medical History',
      'af': 'Mediese Geskiedenis'
    },
    'consent_signatures': {
      'en': 'Consent & Signatures',
      'af': 'Toestemming & Handtekeninge'
    },
    
    // Basic fields
    'surname': {
      'en': 'Surname',
      'af': 'Van'
    },
    'full_names': {
      'en': 'Full Names',
      'af': 'Volle Name'
    },
    'id_number': {
      'en': 'ID No',
      'af': 'ID Nr'
    },
    'date_of_birth': {
      'en': 'Date of Birth',
      'af': 'Geboortedatum'
    },
    'work_name_address': {
      'en': 'Work Name and Address',
      'af': 'Werk Naam en Adres'
    },
    'work_postal_address': {
      'en': 'Work Postal Address',
      'af': 'Werk Pos Adres'
    },
    'work_tel_no': {
      'en': 'Work Tel No',
      'af': 'Werk Tel Nr'
    },
    'patient_cell': {
      'en': 'Patient Cell',
      'af': 'Pasient Sel'
    },
    'home_tel_no': {
      'en': 'Home Tel No',
      'af': 'Huis Tel Nr'
    },
    'email': {
      'en': 'Email',
      'af': 'E-pos'
    },
    'marital_status': {
      'en': 'Marital Status',
      'af': 'Huwelikstatus'
    },
    'occupation': {
      'en': 'Occupation',
      'af': 'Beroep'
    },
    'relation_to_patient': {
      'en': 'Relation to the Patient',
      'af': 'Verhouding tot die Pasient'
    },
    
    // Medical Aid
    'name_of_scheme': {
      'en': 'Name of Scheme',
      'af': 'Naam van Skema'
    },
    'medical_aid_no': {
      'en': 'M/Aid No',
      'af': 'M/Fonds Nr'
    },
    'plan_and_dep_no': {
      'en': 'Plan and DEP No',
      'af': 'Plan en AFH Nr'
    },
    'name_of_main_member': {
      'en': 'Name of Main Member',
      'af': 'Naam van Hooflid'
    },
    'private_patient': {
      'en': 'Private Patient',
      'af': 'Privaat Pasiënt'
    },
    'private_patient_description': {
      'en': 'Patient is not on medical aid',
      'af': 'Pasiënt is nie op mediese fonds nie'
    },
    
    // Medical History
    'treated_for_illness': {
      'en': 'Have you been treated for any illness related to:',
      'af': 'Is u al behandel vir enige siekte verwant aan:'
    },
    'heart': {
      'en': 'Heart',
      'af': 'Hart'
    },
    'lungs': {
      'en': 'Lungs',
      'af': 'Longe'
    },
    'kidneys': {
      'en': 'Kidneys',
      'af': 'Niere'
    },
    'colon_digestive': {
      'en': 'Colon or digestive system',
      'af': 'Kolon of spysverteringstelsel'
    },
    'cancer': {
      'en': 'Cancer',
      'af': 'Kanker'
    },
    'liver': {
      'en': 'Liver',
      'af': 'Lewer'
    },
    'pancreas': {
      'en': 'Pancreas',
      'af': 'Pankreas'
    },
    'diabetes': {
      'en': 'Diabetes',
      'af': 'Diabetes'
    },
    'hiv': {
      'en': 'HIV',
      'af': 'MIV'
    },
    'arthritis': {
      'en': 'Arthritis',
      'af': 'Artritis'
    },
    'auto_immune': {
      'en': 'Auto Immune Disease (MS, Muscle Dystrophy, Fibromyalgia etc.)',
      'af': 'Outo-immuun Siekte (MS, Spierdistrofie, Fibromialgie ens.)'
    },
    'paraplegic': {
      'en': 'Paraplegic',
      'af': 'Paraplegies'
    },
    'quadriplegic': {
      'en': 'Quadriplegic',
      'af': 'Kwadriplegies'
    },
    'other': {
      'en': 'Other',
      'af': 'Ander'
    },
    'current_medications': {
      'en': 'Please list your Medicines that you are taking:',
      'af': 'Lys asseblief u medisyne wat u neem:'
    },
    'allergies': {
      'en': 'Are you allergic to any medicines or foods or dressings?',
      'af': 'Is u allergies vir enige medisyne of kos of verbande?'
    },
    'smoker': {
      'en': 'Are you a smoker?',
      'af': 'Is u \'n roker?'
    },
    'natural_treatments': {
      'en': 'Are you using any natural/herbal or traditional medicines or treatments? Please specify:',
      'af': 'Gebruik u enige natuurlike/kruie of tradisionele medisyne of behandelings? Spesifiseer asseblief:'
    },
    
    // Consent text
    'account_responsibility_disclaimer': {
      'en': 'I understand that I am responsible for my account and NOT my Medical Aid. I undertake to settle my account. Please note that if payment is not made within 30 days, the account will be handed over to our attorneys for collection. You will be liable to pay any collection and/or attorney fees on the Attorney Client Scale. GEMS AND MEDSCHEME PATIENTS ARE RESPONSIBLE FOR AUTHORISATION FROM SCHEME BEFORE TREATMENT WILL COMMENCE.',
      'af': 'Ek verstaan dat ek verantwoordelik is vir my rekening en NIE my Mediese Fonds nie. Ek onderneem om my rekening te skik. Let asseblief daarop dat indien betaling nie binne 30 dae gemaak word nie, sal die rekening oorhandig word aan ons prokureurs vir invordering. U sal aanspreeklik wees om enige invorderings- en/of prokureurskoste op die Prokureur-Kliënt Skaal te betaal. GEMS EN MEDSCHEME PASIËNTE IS VERANTWOORDELIK VIR MAGTIGING VAN SKEMA VOORDAT BEHANDELING SAL BEGIN.'
    },
    'wound_photography_consent': {
      'en': 'During your treatment we will be taking regular images/photos of your wounds. These images are shared with the Medical Aid during motivations for wound treatment and to update them on the progress of your treatment. The images are also shared with your Doctor/Specialist.',
      'af': 'Gedurende u behandeling sal ons gereelde beelde/foto\'s van u wonde neem. Hierdie beelde word gedeel met die Mediese Fonds tydens motiverings vir wondbehandeling en om hulle op hoogte te hou van die vordering van u behandeling. Die beelde word ook gedeel met u Dokter/Spesialis.'
    },
    'training_photos_consent': {
      'en': 'From time to time I might ask for your consent to use your photographs for training purposes. Your identity will be protected at all times. If you are willing to assist in the training of qualifying wound specialists, kindly give permission below.',
      'af': 'Van tyd tot tyd mag ek u toestemming vra om u foto\'s vir opleidingsdoeleindes te gebruik. U identiteit sal te alle tye beskerm word. As u bereid is om te help met die opleiding van kwalifikasie wondspesialiste, gee asseblief toestemming hieronder.'
    },
    
    // Marital status options
    'single': {
      'en': 'Single',
      'af': 'Enkel'
    },
    'married': {
      'en': 'Married',
      'af': 'Getroud'
    },
    'divorced': {
      'en': 'Divorced',
      'af': 'Geskei'
    },
    'widowed': {
      'en': 'Widowed',
      'af': 'Weduwee/Wewenaar'
    },
    
    // Common buttons and actions
    'yes': {
      'en': 'Yes',
      'af': 'Ja'
    },
    'no': {
      'en': 'No',
      'af': 'Nee'
    },
    'next': {
      'en': 'Next',
      'af': 'Volgende'
    },
    'previous': {
      'en': 'Previous',
      'af': 'Vorige'
    },
    'submit': {
      'en': 'Submit',
      'af': 'Indien'
    },
    'signature': {
      'en': 'Signature',
      'af': 'Handtekening'
    },
    'date': {
      'en': 'Date',
      'af': 'Datum'
    },
    'required': {
      'en': 'Required',
      'af': 'Verplig'
    },
    'please_specify': {
      'en': 'Please specify',
      'af': 'Spesifiseer asseblief'
    },
    'give_permission': {
      'en': 'Yes, I give permission',
      'af': 'Ja, ek gee toestemming'
    },
    'do_not_give_permission': {
      'en': 'No, I do not give permission',
      'af': 'Nee, ek gee nie toestemming nie'
    },
  };
}
