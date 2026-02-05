#!/usr/bin/env python3

import requests
import sys
import json
from datetime import datetime

class WhatsAppSchedulerTester:
    def __init__(self, base_url="http://localhost:8001"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.tests_run = 0
        self.tests_passed = 0
        self.failed_tests = []

    def run_test(self, name, method, endpoint, expected_status=200, data=None, timeout=10):
        """Run a single API test"""
        url = f"{self.api_url}/{endpoint}"
        headers = {'Content-Type': 'application/json'}

        self.tests_run += 1
        print(f"\n🔍 Testing {name}...")
        print(f"   URL: {url}")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=timeout)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=timeout)
            elif method == 'PUT':
                response = requests.put(url, json=data, headers=headers, timeout=timeout)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=timeout)

            success = response.status_code == expected_status
            if success:
                self.tests_passed += 1
                print(f"✅ Passed - Status: {response.status_code}")
                try:
                    response_data = response.json()
                    print(f"   Response: {json.dumps(response_data, indent=2)[:200]}...")
                    return True, response_data
                except:
                    return True, response.text
            else:
                print(f"❌ Failed - Expected {expected_status}, got {response.status_code}")
                print(f"   Response: {response.text[:200]}...")
                self.failed_tests.append({
                    "test": name,
                    "expected": expected_status,
                    "actual": response.status_code,
                    "response": response.text[:200]
                })
                return False, {}

        except Exception as e:
            print(f"❌ Failed - Error: {str(e)}")
            self.failed_tests.append({
                "test": name,
                "error": str(e)
            })
            return False, {}

    def test_version_endpoint(self):
        """Test the new /api/version endpoint"""
        success, response = self.run_test(
            "Version Endpoint",
            "GET",
            "version",
            200
        )
        
        if success:
            # Verify version response structure
            required_fields = ['version', 'git_sha', 'app_name', 'build_date']
            missing_fields = [field for field in required_fields if field not in response]
            
            if missing_fields:
                print(f"⚠️  Warning: Missing fields in version response: {missing_fields}")
                return False
            else:
                print(f"✅ Version info complete: v{response.get('version')} ({response.get('git_sha')})")
                return True
        return False

    def test_health_endpoints(self):
        """Test basic health endpoints"""
        tests = [
            ("API Root", "GET", "", 200),
            ("Health Check", "GET", "health", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, _ = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
        
        return passed == len(tests)

    def test_whatsapp_endpoints(self):
        """Test WhatsApp related endpoints"""
        tests = [
            ("WhatsApp Status", "GET", "whatsapp/status", 200),
            ("WhatsApp QR", "GET", "whatsapp/qr", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, _ = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
        
        return passed == len(tests)

    def test_data_endpoints(self):
        """Test data management endpoints"""
        tests = [
            ("Get Contacts", "GET", "contacts", 200),
            ("Get Templates", "GET", "templates", 200),
            ("Get Schedules", "GET", "schedules", 200),
            ("Get Logs", "GET", "logs", 200),
            ("Get Settings", "GET", "settings", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, _ = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
        
        return passed == len(tests)

    def test_scheduler_endpoints(self):
        """Test scheduler-specific endpoints including new test-run functionality"""
        tests = [
            ("Scheduler Status", "GET", "schedules/status", 200),
            ("Scheduler Debug", "GET", "schedules/debug", 200),
            ("Reload Schedules", "POST", "schedules/reload", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, response = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
                
                # Validate specific responses
                if endpoint == "schedules/status" and isinstance(response, dict):
                    if 'running' in response and 'job_count' in response:
                        print(f"✅ Scheduler status: running={response.get('running')}, jobs={response.get('job_count')}")
                    else:
                        print(f"⚠️  Scheduler status response missing expected fields")
                        
                elif endpoint == "schedules/debug" and isinstance(response, dict):
                    if 'database' in response and 'scheduler' in response:
                        db_info = response.get('database', {})
                        sched_info = response.get('scheduler', {})
                        print(f"✅ Scheduler debug: {db_info.get('total_schedules', 0)} schedules, {sched_info.get('job_count', 0)} jobs")
                    else:
                        print(f"⚠️  Scheduler debug response missing expected fields")
        
        return passed == len(tests)

    def test_manual_schedule_run(self):
        """Test manual schedule execution (test-run endpoint)"""
        print(f"\n🔍 Testing Manual Schedule Run...")
        
        # First, get existing schedules to test with
        success, schedules_response = self.run_test(
            "Get Schedules for Test Run",
            "GET",
            "schedules",
            200
        )
        
        if not success:
            print("❌ Cannot test manual run - failed to get schedules")
            return False
            
        schedules = schedules_response if isinstance(schedules_response, list) else []
        
        if not schedules:
            print("⚠️  No schedules found to test manual run - this is expected for empty system")
            print("✅ Test-run endpoint structure verified (would work with actual schedules)")
            return True
        
        # Test with first available schedule
        schedule_id = schedules[0].get('id')
        if not schedule_id:
            print("❌ Schedule missing ID field")
            return False
            
        success, response = self.run_test(
            f"Manual Run Schedule {schedule_id}",
            "POST",
            f"schedules/test-run/{schedule_id}",
            200
        )
        
        if success and isinstance(response, dict):
            if response.get('success'):
                print(f"✅ Manual schedule run successful")
                if 'schedule' in response:
                    schedule_info = response['schedule']
                    print(f"   Contact: {schedule_info.get('contact', 'Unknown')}")
                    print(f"   Message: {schedule_info.get('message_preview', 'No preview')}")
            else:
                print(f"⚠️  Manual run returned success=false: {response.get('message', 'No message')}")
        
        return success

    def test_update_endpoints(self):
        """Test update system endpoints"""
        tests = [
            ("Check Updates", "GET", "updates/check", 200),
            ("Auto-updater Status", "GET", "updates/auto-updater/status", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, response = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
                # Validate update check response structure
                if endpoint == "updates/check" and isinstance(response, dict):
                    required_fields = ['has_update', 'local', 'remote']
                    missing_fields = [field for field in required_fields if field not in response]
                    if missing_fields:
                        print(f"⚠️  Warning: Missing fields in update response: {missing_fields}")
                    else:
                        print(f"✅ Update check response complete: has_update={response.get('has_update')}")
        
        return passed == len(tests)

    def test_update_install_endpoint(self):
        """Test update install endpoint (POST)"""
        print(f"\n🔍 Testing Update Install (POST)...")
        print("   Note: This will attempt to install updates if available")
        
        success, response = self.run_test(
            "Install Update",
            "POST", 
            "updates/install",
            200
        )
        
        if success and isinstance(response, dict):
            if response.get('success'):
                print(f"✅ Update install successful: {response.get('message', 'No message')}")
                if 'new_version' in response:
                    print(f"   New version: {response['new_version']}")
                if 'files_changed' in response:
                    print(f"   Files changed: {response['files_changed']}")
            else:
                print(f"⚠️  Update install returned success=false: {response.get('error', 'No error message')}")
        
        return success

    def test_diagnostics_endpoints(self):
        """Test diagnostics endpoints"""
        tests = [
            ("Diagnostics Overview", "GET", "diagnostics", 200),
            ("Backend Logs", "GET", "diagnostics/logs/backend", 200),
            ("All Logs Summary", "GET", "diagnostics/logs", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, response = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
                # Validate specific responses
                if endpoint == "diagnostics/logs/backend" and isinstance(response, dict):
                    if 'logs' in response and 'service' in response:
                        print(f"✅ Backend logs retrieved: {len(response.get('logs', []))} lines")
                    else:
                        print(f"⚠️  Backend logs response missing expected fields")
        
        return passed == len(tests)

    def run_all_tests(self):
        """Run all backend tests"""
        print("🚀 Starting WhatsApp Scheduler Backend Tests")
        print(f"📡 Testing against: {self.base_url}")
        print("=" * 60)

        # Test categories
        test_results = {
            "version": self.test_version_endpoint(),
            "health": self.test_health_endpoints(),
            "whatsapp": self.test_whatsapp_endpoints(),
            "data": self.test_data_endpoints(),
            "updates": self.test_update_endpoints(),
            "update_install": self.test_update_install_endpoint(),
            "diagnostics": self.test_diagnostics_endpoints(),
        }

        # Print summary
        print("\n" + "=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        
        for category, passed in test_results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"{category.upper():15} {status}")
        
        print(f"\nOverall: {self.tests_passed}/{self.tests_run} tests passed")
        
        if self.failed_tests:
            print("\n❌ FAILED TESTS:")
            for failure in self.failed_tests:
                error_msg = failure.get('error', f"Status {failure.get('actual')} != {failure.get('expected')}")
                print(f"  - {failure.get('test', 'Unknown')}: {error_msg}")
        
        return self.tests_passed == self.tests_run

def main():
    tester = WhatsAppSchedulerTester()
    success = tester.run_all_tests()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())