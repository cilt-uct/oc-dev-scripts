#! /bin/bash

## Deploys Develop or Main Branch to the Playground Server
## Uses:
##    - Ansible
##    - Git
##    - xmlstarlet

# Original (2017-06-24): Corne Oosthuizen (corne.oosthuizen [at] uct.ac.za)
# See: changelog.md

source config-dist.sh

DEPLOY_TYPE="dev"

DIRNAME=$(dirname "$0")
PROGNAME=$(basename "$0")

# should we execute permanent scripts
LIVE=true

DATE=`date '+%Y-%m-%d %H:%M:%S'`

# list of servers to use
declare -a ACTIVE_LIST

writeConfiguration() {
  INPUT=$1
  OUTPUT=$2

  while read line
  do
      [[ $line = \#* ]] && continue

      if [ ! -z "$line" ]; then

        IFS="=" read find replace <<< "$line"

        sed -i -e "s;$find;$replace;" $OUTPUT
      fi

  done < $INPUT
}

gitstatus() {

  folder=$1

  if [[ $(git -C $folder rev-parse --is-inside-work-tree 2>/dev/null) == "true" ]] ; then

    local gitorigin=$(git -C $folder config --get remote.origin.url | awk -F '/' '{ print $4,"/",$5 }')
    local gitbranch=$(git -C $folder branch | grep -e ^* | sed -E "s;\*\\s;;")

    echo "$gitorigin $gitbranch"
    return
  fi

  echo ""
  return
}

# search a list of ini_files for the desired id, returning the first match
# w/o regard for sections so it also works for setup.py files.
# Strips enclosing white space and quotes and trailing commas
# params:
# $1 -- configuration file
# $2 -- the section (if any)
# $3 -- the key
get_ini_value() {

  cfg_file=$1
  section=""
  key=$3
  shift; shift; shift;

  value=$(
    if [ -n "$section" ]; then
      sed -n "/^\[$section\]/, /^\[/p" $cfg_file
    else
      cat $cfg_file
    fi |

    egrep "^ *\b$key\b *=" |

    head -1 | cut -f2 -d'=' |
    sed 's/^[ "'']*//g' |
    sed 's/[ ",'']*$//g' )

  if [ -n "$value" ]; then
    echo $value
    return
  fi
}

# Write the Ansible connection configuration
  cp $FILES/all.template group_vars/all
  writeConfiguration "$DEPLOY_CFG_FOLDER/deploy.cfg" group_vars/all

  # Read the hosts file
  while read line
  do
      [[ $line = \#* ]] && continue

      if [ ! -z "$line" ]; then

        if [[ $line != \[* ]]; then
           name=$line #$( echo $line | cut -d'.' -f 1)
           ACTIVE_LIST+=($name)
        fi
      fi

  done < "$YML/hosts/all"

  ACTIVE_SERVER_LIST=($(echo "${ACTIVE_LIST[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  servername="localhost"

  # This should generally just be 1 server
  echo "Deploying to: "
  for name in "${ACTIVE_SERVER_LIST[@]}"; do
     echo " - $name"
     servername=$name
  done

  echo
  printf "To Deploy: (1) Develop Branch or (2) Main Branch [Default: 1]: "
  read ni
  choice="$(echo -e "${ni}" | tr -d '[:space:]')"

  if [[ -z  $choice  ]]; then
     choice=1
  fi

  case $choice in
    1)
      DEPLOY_TYPE="dev"
    ;;
    2)
      DEPLOY_TYPE="main"
    ;;
    *)
      echo
      echo "Invalid option :p"
      echo
      exit 1
    ;;
  esac

read -p "Update database after deploy (Y/N) [No]: " clean_db
clean_db=${clean_db:-n}
clean_db=$(echo $clean_db | tr '[:upper:]' '[:lower:]')

echo

# Write the shell script that will run on the server to deploy opencast
cp $FILES/deploy-template.sh $TMP_DIR/deploy.sh
writeConfiguration $CONFIG/server-$DEPLOY_TYPE.cfg $TMP_DIR/deploy.sh
sed -i -e "s;cfg_servername;$servername;" $TMP_DIR/deploy.sh

src_folder=$(get_ini_value $CONFIG/server-$DEPLOY_TYPE.cfg all deploy_src_folder)
src_version=$(xmlstarlet sel -t -v "/_:project/_:version" $src_folder/pom.xml)
cfg_name=$(get_ini_value $CONFIG/server-$DEPLOY_TYPE.cfg all cfg_name)
cfg_service=$(get_ini_value $CONFIG/server-$DEPLOY_TYPE.cfg all cfg_service)
cfg_db_name=$(get_ini_value $CONFIG/server-$DEPLOY_TYPE.cfg all cfg_db_name)
git_details=$(gitstatus $src_folder)

echo "Deploying ($DEPLOY_TYPE - $src_version) from $src_folder: "
$LIVE && ansible-playbook ansible-deploy-custom.yml -i hosts/all \
--extra-vars "target_service=$cfg_service allinone_src=$src_folder/build/opencast-dist-allinone-$src_version.tar.gz allinone_dest=/opt/$cfg_name.tar.gz deploy_src=files/tmp/deploy.sh deploy_dest=/opt/deploy-$DEPLOY_TYPE.sh deploy_git='$git_details' deploy_type=$DEPLOY_TYPE deploy_version='$src_version' status_template=files/status.template status_dest=/var/www/html/$DEPLOY_TYPE.js deploy_date='$DATE'"

if [[ "$clean_db" == "y" ]]; then
  echo " - Deploying Database"
  $LIVE && ansible-playbook ansible-deploy-database.yml -i hosts/all \
   --extra-vars "target_service=$cfg_service source_db=$cfg_db_name target_db=$cfg_db_name target_db=$cfg_service sql_source=$src_folder/docs/scripts/ddl/mysql5.sql sql_dest=/opt/$cfg_name.sql"
fi

echo
echo "Done."
echo