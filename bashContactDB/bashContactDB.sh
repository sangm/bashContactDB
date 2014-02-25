#!/bin/bash

############################################################
################# List of Global Variables ################# 
############################################################
DATABASE_FILE="database_file.txt"
FIELDS=(pid name address phoneNum email)
QUERY_MATCH=()
declare -Ag DB
DB_COUNT=0

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

    for (( i = 0; i < ${#FIELDS[@]}; ++i)); do
        DB[$DB_COUNT,${FIELDS[$i]}]=$(trimWhiteSpace $1)
        shift
    done
    
#    DB[$DB_COUNT,pid]=$(trimWhiteSpace $1)
#    DB[$DB_COUNT,name]=$(trimWhiteSpace $2)
#    DB[$DB_COUNT,address]=$(trimWhiteSpace $3)
#    DB[$DB_COUNT,phoneNum]=$(trimWhiteSpace $4)
#    DB[$DB_COUNT,email]=$(trimWhiteSpace $5)

    ((DB_COUNT++))
}

############################################################
# Function replaces $DATABASE_FILE and writes over with
# new database content
############################################################
updateDB() {
    mv ${DATABASE_FILE}  ${DATABASE_FILE}_backup
    for (( i=0; i < $DB_COUNT; ++i )); do
        if [ ! -z ${DB[$i,pid]} ]; then
            echo "${DB[$i,pid]} | ${DB[$i,name]} | ${DB[$i,address]} | ${DB[$i,phoneNum]} | ${DB[$i,email]}" >> $DATABASE_FILE
        fi
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
    for (( i = 0; i < $DB_COUNT; ++i )); do
        if [ ! -z ${DB[$i,pid]} ]; then
            printf "\e $(tput setaf 1)$(tput sgr 0 1)%-20s $(tput setaf 7)%-20s %-20s %-20s %s$(tput sgr0)\n\n" \
                   "${DB[$i,pid]}" "${DB[$i,name]}" "${DB[$i,address]}" "${DB[$i,phoneNum]}" "${DB[$i,email]}"
        fi
    done
    echo -e "$(tput sgr0)"
}

############################################################
# Function asks the user for an input and queries the 
# "database"
############################################################
findRecord() {
#    read -p "query> " query 
#    read query <<< $(echo "-p0|-a\"Fake Address A\"|-n\"Sang Mercado\"")

    local IFS='|'   
    local query_arr=($1)
    declare -A val_choices
    local OPTIND

    unset QUERY_MATCH

    while getopts "p:n:a:#:e:" opt ${query_arr[@]}; do
        case "$opt" in
            p)  local pk=$(trimWhiteSpace ${OPTARG//\"/})
                val_choices[pid]="$pk";;
            n)  local name=$(trimWhiteSpace ${OPTARG//\"/})
                val_choices[name]="$name";;
            a)  local addr=$(trimWhiteSpace ${OPTARG//\"/})
                val_choices[address]="$addr";;
            \#) local pnum=$(trimWhiteSpace ${$OPTARG//\"/})
                val_choices[phoneNum]="$pnum";;
            e)  local email=$(trimWhiteSpace ${OPTARG//\"/})
                val_choices[email]="$email";;
            :) echo "$OPTARG needs an argument";;
            ?) echo "Unknown argument";;
        esac
    done

    for i in ${!val_choices[@]}; do
        for (( j = 0; j < $DB_COUNT; ++j)); do
            if [[ "${val_choices[$i]}" =~ ${DB[$j,$i]} ]]; then
                QUERY_MATCH+=($j)
            fi
        done
    done

}

############################################################
# Function adds a record to the database
############################################################
addRecord() {
    # Calculate the primary id, starts at 0, no need to offset
    local pID=$((${DB[$((DB_COUNT-1)),pid]} + 1))
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
    local pID
    read -p "What is the primary id of the person you want to remove> " pID
    local query="-p$pID"

    findRecord "$query"
    local index=${QUERY_MATCH[0]}

    if [[ -z "$index" ]]; then
        echo "There is no record associated with that primary key"
        return 1
    fi

    if [ "${DB[$index,pid]}" ]; then
        echo "Removing ${DB[$index,name]}"
        for ((i = 0; i < ${#FIELDS[@]}; ++i)); do
            unset DB[$index,${FIELDS[$i]}]
        done
        updateDB
    else
        echo "The person with that primary id does not exist"
    fi
}

############################################################
# Function updates a record from the database
############################################################
updateRecord() {
    local pID
    local IFS='|'
    local OPTIND

    read -p "What is the primary id of the person you want to update> " pID
    query="-p$pID"

    findRecord "-p$pID"
    local index=${QUERY_MATCH[0]}

    if [[ -z "$index" ]]; then
        echo "There is no record associated with that primary key"
        return 1
    fi
    read -p "What do you want to update? " update
    local update_arr=($update)

    while getopts "n:a:#:e:" opt ${update_arr[@]}; do
        case "$opt" in
            n)  DB[$index,name]=${OPTARG//\"/};;
            a)  DB[$index,address]=${OPTARG//\"/};;
            \#) DB[$index,phoneNum]=${OPTARG//\"/}};;
            e)  DB[$index,email]=${OPTARG//\"/};;
            :)  echo "$OPTARG needs an argument ";;
            ?)  echo "Unknown Option";;
          esac
    done

    updateDB
}

populateDatabase

while :; do
    printMenu
    case "$selection" in 
        a) displayRecords $DB; echo ;;
        b) 
            read -p "query> " query
            findRecord "$query"
            for index in ${QUERY_MATCH[@]}; do
                printf "%s\t%s\t%s\t%s\t%s\n"  ${DB[$index,pid]} ${DB[$index,name]} \
                    ${DB[$index,address]} ${DB[$index,phoneNum]} ${DB[$index,email]}
            done
            echo ;;
        c) addRecord;      echo ;;
        d) updateRecord;   echo ;;
        e) removeRecord;   echo ;;
        f) exit 0 ;;
        *) "Not a valid choice" ;;
    esac
done
