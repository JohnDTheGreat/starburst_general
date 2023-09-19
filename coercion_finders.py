## This script will execute a query for every column on a table and output the results
import trino
import os
import getpass
import sys
import csv
import concurrent.futures
from sqlalchemy import create_engine
from trino.sqlalchemy import URL
from sqlalchemy.sql.expression import select, text
from trino.auth import OAuth2Authentication


import threading
import time

import logging
lg = logging
lg.basicConfig(format='%(asctime)s %(levelname)-4s %(message)s', level=lg.INFO)
import requests 
requests.packages.urllib3.disable_warnings() #TLS verification failure suppression

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

# Function to read schema, table from csv file 
# accepts catalog and csv file as arguments
# appends catalog to schema and table to list
def get_schema_table(csv_file, catalog):
    with open(csv_file, newline='') as csvfile:
        creader = csv.reader(csvfile, delimiter=',', quotechar='"')
        next(creader, None)  # skip the headers
        tuple_list = [tuple(row) for row in creader]
    return tuple_list

# Function to seperate list into chunks using list comprehension
def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

# Function that accepts catalog, schema, and table and returns full table name
def get_full_table(catalog, schema, table):
    return catalog + "." + schema + "." + table

# Function for creating a connection to Trino using SQLAlchemy that 
# accepts arguments for host, port, catalog, username, and password
def create_connection(host, port, catalog, username, password):
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
        pool_size=10, max_overflow=0 #Pool size and max overflow are optional
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
    query = "SELECT column_name FROM " + catalog + ".information_schema.columns \
    where table_schema = '" + schema + "' and table_name = '" + table + "'"
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

# Function accepting catalog and list of tuples containing schema and table calling get_columns
def get_all_columns(cpool, catalog, full_table_list):
    cur = get_connection(cpool)
    for i in full_table_list:
        get_columns(cur, catalog, i[0], i[1])

# Create main function
def main():
    # Get username and password
    # username, password = get_username_password()
    # # Get host and port
    # host, port = get_host_port()
    # # Get catalog
    # catalog = get_catalog()
    # # Get csv file
    # csv_file = get_csv_file()
    # Hard code for testing
    username, password, catalog, host, port = "starburst_service", "StarburstR0cks!", "hive", "ae34a34a332074136a033a3d4c3d3f42-1365266388.us-east-2.elb.amazonaws.com", 8443
    csv_file = "/Users/johndee.burks/Accounts/Sunlife/mismatch.csv"
    # Create connection
    cpool = create_connection(host, port, catalog, username, password)
    # Get connection
    cur = get_connection(cpool)
    # Execute query
    # execute_query(cur, csv_file)
    # Get full table list
    full_table_list = get_schema_table(csv_file, catalog)
    print(full_table_list)
    print(len(full_table_list))
    for i in full_table_list:
        #get_columns(cur, catalog, i[0], i[1])
        print(i[0] + "." + i[1])
    #catalog = "hive"
    # schema = "bootcamp"
    # table = "jcoer_broken"

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

# engine = create_engine(
#     URL(
#         host="ae34a34a332074136a033a3d4c3d3f42-1365266388.us-east-2.elb.amazonaws.com",
#         port=8443,
#         catalog="hive",
#         user="starburst_service"
#     ),
#     connect_args={
#         "http_scheme": "https",
#         "auth": trino.auth.BasicAuthentication("starburst_service", "StarburstR0cks!"), #User needs access to sysadmin role
#         "verify": False
#         #roles: {"system":"sysadmin"} #Only needed for biac
#     },pool_size=10, max_overflow=0
# )



# query = "SELECT * FROM hive.bootcamp.jcoer_broken LIMIT 10"
# try:
#     lg.info('Executing query: ' + query)
#     cur.execute(text(query)).fetchall()
# except Exception as inst:
#     lg.error(inst)


# query = "SELECT column_name FROM " + catalog + ".information_schema.columns \
# where table_schema = '" + schema + "' and table_name = '" + table + "'"
# try:
#     lg.info('Executing query: ' + query)
#     res = cur.execute(text(query)).fetchall()
#     for r in res:
#         column = r[0]
#         query = "SELECT " + column + " FROM hive.bootcamp.jcoer_broken LIMIT 1"
#         try:
#             lg.info('Executing query: ' + query)
#             cur.execute(text(query)).fetchall()
#         except Exception as inst:
#             lg.error("Table: " + full_table + " Column: " + column + " Exception: " + str(inst))
# except Exception as inst:
#     lg.error(inst)

# response = cur.fetchall()
# print(response)

# f = open("queries.sql", "r")

# for q in f:
#     print(q)

# if len(sys.argv) > 1:
#     arg = str(sys.argv[1])
# else:
#     sys.exit("need to supply argument usage: python3 trino_views_updater.py <trino_view_csv_file>")

# if not os.path.exists(arg):
#     sys.exit("need to supply valid filename, you supplied: " + arg)

# f = open(arg)


# interfile = str(f.name + ".intermediate")
# finalfile = str(f.name + ".updated")
# originalfile = str(f.name + ".original")
# lg.info("Deleting old files: " + interfile + ", " + finalfile + ", " + originalfile)
# if os.path.exists(interfile):
#     os.remove(interfile)
# if os.path.exists(finalfile):
#     os.remove(finalfile)
# if os.path.exists(originalfile):
#     os.remove(originalfile)

# lg.info("Creating new files: " + interfile + ", " + finalfile + ", " + originalfile)
# ofile = open(interfile, "a")
# ufile = open(finalfile, "a")
# origfile = open(originalfile, "a")

# lg.info("Performing trino csv correction")
# for i in f:
#     ir = i.replace('"""','"')
#     ofile.writelines(ir)

# lg.info("Writing unmodified ddls to: " + originalfile)
# lg.info("Writing data to updated file: " + finalfile)
# with open(interfile, newline='') as csvfile:
#     creader = csv.reader(csvfile, delimiter=',', quotechar='"')
#     next(creader, None)  # skip the headers
#     for row in creader:
#         ctlg = "pepsicodatalake_hive"
#         schema = row[0]
#         vname = row[1]
#         oq = row[2]
#         lq = oq.split('\\n')
#         #qrep = [s.replace('CAST(','from_iso8601_timestamp(').replace(' AS timestamp)',')') if 'AS timestamp)' in s else s for s in lq]
#         qrep = [s.replace('CAST(','cast(REPLACE(SUBSTRING(').replace(' AS timestamp)',", 1, 19), 'T', ' ') as timestamp)") if 'AS timestamp)' in s else s for s in lq]
#         qrep2 = [x + "\n" if x not in '' else x for x in qrep]
#         origrep = [x + "\n" if x not in '' else x for x in lq]
#         origddl = str("CREATE OR REPLACE VIEW '" + ctlg + "'.'" + schema + "'.'" + vname + "' AS \n" + ''.join(origrep) + "; \n")
#         uddl = str("CREATE OR REPLACE VIEW '" + ctlg + "'.'" + schema + "'.'" + vname + "' AS \n" + ''.join(qrep2) + "; \n")
#         origfile.writelines(origddl)
#         ufile.writelines(uddl)
# lg.info("Finished")


