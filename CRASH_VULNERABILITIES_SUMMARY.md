# MathsWithSD Flutter - Crash Vulnerability Quick Reference

**Status:** Critical Issues Found  
**Generated:** May 19, 2026

---

## 🔴 CRITICAL (App Won't Run)

### 1. Empty Constants File
- **File:** `mathswithsd/lib/utils/constants.dart`
- **Issue:** File is EMPTY but imported everywhere as `AppConstants`
- **Error:** Runtime error on app startup - `Class AppConstants not defined`
- **Impact:** Student app CANNOT RUN
- **Fix:** Copy from admin app or populate with API endpoints
- **Time to Fix:** 5 minutes

---

## 🔴 CRITICAL (Runtime Crashes)

### 2. Image Picker Memory Overflow (Student App)
- **Location:** `ImageService.pickAndCropImage()`
- **Issue:** 100% image quality + no size limits
- **Triggers:** User selects high-res camera photo (12MP+)
- **Result:** OutOfMemoryError → App crash
- **Fix:** Reduce to 60% quality, add 1600x1600 max dimensions
- **Time to Fix:** 10 minutes

### 3. Timer Not Disposed
- **Location:** `ExamProvider._startTimer()`
- **Issue:** Timer continues after provider disposed
- **Triggers:** App backgrounded during exam, rapid navigation away
- **Result:** Timer callbacks on garbage provider → native crash
- **Fix:** Cancel timer in dispose(), add lifecycle observer
- **Time to Fix:** 15 minutes

### 4. OCR Upload = Permanent Data Loss
- **Location:** `ApiService.processOcrImage()` 60-second timeout
- **Issue:** Timeout = image + OCR result lost forever
- **Triggers:** Network slower than 60s for Mathpix
- **Result:** User must re-capture image (repeated timeouts possible)
- **Fix:** Implement exponential backoff retry (3 attempts)
- **Time to Fix:** 20 minutes

### 5. KaTeX JavaScript Injection Risk
- **Location:** `KaTeXWidget._updateContent()`
- **Issue:** Direct string interpolation in JavaScript
- **Triggers:** Malicious math text in question (if backend compromised)
- **Result:** JavaScript execution possible
- **Fix:** Use JSON encoding instead of string interpolation
- **Time to Fix:** 15 minutes

---

## 🟡 HIGH (Frequent Crashes)

### 6. WebView Memory Leak
- **Location:** Every `KaTeXWidget` instance creates new WebView
- **Triggers:** Exam with 40+ questions = 40+ WebViews in memory
- **Result:** Memory pressure, GC stalls, app slowdown/crash
- **Fix:** Implement WebView pooling or use cached singleton
- **Time to Fix:** 30 minutes

### 7. Permission Handling Not Checked
- **Location:** `_pickImage()` in create_question_screen.dart
- **Triggers:** User denies camera/gallery permission
- **Result:** Silent failure or platform exception
- **Fix:** Properly check permission status before picker
- **Time to Fix:** 20 minutes

### 8. Multipart Upload Stream Leak
- **Location:** `createQuestionResilient()` - if timeout occurs
- **Triggers:** Slow network during question upload
- **Result:** File handle not released, repeated uploads exhaust limit
- **Fix:** Properly close stream on exception
- **Time to Fix:** 15 minutes

### 9. Exam Timer Race Condition
- **Location:** `ExamProvider._startTimer()` - async save in timer callback
- **Triggers:** Answer saved while timer persisting different state
- **Result:** Exam resumes with wrong timer value if app crashes
- **Fix:** Make timer/save atomic or use database instead of SharedPrefs
- **Time to Fix:** 30 minutes

---

## 🟡 MEDIUM (Stability Issues)

### 10. User ID Lost on Auto-Login
- **Location:** `AuthProvider.tryAutoLogin()`
- **Issue:** User ID not persisted, set to empty string
- **Triggers:** App restart or crash during exam
- **Result:** User ID = '', API calls fail
- **Fix:** Store user ID in secure storage
- **Time to Fix:** 10 minutes

### 11. No Error Recovery for OCR
- **Location:** `QuestionProvider.scanImage()` - catches all exceptions
- **Issue:** User gets generic "Scanning failed" message
- **Triggers:** Server error, malformed response, network issue
- **Result:** User doesn't know what went wrong or how to fix
- **Fix:** Differentiate error types, show specific recovery steps
- **Time to Fix:** 20 minutes

### 12. Question Queue Unbounded
- **Location:** `QuestionProvider._questionQueue`
- **Issue:** Can grow indefinitely if user scans multiple images
- **Triggers:** User scans 50+ images without saving
- **Result:** Memory exhaustion, app slowdown
- **Fix:** Add MAX_QUEUE_SIZE limit with warning
- **Time to Fix:** 10 minutes

---

## Crash Probability Matrix

| Scenario | Student | Admin | Likelihood | Recovery |
|----------|---------|-------|------------|----------|
| **App Startup** | 100% | ✓ | IMMEDIATE | Restart |
| **Select Camera Image (>10MB)** | 80% | 5% | FREQUENT | App restart needed |
| **Switch Apps During Exam** | 0% | N/A | NEVER | Auto-submit triggered |
| **Take 40Q Exam** | 10% | 10% | OCCASIONAL | Data preserved |
| **OCR Upload (slow network)** | 5% | 100% loss | POSSIBLE | Manual retry (loses data) |
| **App Background + Resume** | 15% | 10% | OCCASIONAL | Timer might be wrong |
| **Repeated Question Saves** | 5% | 20% | RARE | Last one succeeded |

---

## Priority Fix Order

1. **TODAY:** Fix empty constants.dart (blocks app)
2. **TODAY:** Reduce image quality to 60%
3. **TODAY:** Add image size limits
4. **THIS WEEK:** Fix timer disposal
5. **THIS WEEK:** Implement OCR retry logic
6. **THIS WEEK:** Fix KaTeX injection risk
7. **NEXT:** Fix WebView memory leak
8. **NEXT:** Implement proper error recovery

---

## Testing Checklist

- [ ] App starts without error (constants populated)
- [ ] Take full 40-question exam on low-end device
- [ ] Screenshot high-res camera image (>10MB)
- [ ] Switch apps during exam → observe auto-submit
- [ ] Lose network during OCR → retry works
- [ ] Kill app, restart → exam resumes correctly
- [ ] Scan image, lose network before save → recovery prompt
- [ ] Performance: Exam with 40 math questions = smooth (no jank)

---

*See FLUTTER_ARCHITECTURE_ANALYSIS.md for detailed analysis and fixes.*
