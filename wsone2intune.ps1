# Name: Migration script
# Description: This script will remove the endpoint from Workspace ONE management and re-enroll it into Microsoft Intune.
# Developed by: Zoran Topalovic 
# email: topalovic@gmail.com
# Date: 22.01.2025

Add-Type -AssemblyName System.Windows.Forms

# Create a form for displaying the progress bar (double size)
$form = New-Object Windows.Forms.Form
$form.Text = "Intune Enrollment"
$form.Width = 600
$form.Height = 300

# Create and configure a progress bar (double size)
$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Width = 500
$progressBar.Height = 60
$progressBar.Location = New-Object Drawing.Point(50, 100)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

# Create and configure a label for the text (double size)
$label = New-Object Windows.Forms.Label
$label.Text = "Enrollment in progress.  This process will take several minutes."
$label.Width = 500
$label.Location = New-Object Drawing.Point(50, 40)
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$label.Font = New-Object System.Drawing.Font("Arial", 12)  # Adjusted font size

# Add the progress bar and label to the form
$form.Controls.Add($progressBar)
$form.Controls.Add($label)

# Show the form
$form.Show()

# Function to suppress output
function Suppress-Output {
    param($ScriptBlock)
    & {
        $VerbosePreference = "SilentlyContinue"
        $DebugPreference = "SilentlyContinue"
        $ErrorActionPreference = "SilentlyContinue"
        & $ScriptBlock
    } | Out-Null
}

# Total number of steps for the task
$totalSteps = 6  # Including the uninstall step

# Loop through each step and update the progress bar and label
for ($i = 1; $i -le $totalSteps; $i++) {
    # Step 1: Unenroll from Workspace ONE
    if ($i -eq 1) {
        Suppress-Output {
            function DeleteWS1Device {
                param(
                    [string]$Username = "INTUNE-USERNAME",
                    [string]$ApiKey = "API-PASSWORD",
                    [string]$Password = "PASSWORD",
                    [string]$ws1host = "asXXX.awmdm.com"
                )

                $PasswordSecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
                $Credential = New-Object System.Management.Automation.PSCredential($Username, $PasswordSecureString)
                $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber

                $bytes = [System.Text.Encoding]::ASCII.GetBytes($Credential.UserName + ':' + $Credential.GetNetworkCredential().Password)
                $base64Cred = [Convert]::ToBase64String($bytes)
                $headers = @{
                    Authorization    = "Basic $base64Cred"
                    "aw-tenant-code" = $ApiKey
                    Accept           = "application/json;version=1"
                    "Content-Type"   = "application/json"
                }

                $deviceuri = "https://$ws1host/API/mdm/devices?id=$serialNumber&searchby=SerialNumber"
                $deviceresult = Invoke-RestMethod -Method Get -Uri $deviceuri -Headers $headers
                $deviceid = $deviceresult.Id.value
                invoke-restmethod "https://$ws1host/API/mdm/devices/$deviceid/commands?command=EnterpriseWipe&reason=Migration&keep_apps_on_device=true" -Headers $headers -Method Post
                Start-Sleep -s 10
                while (Get-Process -Name AWACMClient -ErrorAction SilentlyContinue) {
                    Start-Sleep -s 10
                }
            }

            try {
                DeleteWS1Device
            }
            catch {
                $message = $_.Exception.Message
                [System.Windows.Forms.MessageBox]::Show("If this is your first or second time seeing this error, please click 'OK', wait 60 seconds and try running the Intune Enrollment app again. If you continue to see this error after 3 tries, please screenshot this error and email IT with the screenshot.", "$message.")
                Exit 1
            }
        }
    }

    # Step 2: Delete the WSONE
    if ($i -eq 2) {
        Suppress-Output {
            $installedPrograms = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Workspace ONE*" }

            if ($installedPrograms) {
                foreach ($program in $installedPrograms) {
                    $program.Uninstall()
                }
            }
        }
    }

    # Step 3: Remove WSONE From School or Work account page
    if ($i -eq 3) {
        Suppress-Output {
            function Remove-WorkspaceOneEnrollment {
                try {
                    $enrollmentsPath = "HKLM:\Software\Microsoft\Enrollments"
                    $subkeys = Get-ChildItem -Path $enrollmentsPath

                    if ($subkeys.Count -eq 0) {
                        return
                    }

                    foreach ($subkey in $subkeys) {
                        $subkeyPath = $subkey.PSPath
                        try {
                            if (Test-Path $subkeyPath) {
                                Remove-Item -Path $subkeyPath -Recurse -Force
                            }
                        }
                        catch {}
                    }
                }
                catch {}
            }

            Remove-WorkspaceOneEnrollment
        }
    }

    # Step 4: Registry Changes
    if ($i -eq 4) {
        Suppress-Output {
            $regKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin"
            $regValueName = "BlockAADWorkplaceJoin"

            if (-not (Test-Path $regKeyPath)) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "WorkplaceJoin" -Force
            }

            Set-ItemProperty -Path $regKeyPath -Name $regValueName -Value 1
            Set-ItemProperty -Path $regKeyPath -Name $regValueName -Value 0
        }
    }

    # Step 5: Download Company Portal
    if ($i -eq 5) {
        Suppress-Output {
            winget install "Company Portal" --accept-source-agreements --accept-package-agreements
            Start-Sleep -Seconds 10

            [System.Windows.Forms.MessageBox]::Show("When the Company Portal app opens, please use your OKTA credentials to login", "INTUNE ENROLLMENT")

            Get-AppxPackage -Name *CompanyPortal* | ForEach-Object { Start-Process "$($_.InstallLocation)\CompanyPortal.exe" }
            Start-Process "companyportal:"
            Start-Sleep -Seconds 1
            Stop-Process -name "CompanyPortal"
            Start-Sleep -Seconds 1
            Start-Process "companyportal:"
        }
    }

    # Calculate percentage completion
    $percentComplete = ($i / $totalSteps) * 100

    # Update the progress bar
    $progressBar.Value = [int]$percentComplete

    # Update the label with the current step
    $label.Text = "Enrollment in progress ($i of $totalSteps)"

    # Allow the form to process events and update the progress bar and label
    [System.Windows.Forms.Application]::DoEvents()
}

# Final update: 100% completion
$progressBar.Value = 100
$label.Text = "Enrollment Complete!"

# Wait for 1 second before closing the form
Start-Sleep -Seconds 1

# Close the form
$form.Close()

# Step 6: Uninstall IntuneEnrollment.exe
# Define the program name you want to uninstall
$programName = "IntuneEnrollment"

# Get the installed application matching the program name
$app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq $programName }

# Check if the application is found
if ($app) {
    # Uninstall the application silently
    $app | ForEach-Object {
        $productCode = $_.IdentifyingNumber
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait
    }
}
