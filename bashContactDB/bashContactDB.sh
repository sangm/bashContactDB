#!/bin/bash

############################################################
################# List of Global Variables ################# 
############################################################
DATABASE_FILE="database_file.txt"
declare -A DB
DB_COUNT=0
DB_PID=()
DB_NAME=()
DB_ADDRESS=()
DB_PHONENUM=()
DB_EMAIL=()

############################################################
################# List of Auxilary Functions ###############
############################################################

############################################################
# Parameters: String
# Output: Gets rid of leading/trailing 
#         whitespace
############################################################
trimWhiteSpace() {
    local var=$@
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

############################################################
# Parameters: String lines in the format of
#             pid | name | address | phonenum | email
############################################################
addEntry() {
    local IFS='|'
    set $1
    
    DB[$DB_COUNT,pid]=$(trimWhiteSpace $1)
    DB[$DB_COUNT,name]=$(trimWhiteSpace $2)
    DB[$DB_COUNT,address]=$(trimWhiteSpace $3)
    DB[$DB_COUNT,phoneNum]=$(trimWhiteSpace $4)
    DB[$DB_COUNT,email]=$(trimWhiteSpace $5)

    ((DB_COUNT++))
    
    DB_PID+=($(trimWhiteSpace $1))
    DB_NAME+=($(trimWhiteSpace $2))
    DB_ADDRESS+=($(trimWhiteSpace $3))
    DB_PHONENUM+=($(trimWhiteSpace $4))
    DB_EMAIL+=($(trimWhiteSpace $5))

}

############################################################
# Function replaces $DATABASE_FILE and writes over with
# new database content
############################################################
updateDB() {
    mv ${DATABASE_FILE}  ${DATABASE_FILE}_backup
#    for i in ${!DB_PID[@]}; do
#        echo "${DB_PID[$i]} | ${DB_NAME[$i]} | ${DB_ADDRESS[$i]} | ${DB_PHONENUM[$i]} | ${DB_EMAIL[$i]}" >> $DATABASE_FILE
#    done

    for (( i=0; i < $DB_COUNT; ++i )); do
        echo "${DB[$i,pid]} | ${DB[$i,name]} | ${DB[$i,address]} | ${DB[$i,phoneNum]} | ${DB[$i,email]}" >> $DATABASE_FILE
    done
}

############################################################
################# List of Program Functions ################
############################################################

# Function prints an option menu and sets the global
# variable "selection" to what the user input
############################################################
printMenu() {
    declare -A local options=(
        ["a"]="Display all the records"
        ["b"]="Find a record"
        ["c"]="Add a new record"
        ["d"]="Update a record"
        ["e"]="Remove a record"
        ["f"]="Quit"
    )

    echo "Welcome to the contact database. Please select an option"
    for opt in ${!options[@]}; do
        printf "[$opt]\t${options[$opt]}\n"
    done
    echo -n "-> Selection: "
    read selection
    echo 
}

############################################################
# Function populates the database by opening the 
# $DATABASE_FILE and populates arrays DB_PID, DB_NAME,
# DB_ADDRESS, DB_PHONENUM, DB_EMAIL with information from
# the file
############################################################
populateDatabase() {
    if [ ! -f $DATABASE_FILE ]; then 
        echo "Database File does not exist"
        exit -1
    fi
    # Setting the IFS to every new line
    # so that it doesn't split on spaces
    local IFS=$'\n'
    mapfile -t database < $DATABASE_FILE
    for data in ${database[@]}; do
        addEntry $data
    done
}

############################################################
# Function prints out a nicely formatted table
# from DB_PID, DB_NAME, DB_ADDRESS, DB_PHONENUM, DB_EMAIL
############################################################
displayRecords() {
    printf "\e $(tput bold)$(tput sgr 0 1)$(tput setaf 1)%-20s %-20s %-20s %-20s %s$(tput sgr0)\n\n" \
           "Primary Key" "Name" "Address" "Phone Number" "Email"
#    for id in ${!DB_PID[@]}; do
#        printf "\e $(tput setaf 1)$(tput sgr 0 1)%-20s $(tput setaf 7)%-20s %-20s %-20s %s$(tput sgr0)\n\n" \
#               "${DB_PID[$id]}" "${DB_NAME[$id]}" "${DB_ADDRESS[$id]}" "${DB_PHONENUM[$id]}" "${DB_EMAIL[$id]}"
#    done
#    echo -e "$(tput sgr0)"

    for (( i = 0; i < $DB_COUNT; ++i )); do
        printf "\e $(tput setaf 1)$(tput sgr 0 1)%-20s $(tput setaf 7)%-20s %-20s %-20s %s$(tput sgr0)\n\n" \
               "${DB[$i,pid]}" "${DB[$i,name]}" "${DB[$i,address]}" "${DB[$i,phoneNum]}" "${DB[$i,email]}"
    done
    echo -e "$(tput sgr0)"
}

############################################################
# Function asks the user for an input and queries the 
# "database"
############################################################
findRecord() {
    read -p "query> " query 

    local IFS='|'   
    query_arr=($query)

    while getopts ":p:a:#:e:" opt ${query_arr[@]}; do
        case "$opt" in
            p)  local pk=$(trimWhiteSpace ${OPTARG//\"/});;
            a)  local addr=$(trimWhiteSpace ${OPTARG//\"/});;
            \#) local pnum=$(trimWhiteSpace ${$OPTARG/\"/};;
            e)  local email=$(trimWhiteSpace ${OPTARG//\"/};;
            :) echo "$OPTARG needs an argument";;
            ?) echo "Unknown argument";;
        esac
    done
}

############################################################
# Function adds a record to the database
############################################################
addRecord() {
    # Calculate the primary id, starts at 0, no need to offset
    local pID=$((${#database[@]}))
    local loc_name
    local loc_addr
    local loc_phoneNum
    local loc_email

    read -p "What is the name> " loc_name
    read -p "What is the address> " loc_addr
    read -p "What is the phone number> " loc_phoneNum
    read -p "What is the email> " loc_email

    insert_query="$pID | $loc_name | $loc_addr | $loc_phoneNum | $loc_email"
    addEntry "$insert_query"
    updateDB
}

############################################################
# Function removes a record from the database
############################################################
removeRecord() {
    # Assume that you get primary id
    echo "null"
}

############################################################
# Function updates a record from the database
############################################################
updateRecord() {
    echo "null"    
}

populateDatabase

while :; do
    printMenu
    case "$selection" in 
        a) displayRecords; echo ;;
        b) findRecord;     echo ;;
        c) addRecord;      echo ;;
        d) updateRecord;   echo ;;
        e) removeRecord;   echo ;;
        f) exit 0 ;;
        *) "Not a valid choice" ;;
    esac
done
