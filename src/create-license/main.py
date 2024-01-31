import os

from crhelper import CfnResource
import logging

import boto3
aws_client = boto3.client('secretsmanager')

from customer import Customer

import datetime
from dateutil.relativedelta import relativedelta

logging.basicConfig()
logger = logging.getLogger(__name__)

helper = CfnResource(
    json_logging=False,
    log_level='DEBUG',
    boto_level='CRITICAL'
)

def get_api_token():
  secret_arn = os.environ["SECRET_ARN"]
  response = aws_client.get_secret_value(SecretId=secret_arn)
  return response['SecretString']

def handler(event, context):
    helper(event, context)

@helper.create
def create(event, context):
    logger.info("creating resoource")
    api_token = get_api_token()
    properties = event.get('ResourceProperties')
    expiration_date = datetime.date.today() + relativedelta(years=1)
    logger.debug("creating customer")
    customer = Customer.create(api_token, properties.get('Name'), properties.get('Email'),
                               properties.get('AppId'), expiration_date, properties.get('Type'),
                               properties.get('Channel'))  

    return customer.id

@helper.delete
def delete(event, context):
    customerId = event['PhysicalResourceId']
    logger.info("deleting customer: {customer}".format(customer=customerId))
    api_token = get_api_token()
    properties = event.get('ResourceProperties')

    customer = Customer(api_token, properties.get('AppId'), customerId)
    customer.remove()

