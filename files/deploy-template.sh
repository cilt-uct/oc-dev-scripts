#!/bin/sh

USER="opencast"
DIRNAME=$(dirname "$0")
PROGNAME=$(basename "$0")

opt="cfg_opt"
working="cfg_install"
working_real="cfg_install"
server_cfg="http://cfg_servername:cfg_port"
file="cfg_name.tar.gz"
tmp="$opt/cfg_name-tmp"

main() {

  cd $opt
  echo
  echo "Starting to deploy Opencast Assembly"
  echo "    - for: cfg_display"
  echo "    - type: All-In-One"
  echo "    - to: $working"

  # stop service (probably stopped already but this is to make sure)
  service cfg_service stop

  echo
  printf "    Extracting ."

  check_directory $working $working_real

  # remove all the old files from the deploy folder
  [ "$(ls -1 $working | wc -l)" -gt "0" ] && rm -rf $working/*
  printf "."

  [ "$(find -type f -name $file -ls | wc -l)" -eq "1" ] && found_tar=true || found_tar=false
  if $found_tar; then

    mkdir -p $tmp

    # extract the assembly tar file to /opt folder then move content to the correct folder
    tar -zxf $file -C $tmp && mv $tmp/opencast-dist-*/* $working/
    printf "."

    # remove the now empty extract folder
    rm -rf $tmp
    printf "."
  else
    echo
    echo "    ERROR: Distribution tar file does not exist."
    return
  fi

  #bin
  echo "export JAVA_HOME=\"cfg_java_home\"" >> $working/bin/setenv

  #etc
  replaceIn "log4j.appender.out=org.apache.log4j.FileAppender" "log4j.appender.out=org.apache.log4j.DailyRollingFileAppender" $working/etc/org.ops4j.pax.logging.cfg

  replaceIn "org.opencastproject.server.url=http://localhost:8080" "org.opencastproject.server.url=http://cfg_servername:cfg_port" $working/etc/custom.properties
  replaceIn "org.opencastproject.security.digest.pass=CHANGE_ME" "org.opencastproject.security.digest.pass=cfg_digest_pass" $working/etc/custom.properties
  replaceIn "org.opencastproject.storage.dir=\${karaf.data}/opencast" "org.opencastproject.storage.dir=cfg_storage" $working/etc/custom.properties
  replaceIn "#org.opencastproject.episode.rootdir=\${org.opencastproject.storage.dir}/archive" "org.opencastproject.episode.rootdir=\${org.opencastproject.storage.dir}/archive" $working/etc/custom.properties
  replaceIn "#org.opencastproject.file.repo.path=\${org.opencastproject.storage.dir}/files" "org.opencastproject.file.repo.path=\${org.opencastproject.storage.dir}/files" $working/etc/custom.properties
  replaceIn "#org.opencastproject.workflow.default.definition=schedule-and-upload" "org.opencastproject.workflow.default.definition=cfg_workflow" $working/etc/custom.properties

  replaceIn "org.opencastproject.db.ddl.generation=true" "org.opencastproject.db.ddl.generation=false" $working/etc/custom.properties
  replaceIn "#org.opencastproject.db.vendor=MySQL" "org.opencastproject.db.vendor=MySQL" $working/etc/custom.properties
  replaceIn "#org.opencastproject.db.jdbc.driver=com.mysql.jdbc.Driver" "org.opencastproject.db.jdbc.driver=com.mysql.jdbc.Driver" $working/etc/custom.properties
  replaceIn "#org.opencastproject.db.jdbc.url=jdbc:mysql://localhost/opencast" "org.opencastproject.db.jdbc.url=jdbc:mysql://cfg_db_path" $working/etc/custom.properties
  replaceIn "#org.opencastproject.db.jdbc.user=opencast" "org.opencastproject.db.jdbc.user=cfg_db_user" $working/etc/custom.properties
  replaceIn "#org.opencastproject.db.jdbc.pass=dbpassword" "org.opencastproject.db.jdbc.pass=cfg_db_pass" $working/etc/custom.properties

  replaceIn "#activemq.broker.url=failover://(tcp://127.0.0.1:61616)?initialReconnectDelay=2000\&maxReconnectAttempts=2" "activemq.broker.url=failover://(tcp://cfg_activemq_url)?initialReconnectDelay=2000\&maxReconnectAttempts=2" $working/etc/custom.properties
  replaceIn "#activemq.broker.username=admin" "activemq.broker.username=cfg_activemq_user" $working/etc/custom.properties
  replaceIn "#activemq.broker.password=password" "activemq.broker.password=cfg_activemq_pass" $working/etc/custom.properties

  replaceIn "#org.opencastproject.solr.dir=\${karaf.data}/solr-indexes" "org.opencastproject.solr.dir=\${karaf.data}/solr-indexes" $working/etc/custom.properties

  replaceIn "org.ops4j.pax.web.listening.addresses=127.0.0.1" "org.ops4j.pax.web.listening.addresses=0.0.0.0" $working/etc/org.ops4j.pax.web.cfg
  replaceIn "org.osgi.service.http.port=8080" "org.osgi.service.http.port=cfg_port" $working/etc/org.ops4j.pax.web.cfg

  # elastic search
  replaceIn "cluster.name: opencast" "cluster.name: cfg_search_name" $working/etc/index/adminui/settings.yml
  replaceIn "cluster.name: opencast" "cluster.name: cfg_search_name" $working/etc/index/externalapi/settings.yml

  echo " Done."

  chown -R opencast:opencast $working_real/

  server_etc=$(awk '/org.opencastproject.server.url=http/ && /.za/' $working/etc/custom.properties | cut -d "=" -f2)

  echo
  echo "    Config:"
  echo "        $server_etc"
  echo "        $server_cfg"
  echo

  if [ "$server_etc" = "$server_cfg" ]; then

    # Configuration correct
    echo "    SUCCESS: Configuration is correct."
    echo

    #$START_SERVICE && service opencast start

    echo
    echo "    Cleaning ..."
    #rm $file
    #rm ${PROGNAME};

  else

    # Configuration correct
    echo "    ERROR: server.urls do not match ($working/etc/custom.properties)."
  fi

  echo $(service cfg_service status)

  echo
  echo "Done."
  echo
}

replaceIn() {

    st1=$1
    st2=$2
    out=$3
    shift; shift; shift;

    sed -i -e "s;.*$st1.*;$st2;" $out
}

check_directory() {

  dir=$1
  real=$2
  shift; shift

  if [ ! -d "$dir" ]; then

    # Directory does not exist - so create it
    if [ "$real" = "$dir" ]; then

        # Real directory
        mkdir $real
        chown -R $USER $real
    else

        # It should be a symlink
        if [ ! -d "$real" ]; then

          # so the real directory does not exist
          mkdir $real
          chown -R $USER $real
        fi

        ln -s $real $bak
        chown -R $USER $bak
    fi
  fi
}

cd $opt

[ "$(find $opt -type f -name $file -ls | wc -l)" -eq "1" ] && ERR_TAR=false || ERR_TAR=true

if $ERR_TAR; then
  echo
  $ERR_TAR && printf "Distribution tar file does not exist."
  exit 1
fi

main

