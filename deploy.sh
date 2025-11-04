#!/bin/bash
# Netlify Manual Deployment Script

echo "🚀 Building Decent Espresso Control App..."
npm run build

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Your app is ready in the 'dist/' folder"
echo ""
echo "🌐 TO DEPLOY TO NETLIFY:"
echo ""
echo "Option 1: DRAG & DROP (Easiest)"
echo "  1. Go to https://app.netlify.com/drop"
echo "  2. Drag the entire 'dist' folder onto the page"
echo "  3. Done! You'll get a live URL instantly"
echo ""
echo "Option 2: NETLIFY CLI"
echo "  Run: npx netlify-cli deploy --prod --dir=dist"
echo ""
