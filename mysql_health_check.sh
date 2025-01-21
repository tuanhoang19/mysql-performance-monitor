#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for installation
prompt_install() {
    local package_name=$1
    read -p "$package_name is not installed. Do you want to install it? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        if command_exists apt; then
            sudo apt update && sudo apt install -y $package_name
        elif command_exists yum; then
            sudo yum install -y $package_name
        else
            echo "Error: Package manager not supported. Please install $package_name manually."
            exit 1
        fi
    else
        echo "Error: $package_name is required. Exiting."
        exit 1
    fi
}

# Check if mysql is installed
if ! command_exists mysql; then
    prompt_install mysql-client
fi

# Check if awk is installed
if ! command_exists awk; then
    prompt_install gawk  # GNU Awk
fi

# Check if bc is installed
if ! command_exists bc; then
    prompt_install bc
fi

# MySQL credentials
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_HOST=""
MYSQL_DB=""
MYSQL_SOCKET=""

# Connect to MySQL and execute queries, store results in variables
buffer_pool_read_requests=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';" | awk '{print $2}')
buffer_pool_reads=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';" | awk '{print $2}')

open_tables=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Open_tables';" | awk '{print $2}')
opened_tables=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Opened_tables';" | awk '{print $2}')

open_table_definitions=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Open_table_definitions';" | awk '{print $2}')
opened_table_definitions=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Opened_table_definitions';" | awk '{print $2}')

created_tmp_disk_tables=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Created_tmp_disk_tables';" | awk '{print $2}')
created_tmp_tables=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -D$MYSQL_DB --socket=$MYSQL_SOCKET -se "SHOW GLOBAL STATUS LIKE 'Created_tmp_tables';" | awk '{print $2}')

# Calculate percentages
buffer_cache_hit=$(awk -v req=$buffer_pool_read_requests -v read=$buffer_pool_reads 'BEGIN { print (req - read) * 100 / req }')
table_cache_hit=$(awk -v open=$open_tables -v opened=$opened_tables 'BEGIN { print (open / opened) * 100 }')
table_definition_cache_hit=$(awk -v open_def=$open_table_definitions -v opened_def=$opened_table_definitions 'BEGIN { print (open_def / opened_def) * 100 }')
temp_table_on_memory=$(awk -v tmp=$created_tmp_tables -v disk_tmp=$created_tmp_disk_tables 'BEGIN { print (tmp - disk_tmp) * 100 / tmp }')

# Function to color output if below threshold
color_if_below_threshold() {
    local value=$1
    local threshold=$2
    if (( $(echo "$value < $threshold" | bc -l) )); then
        echo -e "\e[31m$value\e[0m"  # Red color
    else
        echo "$value"
    fi
}

# Output results in a table format
echo -e "Section\t\t\t\tPercentage"
echo -e "-----------------------------------------"
echo -e "Buffer Cache Hit\t\t$(color_if_below_threshold $buffer_cache_hit 90)"
echo -e "Table Cache Hit\t\t\t$(color_if_below_threshold $table_cache_hit 80)"
echo -e "Table Definition Cache Hit\t$(color_if_below_threshold $table_definition_cache_hit 80)"
echo -e "Temporary Table on Memory\t$(color_if_below_threshold $temp_table_on_memory 80)"
