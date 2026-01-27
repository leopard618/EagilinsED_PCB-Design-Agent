# How to Run DRC in Altium Designer

## Manual DRC Execution

Since Altium Designer's DRC process may require manual confirmation, here's how to run it:

### Step-by-Step Instructions

1. **Open Altium Designer**
   - Make sure your PCB document is open
   - Example: `Y904A23-GF-DYPCB-V1.0.PcbDoc`

2. **Open Design Rule Check Dialog**
   - Go to: **Tools → Design Rule Check...**
   - Or use keyboard shortcut: **T → D** (Tools → Design Rule Check)

3. **Configure DRC Settings (Optional)**
   - In the DRC dialog, you can:
     - Select which rules to check
     - Choose report options
     - Set output folder
   - For most cases, default settings work fine

4. **Run DRC**
   - Click the **"Run Design Rule Check"** button
   - Wait for DRC to complete (may take a few seconds to minutes depending on board size)

5. **DRC Report Generated**
   - Altium automatically generates an HTML report
   - Location: `PCB_Project/Project Outputs for PCB_Project/Design Rule Check*.html`
   - The report opens automatically in your browser

### After Running DRC

Once DRC completes, you have two options:

#### Option 1: Automatic Analysis (Recommended)
- In the EagilinsED chat, simply type: **`check DRC result`**
- The system will:
  - Find the latest DRC report
  - Parse violations and warnings
  - Generate AI summary with recommendations
  - Display in chat

#### Option 2: View Report Manually
- The HTML report opens automatically in your browser
- Or use menu: **⋮ → View DRC Report**

---

## Alternative: Using the Menu Button

1. In EagilinsED UI, click the **⋮** (three-dot) menu
2. Select **"Run DRC"**
3. **Check Altium Designer window:**
   - If a DRC dialog appears, click **"Run Design Rule Check"**
   - Wait for DRC to complete
4. After DRC completes, the system will automatically analyze the results
5. Or type **`check DRC result`** in chat

---

## Troubleshooting

### DRC Dialog Doesn't Appear
- Make sure PCB document is active (not schematic)
- Try: **Tools → Design Rule Check** manually

### Report Not Found
- Check if report was saved to a different location
- In Altium: **Project → Project Options → Options → Output Path**
- Tell the agent: **`check DRC result`** - it will search multiple locations

### DRC Takes Too Long
- Large designs can take several minutes
- Wait for DRC to complete
- Then ask: **`check DRC result`**

---

## Quick Reference

| Action | Command |
|--------|---------|
| Run DRC manually | Tools → Design Rule Check → Run |
| Check DRC results | Type: `check DRC result` in chat |
| View report in browser | Menu: ⋮ → View DRC Report |
| Run DRC via menu | Menu: ⋮ → Run DRC |

---

## Example Workflow

```
1. Open Altium Designer
2. Open PCB: Y904A23-GF-DYPCB-V1.0.PcbDoc
3. Tools → Design Rule Check
4. Click "Run Design Rule Check"
5. Wait for completion
6. In EagilinsED chat: "check DRC result"
7. Get AI analysis with recommendations ✅
```

---

**Note:** The DRC report is saved automatically by Altium Designer. You don't need to save it manually.
