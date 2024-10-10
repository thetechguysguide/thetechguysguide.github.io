# -----------------------------
# Legal Disclaimer:
# -----------------------------
# This script is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. 
# The author of this script assumes no liability for any damage or data loss caused by the use of this script, directly or indirectly. 
# It is the user's responsibility to thoroughly review, test, and modify this script before deploying it in a production environment.
# This script is intended for educational and informational purposes only. Use it at your own risk and discretion.

# -----------------------------
# Purpose of This Script:
# -----------------------------
# The primary purpose of this script is to integrate Microsoft Windows DHCP server leases with the phpIPAM IP Address Management (IPAM) system. 
# The script retrieves all DHCP leases from a Windows DHCP server and then updates phpIPAM with the IP addresses, ensuring that the phpIPAM database reflects the current state of the DHCP server.
# Optionally updates custom fields in phpIPAM, such as lease duration or device status. Ensure the necessary custom fields are defined in phpIPAM for proper functionality.

# Functionality Summary:
# 1. Retrieves all DHCP leasses contain in the scopes from the Windows DHCP server.
# 2. Updates phpIPAM with the ip information.
#		-   The script can be set up to run manually or scheduled to run automatically as a Windows Task Scheduler job 
#			on the DHCP server itself or another machine with network access to the DHCP server.
# 3. Optionally logs all operations to a file for auditing and troubleshooting purposes.
# 4. Optionally performs host checks (ping) before adding IPs to phpIPAM.

# -----------------------------
# Configuration Instructions:
# -----------------------------
# Required Items for Script to Work:
# 1. phpIPAM API Base URL, Section ID, and API Token.
# 2. The PowerShell script should be run on a machine that has access to a Windows DHCP server and the script needs Admin rights
# 3. Timeout Configuration: The script enforces a 5-second timeout for phpIPAM API requests. If a response is not received within this period, the request is considered failed, and the script will log the error and continue.
#     - This is under "Function to check if an IP address exists in phpIPAM"
# 4. Logging Configuration: The script supports logging to a file for auditing and troubleshooting. Set $logToFile = $true to enable file logging. Note that 
#       enabling logging may impact performance, especially when processing a large number of leases. Consider disabling logging in production for optimal performance.

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
$apiBase = "https://yourservernameorip/api/appcode"
$token = "yourtokengoeshere"
$sectionId = YourSection#

# Optional feature flags
$descriptionPrefix = "Imported from WIN DHCP"  # Set a description prefix for IP and subnet entries in phpIPAM.
$useFullHostname = $false  # Set to $false to use truncated hostname (part before the first dot)
$checkHost = $false  # Host Check (Ping): The script includes an optional feature to perform a ping check before adding each IP to phpIPAM. 
                        # Enabling this feature ($checkHost = $true) will verify whether the IP is reachable before proceeding. Be aware that 
                        # enabling this option can significantly increase the overall processing time, especially for large numbers of leases, 
                        # as each IP is pinged individually.

# Logging configuration
$logToFile = $false  # Enable or disable logging to a file (set to $true for logging)

# Disable SSL certificate validation (only if necessary for self-signed certificates)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Enforce TLS 1.2 for secure communications with the phpIPAM API.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -----------------------------
# Log function: Writes to console and optionally to a log file, additional logging
# Important Note on Logging: Enabling logging to a file ($logToFile = $true) can significantly increase the amount of disk I/O, especially if the 
#    script processes many DHCP leases. It is recommended to enable logging only for debugging or auditing purposes, and disable it in production 
#    environments to improve performance.
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

# Function to check if an IP address exists in phpIPAM
function Get-IPAddressFromPhpIPAM {
    param (
        [string]$ipAddress,
        [bool]$logToFile = $false
    )

    Write-Log "Checking if IP $ipAddress exists in phpIPAM..." $logToFile

    $getIpUrl = "$apiBase/addresses/search/$ipAddress/"
    try {
        $request = [System.Net.HttpWebRequest]::Create($getIpUrl)
        $request.Method = "GET"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"
        $request.ProtocolVersion = [System.Net.HttpVersion]::Version11
        $request.Timeout = 5000  # Timeout in milliseconds (5 seconds)

        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        $parsedJson = $result | ConvertFrom-Json

        if ($parsedJson.data) {
            Write-Log "IP $ipAddress found in phpIPAM." $logToFile
            return $parsedJson.data  # Return IP address details
        } else {
            Write-Log "IP $ipAddress not found in phpIPAM." $logToFile
            return $null
        }
    } catch [System.Net.WebException] {
        # Handle 404 errors (IP not found in phpIPAM)
        if ($_.Response -and $_.Response.StatusCode -eq 404) {
            Write-Log "IP $ipAddress not found in phpIPAM. Proceeding to add it." $logToFile
        } else {
            # Handle other errors
            Write-Log "Error checking IP $ipAddress in phpIPAM: $_" $logToFile
        }
        return $null
    }
}

