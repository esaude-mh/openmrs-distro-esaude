# <img src="https://s3-eu-west-1.amazonaws.com/esaude/images/mozambican-emblem.png" height="50px"/> eSaude OpenMRS Distro <img src="https://s3-eu-west-1.amazonaws.com/esaude/images/mozambican-flag.png" height="45px"/>

eSaude [OpenMRS](http://www.openmrs.org/) distribution. This repository contains installation scripts and instructions.

For more information visit [esaude.org](http://esaude.org).

## Installation

### Automated

To automatically deploy the eSaude OpenMRS Distro using Vagrant navigate to the `infrastructure/vagrant` directory and run:

````
    $ vagrant up
````

## Access

The default OpenMRS interface can be accessed at [http://localhost:8258/openmrs](http://localhost:8258/openmrs).

The Angular apps can be accessed at [http://localhost:8258/poc/home](http://localhost:8258/poc/home).

* **user**: admin
* **pass**: eSaude123

## Development

To code for the Angular apps is in the [`esaude/openmrs-module-bahmniapps`](https://github.com/esaude/openmrs-module-bahmniapps) repo. Specifically, in the `ui` folder.

If you want to work on the apps and have the code changes reflect in the VM, change the `openmrs-esaude-distro.pp` file and remove the following stanza:

`````
  # Extract POC App
  exec { "extract-esaude-poc":
    cwd => "/esaude/infrastructure/artifacts",
    command => "mkdir -p /var/www/bahmniapps && unzip -o esaude-poc.zip -d /var/www/bahmniapps",
    require => [ Package["unzip"], Exec["download-esaude-poc"] ],
    notify  => Service["tomcat7"]
  }
````
Then add:
````
  config.vm.synced_folder "/path/to/bahmniapps/ui/folder", "/var/www/bahmniapps"
````
to your Vagrantfile and re-up the instance.