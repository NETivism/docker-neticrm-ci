## Usage 

- This will pull last neticrm, automatic running testing.
- This will also mapping port 8888 <-> 80 to container, you can copy nginx setting to enable web browsing

```
docker pull netivism/neticrm-ci
./docker-start.sh DRUPAL-VERSION netiCRM-VERSION
./docker-start.sh 7.37 2.0-dev
```
