# !/bin/bash

curl -s https://raw.githubusercontent.com/CryptoBureau01/logo/main/logo.sh | bash
sleep 5

# Function to print info messages
print_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

# Function to print error messages
print_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
}



#Function to check system type and root privileges
master_fun() {
    echo "Checking system requirements..."

    # Check if the system is Ubuntu
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            echo "This script is designed for Ubuntu. Exiting."
            exit 1
        fi
    else
        echo "Cannot detect operating system. Exiting."
        exit 1
    fi

    # Check if the user is root
    if [ "$EUID" -ne 0 ]; then
        echo "You are not running as root. Please enter root password to proceed."
        sudo -k  # Force the user to enter password
        if sudo true; then
            echo "Switched to root user."
        else
            echo "Failed to gain root privileges. Exiting."
            exit 1
        fi
    else
        echo "You are running as root."
    fi

    echo "System check passed. Proceeding to package installation..."
    
}


# Function to dependency install the Nexus node
install_dependency() {
    echo "Updating packages..."
    sudo apt update && sudo apt upgrade -y

    echo "Installing necessary packages..."
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip cmake -y

    # Download and execute the Rust installation script
    if curl -s https://raw.githubusercontent.com/CryptoBureau01/packages/main/rust.sh | bash; then
        echo "Rust installation script executed successfully."
    else
        echo "Error: Failed to run the Rust installation script. Please check the link or your network connection."
        exit 1
    fi

    # Display Rust version
    if command -v rustc &> /dev/null; then
        echo "Rust version installed:"
        rustc --version
    else
        echo "Rust installation failed. Please verify manually."
        exit 1
    fi

    # Redirect back to the main menu
    echo "Navigating to main menu..."
    master
}


# Function to file setup the Nexus node
nexus_setup() {
    echo "<===== Installing Nexus Prover =====>"

    # Ensure Rust and Cargo are installed
    if ! command -v rustc &> /dev/null; then
        echo "Rust is not installed. Installing Rust..."
        curl -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi

    NEXUS_HOME=$HOME/.nexus

    # Check for git installation
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Please install Git and try again."
        exit 1
    fi

    # Clone or update Nexus network API repository
    if [ -d "$NEXUS_HOME/network-api" ]; then
        echo "$NEXUS_HOME/network-api already exists. Updating..."
        (cd $NEXUS_HOME/network-api && git pull)
    else
        mkdir -p $NEXUS_HOME
        (cd $NEXUS_HOME && git clone https://github.com/nexus-xyz/network-api)
    fi


    # Set ownership for Nexus files
    echo "Setting file ownership for Nexus..."
    sudo chown -R root:root /root/.nexus

    sed -i 's|rustc|/root/.cargo/bin/rustc|g' nexus.sh
    sed -i 's|cargo|/root/.cargo/bin/cargo|g' nexus.sh

    sed -i '5i NONINTERACTIVE=1' nexus.sh

    # Define systemd service file path
    SERVICE_FILE="/etc/systemd/system/nexus.service"
    
    # Create systemd service file if it doesn't exist
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Creating systemd service file for Nexus..."
        sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Nexus Process
After=network.target

[Service]
ExecStart=/root/nexus.sh  # <==== make sure to change this file location to match where you put the file
Restart=on-failure
RestartSec=5
RestartPreventExitStatus=127
SuccessExitStatus=127
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    else
        echo "Service file already exists. Skipping creation."
    fi

    # Reload systemd daemon, enable, and start Nexus service
    echo "Reloading systemd daemon and enabling Nexus service..."
    sudo systemctl daemon-reload
    sudo systemctl enable nexus.service
    sudo systemctl start nexus.service

    echo "Nexus Prover service setup and started successfully!"

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}



# Function to update Nexus Network API to the latest version
nexus_api() {
    echo "Checking for updates in Nexus Network API..."

    # Ensure the Nexus directory exists
    NEXUS_DIR="$HOME/.nexus/network-api"
    if [ -d "$NEXUS_DIR" ]; then
        cd "$NEXUS_DIR" || { echo "Failed to navigate to Nexus Network API directory."; return 1; }
    else
        echo "Error: Nexus Network API directory not found."
        return 1
    fi

    # Fetch all updates from the repository
    git fetch --all --tags || { echo "Failed to fetch updates. Please check your network connection."; return 1; }

    # Get the latest release tag
    LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))

    if [ -z "$LATEST_TAG" ]; then
        echo "Error: No tags found in the repository. Update cannot proceed."
        return 1
    fi

    # Checkout the latest version
    git checkout "$LATEST_TAG" || { echo "Failed to checkout to the latest tag ($LATEST_TAG)."; return 1; }

    # Navigate to the cli directory where Cargo.toml is located
    cd clients/cli || { echo "Error: clients/cli directory not found."; return 1; }

    # Verify that Cargo.toml exists
    if [ ! -f Cargo.toml ]; then
        echo "Error: Cargo.toml not found in the Nexus Network API directory."
        return 1
    fi

    # Check if the project has already been built
    if [ -d target/release ]; then
        echo "Nexus Network API has already been built. Skipping build step."
    else
        # Clean and rebuild the project with the latest version
        cargo clean
        cargo build --release || { echo "Build failed. Please check the error logs."; return 1; }
        echo "Nexus Network API built successfully."
    fi

    echo "Nexus Network API updated to the latest version ($LATEST_TAG)."

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}



