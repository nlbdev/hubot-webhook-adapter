hubot-webhook-adapter
=====================

This adapter sets up a webhook to receive messages from another "master" HuBot instance,
and sends the responses back to that HuBot instance.

The environment variable HUBOT_MASTER_URL must be set to the webhook URL for this the "master" HuBot instance.
The webhook URL for the main instance is also on the form `http://<ip>:8080/hubot/message`.

## Usage

```shell
# install webhook-adapter
npm install josteinaj/hubot-webhook-adapter --save

# set environment variable and run HuBot using the webhook-adapter
HUBOT_MASTER_URL='http://localhost:8080/hubot/message' bin/hubot -a webhook-adapter
```
