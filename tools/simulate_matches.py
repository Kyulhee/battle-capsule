import subprocess
import re
import json
import os

import sys

GODOT_BIN = ".\\Godot_v4.6.2-stable_win64_console.exe"
PROJECT_PATH = "."
NUM_MATCHES = 20
if len(sys.argv) > 1:
	NUM_MATCHES = int(sys.argv[1])
TIMEOUT_PER_MATCH = 300 # seconds

def run_match(match_id):
	print(f"--- Running Match {match_id+1}/{NUM_MATCHES} ---", flush=True)
	cmd = [GODOT_BIN, "--path", PROJECT_PATH, "--headless", "--", "autostart=true"]
	try:
		process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
		output = ""
		while True:
			line = process.stdout.readline()
			if not line: break
			output += line
			if "died" in line or "Match Ended" in line or "Supply Zone" in line:
				print(f"  {line.strip()}", flush=True)
		process.wait(timeout=10)
		return output
	except Exception as e:
		print(f"Match {match_id+1} error: {e}", flush=True)
		return ""

def parse_telemetry(output):
	data = {
		"duration": 0.0,
		"ammo_empty_bouts": 0,
		"recovery_success_count": 0,
		"recovery_total_bouts": 0,
		"died_while_recovering": 0,
		"reengaged_after_recovery": 0,
		"supply_interest": 0,
		"supply_contests": 0,
		"kill_distances": {},
		"weapon_stats": {}
	}
	
	if "AI TACTICS & ECONOMY SUMMARY" not in output: return data

	m = re.search(r"Duration: ([\d.]+)", output)
	if m: data["duration"] = float(m.group(1))

	m = re.search(r"Supply Interest/Contests: (\d+) / (\d+)", output)
	if m:
		data["supply_interest"] = int(m.group(1))
		data["supply_contests"] = int(m.group(2))

	m = re.search(r"Ammo Empty Bouts: (\d+)", output)
	if m: data["ammo_empty_bouts"] = int(m.group(1))

	m = re.search(r"Recovery Success Rate: [\d.]+% \((\d+)/(\d+)\)", output)
	if m:
		data["recovery_success_count"] = int(m.group(1))
		data["recovery_total_bouts"] = int(m.group(2))

	m = re.search(r"Died While Recovering: (\d+)", output)
	if m: data["died_while_recovering"] = int(m.group(1))

	m = re.search(r"Re-engaged After Recovery: (\d+)", output)
	if m: data["reengaged_after_recovery"] = int(m.group(1))

	dist_section = re.findall(r"  (\w+): Avg Kill Dist ([\d.]+)m", output)
	for w_name, dist in dist_section:
		data["kill_distances"][w_name] = float(dist)
		
	return data

if __name__ == "__main__":
	all_matches = []
	for i in range(NUM_MATCHES):
		out = run_match(i)
		stats = parse_telemetry(out)
		if stats["duration"] > 0:
			all_matches.append(stats)
			with open("tools/simulation_results.json", "w") as f:
				json.dump(all_matches, f, indent=2)
	print(f"\nFinalized {len(all_matches)} simulations.", flush=True)
