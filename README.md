# Azure-App-Service-Drupal8
A Docker solution for Drupal 8 on Azure Web App for Containers.

- [Azure-App-Service-Drupal8](#azure-app-service-drupal8)
  - [Overview](#overview)
    - [Some history](#some-history)
  - [Bring your own code](#bring-your-own-code)
  - [Bring your own database](#bring-your-own-database)
    - [Connection string tip](#connection-string-tip)
  - [Persistent Files](#persistent-files)
  - [Troubleshooting Tips](#troubleshooting-tips)
    - [My theme is not loading!](#my-theme-is-not-loading)
    - [When I visit my site, I get a WSOD!](#when-i-visit-my-site-i-get-a-wsod)
    - [I can't connect to my database!](#i-cant-connect-to-my-database)
  - [References](#references)


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

### Some history

When originally committed as a public repository on GitHub, the solution was very different - the base image was nginx; php 7.0 was installed in the container upon build; and Composer was included. The original deployment has been archived as branch `nginx-php7.0`.

While considering an upgrade to php 7.3, we decided to take a different approach, more consistent with our [Drupal 7 on App Service](https://github.com/snp-technologies/Azure-App-Service-Drupal7) solution and the official [Docker Hub image for Drupal](https://hub.docker.com/_/drupal/). You'll find in this latest version:
- Base image is `php:7.3-apache-stretch`
- Rsyslog support
- ARM Template for your Web App for Containers resources that you can include in a release pipeline.

<a id="byo-code"></a>
## Bring your own code

In the Dockerfile, there is a placeholder for your code: 
```
RUN git clone -b $BRANCH https://$GIT_TOKEN@github.com/$GIT_REPO.git .
```
Note the use of build args for `$BRANCH`, `$GIT_TOKEN`, and `$GIT_REPO`.

Alternatively, you can use the Docker COPY command to copy code from your local disk into the image.

Our recommendation is to place your code in a directory directly off the root of the repository. In this repository we provide a `/docroot` directory into which you can place your application code. In the Dockerfile, it is assumed that the application code is in the `/docroot` directory. Feel free, of course, to rename the directory with your preferred naming convention.

> :warning: If you use a different directory as your document root, remember to change the `DocumentRoot` value in `apache2.conf`.

<a id="byo-database"></a>
## Bring your own database

MySQL (or other Drupal compatible database) is not included in the Dockerfile. You can add this to the Dockerfile, connect to another container hosting MySQL, or utilize an external database resource such as [Azure Database for MySQL](https://docs.microsoft.com/en-us/azure/mysql/).

### Connection string tip

Azure Web App provides a setting into which you can enter a database connection string. This string is an environment variable within the Web App. At run-time, this environment variable can be interpreted in your `settings.php` file and parsed to populate your $databases array. **However**, in a container SSH session, the environment variable is not available. As a result Drush commands do not work if they require a database bootstrap level.

An alternative to the Web App, connection string environment variable is to reference in `settings.php` a secrets file mounted to the Web App `/home` directory. For example, assume that we have a `secrets.txt` file that contains the string:
```
db=[mydb]&dbuser=[mydbuser]@[myazurewebappname]&dbpw=[mydbpassword]&dbhost=[mydb]
```
In our `settings.php` file, we can use the following code to populate the `$databases` array:
```
$secret = file_get_contents('/home/secrets.txt');
$secret = trim($secret);
$dbconnstring = parse_str($secret,$output);
$databases = array (
  'default' =>
  array (
    'default' =>
    array (
      'database' => $output['db'],
      'username' => $output['dbuser'],
      'password' => $output['dbpw'],
      'host' => $output['dbhost'],
      'port' => '3306',
      'driver' => 'mysql',
      'prefix' => false,
    ),
  ),
);
```
<a id="files"></a>
## Persistent Files

> :warning: Web App for Containers mounts an SMB share to the `/home` directory. This is provided by setting the `WEBSITES_ENABLE_APP_SERVICE_STORAGE` app value  to `true`.
> 
> If the `WEBSITES_ENABLE_APP_SERVICE_STORAGE` setting is `false`, the `/home` directory will not be shared across scale instances, and files that are written there will not be persisted across restarts.
> 
To persist files, we leverage the Web App's `/home` directory that is mounted to Azure File Storage. The `/home` directory is accessible from the container. As such, we persist files by making directories for `/files` and `/files/private` and then setting symbolic links in our Dockerfile, as follows:
```
# Add directories for public and private files
RUN mkdir -p  /home/site/wwwroot/sites/default/files \
    && mkdir -p  /home/site/wwwroot/sites/default/files/private \
    && ln -s /home/site/wwwroot/sites/default/files  /var/www/html/docroot/sites/default/files \
    && ln -s /home/site/wwwroot/sites/default/files/private  /var/www/html/docroot/sites/default/files/private
```
Similarly we persist log files such as `php-error.log` and `drupal.log`
```
...
&& mkdir -p /home/LogFiles \
&& ln -s /home/LogFiles /var/log/apache2
```   
You can also use the `/home` mount for `settings.php` configurations that use files outside the repo. For example:
```
* Location of the site configuration files.

settings['config_sync_directory'] = '/home';

/**
* Salt for one-time login links, cancel links, form tokens, etc. 
*
* Include your salt value in a salt.txt file and reference it with:
*/
$settings['hash_salt'] = file_get_contents('/home/salt.txt');
```

<a id="troubleshooting"></a>
## Troubleshooting Tips

### My theme is not loading!

1. Log in as an administrator and clear all caches. You can do this from the `/admin/config/development/performance` page, or via the drush command `drush cr` in an SSH session via Kudu. Clear your browser cache and reload  your home page. If the theme still does not load, try visiting the site from a different browser.
   
2. If these steps fail to solve the problem, proceed with the tips below.

### When I visit my site, I get a WSOD!

1. Check your php-error.log. Perhaps there is a glaring problem.

2. Verify that your website code is in the `/var/www/html/docroot` directory. Start an SSH session via Kudu, change to your `/var/www/html/docroot` directory, list directory contents. It should resemble this:
```
root@356db9bf9fdf:/home# cd /var/www/html/docroot/                                                                                                          root@356db9bf9fdf:/var/www/html/docroot# ls                                                                                                                 INSTALL.txt   composer.json      index.php   sites       web.config                                                                                         LICENSE.txt   composer.lock      modules     themes                                                                                                         README.txt    core               profiles    update.php                                                                                                     autoload.php  example.gitignore  robots.txt  vendor
```
3. While in the `/var/www/html/docroot` directory, check your site status with drush.  It should resemble this:
```
root@356db9bf9fdf:/var/www/html/docroot# drush status
Drupal version                  :  8.8.5                                                                                                                    Site URI                        :  http://default                                                                                                           Database driver                 :  mysql                                                                                                                    Database hostname               :  mydatabase.mysql.database.azure.com                                                                                      Database port                   :  3306                                                                                                                     Database username               :  user@mydatabase                                                                                                       Database name                   :  mydbname                                                                                                              Database                        :  Connected                                                                                                                Drupal bootstrap                :  Successful                                                                                                               Drupal user                     :                                                                                                                           Default theme                   :  umami                                                                                                                    Administration theme            :  seven                                                                                                                    PHP configuration               :  /usr/local/etc/php/php.ini                                                                                               PHP OS                          :  Linux                                                                                                                    Drush script                    :  /usr/local/bin/drush                                                                                                     Drush version                   :  8.1.13                                                                                                                   Drush temp directory            :  /tmp                                                                                                                     Drush configuration             :                                                                                                                           Drush alias files               :                                                                                                                           Install profile                 :  demo_umami                                                                                                               Drupal root                     :  /var/www/html/docroot                                                                                                    Drupal Settings File            :  sites/default/settings.php                                                                                               Site path                       :  sites/default                                                                                                            File directory path             :  sites/default/files                                                                                                      Temporary file directory path   :  /tmp                                                                                                                     Sync config path                :  /home
```
4. While in the `/var/www/html/docroot` directory, rebuild your cache with `drush cache-rebuild` or `drush cr`.

### I can't connect to my database!

1. If you are using an Azure Database for MySQL resource, ensure that you have a Firewall rule configured in the resource's Connection Security settings.

2. Validate that you can connect to the database from container. Start an SSH session via Kudu and from the `/home` directory (or any directory for that matter) upload a simple php file to check your connection string. Here is an example of a file named `php-pdo-test.php` uploaded to the `/home` directory.

```
<?php

$secret = file_get_contents('/home/secrets.txt');
$secret = trim($secret);

$dbconnstring = parse_str($secret,$output);

$database = $output['db'];
$username = $output['dbuser'];
$password = $output['dbpw'];
$dbhost = $output['dbhost'];

$dsn = 'mysql:dbname=' . $database .';host=' . $dbhost;

try {
    $dbh = new PDO($dsn, $username, $password);
} catch (PDOException $e) {
    echo 'Connection failed: ' . $e->getMessage();
}

$sql = 'SELECT u.`uid`, u.`uuid` FROM `users` AS u';
foreach ($dbh->query($sql) as $row) {
    echo $row['uid'] . "\t";
    echo $row['uuid'] . "\n";
}

?>
```
Run file from the command line. Your output should resemble:
```
root@356db9bf9fdf:/home# php php-pdo-test.php                                                                                                               3       2dad0fee-2d31-4acf-951f-acb816a0e673                                                                                                                5       6d60461c-81f8-4583-9bbd-47d130e8abac                                                                                                                1       7b07bdc7-fe74-4a99-bc7a-e9aae49fc46e                                                                                                                0       7d730abc-a986-4a72-9a3e-62eb8805e68f                                                                                                                7       956730d4-23d8-4c2e-a755-daa9146433d4                                                                                                                4       aad4b8a9-6a7d-4063-b0ec-ff3e3a1237ee                                                                                                                2       ab1ddaaf-2472-4634-b390-8904dd16ab73                                                                                                                6       fe18b850-7149-435e-b6cf-3b6166b8ff86
```

<a id="references"></a>
## References

* [Web App for Containers home page](https://azure.microsoft.com/en-us/services/app-service/containers/)
* [Use a custom Docker image for Web App for Containers](https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image)
* [Understanding the Azure App Service file system](https://github.com/projectkudu/kudu/wiki/Understanding-the-Azure-App-Service-file-system)
* [Azure App Service on Linux FAQ](https://docs.microsoft.com/en-us/azure/app-service/containers/app-service-linux-faq)
* [Things You Should Know: Web Apps and Linux](https://docs.microsoft.com/en-us/archive/blogs/waws/things-you-should-know-web-apps-and-linux)
* [Docker Hub Official Repository for php](https://hub.docker.com/r/_/php/)

Git repository sponsored by [SNP Technologies](https://www.snp.com)

If you are interested in a WordPress container solution, please visit https://github.com/snp-technologies/Azure-App-Service-WordPress.