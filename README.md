# `docker-image-retag-action`

A simple Github Action for pulling a Docker image from a repository and
re-tagging it. Most likely used as part of an image promotion process.

## Basic Flow

The idea here is that when you are ready to release a known-good version of
your application, you have already built, published and tested an artifact.
_That artifact_ is the one that you then want to release to the world as a
known quantity. In this action, we simply pull a known-good docker image, retag
it with the desired version number, and re-push it.

_There is specifically no `docker build ...` code in this action on purpose._

1. Developer writes code and merges it into `HEAD`.
2. CI system builds image and tags it (eg: `test-$SHA`). (_This is your
   existing build/release system. It is important that you publish the image
   with a reference to the Git SHA in some way so that this action can later
   pull this image down._)
3. Staging/Testing environment pulls `myapp:test-$SHA` and validates that it is
   good.
4. Developer tags (or uses a Github Release) `$SHA` in Git repository as
   `v1.2.3`
5. This action is triggered to `docker pull myapp:test-$SHA && docker tag ...
   && docker push`

## Usage

```yaml
# .github/workflows/release.yml
name: RetagAndRelease

# Generally you want to run this on a `release` - but you could also
# selectively run this on a `push` where you exclude all branches from builds.
on: [release]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master

    - name: Retag Docker Image for Production
      uses: Nextdoor/docker-image-retag-action@main
      
      # If you are pushing an image to ECR, include AWS credentials in the
      # environment. You do not need to set the `AWS_REGION` because that will be
      # automatically picked up from the `image` value.
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      with:
        # This is the image name in its fully qualified format. If you use an
        # ECR repository, you must also set the AWS credentials (see above).
        image: 111111111111.dkr.ecr.us-west-2.amazonaws.com/my-image

        # This is the "source tag" to pull - this tag must already exist in the
        # Docker registry and be discoverable. Typically you would build the
        # image with the Git SHA in its tag, which makes it easy to reference here.
        #
        # Eg: If your CI system builds `docker build . -t myapp:test-$(git
        # rev-parse)`.. then you would use `test-${{ github.sha }}` here.
        #
        source_tag: ${{ github.sha }}

        # This is the name of the destination tag you want to push. You can
        # templatize this with the standard Github environment variables for
        # actions.
        dest_tag: ${{ github.ref }}

        # Set the action to run in `set -x` mode for very verbose logging. Set
        # to `true` or `false`.
        #
        # verbose: false

        # Optionally run the action in 'dry' mode - where all of the normal
        # actions happen, but no `docker push` happens. Useful for initial
        # testing of the configuration. Set to `true` or `false`.
        #
        # dry: false
```

The action will first log into AWS ECR, then pull down
`111111111111.dkr.ecr.us-west-2.amazonaws.com/my-image:test-$SHA`, tag it as
`111111111111.dkr.ecr.us-west-2.amazonaws.com/my-image:<release tag>` and then
push that image.

## Amazon ECR Credentials

If your `image` value points to an AWS ECR repository, then the action will
automatically log into AWS on your behalf. It expects that you will set the
`AWS_ACCES_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
