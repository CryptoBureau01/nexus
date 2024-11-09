# Nexus
Nexus-Node With CryptoBureau

# System Requirements
 
| **Hardware** | **Minimum Requirement** |
|--------------|-------------------------|
| **CPU**      | 4 Cores                 |
| **RAM**      | 2 GB                    |
| **Disk**     | 1 GB                    |
| **Bandwidth**| 10 MBit/s               |


_____________________________________________________________________________________________________________

**Follow our TG : https://t.me/CryptoBureau01**

## Tool Installation Command

To install the necessary tools for managing your Nexus node, run the following command in your terminal:



```bash

cd $HOME && wget https://raw.githubusercontent.com/CryptoBureau01/nexus/main/nexus.sh && chmod +x nexus.sh && ./nexus.sh
```

_____________________________________________________________________________________________________________

# Nexus Node Setup and Management Script

This script automates the setup, installation, and management of a Nexus node environment on an Ubuntu system. Below are the key features and steps included in the script:

### Features

1. **Logo Display**: Displays the CryptoBuro logo at the start of the script.
2. **System Check**: Validates if the system is running on Ubuntu and if the user has root privileges. If not, it prompts for root access.
3. **Dependency Installation**: Installs necessary packages and dependencies, including `curl`, `git`, `rust`, and other essential tools.
4. **Nexus Node Setup**: Installs and sets up the Nexus Prover by:
   - Creating the required directory structure.
   - Installing the Nexus CLI.
   - Configuring a `systemd` service for easy management of the Nexus Prover.
5. **Nexus Network API Update**: Fetches the latest release tag from the Nexus repository, updates to the latest version, and builds the Nexus Network API.
6. **Nexus ZKVM Setup**: Sets up the Nexus ZKVM environment and installs `nexus-tools`. Creates a sample Rust program (`fib`) for testing purposes.
7. **Nexus Program Management**: Runs, proves, and verifies Nexus programs, and manages Nexus node services.
8. **Logs Checker**: Checks logs for the Nexus node, restarts the service if necessary, and provides the latest logs for troubleshooting.
9. **Node Restart**: Provides a simple restart function for the Nexus node.

### Menu Options

The script includes a main menu for easy navigation:

- **1. Install-Dependency**: Installs required system packages and Rust environment.
- **2. Setup-Nexus**: Sets up the Nexus Prover and configures it as a service.
- **3. Node-Run**: Manages Nexus program (run, prove, and verify sequence).
- **4. Logs-Checker**: Starts Nexus service if not running and displays recent logs.
- **5. Refresh-Node**: Restarts the Nexus service.
- **6. Exit**: Exits the script.

### Usage

Run the script with root privileges on an Ubuntu system. Follow the on-screen menu to install dependencies, set up the Nexus node, manage it, or check logs as needed.


_____________________________________________________________________________________________________________


# Conclusion
This Auto Script for Node Management on the Nexus has been created by CryptoBuroMaster. It is a comprehensive solution designed to simplify and enhance the node management experience. By providing a clear and organized interface, it allows users to efficiently manage their nodes with ease. Whether you are a newcomer or an experienced user, this script empowers you to handle node operations seamlessly, ensuring that you can focus on what truly matters in your blockchain journey.


**Join our TG : https://t.me/CryptoBureau01**
