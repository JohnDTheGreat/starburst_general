## This script will execute a query for every column on a table and output the results
import trino
import os
import getpass
import sys
import csv
import math
from sqlalchemy import create_engine
from trino.sqlalchemy import URL
from sqlalchemy.sql.expression import select, text
from trino.auth import OAuth2Authentication
import threading

import logging
lg = logging
lg.basicConfig(format='%(asctime)s %(levelname)-4s %(threadName)s %(message)s', level=lg.INFO, filename='coercion_finders.log', filemode='w')

import requests 
requests.packages.urllib3.disable_warnings() #TLS verification failure suppression

import warnings
warnings.filterwarnings('ignore') #SQLAlchemy warnings suppression

# Function to collect and verify the username and password
def get_username_password():
    username = input("Username: ")
    password = getpass.getpass("Password: ")
    if username == "" or password == "":
        sys.exit("Username and password cannot be blank")
    return username, password

# Function to collect and verify the host and port
def get_host_port():
    host = input("Host: ")
    port = input("Port: ")
    if host == "" or port == "":
        sys.exit("Host and port cannot be blank")
    return host, port

# Function to collect and verify catalog
def get_catalog():
    catalog = input("Catalog: ")
    if catalog == "":
        sys.exit("Catalog cannot be blank")
    return catalog

# Function to collect csv file and test if it exists
def get_csv_file():
    csv_file = input("CSV File: ")
    # Verify existence
    if not os.path.exists(csv_file):
        sys.exit("CSV file name supplied: " + csv_file + " does not exist")
    # Verify it is a csv file
    if not csv_file.endswith('.csv'):
        sys.exit("CSV file must be end in .csv, you supplied: " + csv_file)
    # Verify it has two columns
    with open(csv_file, newline='') as csvfile:
        creader = csv.reader(csvfile, delimiter=',', quotechar='"')
        next(creader, None)  # skip the headers
        for row in creader:
            if len(row) != 2:
                sys.exit("CSV file must have two columns {schema,table} , you supplied: " + str(len(row)))
    return csv_file

# Function to read schema, table from csv file and return list of tuples
def get_schema_table(csv_file):
    with open(csv_file, newline='') as csvfile:
        creader = csv.reader(csvfile, delimiter=',', quotechar='"')
        next(creader, None)  # skip the headers
        tuple_list = [tuple(row) for row in creader]
    return tuple_list

# Function to seperate list into chunks using list comprehension
def chunks(lst, number_of_chunks):
    step_size = math.ceil(len(lst) / number_of_chunks)
    for i in range(0, len(lst), step_size):
        yield lst[i:i + step_size]

# Function that accepts catalog, schema, and table and returns full table name
def get_full_table(catalog, schema, table):
    return catalog + "." + schema + "." + table


# Function for creating a connection to Trino using SQLAlchemy that 
# accepts arguments for host, port, catalog, username, and password
def create_connection(host, port, catalog, username, password, poolsize):
    lg.info('Connection pool created with the following parameters: host: ' + 
            host + ' port: ' + str(port) + ' catalog: ' + catalog + ' username: ' + 
            username + ' poolsize: ' + str(poolsize))
    return create_engine(
        URL(
            host=host,
            port=port,
            catalog=catalog,
            user=username
        ),
        connect_args={
            "http_scheme": "https",
            "auth": trino.auth.BasicAuthentication(username, password),
            "verify": False
        },
        pool_size=poolsize, max_overflow=0 #Pool size and max overflow are optional
    )

# Function to get connection from cpool and test
def get_connection(cpool):
    try:
        lg.info('Attempting connection to host: ' + str(cpool.url))
        cur = cpool.connect()
        lg.info('Connection successful')
    except Exception as inst:
        lg.error(inst)
        sys.exit("Connection failed")
    return cur

# Function to execute query that accepts a cursor and full table name
def execute_query(cur, full_table):
    query = "SELECT * FROM " + full_table + " LIMIT 10"
    try:
        lg.info('Executing query: ' + query)
        cur.execute(text(query)).fetchall()
    except Exception as inst:
        lg.error(inst)

# Function to get all columns from a table and query each column collecting the exception or results
def get_columns(cur, catalog, schema, table):
    query = ("SELECT column_name FROM " + catalog + 
             ".information_schema.columns where table_schema = '" 
             + schema + "' and table_name = '" + table + "'")
    full_table = get_full_table(catalog, schema, table)
    try:
        lg.info('Executing query to gather columns: ' + query)
        res = cur.execute(text(query)).fetchall()
        for r in res:
            column = r[0]
            query = "SELECT " + column + " FROM " + full_table + " LIMIT 1"
            try:
                lg.info('Executing query to test : ' + query)
                cur.execute(text(query)).fetchall()
            except Exception as inst:
                lg.error("Table: " + full_table + " Column: " + column + " Exception: " + str(inst))
    except Exception as inst:
        lg.error(inst)

