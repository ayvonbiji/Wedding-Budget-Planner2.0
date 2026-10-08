# Wedding Budget Planner

A private, mobile-first wedding budget planner in a single file: `index.html`.
No build step, no backend, no npm install.

## Run it

Double-click `index.html`, or serve the folder so it behaves like a real website:

```bash
python3 -m http.server 8000
# open http://localhost:8000 on your laptop,
# or http://<your-laptop-ip>:8000 on your phone (same Wi-Fi)
```

An internet connection is needed only for the fonts and the PDF library (jsPDF from cdnjs).

## Deploy it (free options)

- **Netlify Drop**: go to app.netlify.com/drop and drag this folder in.
- **GitHub Pages**: push `index.html` to a repository, then Settings → Pages → Deploy from branch.
- **Vercel / Cloudflare Pages**: create a project from the folder; no build command, output directory `/`.

Add the site to your phone's home screen (Share → Add to Home Screen) so it opens like an app.

## Bride and groom login

The app opens on a login screen with two profiles: **Bride** and **Groom**. Logging in as the bride shows only the bride's planner; logging in as the groom shows only the groom's. Budget, items, ideas, vendors, payments, to-dos, savings and photos are all separate. Tap your initial (top right on mobile) or your name (bottom of the sidebar on desktop) to change your name or password, or to log out.

It runs in one of two modes:

| | Browser only (default) | Database (Supabase) |
| --- | --- | --- |
| Setup | None | 5 minutes, free |
| Login | Name + password | Name + email + password |
| Where data lives | This browser only | Your Supabase database |
| Log in from another phone/laptop | No | Yes |
| Forgot password | No (restore a backup) | Yes, reset link by email |
| Privacy | Lock inside the browser | Enforced by the database (Row Level Security) |

## Wedding page and wedding party

- **Wedding** page: both names, both sets of parents, the verse (Job 23:14), a countdown to 23 August 2027, your invitation card, and every event with date, weekday, time and venue (Engagement, Chantham Charthal, Wedding, Reception). Tap **Map** to open a venue in Google Maps. Edit everything with **Edit details** / **Edit**, or **Add event** (e.g. Mehendi).
- **Wedding Party** page: flower girls, bridesmaids and maid of honour on the bride's side; best man, groomsmen, page boy and ring bearer on the groom's side. Each person has role, age, phone, outfit, size, outfit status (Not started / Fabric bought / At tailor / Ready), photo and notes. Like everything else, the bride sees only her list and the groom only his.
- **Profile photo**: open the account menu (your initial or photo) and tap **Add your photo**.

The wedding defaults live in `WEDDING_DEFAULTS` and `DEFAULT_EVENTS` near the top of the script. Data shape additions: `settings.wedding`, `settings.photo`, `events: [{ id, name, kind, date, time, timeNote, venue, place, notes }]`, `people: [{ id, name, role, side, age, phone, outfit, size, outfitStatus, photo, notes }]`.

## Connect the database (Supabase)

1. Go to **supabase.com**, sign up (free) and click **New project**. Pick a name, a database password and the region closest to you (e.g. Mumbai). Wait about a minute for it to start.
2. Open **SQL Editor → New query**, paste the whole of `supabase-setup.sql`, and click **Run**. This creates the `profiles`, `planner_sections` and `planner_images` tables with rules that let each person read and write only their own rows. There is one bride account and one groom account.
3. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
4. In `index.html`, near the top of the script, fill in:
   ```js
   const SUPABASE_URL = 'https://xxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJhbGciOi...';
   ```
   The anon key is meant to be public; the database rules are what protect the data.
5. In **Authentication → URL Configuration**, set **Site URL** to the address where you host the app (e.g. `https://your-site.netlify.app`). Password-reset and confirmation emails link back there.
6. Optional: in **Authentication → Providers → Email**, turn off **Confirm email** if you want to skip the confirmation email when creating the two accounts.

Open the app, pick **Bride**, and create the account; then the groom does the same. You can see the data in Supabase under **Table Editor**.

How it works in the code: `DbStore` loads the person's rows after login, saves each changed section (upsert) about half a second after every edit, keeps a copy in the browser for speed, and reloads from the database when you come back to the tab. On log out the copy on the device is removed. If no URL/key is filled in, the app uses the browser-only login instead (`wbp.auth.bride` / `wbp.auth.groom` hold a name and salted SHA-256 hash, never the password).

## Project structure

Everything lives in `index.html`, in clearly marked sections:

| Section | What it holds |
| --- | --- |
| `<style>` 1–13 | Design tokens (colors, fonts, light/dark), shell, forms, each page, sheets, mobile fixes |
| A. Config | Categories, statuses, payment methods |
| B. Utilities | Money formatting (Indian grouping), dates, escaping |
| C. Icons & sample images | Inline SVG icons and the sample stage illustrations |
| D. Sample data & state | The example wedding and the shape of your data |
| E. Storage | `LocalStore` (browser) and `CloudStore` (optional sync) |
| F. Images | Resize, store and look up photos |
| G. Calculations | Every total on every page |
| H. Views | Home, Dashboard, Budget, Ideas, Vendors, Payments, To-Do, Savings, Reports |
| I–J. Forms & actions | Add/edit sheets and every button |
| K. Backup | Export and import JSON |
| L. PDF | Item, vendor and full report PDFs |
| M. Boot | Starts the app |

## How the budget calculation works

For every item:

- **Cost** = final price if one is entered, otherwise the estimated price
- **Paid** = the sum of all payments recorded against the item
- **Balance** = cost − paid

Only items with status **Selected, Booked or Completed** count toward the budget. Ideas, Shortlisted and Rejected items are saved but not counted.

