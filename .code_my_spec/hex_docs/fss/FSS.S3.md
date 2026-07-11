# FSS.S3

Specification for accessing AWS S3 resources.

## parse/2

Parses a URL in the format `s3://bucket/resource-key`.

## Options

  * `:config` - It expects a `Config.t()` or a `Keyword.t()` with the keys
    representing the attributes of the `Config.t()`. By default it is `nil`,
    which means that we are going to try to fetch the credentials and configuration
    from the system's environment variables.

    The following env vars are read:

    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
    - `AWS_REGION` or `AWS_DEFAULT_REGION`
    - `AWS_SESSION_TOKEN`

    In case the endpoint is not provided, we compute a valid one for the AWS S3 API,
    That is going to follow the path style. The endpoint is not going to include the
    `:bucket` in it, being necessary to do that when using this FSS entry.

    See https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-bucket-intro.html
    for more details.

## config_from_system_env/0

Builds a `Config.t()` reading from the system env.