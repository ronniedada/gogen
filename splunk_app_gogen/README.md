## GOGEN Modular Input Wrapper v0.5

## Overview

This app is Splunk Modular Input wrapper for streaming GoGen generated events : https://github.com/coccyx/gogen

## Dependencies

* Splunk version 5+
* Python runtime if installing on a Universal Forwarder
* Supported on OSX , Windows , Linux
* Network access to http://api.gogen.io to download the gogen executable, this will by dynamically downloaded for you the first time you run the Modular Input and placed in the splunk_app_gogen/bin directory.If you want to update this executable , simply delete the previously downloaded executable and restart the Modular Input stanza.

## Setup

* Untar the release to your `$SPLUNK_HOME/etc/apps` directory
* Restart Splunk
* Browse to Settings -> Data Inputs -> Gogen to setup a new stanza

## Modular Input Configuration

* Descriptions of the fields you can configure in your stanzas in inputs.conf are in README/inputs.conf.spec and also annotated in the web interface if you are setting up your stanzas there.These fields are basically mappings through to the various command line arguments you can pass to the gogen executable.

## Gogen Configuration

* Documentation can be found here : https://github.com/coccyx/gogen/blob/master/README.md
* YAML configuration files, samples files and custom lua generator scripts can be placed in splunk_app_gogen/gogen_assets

## Logging

Standard logging is written to SPLUNK_HOME/var/log/splunk/gogen.log
Any system errors can be searched for : index=_internal error gogen.py

## Troubleshooting

* You are using Splunk version 5+ ?
* Look for any errors in the logs
* Any firewalls blocking outgoing HTTP calls to retrieve the gogen binary ?
* Are you running on a supported OS platform ?
* If running on a Universal Forwarder , do you have a Python 2.7 runtime installed ?
* Was the gogen executable downloaded to splunk_app_gogen/bin  ?