Totals: estimated cost = sum of costs; total paid = sum of payments; remaining budget = budget − paid; expected remaining cost = estimated cost − paid; headroom = budget − estimated cost (shown as "Budget Remaining" or "Over Budget").

Nothing is stored as a total. Every change calls `commit()`, which saves and redraws, and every page recalculates from the raw items and payments. That is why totals can never drift out of sync.

**Option groups.** Items in the same category with the same option group (for example "Main stage") are alternatives. Selecting one moves the others back to Shortlisted, so the old amount leaves the budget and the new amount enters it.

**Amount paid** in the item and vendor forms is a convenience: changing it records a payment for the difference, so the payment history stays complete.

## How image uploads work

1. You pick or take a photo (`<input type="file" accept="image/*">`).
2. The browser resizes it on a canvas and converts it to JPEG (about 100–250 KB).
3. The item stores only a short reference:
   - `img:<id>` → compressed image kept in the browser's localStorage
   - `asset:<id>` → file stored by claude.ai when running as a Claude artifact
   - `sample:<name>` → built-in sample illustration

Browser storage holds roughly 5 MB, which is about 25–40 photos. Export a backup regularly (backups include photos). To store unlimited photos, upload them to Google Drive or Cloudinary in `Images.put()` and save the returned URL instead.

## How data is stored

- Each person's planner is saved to `localStorage` under `wbp.v1.bride.state` or `wbp.v1.groom.state` after every change, so refresh never loses data.
- On claude.ai, it also syncs each section (settings, items, vendors, payments, tasks, savings) to the artifact's private database.
- Reports → **Export backup** downloads a `.json` file with all data and photos. **Import backup** restores it on any device.

The data shape:

```js
{
  settings: { totalBudget, customCategories, taskGroups, guests, perPlate, cateringItemId },
  items:    [{ id, name, category, group, image, estimated, final, vendorId, status, notes }],
  vendors:  [{ id, name, category, phone, email, link, quoted, final, status, notes, image }],
  payments: [{ id, itemId, amount, date, method, notes }],
  tasks:    [{ id, title, group, due, notes, done }],
  savings:  [{ id, itemId, label, category, current, alternative, notes }]
}
```

## How PDF generation works

jsPDF draws each report directly as vector text on A4 pages (no screenshots), so files are small and sharp:

- `buildItemPdf(id)`: item, image, price boxes, notes, payment table
- `buildVendorPdf(id)`: contact details, quote vs final, advance, balance, linked items, payments, quotation image
- `buildReportPdf()`: summary boxes, category table with TOTAL, selected items, pending payments, vendors, potential savings, tasks

**Generate PDF** builds the file; **Download PDF** saves it (and builds it first if needed). Standard PDF fonts can't draw the ₹ symbol, so amounts print as "Rs. 1,00,000".

## Connecting Google Sheets later

The app talks to storage through one small interface. `CloudStore` shows the pattern: load every section, then save a section whenever it changes. A Google Sheets version stores each section as JSON in one row.

### 1. Create the Apps Script

Create a Google Sheet, then Extensions → Apps Script, and paste:

```js
const SHEET = 'planner';
function sheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  return ss.getSheetByName(SHEET) || ss.insertSheet(SHEET);
}
function doGet() {
  const rows = sheet_().getDataRange().getValues();
  const out = {};
  rows.forEach(([section, json, updatedAt]) => { if (section) out[section] = { data: JSON.parse(json), updatedAt }; });
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}
function doPost(e) {
  const { key, section, data, updatedAt } = JSON.parse(e.postData.contents);
  if (key !== 'CHANGE-THIS-SECRET') return ContentService.createTextOutput('{"ok":false}');
  const sh = sheet_(), rows = sh.getDataRange().getValues();
  const i = rows.findIndex(r => r[0] === section);
  const row = [section, JSON.stringify(data), updatedAt];
  if (i >= 0) sh.getRange(i + 1, 1, 1, 3).setValues([row]); else sh.appendRow(row);
  return ContentService.createTextOutput('{"ok":true}').setMimeType(ContentService.MimeType.JSON);
}
```

Deploy → New deployment → Web app → Execute as **Me**, access **Anyone with the link**. Copy the web app URL.

### 2. Add the adapter to `index.html`

Paste this after `CloudStore` and call `SheetsStore.init()` in the boot section instead of `CloudStore.init()`:

```js
const SHEETS_URL = 'https://script.google.com/macros/s/XXXX/exec';
const SHEETS_KEY = 'CHANGE-THIS-SECRET';
const SheetsStore = {
  db: null, // keeps commit() from treating Sheets as claude.ai storage
  async init() {
    try {
      const remote = await (await fetch(SHEETS_URL)).json();
      SECTIONS.forEach(s => {
        const r = remote[s];
        if (r && r.updatedAt >= (state.meta.sectionTimes[s] || 0)) { state[s] = r.data; state.meta.sectionTimes[s] = r.updatedAt; }
      });
      state = normalizeState(state); LocalStore.save(state); render();
    } catch (e) { toast('Couldn’t reach Google Sheets. Using this device’s copy.'); }
  },
  mark(sections) {
    sections.forEach(section => fetch(SHEETS_URL, {
      method: 'POST', headers: { 'Content-Type': 'text/plain' },
      body: JSON.stringify({ key: SHEETS_KEY, section, data: state[section], updatedAt: state.meta.sectionTimes[section] })
    }).catch(() => {}));
  }
};
```

Finally, in `commit()`, add `SheetsStore.mark(sections);` next to `CloudStore.mark(sections);`.

Notes: a Sheets cell holds up to 50,000 characters, which is plenty for text data. Keep photos out of the sheet (use Drive or Cloudinary URLs). Anyone with the web app URL and secret can write to the sheet, so keep both private.
