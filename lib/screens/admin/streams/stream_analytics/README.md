# Stream Analytics Refactoring

This folder contains the refactored Stream Analytics screen components, organized for better maintainability.

## Folder Structure

```
stream_analytics/
├── utils/
│   └── analytics_helpers.dart          # Date range helpers, currency formatting
├── widgets/
│   ├── shared/
│   │   ├── analytics_header.dart       # Header widget
│   │   ├── analytics_filters_bar.dart  # Filter bar widget
│   │   ├── stat_card.dart              # Stat card and stats row widgets
│   │   └── section_title.dart          # Section title widget
│   └── charts/
│       ├── chart_styling.dart          # Shared chart styling utilities
│       └── [individual chart files]     # Individual chart widgets
├── tabs/
│   └── [tab files]                     # Tab content widgets
├── widgets/
│   └── [list widgets]                  # List and display widgets
└── data/
    └── analytics_data_generators.dart   # Mock data generators
```

## Usage

The main `stream_analytics_screen.dart` file imports from these organized components, making the codebase much more maintainable and readable.
