# -----------------------------
# Legal Disclaimer:
# -----------------------------
# This script is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. 
# The author of this script assumes no liability for any damage or data loss caused by the use of this script, directly or indirectly. 
# It is the user's responsibility to thoroughly review, test, and modify this script before deploying it in a production environment.
# This script is intended for educational and informational purposes only. Use it at your own risk and discretion.
# Thoroughly test in a none production environment

# -----------------------------
# Purpose of This Script:
# -----------------------------
# The primary purpose of this script is to integrate Microsoft Windows DHCP server scopes and leases with the phpIPAM IP Address Management (IPAM) system. 
# The script retrieves all DHCP scopes and leases from a Windows DHCP server and then updates phpIPAM with the subnet details and IP addresses, ensuring that the phpIPAM database reflects the current state of the DHCP server.
# It also optionally updates custom fields for lease duration (`custom_leaseDuration`) and subnet state (`custom_subnetState`), allowing phpIPAM users to track DHCP lease and subnet information.
# Note:  The leases are coming in a second release

# Functionality Summary:
# 1. Retrieves all DHCP scopes from the Windows DHCP server.
# 2. Updates phpIPAM with the subnet details (e.g., description, lease duration, subnet state).
#		-   The script can be set up to run manually or scheduled to run automatically as a Windows Task Scheduler job 
#			on the DHCP server itself or another machine with network access to the DHCP server (you must have rsat tools installed and have admin rights assigned on the server).
# 3. Optionally logs all operations to a file for auditing and troubleshooting purposes.
# 4. Supports custom fields in phpIPAM for storing lease duration and subnet state.
# 5. Optionally performs host checks (ping) before adding IPs to phpIPAM.

# -----------------------------
# Configuration Instructions:
# -----------------------------
# Required Items for Script to Work:
# 1. phpIPAM API Base URL, Section ID, and API Token.
# 2. The PowerShell script should be run on a machine that has access to a Windows DHCP server and the script needs Admin rights
# 3. Ensure the following custom fields are defined in phpIPAM (if using them):
#    - `custom_leaseDuration`: Used to store the DHCP lease duration (Optional).
#    - `custom_subnetState`: Used to store the subnet state ("active" or "inactive") (Optional).
#    - `pingSubnet`: Controls whether a subnet should be included in status checks (Default: 0/off).
#    - `scanAgent`: Assigns a scan agent for scanning the subnet (Default: 1).
# 4. Powershell 5.1 this is what the script was written this has not been tested at all in Powershell 7.x
#
# Optional Settings:
# 1. `$useLeaseDuration`: Set to `$true` to update the lease duration field in phpIPAM.
# 2. `$useSubnetState`: Set to `$true` to update the subnet state field in phpIPAM.
# 3. `$checkHost`: Set to `$true` to perform host checks (ping) for each IP in the lease before adding to phpIPAM.
# 4. `$logToFileSubnet`: Set to `$true` to log the subnet processing to a file. 
# 5. `$logToFileLeases`: Set to `$true` to log the lease processing to a file.
# 6. `$descriptionPrefix`: Set the prefix for IP descriptions when adding them to phpIPAM.

# Running as a Scheduled Task:
# ----------------------------
# You can set up this script to run automatically by adding it as a scheduled task in Windows Task Scheduler.
# 1. Open Task Scheduler.
# 2. Create a new task.
# 3. Set the trigger to run the task at your desired interval (e.g., hourly, daily).
# 4. Set the action to "Start a program" and point it to the PowerShell executable (`powershell.exe`).
# 5. In the arguments field, provide the path to the script (e.g., `-File C:\path\to\script.ps1`).
# 6. Ensure that the task is set to run under an account with sufficient permissions to access both the DHCP server and phpIPAM.

# -----------------------------
# Define your phpIPAM API base, section ID, and API token
# -----------------------------
$apiBase = "https://yourserverIPorNAME/api/APPID"
$token = "APP code goes here"
$sectionId = Numeric Value of the section example (3)

# Optional feature flags
$useLeaseDuration = $false   # Set to $true to use the lease duration custom field in phpIPAM.
$useSubnetState = $false     # Set to $true to use the subnet state custom field in phpIPAM.
$descriptionPrefix = "Imported from WIN DHCP"  # Set a description prefix for IP and subnet entries in phpIPAM.