# Function to retrieve all subnets from phpIPAM
function Get-AllSubnetsFromPhpIPAM {
    param (
        [bool]$logToFile = $false
    )

    Write-Log "Retrieving all subnets from phpIPAM..." $logToFile

    $getSubnetsUrl = "$apiBase/sections/$sectionId/subnets/"
    try {
        $request = [System.Net.HttpWebRequest]::Create($getSubnetsUrl)
        $request.Method = "GET"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"
        $request.ProtocolVersion = [System.Net.HttpVersion]::Version11

        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        # Manually parse JSON to handle duplicate keys
        $parsedJson = Parse-JsonHandlingDuplicates $result

        # Log all retrieved subnets for debugging purposes
        foreach ($subnet in $parsedJson.data) {
            Write-Log "Retrieved Subnet: $($subnet.subnet)/$($subnet.mask), Subnet ID: $($subnet.id)" $logToFile
        }

        Write-Log "Successfully retrieved all subnets from phpIPAM." $logToFile
        return $parsedJson.data
    } catch {
        Write-Log "Error retrieving subnets from phpIPAM: $_" $logToFile
        return $null
    }
}

# Function to parse JSON with duplicate key handling
function Parse-JsonHandlingDuplicates {
    param (
        [string]$jsonString
    )

    try {
        # Handle the "Used" and "used" issue manually
        $jsonString = $jsonString -replace '"Used":', '"UsedDuplicate":'  # Rename the duplicated key

        # Safely convert the JSON
        $jsonData = $jsonString | ConvertFrom-Json
        return $jsonData
    } catch {
        Write-Log "Error parsing JSON: $_"
        return $null
    }
}

# Function to add IP address to phpIPAM using the correct JSON payload format
function Add-IPToPhpIPAM {
    param (
        [string]$ipAddress,
        [string]$hostname,
        [string]$macAddress,
        [int]$subnetId,
        [bool]$logToFile = $false
    )

    # Convert MAC address to colon-separated format (phpIPAM typically uses this format)
    $macAddress = $macAddress -replace '-', ':'

    Write-Log "Adding IP $ipAddress to subnet $subnetId in phpIPAM..." $logToFile
    try {
        $ipData = @{
            "ip" = $ipAddress
            "subnetId" = $subnetId
            "hostname" = $hostname
            "mac" = $macAddress
            "description" = "$descriptionPrefix - $hostname"  # Use the description prefix from the variable
        }

        Write-Log "Payload to be sent: $(ConvertTo-Json $ipData -Depth 3)" $logToFile

        $addIpUrl = "$apiBase/addresses/"
        $request = [System.Net.HttpWebRequest]::Create($addIpUrl)
        $request.Method = "POST"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"
        $request.ProtocolVersion = [System.Net.HttpVersion]::Version11

        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($ipData | ConvertTo-Json))
        $request.ContentLength = $bytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()

        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $result = $reader.ReadToEnd()

        Write-Log "Successfully added IP $ipAddress to phpIPAM." $logToFile
        return $result
    } catch {
        Write-Log "Error adding IP $ipAddress to phpIPAM: $_" $logToFile
        if ($_.Exception.Response) {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorResult = $reader.ReadToEnd()
            Write-Log "Detailed response: $errorResult" $logToFile
        }
    }
}

