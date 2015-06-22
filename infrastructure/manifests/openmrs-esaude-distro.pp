# Variables
$mysql_root_password = "esaude"
$mysql_esaude_user = "esaude"
$mysql_esaude_user_password = "esaude"
$mysql_esaude_database_name = "openmrs"

# Defaults for exec
Exec {
  path => ["/bin", "/usr/bin", "/usr/local/bin", "/usr/local/sbin"],
  user => "root"
}

# Grab the clean esaude database from S3
exec { "download-esaude-database":
  cwd => "/esaude/infrastructure/artifacts",
  command => "wget https://s3-eu-west-1.amazonaws.com/esaude/openmrs-distro-esaude/openmrs-distro-esaude.sql.zip",
  creates => "/esaude/infrastructure/artifacts/openmrs-distro-esaude.sql.zip",
  timeout => 0
}

# Grab the OpenMRS WAR from S3
exec { "download-esaude-war":
  cwd => "/esaude/infrastructure/artifacts",
  command => "wget https://s3-eu-west-1.amazonaws.com/esaude/openmrs-distro-esaude/openmrs.war",
  creates => "/esaude/infrastructure/artifacts/openmrs.war",
  timeout => 0
}

# Grab the OpenMRS modules from S3
exec { "download-esaude-modules":
  cwd => "/esaude/infrastructure/artifacts",
  command => "wget https://s3-eu-west-1.amazonaws.com/esaude/openmrs-distro-esaude/openmrs-distro-esaude-modules.zip",
  creates => "/esaude/infrastructure/artifacts/openmrs-distro-esaude-modules.zip",
  timeout => 0
}

# Install MySQL server
package { "mysql-server-5.6":
  ensure => "latest"
}

# Install zip
package {"zip":
  ensure  => latest,
}

# Install unzip
package {"unzip":
  ensure  => latest,
}

# Extract the database
exec { "extract-esaude-database":
  cwd => "/esaude/infrastructure/artifacts",
  command => "unzip openmrs-distro-esaude.sql.zip",
  creates => "/esaude/infrastructure/artifacts/openmrs-distro-esaude.sql",
  require => Package["unzip"]
}

service { "mysql":
  enable => true,
  ensure => running,
  require => Package["mysql-server-5.6"],
}

exec { "mysqlpass":
  command => "mysqladmin -uroot password $mysql_root_password",
  require => Service["mysql"]
}

exec { "openmrs-user-password":
  alias => "mysqluserpass",
  command => "mysql -uroot -p${mysql_root_password} -e \"CREATE USER '${mysql_esaude_user}'@'localhost' IDENTIFIED BY '${mysql_esaude_user_password}';\"",
  require => Exec["mysqlpass"]
}

exec { "create-openmrs-db":
  unless => "mysql -uroot -p${mysql_root_password} openmrs",
  command => "mysql -uroot -p${mysql_root_password} -e \"create database openmrs;\"",
  require => [ Service["mysql"], Exec["mysqlpass"] ],
}

exec { "openmrs-user-privileges":
  command => "mysql -uroot -p${mysql_root_password} -e \"GRANT ALL PRIVILEGES ON openmrs.* TO '${mysql_esaude_user}'@'localhost';\"",
  require => [ Exec["openmrs-user-password"], Exec["create-openmrs-db"] ]
}

exec { "apply-db-dump":
  command => "mysql -uroot -p${mysql_root_password} openmrs < /esaude/infrastructure/artifacts/openmrs-distro-esaude.sql",
  require => [ Service["mysql"], Exec["create-openmrs-db"], Exec["extract-esaude-database"] ]
}

# Install Java 6
package { "openjdk-6-jdk":
  ensure  => latest
}

# Install Tomcat
package { "tomcat7":
  ensure  => latest,
  require => Package["openjdk-6-jdk"]
}

# Define Tomcat service
service { "tomcat7":
    ensure  => "running",
    enable  => "true",
    require => Package["tomcat7"],
}

# Configure Tomcat memory
file { "/usr/share/tomcat7/bin/setenv.sh":
  source  => "/esaude/infrastructure/artifacts/setenv.sh",
  owner => "tomcat7",
  group   => "tomcat7",
  mode  => "a+x",
  require => Package["tomcat7"],
  notify  => Service["tomcat7"]
}

