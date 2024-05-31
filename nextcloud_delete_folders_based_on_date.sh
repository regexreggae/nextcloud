#!/bin/bash

# Function to print the given string with a timestamp
function print_w_ts { echo -e $1 | ts; }

# Check if an argument is provided
if ! [[ $1 ]]
then
  echo -e "\nPlease run the script with one of the following three parameters:\n\nproductive\ndebug_curl\ndebug_no_curl\n\n"
  exit
fi

# Set the starting folder
start_folder="/mnt/ncdata"
# Get the Telegram chat ID and server name from environment variables
telegram_chat_id=$TLG_CHAT_ID
server_name=$HOSTNAME
# Set the pattern for folder names based on the current date (productive mode)
pattern="delete_"$(date +%Y%m%d)"*" #productive
#pattern="debug_*" #debug

# Enable recursive globbing
shopt -s globstar

# Change to the starting folder
cd $start_folder

# Check if there are any folders matching the pattern
if ! [[ $(find -name $pattern -type d -not -path "*/files_versions/*" -not -path "*/files_trashbin/*") ]]; then
  print_w_ts "No folder found with pattern $pattern, exiting script."
  exit
fi

# Loop through all folders matching the pattern
for i in $(find -name $pattern -type d -not -path "*/files_versions/*" -not -path "*/files_trashbin/*"); do
  echo -e "\n"
  print_w_ts "Folder found with pattern $pattern: $i"

  # Check if the folder is empty
  if ! [[ $(ls -1 $i) ]]; then #if the found folder is empty
    echo -e "\nThis folder is empty."
    if [[ $1 = "productive" ]]; then #if in productive mode
      rmdir $i #delete the empty folder
      print_w_ts "$i has been deleted. Sending Telegram message..."
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: empty folder $i found AND DELETED" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
    fi
    if [[ $1 = "debug_curl" ]]; then #if in debug mode with curl
      print_w_ts "Sending debug Telegram message..."
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: empty folder $i found (not deleted because debug mode)" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
    fi
  else #if the folder contains at least one file:
    echo -e "\nThe contents of this folder are:\n"
    dir_contents=$(ls -1 -R $i)
    ls -1 -R $i
    if [[ $1 = "productive" ]]; then #if in productive mode
      rm -rf $i #delete the non-empty folder
      print_w_ts "$i has been deleted. Sending Telegram message..."
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: non-empty folder $i found AND DELETED" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: The following files from the folder have been deleted: $dir_contents" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
    fi
    if [[ $1 = "debug_curl" ]]; then
      print_w_ts "Sending debug Telegram message..."
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: non-empty folder $i found (not deleted because debug mode)" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
      curl -d "chat_id=$telegram_chat_id&text=%E2%9C%85 Message from $server_name: The following files from the folder would theoretically be deleted: $dir_contents" https://api.telegram.org/$TLG_BOT_ID/sendMessage &> /dev/null
    fi
  fi
done

# If in productive mode, update the database
if [[ $1 = "productive" ]]; then
  echo -e "\nEverything finished. Now updating the database.\n"
  sudo -u www-data php /var/www/nextcloud/occ files:scan --all #productive use: Update Web GUI
fi