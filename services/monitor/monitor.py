#!/usr/bin/env python3
"""Fleet Monitor - Central telemetry aggregation and API"""
from flask import Flask, request, jsonify
from datetime import datetime
from threading import Lock
import os

app = Flask(__name__)
fleet_state = {}
state_lock = Lock()

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "fleet-monitor"}), 200

@app.route("/ingest", methods=["POST"])
def ingest():
    """Ingest telemetry from robots"""
    data = request.get_json(force=True)
    with state_lock:
        robot_id = str(data.get("robot_id", "unknown"))
        data["last_seen"] = datetime.utcnow().isoformat()
        fleet_state[robot_id] = data
    return jsonify({"accepted": True}), 200

@app.route("/fleet")
def fleet():
    """Get current fleet status"""
    with state_lock:
        operational = sum(1 for r in fleet_state.values() if r.get("status") == "operational")
        return jsonify({
            "total_robots": len(fleet_state),
            "operational": operational,
            "low_battery": len(fleet_state) - operational,
            "robots": fleet_state,
            "timestamp": datetime.utcnow().isoformat()
        })

@app.route("/metrics")
def metrics():
    """Prometheus-style metrics"""
    with state_lock:
        metrics_text = f"""# HELP fleet_robots_total Total number of robots
# TYPE fleet_robots_total gauge
fleet_robots_total {len(fleet_state)}
# HELP fleet_robots_operational Number of operational robots
# TYPE fleet_robots_operational gauge
fleet_robots_operational {sum(1 for r in fleet_state.values() if r.get("status") == "operational")}
"""
    return metrics_text, 200, {'Content-Type': 'text/plain'}

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=False)
