# ⚡ Quick Start Guide - Complete Feature Testing

## 5-Minute Setup

### Step 1: Start MCP Server
```powershell
cd D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent
.\venv\Scripts\activate
python mcp_server.py
```
**Keep this terminal open!**

### Step 2: Start UI
```powershell
# New terminal
cd D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent
.\venv\Scripts\activate
python main.py
```

### Step 3: Connect Altium Designer (ONE COMMAND DOES EVERYTHING!)
1. Open Altium Designer
2. Open your PCB: `PCB_Project/Y904A23-GF-DYPCB-V1.0.PcbDoc`
3. Run: **DXP → Run Script → `command_server.pas` → `StartServer`**
   - ✅ **Automatically exports PCB info** (components, nets, tracks, vias, **design rules**)
   - ✅ **Continuously listens for commands** (move, add track, run DRC, etc.)
   - ✅ **No manual export needed!**

### Step 4: Load PCB Data
**Two ways to load (both include design rules!):**

**Option 1 (Recommended):** Python File Reader (No Altium needed!)
- Click **📁** → Select `.PcbDoc` file
- ✅ **Automatically extracts design rules from file!**
- ✅ No Altium Designer needed for reading
- ✅ Works offline

**Option 2:** Altium Export (if StartServer is running)
- Menu **⋮** → **Refresh Data** (loads auto-exported file)
- ✅ Includes design rules from Altium export

**Both methods extract design rules automatically!**

---

## 🧪 Complete Feature Testing Guide

### Test 1: G-IR (Geometry IR) - View Board Data

**What to test:** Verify the agent can read and understand PCB geometry

**Steps:**
1. Load PCB (Step 4 above)
2. In chat, ask:
   - `"how many components are on this board?"`
   - `"list all nets"`
   - `"where is component C135?"`
   - `"show me all components on the top layer"`

**Expected results:**
- ✅ Agent shows component count
- ✅ Lists all nets with names
- ✅ Shows component positions (X, Y coordinates)
- ✅ Identifies layer information

**Menu alternative:**
- **⋮** → **List Components** (shows all components)

---

### Test 2: C-IR (Constraint IR) - Design Rules

**What to test:** Verify design rules are extracted and understood

**Steps:**
1. **Load PCB file (design rules extracted automatically!):**
   - **Option A:** Click **📁** → Select `.PcbDoc` file (Python file reader extracts rules!)
   - **Option B:** Menu **⋮** → **Refresh Data** (if StartServer exported data)

2. **Ask about rules:**
   - `"what are the design rules?"`
   - `"what is the minimum trace width?"`
   - `"what clearance rules are set?"`

2. **Query design rules:**
   - `"what are the design rules?"` → Shows all rules
   - `"what is the minimum trace width?"` → Shows specific value
   - `"what clearance rules are set?"` → Shows clearance rules
   - `"what is the minimum via drill size?"` → Shows via rules

**Expected results:**
- ✅ Agent extracts **actual rules** from Altium export
- ✅ Shows design rules (clearance, width, via rules) with **real values from your PCB**
- ✅ Displays rule parameters (min/max values in mm)
- ✅ Answers specific questions about rule values
- ✅ Shows default rules only if no rules found in export

**Important Notes:**
- ✅ **Python file reader extracts design rules automatically** from `.PcbDoc` files!
- ✅ **No Altium Designer needed** for reading PCB data and design rules
- ✅ **File upload (📁) includes design rules** - extracted directly from file!
- ✅ **Menu → Refresh Data** also works (if StartServer exported data)

**How to Get Design Rules:**
1. **Upload `.PcbDoc` file** (📁 button) → Rules extracted automatically!
2. Or: Run `StartServer` in Altium → Menu **⋮** → **Refresh Data**
3. Ask: `"what are the design rules?"` → Shows your actual rules!

**Troubleshooting:**
- If rules show as "not available": 
  - Make sure `StartServer` is running
  - Click Menu → **Refresh Data** to reload
- If rules show defaults only: Check that rules exist in Altium (Design → Rules)

---

### Test 3: DRC Module - Design Rule Checking with AI Analysis

**What to test:** The agent provides AI-powered analysis beyond Altium's raw DRC report

**Steps:**
1. **Run DRC in Altium Designer:**
   - In Altium: **Tools → Design Rule Check...**
   - Click **"Run Design Rule Check"**
   - Wait for DRC to complete (report saved automatically)

2. **Get AI Analysis (Two Ways):**
   - **Option A:** Menu **⋮** → **Run DRC**
     - If report exists → Analyzes immediately! ✅
     - If no report → Shows simple instructions
   - **Option B:** In chat, type: **`check DRC result`**
     - Automatically finds and analyzes the report

