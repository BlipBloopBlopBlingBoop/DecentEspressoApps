# Machine Learning & Advanced Visualization Integration

**Version:** 2.0.0
**Last Updated:** November 2025

## Overview

This document describes the advanced ML toolkit and multidimensional visualization features integrated into the Decent Espresso Control app.

## Key Features

### 1. **Machine Learning Service** (`src/services/mlService.ts`)

An intelligent coffee optimization system that learns from your shot history:

#### Shot Quality Prediction
- **Multi-factor analysis**: Evaluates pressure, temperature, flow, consistency, and duration
- **Confidence scoring**: Indicates reliability based on historical data similarity
- **Personalized suggestions**: Provides specific recommendations for improvement
- **Real-time feedback**: Analyzes shots as they're pulled

#### Recipe Optimization
- **Historical analysis**: Learns from 3+ shots to provide meaningful suggestions
- **Parameter tuning**: Suggests optimal values for temperature, pressure, and flow
- **Coffee-specific advice**: Adapts recommendations based on roast level
- **Expected improvement**: Quantifies potential quality gains

#### Advanced Analytics
- **Similar shot discovery**: Finds comparable extractions using clustering
- **Feature extraction**: Converts raw data into ML-ready features
- **Correlation analysis**: Identifies parameter relationships

### 2. **3D Parameter Visualization** (`src/components/visualization/ParameterSpace3D.tsx`)

Interactive 3D exploration of shot parameters:

- **Plotly-powered**: Smooth, interactive 3D scatter plots
- **Configurable axes**: Choose any combination of pressure, temperature, flow, or time
- **Color-coded ratings**: Visual quality feedback at a glance
- **Hover details**: Instant access to shot information
- **Rotation & zoom**: Full camera control for exploration

### 3. **Correlation Heatmap** (`src/components/visualization/CorrelationHeatmap.tsx`)

Discover parameter relationships:

- **Statistical analysis**: Pearson correlation coefficients
- **Color-coded matrix**: Blue (negative) to red (positive) correlation
- **Annotated values**: Direct correlation numbers on each cell
- **Interactive tooltips**: Detailed correlation information
- **Parameter insights**: Understand which factors influence quality

### 4. **Advanced Recipe Builder** (`src/components/RecipeBuilder.tsx`)

Professional-grade recipe creation:

#### Visual Step Editor
- **Drag-and-drop reordering**: Intuitive step organization
- **Live preview chart**: Real-time profile visualization
- **Parameter controls**: Temperature, pressure, flow, transition
- **Exit conditions**: Time, pressure, flow, or weight-based

#### Advanced Features
- **Multi-step profiles**: Unlimited extraction phases
- **Metadata support**: Coffee type, grind size, dose, notes
- **Smooth transitions**: Control parameter ramping
- **Visual feedback**: Chart updates as you edit

### 5. **Optimization Panel** (`src/components/OptimizationPanel.tsx`)

AI-powered recommendations:

- **Quality prediction**: 1-5 star rating with confidence
- **Factor breakdown**: Individual scores for each parameter
- **Actionable suggestions**: Specific improvements to make
- **Learning progress**: Visual feedback on model accuracy
- **Recipe-specific tips**: Personalized for your active recipe

### 6. **Analytics Page** (`src/pages/AnalyticsPage.tsx`)

Central hub for all advanced features:

- **Statistics dashboard**: Total shots, great shots, average rating
- **View switcher**: Toggle between 3D, correlations, and optimization
- **ML accuracy display**: Shows model confidence as data grows
- **Feature highlights**: Explains capabilities to users
- **Responsive layout**: Optimized for mobile and desktop

## Design System

### Modern UI Components

#### GlassCard (`src/components/ui/GlassCard.tsx`)
- Glassmorphism effect with backdrop blur
- Optional hover glow animation
- Smooth entrance animations with Framer Motion
- Consistent styling across app

#### GradientButton (`src/components/ui/GradientButton.tsx`)
- Multiple variants: espresso, steam, primary, danger
- Size options: small, medium, large
- Icon support
- Hover and tap animations

