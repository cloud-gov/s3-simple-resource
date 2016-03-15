# Simple S3 Resource for [Concourse CI](http://concourse.ci)

Resource to upload files to S3. Unlike the [the official S3 Resource](https://github.com/concourse/s3-resource), this Resource doesn't care about files being versioned.

## Usage

Include the following in your Pipeline YAML file, replacing the values in the angle brackets (`< >`):

```yaml
resource_types:
- name: <resource type name>
  type: docker-image
  source:
    repository: 18fgsa/s3-resource-simple
resources:
- name: <resource name>
  type: <resource type name>
  source:
    access_key_id: {{aws-access-key}}
    secret_access_key: {{aws-secret-key}}
    bucket: {{aws-bucket}}
    filter: <optional, see note below>
jobs:
- name: <job name>
  plan:
  - <some Resource or Task that outputs files>
  - put: <resource name>
```

The `filter` parameter defines a filter for files that will be synced with S3. Leaving it out will sync the working directory. A few examples:

* Setting it to `results/*` will only sync the contents of the `results` directory.

* Setting it to `*.json` will sync all JSON files in the root directory.

See [the instructions for getting your AWS credentials](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html#cli-signup), then pass them and the bucket name in as [parameters](http://concourse.ci/fly-set-pipeline.html#section_parameters).

## Development

Requires [Docker](https://www.docker.com/).

1. Run `cp config.example.json config.json`.
1. Modify `config.json`.
    * See [the instructions for getting your AWS credentials](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html#cli-signup).
    * Exclude the `s3://` prefix/protocol for the `bucket`.
1. Run `./test/out </full/path/to/dir/or/file>`.
