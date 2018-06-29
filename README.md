# Azure-App-Service-Drupal8
A Docker solution for Drupal 8 on Azure Web App for Containers.

* [Overview](#overview)
* [Edit nginx.conf](#nginx)
* [Bring your own code](#byo-code)
* [Bring your own database](#byo-database)
* [Persistent Files](#files)
* [References](#references)


<a id="overview"></a>
## Overview

In September 2017 [Microsoft announced the general availability](https://azure.microsoft.com/en-us/blog/general-availability-of-app-service-on-linux-and-web-app-for-containers/) of Azure Web App for Containers and Azure App Service on Linux.

While it is possible to host Drupal websites with Azure App Service on Linux, its built-in image for PHP is not an ideal environment for Drupal in production. At SNP we turned our attention to the Web App for Containers resource as a way to provide custom Docker images for our customers. Our priorities were to:

* Include Drupal code in the image, not referenced from the Web App /home mount.
* Set custom permissions on the document root.
* Add Drush (the Drupal CLI) 
* Add more PHP extensions commonly used by Drupal 8 sites
* Add additional PHP configuration settings recommended for Drupal 8

This repository is an example solution for Drupal 8. By itself, this solution does not install Drupal. *You need to bring your own code and database.* (More about this below.) 

This repository is intended to satisfy common Drupal 8 use cases. We expect that users of this solution will customize it to varying degrees to match their application requirements. For instance, we include many PHP extensions commonly required by Drupal 8, but you may need to add one or more (or remove ones that you do not need).

### What about Drupal 7 (and 6)?

We specifically had Drupal 8 in mind for this solution. You can tweak it to support Drupal 7 (or 6). However, we have a separate [repository for Drupal 7](https://github.com/snp-technologies/Azure-App-Service-Drupal7). Unlike this Drupal 8 solution, the Drupal 7 solution uses Apache (rather than NGINX) and PHP 5.6 (rather than PHP 7.0).

<a id="nginx"></a>
## Edit nginx.conf

In the `nginx.conf` file, update `server_name www.example.com;` for your requirement.

<a id="byo-code"></a>
## Bring your own code

In the Dockerfile, there is a placeholder for your code: 
```
RUN git clone -b master [REPLACE WITH YOUR GIT REPOSITORY CLONE URL] .
```
Alternatively, you can use the Docker COPY command to copy code from your local disk into the image.

Near the top of the Dockerfile, there is a line:
`ARG GIT_TOKEN`. You can use this to pass the token as a build argument, if required to clone your git repo.

<a id="byo-database"></a>
## Bring your own database

MySQL (or other Drupal compatible database) is not included in the Dockerfile. You can add this to the Dockerfile, connect to another container hosting MySQL, or utilize an external database resource such as [Azure Database for MySQL](https://docs.microsoft.com/en-us/azure/mysql/).

### Connection string tip

The Azure Web App provides a setting into which you can enter a database connection string. This string is an environment variable within the Web App. At run-time, this environment variable can be interpreted in your settings.php file and parsed to populate your $databases array. However, in a container SSH session, the environment variable is not available. As a result Drush commands that require a database bootstrap level do not work.

An alternative to the Web App Connection string environment variable is to reference in settings.php a secrets file mounted to the Web App /home directory. For example, assume that we have a secrets.txt file that contains the string:
```
db=[mydb]&dbuser=[mydbuser]@[myazurewebappname]&dbpw=[mydbpassword]&dbhost=[mydb]
```
In our settings.php file, we can use the following code to populate the $databases array:
```
$secret = file_get_contents('/home/secrets.txt');
$secret = trim($secret);
$dbconnstring = parse_str($secret);
$databases = array (
  'default' => 
  array (
    'default' => 
    array (
      'database' => $db,
      'username' => $dbuser,
      'password' => $dbpw,
      'host' => $dbhost,
      'port' => '3306',
      'driver' => 'mysql',
      'prefix' => false,
    ),
  ),
);
```
<a id="files"></a>
## Persistent Files

In order to persist files, we leverage the Web App's /home directory that is mounted to Azure File Storage. The /home directory is accessible from the container. As such, we persist files by making directories for /files and /files/private and then setting symbolic links, as follows:
```
# Add directories for public and private files
RUN mkdir -p  /home/site/wwwroot/sites/default/files \
    && mkdir -p  /home/site/wwwroot/sites/default/files/private \
    && ln -s /home/site/wwwroot/sites/default/files  /var/www/html/docroot/sites/default/files \
    && ln -s /home/site/wwwroot/sites/default/files/private  /var/www/html/docroot/sites/default/files/private
```
<a id="references"></a>
## References

* [Docker Hub Official Repository for php](https://hub.docker.com/r/_/php/)
* [Web App for Containers home page](https://azure.microsoft.com/en-us/services/app-service/containers/)
* [Use a custom Docker image for Web App for Containers](https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image)
* [Azure App Service on Linux FAQ](https://docs.microsoft.com/en-us/azure/app-service/containers/app-service-linux-faq)
* [NGINX recipe for Drupal](https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/)

Git repository sponsored by [SNP Technologies](https://www.snp.com)

If you are interested in a WordPress container solution, please visit https://github.com/snp-technologies/Azure-App-Service-WordPress.