**Expected results:**
- ✅ Agent finds and parses the DRC HTML report
- ✅ Shows violation summary (counts by type)
- ✅ **AI Analysis** (this is the value-add!):
  - Prioritized recommendations (which to fix first)
  - Specific fix suggestions (e.g., "move C135 to 50, 60")
  - Impact assessment
  - Context-aware insights
- ✅ Natural language Q&A about violations

**Why use the agent instead of just reading Altium's report?**
- Altium shows: "Clearance violation: C135, U1, 0.15mm"
- Agent shows: "HIGH priority - Move C135 to (50, 60) to fix. Impact: prevents short circuit. Command: `move C135 to 50, 60`"

**Test AI Q&A:**
- Ask: `"why is there a clearance violation on C135?"`
- Ask: `"what's the best way to fix the width violations?"`
- Ask: `"which violations should I fix first?"`

---

### Test 4: Routing Module - AI Routing Suggestions

**What to test:** Get intelligent routing recommendations with actual routing status

**Steps:**
1. Ensure PCB is loaded
2. In chat, ask:
   - `"routing suggestions"`
   - `"what nets need routing?"`
   - `"suggest routing for power nets"`
3. Or use menu: **⋮** → **Routing Suggestions**

**Expected results:**
- ✅ Shows routing status (routed ✅ vs unrouted 🔴)
- ✅ Prioritized by net type (HIGH/MEDIUM/NORMAL)
- ✅ Identifies unconnected nets automatically
- ✅ Recommends specific trace widths per net type
- ✅ Shows component connection counts
- ✅ Provides actionable routing commands
- ✅ Summary: "X nets routed, Y nets unrouted"

**Example output:**
```
🔌 Routing Suggestions & Analysis

15 nets need routing, 8 nets are already routed

🔴 HIGH Priority (Route First)
🔴 GND (unrouted)
   🔴 URGENT: Route ground net with wide traces (1.0mm+) or use ground plane
   Trace Width: 1.0mm+ (or ground plane)
   Components: 12 connected

✅ VCC (routed)
   ✅ Power net is routed. Verify trace width is adequate for current.
   Trace Width: 0.5-1.0mm (based on current)
   Components: 5 connected
```

---

### Test 5: PCB Modification - Natural Language Commands

**What to test:** Modify PCB using natural language

**Steps:**
1. Ensure Altium Script Server is running (Step 3)
2. In chat, try:
   - `"move C135 to 50, 60"`
   - `"move U1 to position 100, 50"`
   - `"add a track on net GND from 10,10 to 50,50"`
   - `"add a via at position 30, 30"`

**Expected results:**
- ✅ Agent confirms the command
- ✅ Shows confirmation dialog
- ✅ Executes command in Altium Designer
- ✅ Component/track/via appears in Altium
- ✅ Agent confirms completion

**Test workflow:**
1. Move a component: `"move C135 to 80, 45"`
2. Click **Yes** in confirmation
3. Check Altium Designer - component should move!
4. Run DRC: `"check DRC result"` (to verify no new violations)

---

### Test 6: Component Analysis

**What to test:** Query component information

**Steps:**
1. In chat, ask:
   - `"where is U1?"`
   - `"list all capacitors"`
   - `"show me components on the bottom layer"`
   - `"what components are connected to net GND?"`

**Expected results:**
- ✅ Shows component positions
- ✅ Lists components by type
- ✅ Filters by layer
- ✅ Shows net connections

---

### Test 7: Net Analysis

**What to test:** Understand electrical connections

**Steps:**
1. In chat, ask:
   - `"list all nets"`
   - `"what components are on net GND?"`
   - `"show me power nets"`
   - `"which nets are not routed?"`

**Expected results:**
- ✅ Lists all electrical nets
- ✅ Shows components connected to each net
- ✅ Identifies power/signal nets
- ✅ Highlights unrouted nets

---

### Test 8: Refresh Data

**What to test:** Update data from Altium auto-export

**Steps:**
1. Make changes in Altium Designer (move a component, add a track)
2. **StartServer automatically re-exports** (runs continuously)
3. In EagilinsED: Menu **⋮** → **Refresh Data**

**Expected results:**
- ✅ Loads latest auto-exported data from StartServer
- ✅ Shows updated statistics
- ✅ Agent now has latest component positions
- ✅ Design rules are included in the refresh

---

## 🎯 Complete Testing Workflow

### Full End-to-End Test

