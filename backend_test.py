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

    def test_update_endpoints(self):
        """Test update system endpoints"""
        tests = [
            ("Check Updates", "GET", "updates/check", 200),
            ("Auto-updater Status", "GET", "updates/auto-updater/status", 200),
        ]
        
        passed = 0
        for name, method, endpoint, expected in tests:
            success, _ = self.run_test(name, method, endpoint, expected)
            if success:
                passed += 1
        
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
        }

        # Print summary
        print("\n" + "=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        
        for category, passed in test_results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"{category.upper():12} {status}")
        
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