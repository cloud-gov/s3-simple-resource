# Simple S3 Resource for [Concourse CI](http://concourse.ci)

Resource to upload files to S3. Unlike the [the official S3 Resource](https://github.com/concourse/s3-resource), this Resource can upload or download multiple files.

## Usage

Include the following in your Pipeline YAML file, replacing the values in the angle brackets (`< >`):

```yaml
resource_types:
  - name: <resource type name>
    type: registry-image
    source:
      aws_access_key_id: ((ecr_aws_key))
      aws_secret_access_key: ((ecr_aws_secret))
      repository: s3-resource-simple
      aws_region: ((aws_region))
      tag: ((tag))
resources:
  - name: <resource name>
    type: <resource type name>
    source:
      access_key_id: { { aws-access-key } }
      secret_access_key: { { aws-secret-key } }
      bucket: { { aws-bucket } }
      path:
        [
          <optional>,
          use to sync to a specific path of the bucket instead of root of bucket,
        ]
      change_dir_to: [<optional, see note below>]
      options: [<optional, see note below>]
      region: <optional, see below>
jobs:
  - name: <job name>
    plan:
      - <some Resource or Task that outputs files>
      - put: <resource name>
```

## AWS Credentials

The `access_key_id` and `secret_access_key` are optional and if not provided the EC2 Metadata service will be queried for role based credentials.

## change_dir_to

The `change_dir_to` flag lets you upload the contents of a sub-directory without including the directory name as a prefix in your bucket.
Given the following directory `test`:

```
test
├── 1.json
└── 2.json
```

and the config:

```
- name: test
  type: s3-resource-simple
  source:
    change_dir_to: test
    bucket: my-bucket
    [...other settings...]
```

`put` will upload 1.json and 2.json to the root of the bucket. By contrast, with `change_dir_to` set to `false` (the default), 1.json and 2.json will be uploaded as `test/1.json` and `test/2.json`, respectively.
This flag has no effect on `get` or `check`.

## Options

The `options` parameter is synonymous with the options that `aws cli` accepts for `sync`. Please see [S3 Sync Options](http://docs.aws.amazon.com/cli/latest/reference/s3/sync.html#options) and pay special attention to the [Use of Exclude and Include Filters](http://docs.aws.amazon.com/cli/latest/reference/s3/index.html#use-of-exclude-and-include-filters).

Given the following directory `test`:

```
test
├── results
│   ├── 1.json
│   └── 2.json
└── scripts
    └── bad.sh
```

we can upload _only_ the `results` subdirectory by using the following `options` in our task configuration:

```yaml
options:
  - "--exclude '*'"
  - "--include 'results/*'"
```

### Region

Interacting with some AWS regions (like London) requires AWS Signature Version 4. This options allows you to explicitly specify region where your bucket is
located (if this is set, AWS_DEFAULT_REGION env variable will be set accordingly).

```yaml
region: eu-west-2
```
