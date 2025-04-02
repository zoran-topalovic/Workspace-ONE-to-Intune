# Workspace ONE to Microsoft Intune migration script

Overview
This PowerShell script automates the migration of Windows devices from Workspace ONE to Microsoft Intune. It removes Workspace ONE management, cleans up registry entries, and enrolls the device into Intune via Company Portal.

Features
1. Automated Unenrollment: Sends an Enterprise Wipe command to Workspace ONE.
2. Workspace ONE Cleanup: Uninstalls the Workspace ONE agent and removes related registry entries.
3. Device Preparation: Updates registry settings to allow seamless Intune enrollment.
4. Company Portal Installation: Downloads and launches the Company Portal for enrollment.
5. User-Friendly Interface: Displays a progress bar and status messages throughout the process.
6. Silent Execution: Suppresses unnecessary output for a smooth user experience.

Prerequisites
1. The script must be run with administrator privileges.
2. Ensure Windows Package Manager (winget) is available for Company Portal installation.
3. API Key (ApiKey)
    Generated from the Workspace ONE Admin Console.
    Required for authentication in API requests.
    You can create it by navigating to:
    Workspace ONE UEM Console → Groups & Settings → All Settings → System → Advanced → API → REST API
    Ensure you copy the API key when generating it.
4. Admin Username (Username)
    A Workspace ONE admin account with sufficient privileges to remove devices.
    This account should have API access enabled.
5. Admin Password (Password)
    The password for the Workspace ONE admin account.
    Used to authenticate API requests.
6. Workspace ONE API Host (ws1host)
    The Workspace ONE UEM tenant URL (e.g., asXXX.awmdm.com).
    This is your specific UEM instance where the API calls will be directed.

How It Works
- Unenroll from Workspace ONE: Sends an API request to remove the device.
- Uninstall Workspace ONE Agent: Removes installed Workspace ONE applications.
- Remove Enrollment from Settings: Cleans up MDM-related registry keys.
- Modify Registry for Intune Enrollment: Ensures Intune can take over management.
- Install & Launch Company Portal: Guides users to log in with their OKTA credentials.
- Clean Up: Uninstalls the migration script after completion.

Disclaimer

**This script is provided "as-is" without any warranties. Use at your own risk.**

