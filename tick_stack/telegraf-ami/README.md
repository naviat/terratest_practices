# Telegraf AMI

This folder shows an example of how to use the 
[install-telegraf](/modules/install-telegraf)
modules with [Packer](https://www.packer.io/) to create [Amazon Machine 
Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) that have 
[Telegraf](https://www.influxdata.com/time-series-platform/telegraf/), and its dependencies installed on top of:
 
1. Ubuntu 18.04
1. Amazon Linux 2

Telegraf is usually installed as a collection agent on your application's EC2 instance(s).
This Telegraf AMI is only useful for standing up Telegraf to pull remote data or accept data from a remote service,
e.g. connecting to a queue like Kafka/PubSub or using it as a scraper to pull prometheus metrics.

## Quick start

To build the Telegraf AMI:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `telegraf.json` Packer template to specify the AWS region and Telegraf
   version you wish to use.
1. To build an Ubuntu AMI for Telegraf: `packer build -only=telegraf-ami-ubuntu telegraf.json`.
1. To build an Amazon Linux AMI for Telegraf: `packer build -only=telegraf-ami-amazon-linux telegraf.json`.

## Creating your own Packer template for production usage

When creating your own Packer template for production usage, you can copy the example in this folder more or less 
exactly, except for one change: we recommend replacing the `file` provisioner with a call to `git clone` in a `shell` 
provisioner. Instead of:

```json
{
  "provisioners": [{
    "type": "file",
    "source": "{{template_dir}}/tick_stack",
    "destination": "/tmp"
  },{
    "type": "shell",
    "inline": [
      "/tmp/tick_stack/modules/install-telegraf/install-telegraf --version {{user `version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

