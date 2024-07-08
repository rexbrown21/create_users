#!/bin/bash

# Script to create users and assign groups based on input file
# Log file: /var/log/user_management.log
# Password file: /var/secure/user_passwords.txt

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure the log file and password file exist
touch $LOG_FILE
touch $PASSWORD_FILE

# Set permissions for the password file
chmod 600 $PASSWORD_FILE

#function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

#function to generate random passwords
generate_password() {
  openssl rand -base64 12
}

#this checks if the input file is provided and exists
if [ -z "$1" ]; then
  echo "Usage: $0 <input-file>"
  exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file does not exist."
  exit 1
fi

#this reads the input file line by line 
while IFS=';' read -r username groups; do
  # Remove leading and trailing whitespace
  username=$(echo $username | xargs)
  groups=$(echo $groups | xargs)

  # Create user and personal group
  if id "$username" &>/dev/null; then
    log_message "User $username already exists."
  else
    useradd -m -G $username $username
    log_message "User $username created with personal group $username."
  fi

  # Assign additional groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo $group | xargs)  # Remove whitespace
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      log_message "Group $group created."
    fi
    usermod -aG "$group" "$username"
    log_message "User $username added to group $group."
  done

  # Generate and store password
  password=$(generate_password)
  echo "$username,$password" >> $PASSWORD_FILE
  echo "$username:$password" | chpasswd
  log_message "Password for user $username set."
done < "$INPUT_FILE"

# Ensure only the owner can read the password file
chmod 600 $PASSWORD_FILE

log_message "Script execution completed."

chmod +x create_users.sh

