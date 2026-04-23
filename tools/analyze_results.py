import json

with open("scratch/simulation_results.json", "r") as f:
    results = json.load(f)

num = len(results)
if num == 0:
    print("No results to analyze.")
    exit()

avg_duration = sum(r["duration"] for r in results) / num
total_recovery_bouts = sum(r["recovery_total_bouts"] for r in results)
total_recovery_success = sum(r["recovery_success_count"] for r in results)
total_died_recovering = sum(r["died_while_recovering"] for r in results)
total_reengaged = sum(r["reengaged_after_recovery"] for r in results)
total_supply_interest = sum(r["supply_interest"] for r in results)

avg_dist_ar = sum(r["kill_distances"].get("assault_rifle", 0) for r in results if "assault_rifle" in r["kill_distances"]) / max(1, len([r for r in results if "assault_rifle" in r["kill_distances"]]))
avg_dist_sg = sum(r["kill_distances"].get("shotgun", 0) for r in results if "shotgun" in r["kill_distances"]) / max(1, len([r for r in results if "shotgun" in r["kill_distances"]]))

print(f"--- 20-Match Simulation Analysis (AI Tactics Pass) ---")
print(f"Avg Match Duration: {avg_duration:.2f}s")
print(f"Total Supply Interest: {total_supply_interest}")
print(f"Ammo Recovery Success Rate: {total_recovery_success/max(1, total_recovery_bouts)*100.0:.1f}% ({total_recovery_success}/{total_recovery_bouts})")
print(f"Died While Recovering: {total_died_recovering}")
print(f"Re-engaged After Recovery: {total_reengaged}")
print(f"Avg Kill Dist (AR): {avg_dist_ar:.1f}m")
print(f"Avg Kill Dist (Shotgun): {avg_dist_sg:.1f}m")
