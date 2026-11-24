## Cloud Run Job image

This branch is `drone-php83-d10` plus what is needed to run the tests as a Cloud Run
Job: `/ci-run.sh` (job entrypoint), `/usr/local/bin/run-all.sh` and
`cloudbuild.yaml`, which builds the image and updates the job.

```
gcloud builds submit --config cloudbuild.yaml .
```

The image CMD is still supervisord, but this image is not published to
ghcr.io. To run the test environment locally, use the `drone-php83-d10` branch:

```
git checkout drone-php83-d10
./docker-start.sh host:port
```