# Set default values for scanAgent and pingSubnet if they are not provided
$scanAgent = 1        # Set to your default scan agent ID 
$pingSubnet = 1       # Set to 0 to disable pinging, or 1 to enable pinging

# Custom field variables
$leaseDurationField = "leaseDuration"  # Custom field for storing the DHCP lease duration in phpIPAM.
$subnetStateField = "subnetState"      # Custom field for storing the subnet state ("active" or "inactive") in phpIPAM.

# Disable SSL certificate validation (only if necessary for self-signed certificates)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Enforce TLS 1.2 for secure communications with the phpIPAM API.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -----------------------------
# Log function: Writes to console and optionally to a log file
# -----------------------------
function Write-Log {
    param (
        [string]$message,
        [bool]$logToFile = $false,
        [string]$logFile = "C:\logs\phpipam_script.log"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host $logMessage

    if ($logToFile) {
        # Ensure the logs directory exists
        $logDirectory = [System.IO.Path]::GetDirectoryName($logFile)
        if (-not (Test-Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force
        }

        # Write to the log file
        Add-Content -Path $logFile -Value $logMessage
    }
}

# Function to convert subnet mask to CIDR notation
function Convert-MaskToCIDR {
    param (
        [string]$mask
    )

    # Split the mask into octets
    $octets = $mask.Split('.')

    # Convert each octet to binary and count the number of 1's
    $cidr = 0
    foreach ($octet in $octets) {
        $binaryOctet = [Convert]::ToString([int]$octet, 2) # Convert octet to binary
        $cidr += ($binaryOctet -split '1').Length - 1       # Count the 1's
    }

    return $cidr
}

# Function to log API response errors for more detail
function Log-ApiError {
    param (
        [System.Management.Automation.ErrorRecord]$exception,
        [bool]$logToFile = $false
    )

    $errorMessage = "Exception: $($exception.Exception.Message)"
    Write-Log $errorMessage $logToFile

    # Check if there's a web response available
    if ($exception.Exception -is [System.Net.WebException]) {
        $webException = $exception.Exception
        if ($webException.Response) {
            $errorStream = $webException.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorResult = $reader.ReadToEnd()
            Write-Log "Detailed error response: $errorResult" $logToFile
        }
    }
    else {
        Write-Log "No detailed web exception response available." $logToFile
    }
}

# Function to create a subnet in phpIPAM
function Create-SubnetInPhpIPAM {
    param (
        [string]$subnet,
        [int]$mask,
        [string]$leaseDuration = $null,
        [string]$subnetState = $null,
        [string]$name,   # Add the name as a parameter
        [bool]$logToFile = $false
    )

    Write-Log "Creating subnet with description: '$name'" $logToFile  # Log the description

    # Prepare data for creating subnet
    $subnetData = @{
        "subnet" = $subnet
        "mask" = $mask
        "sectionId" = $sectionId
        "description" = $name       # Use the name from the DHCP scope as the description
        "scanAgent" = $scanAgent
        "pingSubnet" = $pingSubnet
    }

    if ($useLeaseDuration -and $leaseDuration) {
        $subnetData["custom_$leaseDurationField"] = $leaseDuration
    }
    if ($useSubnetState -and $subnetState) {
        $subnetData["custom_$subnetStateField"] = $subnetState
    }

    $createSubnetUrl = "$apiBase/subnets/"

    try {
        # Create HTTP request to phpIPAM API
        $request = [System.Net.HttpWebRequest]::Create($createSubnetUrl)
        $request.Method = "POST"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"

        # Convert the data to JSON and send to phpIPAM
        $jsonData = $subnetData | ConvertTo-Json
        Write-Log "Sending POST request to create subnet with data: $jsonData" $logToFile
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        $request.ContentLength = $bytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()

        # Get the response
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        Write-Log "Successfully created subnet ${subnet}/${mask} in phpIPAM." $logToFile
        return $result
    } catch [System.Net.WebException] {
        Write-Log "Error creating subnet ${subnet}/${mask}." $logToFile
        Log-ApiError $_ $logToFile
    }
}

# Function to update a subnet in phpIPAM
function Update-SubnetInPhpIPAM {
    param (
        [int]$subnetId,
        [string]$name,   # Add the name as a parameter
        [string]$leaseDuration = $null,
        [string]$subnetState = $null,
        [bool]$logToFile = $false
    )

    Write-Log "Updating subnet with description: '$name'" $logToFile  # Log the description

    # Prepare data for updating the subnet
    $updateData = @{
        "description" = $name       # Use the name from the DHCP scope as the description
        "scanAgent" = $scanAgent
        "pingSubnet" = $pingSubnet
    }

    if ($useLeaseDuration -and $leaseDuration) {
        $updateData["custom_$leaseDurationField"] = $leaseDuration
    }
    if ($useSubnetState -and $subnetState) {
        $updateData["custom_$subnetStateField"] = $subnetState
    }

    $updateSubnetUrl = "$apiBase/subnets/$subnetId/"

    try {
        # Create the HTTP request
        $request = [System.Net.HttpWebRequest]::Create($updateSubnetUrl)
        $request.Method = "PATCH"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"

        # Convert data to JSON and send the request
        $jsonData = $updateData | ConvertTo-Json
        Write-Log "Sending PATCH request to update subnet with data: $jsonData" $logToFile
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        $request.ContentLength = $bytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()

        # Get the response
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        Write-Log "Successfully updated subnet ID $subnetId." $logToFile
        return $result
    } catch [System.Net.WebException] {
        Write-Log "Error updating subnet ID ${subnetId}." $logToFile
        Log-ApiError $_ $logToFile
    }
}

# -----------------------------
# Function to check if a subnet exists in phpIPAM
# -----------------------------
function Check-SubnetInPhpIPAM {
    param (
        [string]$subnet,
        [int]$mask,
        [bool]$logToFile = $false
    )

    $searchUrl = "$apiBase/subnets/search/$subnet/$mask"
    try {
        # Create the HTTP request
        $request = [System.Net.HttpWebRequest]::Create($searchUrl)
        $request.Method = "GET"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"

        # Get the response
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        # Convert the result to JSON
        $jsonResult = $result | ConvertFrom-Json
        Write-Log "Subnet ${subnet}/${mask} already exists in phpIPAM." $logToFile
        return $jsonResult.data
    }
    catch [System.Net.WebException] {
        Log-ApiError $_ $logToFile
        return $null
    }
}

# -----------------------------
# Function to process DHCP scopes
# -----------------------------
function Process-DhcpScopes {
    param (
        [bool]$logToFile = $false
    )

    # Retrieve DHCP scopes
    $scopes = Get-DhcpServerv4Scope
    foreach ($scope in $scopes) {
        $subnet = $scope.ScopeId.IPAddressToString
        $mask = Convert-MaskToCIDR -mask $scope.SubnetMask.IPAddressToString  # Convert mask to CIDR
        $name = $scope.Name.Trim()  # Ensure the name is cleaned up
        Write-Log "Retrieved scope: Subnet $subnet, Mask $mask, Name '$name'" $logToFile  # Log the name field
        $leaseDuration = $scope.LeaseDuration
        $subnetState = if ($scope.State -eq 'Active') { "active" } else { "inactive" }


        Write-Log "Processing subnet $subnet with mask $mask and name '$name'" $logToFile

        # Check if the subnet exists in phpIPAM
        $existingSubnet = Check-SubnetInPhpIPAM -subnet $subnet -mask $mask -logToFile $logToFile

        if (-not $existingSubnet) {
            Write-Log "phpIPAM reports that subnet $subnet/$mask does not exist. Attempting to create it." $logToFile
            # If not, create the subnet in phpIPAM
            Create-SubnetInPhpIPAM -subnet $subnet -mask $mask -leaseDuration $leaseDuration -subnetState $subnetState -name $name -logToFile $logToFile
        } else {
            Write-Log "Subnet $subnet/$mask already exists in phpIPAM." $logToFile
            Update-SubnetInPhpIPAM -subnetId $existingSubnet.id -name $name -leaseDuration $leaseDuration -subnetState $subnetState -logToFile $logToFile
        }
    }
}

# Start the process with optional logging
$logToFile = $true  # Set to $false if you don't want to log to a file
Process-DhcpScopes -logToFile $logToFile