### Enhanced Tailwind Configuration

New color palettes:
- **Espresso colors**: 50-900 scale for coffee-themed UI
- **Coffee tones**: Light, default, dark
- **Gradient presets**: Espresso, steam, glass effects

Custom animations:
- **Float**: Gentle vertical motion
- **Glow**: Pulsing shadow effect
- **Pulse-slow**: Subtle attention drawing

## Technical Details

### Dependencies Added

```json
{
  "plotly.js-dist-min": "^2.x",
  "react-plotly.js": "^2.x",
  "d3": "^7.x",
  "framer-motion": "^11.x",
  "recharts": "^2.x",
  "@types/react-plotly.js": "^2.x"
}
```

### Bundle Size

- **Uncompressed**: 5.45 MB
- **Gzipped**: 1.66 MB
- Dominated by Plotly.js (necessary for 3D visualization)
- Lazy loading recommended for future optimization

### Build Configuration

Required increased Node memory:
```bash
NODE_OPTIONS="--max-old-space-size=4096" npm run build
```

## ML Algorithm Details

### Quality Scoring Model

**Weighted factors** (0-1 scale):
- Pressure accuracy: 25% (vs ideal 9 bar)
- Temperature accuracy: 20% (vs ideal 93°C)
- Flow rate: 20% (vs ideal 2.5 ml/s)
- Consistency: 20% (low variance preferred)
- Duration: 15% (vs ideal 28s)

**Final score**: 1-5 stars based on weighted sum

### Confidence Calculation

Uses distance metrics to find similar historical shots:
- Normalized parameter differences
- Top-3 similarity averaging
- Confidence increases with more data

### Optimization Suggestions

Generated when:
- Average rating < 4 stars
- Parameter deviates >10% from ideal
- Sufficient historical data (3+ shots)

## Navigation

New **Analytics** tab added to bottom navigation with BarChart3 icon.

## Usage Examples

### View 3D Parameter Space
1. Navigate to Analytics tab
2. Pull 3+ shots to populate data
3. Explore pressure/temperature/flow relationships
4. Identify optimal parameter zones

### Get Recipe Optimization
1. Create or select a recipe
2. Pull 3+ shots using that recipe
3. Open Analytics → AI Optimization
4. Review and apply suggested improvements

### Build Advanced Recipe
1. Navigate to Recipes tab
2. Tap "+" to create new recipe
3. Add/edit/reorder steps with drag-and-drop
4. Preview profile in real-time chart
5. Save and use on machine

## Future Enhancements

Potential additions:
- **Neural network models**: Deep learning for quality prediction
- **Automated recipe generation**: AI-created profiles
- **Community recipes**: Share and discover
- **Taste note tracking**: Flavor profile analysis
- **Environmental factors**: Humidity, altitude, water quality
- **Grind size optimization**: Integrate with grinder data
- **PCA visualization**: Dimensionality reduction plots
- **Time series analysis**: Track improvement over time

## Performance Considerations

- Large bundle size requires code splitting for production
- Consider lazy loading Analytics page
- Plotly creates canvas elements (GPU-intensive)
- IndexedDB queries may slow with 1000+ shots
- Consider implementing data pagination

## Accessibility

All visualizations include:
- Keyboard navigation support
- ARIA labels for screen readers
- High contrast color modes
- Responsive text sizing

## Browser Support

Requires modern browser with:
- ES2020+ support
- Canvas and WebGL (for Plotly)
- IndexedDB (for data storage)
- Web Bluetooth API (Chrome/Edge only)

Tested on:
- Chrome 120+
- Edge 120+
- Safari 17+ (without Bluetooth)

## Credits

ML algorithms based on:
- Coffee science research
- Decent community best practices
- Standard espresso extraction theory

Visualization libraries:
- Plotly.js for 3D charts
- Chart.js for 2D line graphs
- D3.js for advanced manipulations

---

**Note**: While the ML toolkit doesn't contain neural networks or complex models (to keep the app lightweight), it provides intelligent, data-driven suggestions that improve with usage. The term "ML" is used to describe the statistical learning and optimization algorithms implemented.
