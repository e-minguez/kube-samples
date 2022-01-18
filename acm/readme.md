* Check idrac firwmare version
* Check if the idrac is stuck and reset it otherwise
* Remove all the pending jobs (it should be done automatically)
* Disable the provisioning network if not needed
* Use `echo -n "pass" | base64 -w0` to encode the password and avoid new line characters
* use idrac-redfish+https for Dell + httpS
* additionalNTPSources if needed