**Scenario: Fix a DRC violation using the agent**

1. **Load PCB**
   - Make sure `StartServer` is running (auto-exports everything)
   - Menu **⋮** → **Refresh Data** (loads auto-exported file with design rules)

2. **Run DRC**
   - In Altium: **Tools → Design Rule Check → Run**
   - In EagilinsED: Menu **⋮** → **Run DRC** (auto-detects and analyzes!)
   - Or in chat: `"check DRC result"`

3. **Analyze Violations**
   - Agent shows AI analysis with recommendations
   - Ask: `"which violation should I fix first?"`

4. **Fix Violation**
   - Agent suggests: "Move C135 to (50, 60)"
   - In chat: `"move C135 to 50, 60"`
   - Click **Yes** to confirm
   - Check Altium - component moved!

5. **Verify Fix**
   - Run DRC again in Altium
   - In chat: `"check DRC result"`
   - Verify violation is resolved

---

## 📋 Feature Checklist

Test each feature and check off:

- [ ] **G-IR**: View board data (components, nets, layers)
- [ ] **C-IR**: View design rules
- [ ] **DRC Module**: Run DRC + Get AI analysis
- [ ] **Routing Module**: Get routing suggestions
- [ ] **PCB Modification**: Move components via chat
- [ ] **Component Analysis**: Query component info
- [ ] **Net Analysis**: Query net information
- [ ] **Export/Refresh**: Update data from Altium
- [ ] **Natural Language**: Ask questions about design
- [ ] **AI Recommendations**: Get actionable fix suggestions

---

## 💡 Key Value Propositions

### Why Use the Agent?

**1. AI-Powered Analysis**
- Not just data, but intelligent interpretation
- Understands context and relationships
- Provides actionable insights

**2. Natural Language Interface**
- Ask questions in plain English
- No need to learn commands
- Interactive problem-solving

**3. Automated Fixes**
- Execute fixes via chat commands
- No manual clicking in Altium
- Confirmation before execution

**4. Prioritized Recommendations**
- Know what to fix first
- Understand impact
- Save time

---

## Menu (⋮) Actions Reference

| Action | What It Does | Test Command |
|--------|--------------|--------------|
| **Run DRC** | **Smart DRC Check:** If report exists → analyzes immediately! If not → shows instructions | Auto-detects existing reports |
| **Refresh Data** | **Loads auto-exported data from StartServer** (includes design rules!) | Loads latest export |
| **Routing Suggestions** | **Intelligent routing analysis** with routed/unrouted status | Or: `routing suggestions` |
| **List Components** | Shows all components | Or: `list all components` |
| **Altium Status** | Check connection | Verifies script server |
| **View DRC Report** | Opens DRC HTML in browser | After running DRC |

---

## Common Chat Commands

| Command | Tests Feature |
|---------|--------------|
| `"how many components?"` | G-IR, Component count |
| `"list all nets"` | G-IR, Net listing |
| `"where is C135?"` | Component location |
| `"check DRC result"` | DRC Module + AI Analysis |
| `"routing suggestions"` | Routing Module (with status) |
| `"move C135 to 50, 60"` | PCB Modification |
| `"what are the design rules?"` | C-IR, All rules |
| `"what is the minimum trace width?"` | C-IR, Specific rule value |
| `"what clearance rules are set?"` | C-IR, Clearance rules |
| `"list all capacitors"` | Component filtering |

---

## Troubleshooting

**Server not starting?**
- Check port 8765 is free: `netstat -ano | findstr :8765`

**Altium not connecting?**
- Verify PCB is open in Altium
- Check script paths in `command_server.pas`
- Run `StartServer` again

**"No PCB loaded"?**
- Click **📁** to upload file
- Or Menu → **Export PCB Info**

**DRC report not found?**
- Make sure DRC completed in Altium
- Check: `PCB_Project/Project Outputs for PCB_Project/`
- Menu **⋮** → **Run DRC** (auto-detects existing reports)
- Or try: `check DRC result` (searches multiple locations)

**Design rules not showing?**
- Export PCB info: Menu **⋮** → **Export PCB Info**
- This exports design rules from Altium
- Then ask: `"what are the design rules?"`

**Routing suggestions seem generic?**
- Make sure PCB is loaded with tracks data
- Export PCB info to get complete routing status
- Agent now shows routed/unrouted status automatically

---

## Next Steps

After testing all features:
1. Review `COMPLETE_GUIDE.md` for detailed documentation
2. Check `WEEK_SUMMARY.md` for implementation details
3. Explore advanced features in the full guide

---

**Happy Testing! 🚀**