# Get columns test
def get_columns_test(catalog, schema, table):
    query = ("SELECT column_name FROM " + catalog + ".information_schema.columns " + 
    "where table_schema = '" + schema + "' and table_name = '" + table + "'")
    full_table = get_full_table(catalog, schema, table)
    lg.info('Executing query to gather columns: ' + query)
    query = ("SELECT test_column FROM " + full_table + " LIMIT 1")
    lg.info('Executing query to test : ' + query)

# Function accepting catalog and list of tuples containing schema and table calling get_columns
def get_all_columns(cpool, catalog, table_list_chunks):
    cur = get_connection(cpool)
    for i in table_list_chunks:
        get_columns(cur, catalog, i[0], i[1])

# Test get_all_columns for dry run
def get_all_columns_test(catalog, table_list_chunks):
    for i in table_list_chunks:
        get_columns_test(catalog, i[0], i[1])

# Function for gathering if this is dry run or not
def get_dry_run():
    dry_run = input("Dry Run? (y/n): ")
    if dry_run == "y":
        return True
    elif dry_run == "n":
        return False
    else:
        lg.info("Invalid input, assuming dry run")
        return True

# Function getting all information
def dry_run_true():

    # Get catalog
    catalog = get_catalog()
    #catalog = "hive"

    # Get csv file
    csv_file = get_csv_file()
    #csv_file = "/Users/johndee.burks/Accounts/Sunlife/test.csv"
    
    # Get full table list
    full_table_list = get_schema_table(csv_file)

    # Print starting message
    print ("Staring coercion finder, this will take a while please review the log file: " 
           + os.getcwd() + "/coercion_finders.log")
    lg.info("Coercion finder started")

    # Initialize counter and threads list
    c = 0
    threads = [] 

    # Create threads
    for chunk in chunks(full_table_list, 10):
        c = c + 1
        threadname = str("Worker-" + str(c))
        threads.append(threading.Thread(name = threadname, target=get_all_columns_test, args=(catalog, chunk)))
        lg.info("Starting thread: " + threadname)
        threads[-1].start()

    # Wait for all threads to complete
    for t in threads:
        lg.info("Waiting for thread: " + t.name + " to complete")
        t.join()
        lg.info("Thread: " + t.name + " complete")
    lg.info("Dry run complete")
    print("Dry run complete")

def dry_run_false():
    
    # # Hard code for testing
    # username, password, catalog, host, port = ("starburst_service", 
    #                                            "StarburstR0cks!", 
    #                                            "hive", 
    #                                            "ae34a34a332074136a033a3d4c3d3f42-1365266388.us-east-2.elb.amazonaws.com", 
    #                                            8443)
    # csv_file = "/Users/johndee.burks/Accounts/Sunlife/test.csv"

    # Get username and password
    username, password = get_username_password()
    
    # Get host and port
    host, port = get_host_port()
    
    # Get catalog
    catalog = get_catalog()
    
    # Get csv file
    csv_file = get_csv_file()
    
    # Get full table list
    full_table_list = get_schema_table(csv_file)
    
    # Create connection pool
    cpool = create_connection(host, port, catalog, username, password, 15)

    # Print starting message
    print ("Staring coercion finder, this will take a while please review the log file: " 
           + os.getcwd() + "/coercion_finders.log")
    lg.info("Coercion finder started")

    # Initialize counter and threads list
    c = 0
    threads = [] 

    # Create threads
    for chunk in chunks(full_table_list, 10):
        c = c + 1
        threadname = str("Worker-" + str(c))
        threads.append(threading.Thread(name = threadname, target=get_all_columns, args=(cpool, catalog, chunk)))
        lg.info("Starting thread: " + threadname)
        threads[-1].start()

    # Wait for all threads to complete
    for t in threads:
        lg.info("Waiting for thread: " + t.name + " to complete")
        t.join()
        lg.info("Thread: " + t.name + " complete")
    lg.info("All queries complete")
    print("All queries complete")


# Create main function
def main():
    # If dry run do that and print all queries, if not dry run execute against cluster
    if get_dry_run() == True:
        dry_run_true()
    else:
        dry_run_false()

main()


#Oauth2
# engine = create_engine(
# #"trino://tony.english@starburstdata.com@officialpreview.galaxy.starburst.io/glue",
#     URL(
#         host="officialpreview.galaxy.starburst.io",
#         port=443,
#         catalog="glue",
#         user="johndee.burks@starburstdata.com"
#     ),
#     connect_args={
#         "auth": OAuth2Authentication(),
#         "http_scheme": "https",
#         "schema": "te_demo",
#         "verify": False
#     }
# )