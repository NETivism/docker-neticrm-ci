## Cloud Run Job image

This branch is `drone-php8` plus what is needed to run the tests as a Cloud Run
Job: `/ci-run.sh` (job entrypoint) and `cloudbuild.yaml`, which builds the
image and updates the job. The test steps are not part of the image:
`/ci-run.sh` runs `tests/ci/run-all.sh` from the netiCRM source under test.

```
gcloud builds submit --config cloudbuild.yaml .
```

The image CMD is still supervisord, but this image is not published to
ghcr.io. To run the test environment locally, use the `drone-php8` branch:

```
git checkout drone-php8
./docker-start.sh host:port
```
