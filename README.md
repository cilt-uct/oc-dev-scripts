# UCT Opencast Development Deploy Script

Scripts used to deploy Opencast (Develop and Main Branch) from build to test server.

This deployment does not do the setup for Apache ActiveMQ or the database and assumes that they have already been setup on the target server. Similarly the SSH user, opencast user, and the service setup for the target server is assumed to already exist (ref. Opencast Documentation), otherwise it might cause errors in the deployment script.

## Getting Started - Source Server

* Make sure you have Ansible 2.1 or later installed.

    `ansible --version`

* Make sure you have XMLStarlet installed (To obtain the source build version).

    `apt-get install xmlstarlet`

* Check out oc-scripts into some folder.

    `git clone https://bitbucket.org/cilt/oc-dev-scripts.git /some/folder/`

* Configure your `deploy.cfg` file, you might want to place this file outside this folder because it contains passwords:

    `cp config\deploy-example.cfg \your\config\folder\deploy.cfg`

* Configure your `config.sh` file:

    `cp config-dist.sh config.sh`

* Configure your `hosts\all` file (add the servername):

    `cp hosts\example hosts\all`

* Configure your develop and main branch configurations.

```
cp config/server-example.cfg config/server-main.cfg
cp config/server-example.cfg config/server-dev.cfg
```

### Running

  Usage: run.sh 

You can deploy the All-in-One code from either the Development (dev - option 1 - default) or the Main Branch code (main - option 2).

Note:

1. This deployment REPLACES the existing opencast folder (if it exists), no backup of the previous content.

2. The deploy script DOES NOT clean up after itself e.g it leaves the `deploy.sh` and `opencast.tar.gz` in the chosen operational folder. 

3. The deploy script DOES NOT start up the specific opencast service after deployment.