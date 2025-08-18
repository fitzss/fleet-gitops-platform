#!/usr/bin/env python3
"""Fleet Robot Simulator - Reports telemetry to central monitor"""
import os
import time
import json
import random
import requests
from datetime import datetime

class FleetRobot:
    def __init__(self):
        self.id = os.getenv("ROBOT_ID", "unknown")
        self.monitor_url = os.getenv("MONITOR_URL", "http://fleet-monitor:8000")
        self.battery = 100
        
    def get_telemetry(self):
        """Generate robot telemetry data"""
        self.battery = max(20, self.battery - random.randint(1, 3))
        return {
            "robot_id": self.id,
            "battery": self.battery,
            "position": {
                "x": random.randint(0, 100),
                "y": random.randint(0, 100)
            },
            "status": "operational" if self.battery > 30 else "low_battery",
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def run(self):
        """Main robot loop"""
        print(f"[Robot {self.id}] Starting telemetry stream...")
        while True:
            try:
                telemetry = self.get_telemetry()
                response = requests.post(
                    f"{self.monitor_url}/ingest",
                    json=telemetry,
                    timeout=2
                )
                print(f"[Robot {self.id}] Status: {telemetry['status']}, Battery: {telemetry['battery']}%")
            except Exception as e:
                print(f"[Robot {self.id}] Connection error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    robot = FleetRobot()
    robot.run()
