# InfluxDB AMI

This folder shows an example of how to use the 
[install-influxdb](https://github.com/gruntwork-io/terraform-aws-influx/tree/master/modules/install-influxdb)
modules with [Packer](https://www.packer.io/) to create [Amazon Machine 
Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) that have 
[InfluxDB Enterprise](https://www.influxdata.com/time-series-platform/influxdb/), and its dependencies installed on top of:
 
1. Ubuntu 18.04
1. Amazon Linux 2

## Quick start

To build the InfluxDB AMI:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `influxdb.json` Packer template to specify the AWS region and InfluxDB
   version you wish to use.
1. To build an Ubuntu AMI for InfluxDB Enterprise: `packer build -only=ubuntu-ami influxdb.json`.
1. To build an Amazon Linux AMI for InfluxDB Enterprise: `packer build -only=amazon-linux-ami influxdb.json`.

When the build finishes, it will output the IDs of the new AMIs. To see how to deploy this AMI, check out the 
[influxdb-cluster-simple](influxdb-cluster-simple) and
[influxdb-multi-cluster](influxdb-multi-cluster) 
examples.

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
      "/tmp/tick_stack/modules/install-influxdb/install-influxdb --version {{user `influxdb_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```
