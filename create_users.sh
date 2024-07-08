#!/bin/bash

# Check if input file is provided
if [ -z "$1" ]; then
    echo "No input file provided. Usage: $0 <input-file>"
    exit 1
fi

# Check if input file exists
if [ ! -f "$1" ]; then
    echo "Input file does not exist."
    exit 1
fi

# Store the input file name from the command-line argument
INPUT_FILE=$1

# Ensure /var/secure directory exists
if [ ! -d "/var/secure" ]; then
    sudo mkdir -p /var/secure  # Create the directory if it doesn't exist
    sudo chmod 700 /var/secure  # Set permissions to allow only the owner to access it
fi

# Create user_passwords.txt if it doesn't exist
if [ ! -f "/var/secure/user_passwords.txt" ]; then
    sudo touch /var/secure/user_passwords.txt  # Create the file
    sudo chmod 600 /var/secure/user_passwords.txt  # Set permissions to allow only the owner to read/write
fi

# Log file location
LOG_FILE="/var/log/user_management.log"
sudo touch $LOG_FILE  # Create the log file if it doesn't exist
sudo chmod 644 $LOG_FILE  # Set permissions to allow read/write by owner, read by others

# Process the input file line by line
while IFS=';' read -r username groups; do
    # Remove whitespace around username and groups
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Create a primary group with the same name as the username if it doesn't exist
    if ! getent group "$username" > /dev/null; then
        sudo groupadd "$username"
    fi

    # Create user with the primary group if the user doesn't exist
    if ! id "$username" &>/dev/null; then
        sudo useradd -m -s /bin/bash -g "$username" "$username"  # Create user and home directory
    else
        echo "User $username already exists." | sudo tee -a $LOG_FILE
        continue  # Skip to the next user if the user already exists
    fi

    # Add user to additional groups specified in the input file
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        if ! getent group "$group" > /dev/null; then
            sudo groupadd "$group"  # Create the group if it doesn't exist
        fi
        sudo usermod -aG "$group" "$username"  # Add user to the group
    done

    # Generate a random password for the user
    password=$(openssl rand -base64 12)
    echo "$username:$password" | sudo chpasswd  # Set the user's password

    # Log the user creation details
    echo "User $username created and added to groups: $groups" | sudo tee -a $LOG_FILE

    # Store the username and password in the secure file
    echo "$username,$password" | sudo tee -a /var/secure/user_passwords.txt
done < "$INPUT_FILE"  # Read from the input file

# Log the completion of the user creation process
echo "User creation process completed." | sudo tee -a $LOG_FILE


