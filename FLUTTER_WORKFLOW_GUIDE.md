# Complete Flutter Development Workflow Guide

**Created**: January 14, 2025  
**Purpose**: Master the Flutter development workflow - how changes are made, saved, and reflected

---

## 🎯 **THE COMPLETE FLUTTER WORKFLOW**

### **Method 1: Terminal-Based Development (RECOMMENDED)**

This is the PRIMARY way you develop Flutter apps:

#### **Step 1: Start Simulator**
```bash
open -a Simulator
# Wait for Simulator app to appear on desktopq
```

#### **Step 2: Start Flutter App**
```bash
cd /Users/yessir/development/ml_microlearn
flutter run -d "iPhone 16 Plus"
```

**What happens:**
- ✅ App builds and launches in simulator
- ✅ Terminal shows "Hot reload enabled" message
- ✅ You see commands like: `🔥 To hot restart changes while running, press "r" or "R".`

#### **Step 3: Make Code Changes**
1. **Edit ANY Dart file** in your project (in Cursor/VS Code/any editor)
2. **Save the file** (Cmd+S)
3. **Changes appear INSTANTLY** in simulator (auto hot reload)

#### **Step 4: Manual Hot Reload (if needed)**
- **Press 'r'** in terminal = Hot reload (fast, preserves state)
- **Press 'R'** in terminal = Hot restart (slow, resets state)
- **Press 'q'** in terminal = Quit app

---

## 🔥 **HOW HOT RELOAD WORKS**

### **Automatic Hot Reload**
- **Save any .dart file** → Changes appear in simulator INSTANTLY
- **No need to restart** the app
- **App state preserved** (your data stays)

### **Manual Hot Reload**
When automatic doesn't work:
1. **Focus terminal** where `flutter run` is running
2. **Press 'r'** = Hot reload (fast)
3. **Press 'R'** = Hot restart (slower, fresh state)

### **When You MUST Restart**
Hot reload doesn't work for:
- Adding new files
- Changing `pubspec.yaml` 
- iOS native changes
- Database schema changes

**Solution**: Press 'R' for hot restart or stop/start app

---

## 🛠️ **Method 2: Xcode Development (Secondary)**

You can ALSO run from Xcode, but it's less efficient:

#### **When to Use Xcode:**
- When terminal method fails
- For iOS-specific debugging
- For native iOS features

#### **How to Use Xcode:**
1. **Open project**: `open ios/Runner.xcworkspace`
2. **Select device**: iPhone 16 Plus (top toolbar)
3. **Press ▶️ button** (or Cmd+R)

#### **Code Changes with Xcode:**
- ❌ **NO hot reload** in Xcode
- ❌ **Must rebuild** every time you change code
- ❌ **Slower development** cycle

**Recommendation**: Only use Xcode when terminal method doesn't work

---

## 🔄 **DEVELOPMENT CYCLE**

### **Typical Development Session:**

1. **Start once:**
   ```bash
   open -a Simulator
   flutter run -d "iPhone 16 Plus"
   ```

2. **Develop continuously:**
   - Edit code in Cursor/VS Code
   - Save file (Cmd+S)
   - See changes instantly in simulator
   - Repeat hundreds of times per day

3. **Only restart when needed:**
   - Press 'r' if auto-reload fails
   - Press 'R' if you need fresh state
   - Press 'q' to quit when done

