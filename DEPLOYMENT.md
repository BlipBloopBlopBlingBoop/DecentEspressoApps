# 🚀 Deployment Guide - Decent Espresso Control

This guide will help you deploy your Decent Espresso Control app to a live URL.

## ⚡ Quick Deploy (Easiest Options)

### Option 1: Deploy to Vercel (Recommended)

**Vercel is FREE and takes 2 minutes!**

1. **Go to [vercel.com](https://vercel.com) and sign up/login** with your GitHub account

2. **Click "Add New Project"**

3. **Import your GitHub repository** (`BlipBloopBlopBlingBoop/deepdoopdop`)

4. **Configure the project:**
   - Framework Preset: **Vite**
   - Root Directory: `./`
   - Build Command: `npm run build`
   - Output Directory: `dist`

5. **Click "Deploy"**

6. **Done!** Your app will be live at `https://your-app-name.vercel.app`

**Direct Deploy Link:**
```
https://vercel.com/new/clone?repository-url=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop
```

---

### Option 2: Deploy to Netlify

**Also FREE and super easy!**

1. **Go to [netlify.com](https://netlify.com) and sign up/login**

2. **Click "Add new site" → "Import an existing project"**

3. **Connect to GitHub and select** `BlipBloopBlopBlingBoop/deepdoopdop`

4. **Build settings are auto-detected from netlify.toml:**
   - Build command: `npm run build`
   - Publish directory: `dist`

5. **Click "Deploy"**

6. **Done!** Your app will be live at `https://your-app-name.netlify.app`

**Direct Deploy Button:**
[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop)

---

### Option 3: Deploy to GitHub Pages

**Free hosting on GitHub!**

1. **Install gh-pages:**
```bash
npm install --save-dev gh-pages
```

2. **Add these scripts to package.json:**
```json
"scripts": {
  "predeploy": "npm run build",
  "deploy": "gh-pages -d dist"
}
```

3. **Update vite.config.ts** (add base URL):
```typescript
export default defineConfig({
  base: '/deepdoopdop/',  // Your repo name
  // ... rest of config
})
```

4. **Deploy:**
```bash
npm run deploy
```

5. **Enable GitHub Pages:**
   - Go to repo Settings → Pages
   - Source: Deploy from branch → `gh-pages` → `/ (root)`

6. **Done!** App will be at `https://blipbloopblopblingboop.github.io/deepdoopdop/`

---

## 🔧 Manual Deployment (Advanced)

### Build Locally

```bash
# Install dependencies
npm install

# Create production build
npm run build

# Preview the build locally
npm run preview
```

The built files will be in the `dist/` folder. You can upload these to any static hosting service.

---

## 📱 Testing After Deployment

### Important: HTTPS Required!

**Web Bluetooth API only works over HTTPS or localhost.**

✅ Good:
- `https://your-app.vercel.app`
- `https://your-app.netlify.app`
- `http://localhost:3000` (development only)

❌ Won't work:
- `http://your-app.com` (no HTTPS)

### Browser Requirements

Your deployed app needs:
- **Chrome 56+** (Desktop & Android)
- **Edge 79+**
- **Opera 43+**

Not supported:
- Safari (use Bluefy browser on iOS)
- Firefox (no Web Bluetooth)

### Test Checklist

After deployment:

1. ✅ Open the URL in Chrome/Edge
2. ✅ Check browser console for errors (F12)
3. ✅ Navigate to Connect page
4. ✅ Click "Connect via Bluetooth" - should show device picker
5. ✅ Make sure you can see all pages (Dashboard, Control, Recipes, etc.)

---

## 🌐 Custom Domain (Optional)

### Vercel Custom Domain

1. Go to your project dashboard on Vercel
2. Click "Settings" → "Domains"
3. Add your custom domain (e.g., `espresso.yourdomain.com`)
4. Follow the DNS configuration instructions
5. Vercel automatically provisions SSL certificate

### Netlify Custom Domain

1. Go to "Domain settings" in your site dashboard
2. Click "Add custom domain"
3. Follow the DNS configuration instructions
4. SSL is automatic

---

## 🔐 Environment Variables (If Needed)

If you need to add environment variables later:

### Vercel
1. Project Settings → Environment Variables
2. Add variables like `VITE_API_KEY=xxx`
3. Redeploy

### Netlify
1. Site Settings → Build & Deploy → Environment
2. Add variables
3. Trigger new deploy

**Note:** Vite requires env vars to be prefixed with `VITE_`

---

## 🚨 Troubleshooting

### Build Fails

**Error: "Cannot find module..."**
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

**TypeScript errors:**
```bash
# Check types first
npm run type-check
# Fix errors, then build
npm run build
```

### Bluetooth Not Working

**"Web Bluetooth is not supported"**
- Make sure you're using HTTPS (not HTTP)
- Use Chrome, Edge, or Opera browser
- Check: https://caniuse.com/web-bluetooth

**Can't find device:**
- Ensure Decent machine is powered on
- Check Bluetooth is enabled on your device
- Machine should show as "DE1..." in device picker
- Move closer to the machine (within 10 meters)

### Page Not Loading After Deploy

**404 errors on refresh:**
- Check that routing is configured
- Vercel/Netlify should handle this automatically
- For other hosts, configure rewrites to `/index.html`

---

## 📊 Deployment Status

After deployment, you should see:

```
✅ Build: Successful
✅ Deploy: Live
✅ Domain: Active
✅ SSL: Provisioned
```

Your app will have:
- 📱 Mobile-optimized interface
- 🔒 HTTPS encryption
- ⚡ Fast CDN delivery
- 🔄 Automatic deployments on git push

---

## 🎯 Next Steps After Deployment

1. **Share the URL** with your phone/tablet
2. **Bookmark it** on your home screen (PWA)
3. **Test Bluetooth connection** with your Decent machine
4. **Create your first recipe**
5. **Pull your first shot** and see the live graphs!

---

## 💡 Pro Tips

### Add to Home Screen (iOS/Android)

**iOS:**
1. Open the app in Safari
2. Tap the Share button
3. Tap "Add to Home Screen"
4. Now it works like a native app!

**Android:**
1. Open in Chrome
2. Tap menu → "Add to Home Screen"
3. App appears in your app drawer

### Continuous Deployment

Once set up, every push to the main branch automatically deploys:

```bash
git add .
git commit -m "Update feature"
git push
# ⚡ Auto-deploys to Vercel/Netlify!
```

---

## 📞 Need Help?

**Deployment Issues:**
- Check [Vercel Status](https://vercel-status.com)
- Check [Netlify Status](https://netlifystatus.com)

**App Issues:**
- Open browser console (F12) and check for errors
- Test on different browsers
- Make sure you're on HTTPS

**Bluetooth Issues:**
- Refer to the troubleshooting guide in the app
- Check machine is discoverable
- Verify browser compatibility

---

## 🎉 You're All Set!

Your Decent Espresso Control app is now:
- ✅ Live on the internet
- ✅ Accessible from any device
- ✅ Ready to control your espresso machine
- ✅ Automatically deployed on every update

**Happy brewing! ☕**