# Function to calculate the range (start and end IPs) of a subnet
function Get-SubnetRange {
    param (
        [string]$subnetAddress,
        [int]$mask
    )

    # Ensure the subnet address is valid
    if ([string]::IsNullOrEmpty($subnetAddress)) {
        Write-Log "Subnet address is null or empty. Skipping subnet."
        return $null
    }

    try {
        Write-Log "Calculating range for subnet $subnetAddress/$mask"

        # Convert subnet address to IP bytes
        $subnetIpBytes = [System.Net.IPAddress]::Parse($subnetAddress).GetAddressBytes()
        [Array]::Reverse($subnetIpBytes)  # Ensure proper byte order
        $subnetIpInt = [BitConverter]::ToUInt32($subnetIpBytes, 0)

        # Calculate the number of host bits (usable IPs in the subnet)
        $hostBits = 32 - $mask
        $hostCount = [Math]::Pow(2, $hostBits) - 1

        # Calculate the first usable IP and the last usable IP
        $startIpInt = $subnetIpInt + 1
        $endIpInt = $subnetIpInt + $hostCount - 1

        # Convert back to IP addresses
        $startIpBytes = [BitConverter]::GetBytes([uint32]$startIpInt)
        [Array]::Reverse($startIpBytes)
        $startIp = [System.Net.IPAddress]::new($startIpBytes)

        $endIpBytes = [BitConverter]::GetBytes([uint32]$endIpInt)
        [Array]::Reverse($endIpBytes)
        $endIp = [System.Net.IPAddress]::new($endIpBytes)

        Write-Log "Calculated range for Subnet ${subnetAddress}/${mask}: Start IP: ${startIp}, End IP: ${endIp}"

        return @{
            "StartIp" = $startIp.ToString()
            "EndIp"   = $endIp.ToString()
        }
    } catch {
        Write-Log "Error calculating range for Subnet ${subnetAddress}/${mask}: $_"
        return $null
    }
}

# Function to match an IP address to a subnet by checking if it falls within the range
function Match-SubnetForIP {
    param (
        [string]$ipAddress,
        [array]$subnets,  # List of all subnets from phpIPAM
        [bool]$logToFile = $false
    )

    Write-Log "Attempting to match IP $ipAddress to a subnet..." $logToFile

    foreach ($subnet in $subnets) {
        $subnetAddress = [System.Net.IPAddress]::Parse($subnet.subnet).IPAddressToString()
        $mask = $subnet.mask

        # Calculate the range for the subnet
        $subnetRange = Get-SubnetRange -subnetAddress $subnetAddress -mask $mask

        # Log subnet range for debugging
        Write-Log "Subnet: $subnetAddress/$mask, Start: $($subnetRange.StartIp), End: $($subnetRange.EndIp), Subnet ID: $($subnet.id)" $logToFile

        # Check if the IP falls within the range of this subnet
        if (Is-IPInRange -ipAddress $ipAddress -subnetStart $subnetRange.StartIp -subnetEnd $subnetRange.EndIp) {
            Write-Log "Matched IP $ipAddress to subnet ID $($subnet.id)" $logToFile
            return $subnet.id
        }
    }

    Write-Log "No matching subnet found for IP $ipAddress in phpIPAM." $logToFile
    return $null
}

# Function to check if an IP is within a given subnet range
function Is-IPInRange {
    param (
        [string]$ipAddress,
        [string]$subnetStart,
        [string]$subnetEnd
    )

    # Convert IP, start, and end addresses to integers for comparison
    $ipBytes = [System.Net.IPAddress]::Parse($ipAddress).GetAddressBytes()
    [Array]::Reverse($ipBytes)
    $ipInt = [BitConverter]::ToUInt32($ipBytes, 0)

    $startIpBytes = [System.Net.IPAddress]::Parse($subnetStart).GetAddressBytes()
    [Array]::Reverse($startIpBytes)
    $startIpInt = [BitConverter]::ToUInt32($startIpBytes, 0)

    $endIpBytes = [System.Net.IPAddress]::Parse($subnetEnd).GetAddressBytes()
    [Array]::Reverse($endIpBytes)
    $endIpInt = [BitConverter]::ToUInt32($endIpBytes, 0)

    Write-Log "Comparing IP: $ipAddress with Start: $subnetStart and End: $subnetEnd"

    if ($ipInt -ge $startIpInt -and $ipInt -le $endIpInt) {
        Write-Log "IP $ipAddress falls within the range $subnetStart to $subnetEnd"
        return $true
    } else {
        Write-Log "IP $ipAddress is outside the range $subnetStart to $subnetEnd"
        return $false
    }
}

# Function to delete an IP address from phpIPAM
function Remove-IPFromPhpIPAM {
    param (
        [string]$ipId,  # Use the IP entry's ID instead of the IP address itself for deletion
        [bool]$logToFile = $false
    )

    Write-Log "Deleting IP entry with ID $ipId from phpIPAM..." $logToFile

    $deleteIpUrl = "$apiBase/addresses/$ipId/"
    try {
        $request = [System.Net.HttpWebRequest]::Create($deleteIpUrl)
        $request.Method = "DELETE"
        $request.Headers.Add("token", $token)
        $request.ContentType = "application/json"
        $request.ProtocolVersion = [System.Net.HttpVersion]::Version11

        $response = $request.GetResponse()
        Write-Log "Successfully deleted IP entry with ID $ipId from phpIPAM." $logToFile
    } catch {
        Write-Log "Error deleting IP entry with ID $ipId from phpIPAM: $_" $logToFile
    }
}

