<?php
// Use at Your Own Risk
//
// This software is provided "as is" and without any express or implied warranties. 
// By downloading, installing, or using this software, you acknowledge that you do so entirely at your own risk. 
// The developers and contributors of this software do not assume any responsibility or liability for any damages 
// or losses, including but not limited to system malfunctions, data loss, security breaches, or hardware failures, 
// that may result from its use. You are solely responsible for ensuring that this software is compatible with 
// your system and for taking appropriate precautions, such as backing up important data and testing in a 
// controlled environment, before using it on critical systems.
//
// We take no responsibility for any damage, direct or indirect, that may occur from the use or misuse of this software. 
// By using this software, you agree to indemnify and hold harmless the developers from any claims, damages, 
//  or liabilities arising from its use.
//
//
// PHPIPAM API details
$api_url = "https://yourservernameorip/api/appid/";
$token = "app code token";

// Function to get subnets from PHPIPAM
function get_subnets($api_url, $token) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $api_url . "subnets/");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        'Content-Type: application/json',
        'token: ' . $token
    ));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Ignore SSL verification
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false); // Ignore hostname verification
    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        echo 'Curl error: ' . curl_error($ch) . "\n";
    }
    curl_close($ch);
    echo "API Response: " . $response . "\n"; // Debugging line
    return json_decode($response, true);
}

// Function to add a subnet to PHPIPAM
function add_subnet($api_url, $token, $section_id, $subnet, $mask, $description) {
    $ch = curl_init();
    $data = array(
        'subnet' => $subnet,
        'mask' => $mask,
        'description' => $description,
        'sectionId' => $section_id
    );
    $json_data = json_encode($data);
    curl_setopt($ch, CURLOPT_URL, $api_url . "subnets/");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $json_data);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        'Content-Type: application/json',
        'token: ' . $token
    ));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Ignore SSL verification
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false); // Ignore hostname verification
    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        echo 'Curl error: ' . curl_error($ch) . "\n";
    }
    curl_close($ch);
    echo "Request Data: " . $json_data . "\n"; // Debugging line
    echo "Add Subnet API Response: " . $response . "\n"; // Debugging line
    $response_data = json_decode($response, true);
    if (isset($response_data['code']) && $response_data['code'] != 201) {
        echo "Error adding subnet: " . $response_data['message'] . "\n";
    }
    return $response_data;
}

// Function to check if an IP address exists in PHPIPAM
function ip_exists($api_url, $token, $ip) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $api_url . "addresses/search/" . $ip . "/");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        'Content-Type: application/json',
        'token: ' . $token
    ));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Ignore SSL verification
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false); // Ignore hostname verification
    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        echo 'Curl error: ' . curl_error($ch) . "\n";
    }
    curl_close($ch);
    $response_data = json_decode($response, true);
    if (isset($response_data['data']) && !empty($response_data['data'])) {
        return $response_data['data'][0]; // Assuming the first result is the desired one
    }
    return null;
}

// Function to update PHPIPAM with Nmap results
function update_phpipam($api_url, $token, $ip, $description, $subnetId, $mac = null, $hostname = null, $manufacturer = null) {
    $existing_ip = ip_exists($api_url, $token, $ip);
    $ch = curl_init();
    $data = array(
        'description' => $description,
        'lastSeen' => date('Y-m-d H:i:s') // Add the current timestamp as the last seen time
    );
    if ($mac) {
        $data['mac'] = $mac;
    }
    if ($hostname) {
        $data['hostname'] = $hostname;
    }
    if ($manufacturer) {
        $data['custom_Manufacturer'] = $manufacturer;
    }

    if ($existing_ip && isset($existing_ip['id'])) {
        // Update existing IP address without changing the IP or subnet
        $url = $api_url . "addresses/" . $existing_ip['id'] . "/";
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "PATCH");
    } else {
        // Create new IP address
        $data['ip'] = $ip; // Include IP address only for new entries
        $data['subnetId'] = $subnetId; // Include subnetId only for new entries
        $json_data = json_encode($data);
        $url = $api_url . "addresses/";
        curl_setopt($ch, CURLOPT_POST, 1);
    }

    $json_data = json_encode($data);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $json_data);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        'Content-Type: application/json',
        'token: ' . $token
    ));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Ignore SSL verification
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false); // Ignore hostname verification
    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        echo 'Curl error: ' . curl_error($ch) . "\n";
    }
    curl_close($ch);
    echo "Update Request Data: " . $json_data . "\n"; // Debugging line
    echo "Update API Response: " . $response . "\n"; // Debugging line
    return json_decode($response, true);
}

// Function to run Nmap on a subnet and grab OID info
function scan_subnet($subnet) {
    $command = "nmap -sP --script=snmp-brute " . escapeshellarg($subnet);
    echo "Running command: " . $command . "\n"; // Debugging line
    $output = shell_exec($command . " 2>&1"); // Capture stderr
    if ($output === null) {
        echo "Nmap command failed to execute.\n"; // Debugging line
    } else {
        echo "Nmap Output: " . $output . "\n"; // Debugging line
    }
    return $output;
}