# Function to zkvm the Nexus node
nexus_zkvm() {
    PROJECT_DIR="$HOME/.nexus/nexus-project"  # Define the full path to the project directory

    # Check if the Nexus ZKVM project already exists
    if [ -d "$PROJECT_DIR" ]; then
        echo "Nexus ZKVM project already exists."
        # Go back to main menu
        echo "Navigating to main menu..."
        master
        return 1
    fi

    echo "Setting up Nexus ZKVM environment..."

    # Add the target for RISC-V architecture
    if rustup target add riscv32i-unknown-none-elf; then
        echo "Target riscv32i-unknown-none-elf added successfully."
    else
        echo "Failed to add target riscv32i-unknown-none-elf. Please ensure Rust is installed correctly."
        return 1
    fi

    # Install Nexus tools from the Nexus repository
    if cargo install --git https://github.com/nexus-xyz/nexus-zkvm cargo-nexus --tag 'v0.2.3'; then
        echo "Nexus tools installed successfully."
    else
        echo "Failed to install Nexus tools. Please check your network connection or repository URL."
        return 1
    fi

    # Create Nexus ZKVM project
    if cargo nexus new "$PROJECT_DIR"; then
        echo "Nexus ZKVM project created successfully."
    else
        echo "Failed to create Nexus ZKVM project."
        return 1
    fi

    # Navigate to the project src directory
    cd "$PROJECT_DIR/src" || { echo "Failed to navigate to project src directory."; return 1; }

    # Remove the default main.rs if it exists
    rm -f main.rs

    # Write the sample program to main.rs
    {
        echo '#![no_std]'
        echo '#![no_main]'
        echo ''
        echo 'fn fib(n: u32) -> u32 {'
        echo '    match n {'
        echo '        0 => 0,'
        echo '        1 => 1,'
        echo '        _ => fib(n - 1) + fib(n - 2),'
        echo '    }'
        echo '}'
        echo ''
        echo '#[nexus_rt::main]'
        echo 'fn main() {'
        echo '    let n = 7;'
        echo '    let result = fib(n);'
        echo '    assert_eq!(result, 13);'
        echo '}'
    } > main.rs

    # Return to the project root directory
    cd .. || { echo "Failed to return to project root directory."; return 1; }
    echo "Nexus ZKVM environment setup completed successfully."

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}



# Function to run and setup the Nexus node
nexus_run() {
    echo "Starting Nexus program, proof, and verification sequence..."

    # Run the Nexus program
    echo "Running Nexus program..."
    cargo nexus run || { echo "Failed to run Nexus program."; return 1; }

    # Prove the Nexus program
    echo "Proving your program..."
    cargo nexus prove || { echo "Failed to prove Nexus program."; return 1; }

    # Verify the proof
    echo "Verifying your proof..."
    cargo nexus verify || { echo "Failed to verify Nexus proof."; return 1; }

    # Fix unused import warning
    echo "Fixing unused import warnings..."
    sed -i 's/^use std::env;/\/\/ use std::env;/' /root/.nexus/network-api/clients/cli/src/prover.rs || { echo "Failed to fix unused import warning."; return 1; }

    # Start, enable, and reload up the Nexus service
    echo "Stopping and cleaning up Nexus service..."
    sudo systemctl daemon-reload
    sudo systemctl enable nexus.service
    sudo systemctl start nexus.service

    echo "Nexus Run successfully."

    # Redirect back to the main menu
    echo "Navigating to main menu..."
    master
}



