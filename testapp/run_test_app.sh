#!/bin/bash

# Creates a test app and installs the plugin, then changes domain classes and does the required
# migrations. Change the hard-coded values in the variables below for your local system to use.
# Create a MySQL database 'migrationtest' and another called 'migrationtest_reports' for the
# multi-datasource tests; both databases need a 'migrationtest' user with password 'migrationtest'.

PLUGIN_DIR="/home/burt/workspace/grails/plugins/grails-database-migration"
TESTAPP_DIR="/home/burt/workspace/testapps/migration"
APP_NAME="migrationtests"
DB_NAME="migrationtest"
PLUGIN_VERSION="1.3"
DB_REPORTS_NAME="migrationtest_reports"

GRAILS_VERSION="2.0.4"
GRAILS_HOME="/usr/local/javalib/grails-2.0.4"

PATH=$GRAILS_HOME/bin:$PATH

APP_DIR="$TESTAPP_DIR/$APP_NAME"

verifyExitCode() {
	if [ $1 -ne 0 ]; then
		echo "ERROR: $2 failed with exit code $1"
		exit $1
	fi
}


mkdir -p $TESTAPP_DIR
cd $TESTAPP_DIR

rm -rf "$APP_NAME"
grails create-app "$APP_NAME" --stacktrace
verifyExitCode $? "create-app"

cd "$PLUGIN_DIR/testapp"

# initial domain classes
mkdir "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME"
cp Product.v1.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/Product.groovy"
cp Order.v1.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/Order.groovy"
cp OrderItem.v1.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/OrderItem.groovy"
cp Report.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/"

# config
cp BuildConfig.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/conf"
cp Config.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/conf"
cp DataSource.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/conf"

# scripts
cp PopulateData.groovy "$TESTAPP_DIR/$APP_NAME/scripts/"
cp VerifyData.groovy "$TESTAPP_DIR/$APP_NAME/scripts/"

# drop and create db
mysql -u "$DB_NAME" -p"$DB_NAME" -D "$DB_NAME" -e "drop database if exists $DB_NAME; create database $DB_NAME"
verifyExitCode $? "drop/create database"

# drop and create reports db
mysql -u "$DB_NAME" -p"$DB_NAME" -D "$DB_REPORTS_NAME" -e "drop database if exists $DB_REPORTS_NAME; create database $DB_REPORTS_NAME"
verifyExitCode $? "drop/create database"

cd $APP_DIR

grails compile --stacktrace

# install plugin

grails install-plugin "$PLUGIN_DIR/grails-database-migration-$PLUGIN_VERSION.zip" --stacktrace
verifyExitCode $? "install-plugin"

grails compile --stacktrace

# create the initial changelog and export to db
grails dbm-create-changelog --stacktrace
verifyExitCode $? "dbm-create-changelog"

# create the initial changelog for reports datasource and export to db
grails dbm-create-changelog --dataSource=reports --stacktrace
verifyExitCode $? "dbm-create-changelog for reports datasource"


grails dbm-generate-gorm-changelog initial.groovy --add --stacktrace
verifyExitCode $? "dbm-generate-gorm-changelog"

grails dbm-generate-gorm-changelog initialReports.groovy --add --stacktrace --dataSource=reports
verifyExitCode $? "dbm-generate-gorm-changelog for reports datasource"

grails dbm-update --stacktrace
verifyExitCode $? "dbm-update"

grails dbm-update --stacktrace --dataSource=reports
verifyExitCode $? "dbm-update for reports datasource"

# insert initial data
grails populate-data --stacktrace
verifyExitCode $? "populate-data"

# fix Order.customer by making it a domain class
cd -
cp Customer.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/"
cp Order.v2.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/Order.groovy"
cp customer.changelog.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/migrations"
cd -

grails dbm-register-changelog customer.changelog.groovy --stacktrace
verifyExitCode $? "dbm-register-changelog"
grails dbm-update --stacktrace
verifyExitCode $? "dbm-update"

# fix Product.prize -> Product.price
cd -
cp Product.v2.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/domain/$APP_NAME/Product.groovy"
cp price.changelog.groovy "$TESTAPP_DIR/$APP_NAME/grails-app/migrations"
cd -

grails dbm-register-changelog price.changelog.groovy --stacktrace
verifyExitCode $? "dbm-register-changelog"
grails dbm-update --stacktrace
verifyExitCode $? "dbm-update"

#verify data after migrations
grails verify-data --stacktrace
verifyExitCode $? "verify-data"

echo "SUCCESS!"



#cd /home/burt/workspace/testapps/migration
#rm -rf migrationtests
#grails create-app migrationtests
#mkdir migrationtests/grails-app/domain/migrationtests
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Product.v1.groovy migrationtests/grails-app/domain/migrationtests/Product.groovy
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Order.v1.groovy migrationtests/grails-app/domain/migrationtests/Order.groovy
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/OrderItem.v1.groovy migrationtests/grails-app/domain/migrationtests/OrderItem.groovy
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/BuildConfig.groovy migrationtests/grails-app/conf/
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Config.groovy migrationtests/grails-app/conf/
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/DataSource.groovy migrationtests/grails-app/conf/
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/PopulateData.groovy migrationtests/scripts/
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/VerifyData.groovy migrationtests/scripts/
#mysql -u migrationtest -pmigrationtest -D migrationtest -e "drop database if exists migrationtest; create database migrationtest"
#cd migrationtests/
#grails install-plugin /home/burt/workspace/grails/plugins/grails-database-migration/grails-database-migration-1.2.zip
#grails compile --stacktrace
#grails dbm-create-changelog --stacktrace
#grails dbm-generate-gorm-changelog initial.groovy --add --stacktrace

# remove createIndex changes in initial.groovy
#grails dbm-update --stacktrace

#grails populate-data --stacktrace
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Customer.groovy grails-app/domain/migrationtests/
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Order.v2.groovy grails-app/domain/migrationtests/Order.groovy
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/customer.changelog.groovy grails-app/migrations/
#grails dbm-register-changelog customer.changelog.groovy --stacktrace
#grails dbm-update --stacktrace
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/Product.v2.groovy grails-app/domain/migrationtests/Product.groovy
#cp /home/burt/workspace/grails/plugins/grails-database-migration/testapp/price.changelog.groovy grails-app/migrations/
#grails dbm-register-changelog price.changelog.groovy --stacktrace
#grails dbm-update --stacktrace
#grails verify-data --stacktrace