# Create OpenMRS directory structure
file { [ "/usr/share/tomcat7/.OpenMRS", "/usr/share/tomcat7/.OpenMRS/modules"]:
    ensure  => "directory",
    owner => "tomcat7",
  group   => "tomcat7",
  require => Package["tomcat7"]
}

# Copy runtime properties into place
file { "/usr/share/tomcat7/.OpenMRS/bahmnicore.properties":
  source  => "/esaude/infrastructure/artifacts/bahmnicore.properties",
  owner => "tomcat7",
  group   => "tomcat7",
  require => File["/usr/share/tomcat7/.OpenMRS"],
  notify  => Service["tomcat7"]
}

file { "/usr/share/tomcat7/.OpenMRS/openmrs-runtime.properties":
  source  => "/esaude/infrastructure/artifacts/openmrs-runtime.properties",
  owner => "tomcat7",
  group   => "tomcat7",
  require => File["/usr/share/tomcat7/.OpenMRS"],
  notify  => Service["tomcat7"]
}

# Copy modules into place
exec { "install-esaude-modules":
  cwd => "/esaude/infrastructure/artifacts",
  command => "unzip -o openmrs-distro-esaude-modules.zip -d /usr/share/tomcat7/.OpenMRS/modules",
  require => [ Package["unzip"], File["/usr/share/tomcat7/.OpenMRS/openmrs-runtime.properties"] ],
  notify  => Service["tomcat7"]
}

# Deploy OpenMRS WAR file
file { "/var/lib/tomcat7/webapps/openmrs.war":
  source  => "/esaude/infrastructure/artifacts/openmrs.war",
  owner => "tomcat7",
  group   => "tomcat7",
  require => Exec["install-esaude-modules"],
  notify  => Service["tomcat7"]
}

# Fix Tomcat index
file { "/var/lib/tomcat7/webapps/ROOT/index.html":
  source  => "/esaude/infrastructure/artifacts/tomcat-index.html",
  owner => "tomcat7",
  group   => "tomcat7",
  require => File["/var/lib/tomcat7/webapps/openmrs.war"]
}

# Fix Tomcat lib directory ownership (see https://wiki.openmrs.org/questions/66814449/why-does-openmrs-2.0-hang-at-startup-with-event-module)
file { "/var/lib/tomcat7":
  owner => "tomcat7",
  group   => "tomcat7",
  require  => Package["tomcat7"]
}

# Install Apache
class { 'apache':  }
apache::module { 'proxy': }
apache::module { 'proxy_http': }

# Configure default host
apache::vhost { "default":
    source      => "/esaude/infrastructure/artifacts/000-default.conf",
    template    => "",
    priority  => "000"
}

# Create directories
exec { "create-directories":
  command => "mkdir -p /var/www/patient_images && mkdir -p /var/www/document_images"
}

#################
# Setup POC App #
#################

# Grab POC App
exec { "download-esaude-poc":
  cwd => "/esaude/infrastructure/artifacts",
  command => "wget https://s3-eu-west-1.amazonaws.com/esaude/openmrs-distro-esaude/esaude-poc.zip",
  creates => "/esaude/infrastructure/artifacts/esaude-poc.zip",
  timeout => 0
}

# Extract POC App
exec { "extract-esaude-poc":
  cwd => "/esaude/infrastructure/artifacts",
  command => "mkdir -p /var/www/bahmniapps && unzip -o esaude-poc.zip -d /var/www/bahmniapps",
  require => [ Package["unzip"], Exec["download-esaude-poc"] ],
  notify  => Service["tomcat7"]
}

# Grab POC Config
exec { "download-esaude-poc-config":
  cwd => "/esaude/infrastructure/artifacts",
  command => "wget https://s3-eu-west-1.amazonaws.com/esaude/openmrs-distro-esaude/esaude-poc-config.zip",
  creates => "/esaude/infrastructure/artifacts/esaude-poc-config.zip",
  timeout => 0
}

# Extract POC Config
exec { "extract-esaude-poc-config":
  cwd => "/esaude/infrastructure/artifacts",
  command => "mkdir -p /var/www/bahmni_config && unzip -o esaude-poc-config.zip -d /var/www/bahmni_config",
  require => [ Package["unzip"], Exec["download-esaude-poc-config"] ],
  notify  => Service["tomcat7"]
}