# Function to service status the Nexus node
check_service_status() {
    echo "<===== Checking Nexus Service Status =====>"
    sudo systemctl status nexus.service

    # Check if the service is active
    if systemctl is-active --quiet nexus.service; then
        echo "Nexus service is running."
    else
        echo "Nexus service is not running."
    fi

    # Redirect back to the main menu
    echo "Navigating to main menu..."
    master
}




# Function to logs the Nexus node
logs() {
    if ! systemctl is-active --quiet nexus.service; then
        echo "Nexus service is not running. Attempting to start..."
        sudo systemctl start nexus.service
    fi

    # Re-check service status after attempting to start
    if systemctl is-active --quiet nexus.service; then
       echo "Nexus service started successfully."
       # Show the last 100 lines of logs and continue to follow new logs
       journalctl -u nexus.service -n 50 -f
    else
       echo "Failed to start Nexus service. Checking logs..."
       # Show the last 100 lines of logs without pagination
       sudo journalctl -u nexus.service -n 50 --no-pager
    fi

    # Redirect back to the main menu
    echo "Navigating to main menu..."
    master
}


# Function to restart the Nexus node
restart_nexus_node() {
    echo "Restarting Nexus node..."

    # Stop the Nexus service
    if systemctl is-active --quiet nexus.service; then
        echo "Stopping Nexus service..."
        sudo systemctl stop nexus.service
    else
        echo "Nexus service is not running."
    fi

    # Wait a few seconds to ensure service stops completely
    sleep 3

    # Start the Nexus service again
    echo "Starting Nexus service..."
    sudo systemctl start nexus.service

    # Verify the Nexus service is running
    if systemctl is-active --quiet nexus.service; then
        echo "Nexus node restarted successfully!"
    else
        echo "Failed to restart Nexus node. Checking logs for details..."
        sudo journalctl -u nexus.service -n 50 --no-pager
    fi

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}



# Function to check and display the Prover ID
check_prover_id() {
    PROVER_ID_FILE="$HOME/.nexus/prover-id"

    # Check if the prover-id file exists
    if [ ! -f "$PROVER_ID_FILE" ]; then
        echo "Error: Prover-ID file not found at $PROVER_ID_FILE."
        return 1
    fi

    # Read the Prover ID from the file
    PROVER_ID=$(cat "$PROVER_ID_FILE")

    # Print the Prover ID
    echo "Your Prover-ID: $PROVER_ID"

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}



# Function to display menu and prompt user for input
master() {
    print_info "==============================="
    print_info "    Nexus Node Tool Menu    "
    print_info "==============================="
    print_info ""
    print_info "1. Install-Dependency"
    print_info "2. Nexus-Service-Setup"
    print_info "3. Nexus-API-Setup"
    print_info "4. Nexus-ZKVM-Setup"
    print_info "5. Nexus-Node-Run"
    print_info "6. Service-Check"
    print_info "7. Logs-Checker"
    print_info "8. Refresh-Node"
    print_info "9. Prover-ID-Checker"
    print_info "10. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CB-Master "
    print_info "==============================="
    print_info ""
    
    read -p "Enter your choice (1 or 10): " user_choice

    case $user_choice in
        1)
            install_dependency
            ;;
        2)
            nexus_setup
            ;;
        3) 
            nexus_api
            ;;
        4)
            nexus_zkvm
            ;;
        5)
            nexus_run
            ;;
        6) 
            check_service_status
            ;;
        7)
            logs
            ;;
        8)  
            restart_nexus_node
            ;;
        9)
            check_prover_id
            ;;
       10)
            exit 0  # Exit the script after breaking the loop
            ;;
        *)
            print_error "Invalid choice. Please enter 1 or 10 : "
            ;;
    esac
}

# Call the uni_menu function to display the menu
master_fun
master