# Function to process DHCP leases and find the correct subnet in phpIPAM
function Process-DhcpLeases {
    param (
        [bool]$logToFile = $false
    )

    # Retrieve all subnets from phpIPAM
    $subnets = Get-AllSubnetsFromPhpIPAM -logToFile $logToFile

    if (-not $subnets) {
        Write-Log "No subnets retrieved from phpIPAM. Exiting..." $logToFile
        return
    }

    # Retrieve all DHCP scopes
    $scopes = Get-DhcpServerv4Scope

    foreach ($scope in $scopes) {
        $scopeId = $scope.ScopeId.IPAddressToString
        Write-Log "Processing leases for scope: $scopeId" $logToFile

        # Retrieve all leases for the current scope
        $leases = Get-DhcpServerv4Lease -ScopeId $scope.ScopeId

        foreach ($lease in $leases) {
            $ipAddress = $lease.IPAddress.IPAddressToString

            # Decide whether to use full hostname or truncated hostname
            $hostname = if ($useFullHostname) {
                $lease.HostName  # Full hostname
            } else {
                ($lease.HostName -split '\.')[0]  # Truncated hostname (before the first dot)
            }

            $macAddress = $lease.ClientId -replace '-', ':'  # Convert MAC to colon-separated format
            $state = $lease.AddressState  # Can be Active, Expired, etc.

            Write-Log "Processing Lease: IP: $ipAddress, Hostname: $hostname, MAC: $macAddress, State: $state" $logToFile

            # Only process active leases
            if ($state -ne 'Active') {
                Write-Log "Skipping IP $ipAddress because it is not active." $logToFile
                continue
            }

            # Optionally perform a ping (host check) before proceeding
            if ($checkHost) {
                Write-Log "Pinging IP $ipAddress to check if it's alive..." $logToFile
                $pingResult = Test-Connection -ComputerName $ipAddress -Count 1 -Quiet
                if (-not $pingResult) {
                    Write-Log "IP $ipAddress is not responding to ping. Skipping." $logToFile
                    continue
                } else {
                    Write-Log "IP $ipAddress responded to ping." $logToFile
                }
            }

            # Find the correct subnet ID from phpIPAM for this scope
            $matchingSubnet = $null
            foreach ($subnet in $subnets) {
                $subnetRange = Get-SubnetRange -subnetAddress $subnet.subnet -mask $subnet.mask
                if (Is-IPInRange -ipAddress $ipAddress -subnetStart $subnetRange.StartIp -subnetEnd $subnetRange.EndIp) {
                    $matchingSubnet = $subnet
                    Write-Log "Matched IP $ipAddress to subnet ID $($subnet.id)" $logToFile
                    break
                }
            }

            if (-not $matchingSubnet) {
                Write-Log "No matching subnet found for IP $ipAddress in phpIPAM. Skipping." $logToFile
                continue
            }

            # Check if IP already exists in phpIPAM
            $existingIpDetails = Get-IPAddressFromPhpIPAM -ipAddress $ipAddress -logToFile $logToFile

            if ($existingIpDetails) {
                # Normalize the MAC address from phpIPAM to colon-separated format
                $oldMacAddress = $existingIpDetails.mac -replace '-', ':'

                # Compare MAC addresses
                if ($oldMacAddress -ne $macAddress) {
                    Write-Log "MAC address mismatch for IP $ipAddress. Old MAC: $oldMacAddress, New MAC: $macAddress" $logToFile

                    # Delete old entry
                    Remove-IPFromPhpIPAM -ipId $existingIpDetails.id -logToFile $logToFile
                } else {
                    Write-Log "IP $ipAddress with matching MAC address already exists in phpIPAM. Skipping addition." $logToFile
                    continue
                }
            } else {
                Write-Log "phpIPAM response: IP $ipAddress does not exist. Proceeding to add it." $logToFile
            }

            # Add IP to phpIPAM using the correct subnet ID
            Add-IPToPhpIPAM -ipAddress $ipAddress -hostname $hostname -macAddress $macAddress -subnetId $matchingSubnet.id -logToFile $logToFile
        }
    }
}

# Main entry point
Process-DhcpLeases -logToFile $logToFile