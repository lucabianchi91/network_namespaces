# Network Namespaces
Automation of namespace creation

`./create_net_ns.sh`
Create Network Namespaces that can communicate between them. Options:
* -h: display the help message
* -n `number`: number of namespaces to be created
* -i `intf_name`: network interface to be used as gateway (if any)
* -b: open a new bash (terminal) for each namespace
* -f `script`: run `script` in each namespace. If -b is passed, `script` is run in the new terminals

`./clean_sys.sh`
remove all namespaces
