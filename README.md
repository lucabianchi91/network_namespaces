# network_namespaces
Automation of namespace creation

./create_net_ns.sh
Create Network Namespaces that can communicate between them. Options:
-h help
-n number of ns
-o if the ns must have access to internet
-i intf to use as gateway for internet access. If o is 1, then an intf must be specified.
-b open a new bash (terminal) for each ns after creation
-f run a script for each ns after creation. if b, the script is run in the new terminal

./clean_sys.sh
remove all namespaces
