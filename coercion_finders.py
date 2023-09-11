## This script will execute a query for every column on a table and output the results
import trino
import os
import logging
lg = logging
lg.basicConfig(format='%(asctime)s %(levelname)-4s %(message)s', level=lg.INFO)
import requests 
requests.packages.urllib3.disable_warnings() #TLS verification failure suppression

conn = trino.dbapi.connect(
    host="ae34a34a332074136a033a3d4c3d3f42-1365266388.us-east-2.elb.amazonaws.com",
    port=8443,
    auth=trino.auth.BasicAuthentication("starburst_service", "StarburstR0cks!"), #User needs access to sysadmin role
    http_scheme="https", 
    verify=False,
    roles={"system":"sysadmin"} #Only needed for biac
)
lg.info('Attempting connection to host: ' + conn.http_scheme + '://' + conn.host + ':' + str(conn.port))
cur = conn.cursor()
query = "select * from hive.bootcamp.jcoer_broken"
try:
    lg.info('Executing query: ' + query)
    cur.execute(query)
except Exception as inst:
    lg.error(inst)

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