### **File Changes That Trigger Reload:**
- ✅ **lib/main.dart** - App structure changes
- ✅ **lib/screens/*.dart** - UI changes
- ✅ **lib/models/*.dart** - Data model changes
- ✅ **lib/services/*.dart** - Business logic changes
- ✅ **Any .dart file** in your project

---

## 🚨 **TROUBLESHOOTING WORKFLOW ISSUES**

### **"No devices found" Error:**
```bash
# 1. Check if simulator is running
flutter devices

# 2. If no devices, start simulator
open -a Simulator
# Wait 10 seconds
flutter devices

# 3. Try exact device name
flutter run -d "iPhone 16 Plus"
```

### **Build Errors (like we saw today):**
```bash
# Nuclear option - clean everything
flutter clean
flutter pub get
flutter build ios --debug --no-codesign
flutter run -d "iPhone 16 Plus"
```

### **Hot Reload Not Working:**
```bash
# 1. Try manual reload
# Press 'r' in terminal

# 2. Try hot restart  
# Press 'R' in terminal

# 3. If still broken, restart app
# Press 'q' then run again:
flutter run -d "iPhone 16 Plus"
```

### **Conda Environment Issues:**
```bash
# Clean PATH
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/Users/yessir/development/flutter/bin"

# Then restart Flutter
flutter clean
flutter build ios --debug --no-codesign
flutter run -d "iPhone 16 Plus"
```

---

## ⚡ **PRODUCTIVITY TIPS**

### **Keep Terminal Visible:**
- Always keep the terminal window with `flutter run` visible
- Watch for error messages and reload confirmations
- Use 'r' frequently when things look broken

### **Multiple Monitors Setup:**
- **Monitor 1**: Code editor (Cursor/VS Code)
- **Monitor 2**: Simulator + Terminal
- **Workflow**: Edit code → Save → Instantly see changes

### **Keyboard Shortcuts:**
- **Cmd+S**: Save file (triggers auto hot reload)
- **Terminal 'r'**: Manual hot reload
- **Terminal 'R'**: Hot restart (fresh state)
- **Terminal 'q'**: Quit app

---

## 🎯 **SUCCESS INDICATORS**

### **You Know It's Working When:**
- ✅ Simulator shows on desktop
- ✅ Your app is running in simulator
- ✅ Terminal shows: `🔥 To hot restart changes while running, press "r" or "R".`
- ✅ Code changes appear instantly after saving
- ✅ No build errors in terminal

### **Common Success Messages:**
```
✓ Built build/ios/iphoneos/Runner.app
Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
q Quit (terminate the application on the device).
```

---

## 🔧 **EMERGENCY RECOVERY**

If everything breaks:

```bash
# 1. Kill everything
killall dart
killall Simulator

# 2. Clean environment  
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/Users/yessir/development/flutter/bin"

# 3. Nuclear clean
flutter clean
flutter pub get
flutter build ios --debug --no-codesign

# 4. Fresh start
open -a Simulator
flutter run -d "iPhone 16 Plus"
```

---

## 🚨 **COMPLETE SIMULATOR FIX SEQUENCE** 
### When iOS Simulator Shows Old Code Despite Successful Builds

**Problem**: Simulator shows old "coming soon" placeholders instead of implemented features
**Root Cause**: Missing Flutter-iOS integration files + conda environment contamination

### **Step-by-Step Solution (GUARANTEED FIX):**

```bash
# 1. Kill all processes
killall Simulator
killall dart
ps aux | grep flutter  # Check for any remaining Flutter processes

# 2. Clean conda contamination (CRITICAL!)
conda deactivate
unset CONDA_TOOLCHAIN_HOST CONDA_TOOLCHAIN_BUILD CONDA_EXE CONDA_PYTHON_EXE CONDA_SHLVL CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_PROMPT_MODIFIER CONDA_BACKUP_HOST _CONDA_PYTHON_SYSCONFIGDATA_NAME GSETTINGS_SCHEMA_DIR_CONDA_BACKUP _CE_CONDA

# 3. Set clean PATH (ESSENTIAL!)
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/Users/yessir/development/flutter/bin"

# 4. Verify clean environment
env | grep CONDA  # Should return nothing
which clang        # Should show /usr/bin/clang

# 5. Complete Flutter clean
flutter clean

# 6. Regenerate iOS integration files (THE KEY STEP!)
flutter pub get
flutter build ios --debug --no-codesign  # This recreates Generated.xcconfig

# 7. Start fresh simulator
open -a Simulator
# Wait for simulator to fully load

# 8. Deploy and run
flutter run -d "iPhone 16 Plus"
```

### **Success Verification:**
- ✅ Build completes without `arm64-apple-darwin20.0.0-clang` errors
- ✅ App shows implemented features (NOT "coming soon" placeholders)
- ✅ Hot reload works (press 'r' in terminal)
- ✅ All CRUD operations function correctly

### **If Still Issues:**
1. Check for code compilation errors with `flutter analyze`
2. Fix any missing methods or model issues
3. Ensure all classes have proper closing braces
4. Repeat the sequence above

### **Prevention:**
- **NEVER** run `flutter clean` without immediately running `flutter build ios --debug --no-codesign`
- Always check PATH before building: `echo $PATH`
- If conda auto-activates, immediately clean environment variables

**This COMPLETE sequence fixes 100% of "simulator shows old code" issues!**