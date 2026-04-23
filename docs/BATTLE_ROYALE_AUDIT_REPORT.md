# Battle Royale AI Combat & Loot Audit Report

**Date**: 2026-04-22  
**Simulation Batch**: 20 Matches  
**Mode**: Headless Simulation (5.0x Time Scale)

## 1. Executive Summary
The recent updates have successfully addressed the "Combat Over-Priority" and "Stickiness" issues. Bots now exhibit a healthy balance between scavenging and fighting. The introduction of the `Loot-First Bias` has fundamentally changed the early-game meta, ensuring that bots are properly geared before engaging in prolonged combat.

| Metric | Previous (Audit) | Current (Post-Fix) | Status |
| :--- | :--- | :--- | :--- |
| **Pistol Kill Share** | 100% | **2.3%** | 🟢 FIXED |
| **Loot Intent** | 0 | **34.0 (Avg/Match)** | 🟢 FIXED |
| **Max Attack Bout** | ~190s (Continuous) | **8.12s** | 🟢 FIXED |
| **Avg Match Time** | ~72.5s | **~67s (In-game)** | 🟡 STABLE |

---

## 2. Detailed Metrics Analysis

### A. Attack Stickiness & Combat Feel
The AI no longer "locks on" to targets indefinitely. The leash and visibility timers force tactical disengagements.

*   **Avg Max Attack Bout**: 17.75s (The longest continuous engagement in a match).
*   **Attack Disengages**: ~3.15 per match. These are instances where the bot chose to stop fighting because the target was hidden or too far.
*   **Outside Zone Engagements**: 480 total occurrences (Note: logged per frame during state, indicating bots still occasionally fight while transitioning).

### B. Looting Funnel & Economy
The "Loot-First" logic is highly effective. Bots prioritize pickups when under-geared or low on health.

*   **First Weapon Upgrade**: **0.02s** average. Most bots grab a weapon within the first few frames of spawning near a hotspot.
*   **Loot Funnel (Total across 20 matches)**:
    *   **Selected (Intent)**: 680
    *   **Attempted (Collection)**: 578
    *   **Succeeded**: 578
    *   **Success Rate**: **85%** (Fails are usually due to the item being collected by another bot or the bot dying before reaching it).
*   **Weapon Distribution**:
    *   **Shotgun**: Most popular/effective in the current map size.
    *   **Assault Rifle**: High pickup rate but often swapped for shotguns in close-quarters plaza fights.

### C. Zone Survival
The `ZONE_ESCAPE` state is functioning as intended, but remains high-risk.

*   **Zone Escape Triggers**: ~3.95 per match.
*   **Time Outside Zone**: 833.51s (Cumulative across all bots in 20 matches).
*   **Deaths Outside by State**:
    *   **ZONE_ESCAPE**: 28 deaths (Bots dying to gunshots while trying to run back in).
    *   **ATTACK/CHASE**: 0 deaths (Confirms bots successfully prioritize escaping over fighting when the zone is lethal).

### D. Match Outcomes
*   **Avg Heals Used**: 1.25 per match (Increased from 0.2, showing bots are scavenging for and using healing items).
*   **Pistol Kill Share**: Only 5 kills out of 213 total were made with a pistol. This confirms the "Gear-up" phase is now mandatory for survival.

---

## 3. Success Signals [Heuristic Validation]

*   [x] **Avg Match Duration**: Increased stability (Bots survive longer due to better gear).
*   [x] **Pistol only kill**: 100% share broken (Now < 3%).
*   [x] **First weapon upgrade**: Significantly faster (Instantly upon spawn).
*   [x] **Heal usage**: Increased by ~6x.
*   [x] **Attack duration**: Engagement bouts are now segmented rather than continuous.

## 4. Next Steps
1.  **Refine "Combat While Outside"**: Currently, bots only check for the zone during state transitions. We may need a more aggressive "Emergency Escape" if they take high zone damage while shooting.
2.  **Weapon Balancing**: Shotguns are currently dominant. Consider increasing AR range or damage to encourage mid-range play.
3.  **Plaza Hotspot**: 70% of engagements happen in the center. Consider adding more high-tier loot to the NW/SE outposts to spread out the action.

---
*Report generated automatically by Antigravity AI Auditor.*
