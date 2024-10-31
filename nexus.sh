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

    #Go to Menu
    master
}



nexus_setup() {
    echo "<===== Installing Nexus Prover =====>"

    # Ensure Rust and Cargo are installed
    if ! command -v rustc &> /dev/null; then
        echo "Rust is not installed. Installing Rust..."
        curl -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi

    NEXUS_HOME=$HOME/.nexus

    # Set non-interactive mode for Nexus Terms of Use agreement
    echo "Y" | NONINTERACTIVE=1

    # Check for git installation
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Please install Git and try again."
        exit 1
    fi

    # Clone or update Nexus network API repository
    if [ -d "$NEXUS_HOME/network-api" ]; then
        echo "$NEXUS_HOME/network-api exists. Updating..."
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

    # Update Nexus Network API to latest version
    echo "Updating Nexus Network API..."
    update_nexus_api

    # Set up Nexus ZKVM environment
    echo "Setting up Nexus ZKVM environment..."
    setup_nexus_zkvm

    # Go back to main menu
    echo "Navigating to main menu..."
    master
}






# Function to update Nexus Network API to the latest version
update_nexus_api() {
    echo "Checking for updates in Nexus Network API..."
    
    # Ensure the Nexus directory exists
    if [ -d ~/.nexus/network-api ]; then
        cd ~/.nexus/network-api
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
    git checkout $LATEST_TAG || { echo "Failed to checkout to the latest tag ($LATEST_TAG)."; return 1; }

    # Clean and rebuild the project with the latest version
    cargo clean
    cargo build --release || { echo "Build failed. Please check the error logs."; return 1; }

    echo "Nexus Network API updated to the latest version ($LATEST_TAG)."
}



setup_nexus_zkvm() {
    echo "Setting up Nexus ZKVM environment..."

    # Add the target for RISC-V
    if rustup target add riscv32i-unknown-none-elf; then
        echo "Target riscv32i-unknown-none-elf added successfully."
    else
        echo "Failed to add target riscv32i-unknown-none-elf."
        return 1
    fi

    # Install nexus-tools from the Nexus repository
    if cargo install --git https://github.com/nexus-xyz/nexus-zkvm nexus-tools --tag 'v1.0.0'; then
        echo "Nexus tools installed successfully."
    else
        echo "Failed to install Nexus tools. Please check your network connection or repository URL."
        return 1
    fi

    # Create Nexus ZKVM project
    cargo nexus new nexus-project || { echo "Failed to create Nexus ZKVM project."; return 1; }
    cd nexus-project/src || { echo "Failed to navigate to project src directory."; return 1; }

    # Remove the default main.rs if it exists
    rm -f main.rs

    # Write the sample program to main.rs
    cat <<EOT > main.rs
#![no_std]
#![no_main]

fn fib(n: u32) -> u32 {
    match n {
        0 => 0,
        1 => 1,
        _ => fib(n - 1) + fib(n - 2),
    }
}

#[nexus_rt::main]
fn main() {
    let n = 7;
    let result = fib(n);
    assert_eq!(result, 13);
}
EOT

    cd .. || { echo "Failed to return to project root directory."; return 1; }
    echo "Nexus ZKVM environment setup completed successfully."
}






manage_nexus_environment() {
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

    # Stop, disable, and clean up the Nexus service
    echo "Stopping and cleaning up Nexus service..."
    sudo systemctl stop nexus.service
    sudo systemctl disable nexus.service
    sudo rm -f /etc/systemd/system/nexus.service
    sudo systemctl daemon-reload

    echo "Nexus environment managed successfully."

    #Go to Menu
    master
}




logs() {
    if ! systemctl is-active --quiet nexus.service; then
        echo "Nexus service is not running. Attempting to start..."
        sudo systemctl start nexus.service
    fi

    # Re-check service status after attempting to start
    if systemctl is-active --quiet nexus.service; then
        echo "Nexus service started successfully."
    else
        echo "Failed to start Nexus service. Checking logs..."
        sudo journalctl -u nexus.service -n 50 --no-pager
    fi

    #Go to Menu
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
}






# Function to display menu and prompt user for input
master() {
    print_info "==============================="
    print_info "    Nexus Node Tool Menu    "
    print_info "==============================="
    print_info ""
    print_info "1. Install-Dependency"
    print_info "2. Setup-Nexus"
    print_info "3. Node-Run"
    print_info "4. Logs-Checker"
    print_info "5. Refresh-Node"
    print_info "6. Exit"
    print_info ""
    print_info "==============================="
    print_info " Created By : CB-Master "
    print_info "==============================="
    print_info ""
    
    read -p "Enter your choice (1 or 6): " user_choice

    case $user_choice in
        1)
            install_dependency
            ;;
        2)
            nexus_setup
            ;;
        3) 
            manage_nexus_environment
            ;;
        4) 
            logs
            ;;
        5)  
            restart_nexus_node
            ;;
        6)
            exit 0  # Exit the script after breaking the loop
            ;;
        *)
            print_error "Invalid choice. Please enter 1 or 11 : "
            ;;
    esac
}

# Call the uni_menu function to display the menu
master_fun
master