// Function to parse Nmap output and update PHPIPAM
function process_nmap_output($api_url, $token, $output, $subnetId) {
    // Example parsing logic (adjust based on actual Nmap output format)
    $lines = explode("\n", $output);
    $current_ip = null;
    $current_hostname = null;
    $mac_address = null; // Initialize the variable
    $current_manufacturer = null;
    foreach ($lines as $line) {
        if (preg_match('/Nmap scan report for (.+)/', $line, $matches)) {
            $ip_with_hostname = $matches[1];
            // Extract IP address from the string
            if (preg_match('/\(([\d\.]+)\)/', $ip_with_hostname, $ip_matches)) {
                $current_ip = $ip_matches[1];
                $current_hostname = trim(str_replace("($current_ip)", "", $ip_with_hostname));
            } else {
                $current_ip = $ip_with_hostname;
                $current_hostname = null;
            }
            echo "Parsed IP: " . $current_ip . "\n"; // Debugging line
            echo "Parsed Hostname: " . $current_hostname . "\n"; // Debugging line
        } elseif (preg_match('/MAC Address: ([0-9A-Fa-f:]+)/', $line, $matches)) {
            $mac_address = $matches[1];
            echo "Parsed MAC: " . $mac_address . "\n"; // Debugging line
        } elseif (preg_match('/Manufacturer: (.+)/', $line, $matches)) {
            $current_manufacturer = $matches[1];
            echo "Parsed Manufacturer: " . $current_manufacturer . "\n"; // Debugging line
        }
        if ($current_ip && $mac_address) {
            $description = "Scanned by Nmap";
            echo "Updating PHPIPAM with IP: $current_ip, MAC: $mac_address, Hostname: $current_hostname, Manufacturer: $current_manufacturer\n"; // Debugging line
            update_phpipam($api_url, $token, $current_ip, $description, $subnetId, $mac_address, $current_hostname, $current_manufacturer);
            $current_ip = null; // Reset current IP after updating
            $current_hostname = null; // Reset current hostname after updating
            $mac_address = null; // Reset current MAC after updating
            $current_manufacturer = null; // Reset current manufacturer after updating
        }
    }
}

// Function to retrieve the subnet ID by subnet and mask
function get_subnet_id($api_url, $token, $subnet, $mask) {
    $subnets = get_subnets($api_url, $token);
    if (is_null($subnets) || !isset($subnets['data'])) {
        echo "Failed to retrieve subnets or no data found.\n";
        return null;
    }
    foreach ($subnets['data'] as $subnet_data) {
        if ($subnet_data['subnet'] == $subnet && $subnet_data['mask'] == $mask) {
            return $subnet_data['id'];
        }
    }
    return null;
}

// Main function
function main($scan_existing = true) {
    global $api_url, $token;
    $section_id = "3"; // Replace with your actual section ID
    $new_subnets = array(
        array('subnet' => '192.168.1.0', 'mask' => '24', 'description' => 'New Subnet 1'),
        array('subnet' => '192.168.3.0', 'mask' => '24', 'description' => 'New Subnet 2')
    );

    // Add new subnets to PHPIPAM and scan them
    foreach ($new_subnets as $subnet) {
        $response = add_subnet($api_url, $token, $section_id, $subnet['subnet'], $subnet['mask'], $subnet['description']);
        if ($response['code'] == 409) {
            echo "Subnet already exists: " . $subnet['subnet'] . "\n";
        } elseif ($response['code'] == 201) {
            echo "Subnet added successfully: " . $subnet['subnet'] . "\n";
        } else {
            echo "Error adding subnet: " . print_r($response, true) . "\n";
        }
        // Scan the subnet regardless of whether it was newly added or already exists
        $subnet_cidr = $subnet['subnet'] . '/' . $subnet['mask'];
        echo "Scanning subnet: " . $subnet_cidr . "\n";
        $scan_result = scan_subnet($subnet_cidr);
        // Retrieve the correct subnet ID from the response
        $subnetId = get_subnet_id($api_url, $token, $subnet['subnet'], $subnet['mask']);
        echo "Retrieved Subnet ID: " . $subnetId . "\n"; // Debugging line
        if ($subnetId) {
            process_nmap_output($api_url, $token, $scan_result, $subnetId);
        } else {
            echo "Failed to retrieve subnet ID for: " . $subnet['subnet'] . "\n";
        }
    }

    // Get and scan existing subnets if the switch is enabled
    if ($scan_existing) {
        $subnets = get_subnets($api_url, $token);
        if (is_null($subnets) || !isset($subnets['data'])) {
            echo "Failed to retrieve subnets or no data found.\n";
            return;
        }
        foreach ($subnets['data'] as $subnet) {
            $subnet_cidr = $subnet['subnet'] . '/' . $subnet['mask'];
            echo "Scanning subnet: " . $subnet_cidr . "\n";
            $scan_result = scan_subnet($subnet_cidr);
            process_nmap_output($api_url, $token, $scan_result, $subnet['id']);
        }
    }
}

// Call main function with the switch to scan existing subnets
main(false);
?>
