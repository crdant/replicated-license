import os

from crhelper import CfnResource
import logging

import boto3
secrets_manager = boto3.client('secretsmanager')
s3 = boto3.client('s3')

from customer import Customer
from app import App

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
  response = secrets_manager.get_secret_value(SecretId=secret_arn)
  return response['SecretString']

def handler(event, context):
    helper(event, context)

@helper.create
def create(event, context):
    logger.info("creating resoource")

    api_token = get_api_token()
    properties = event.get('ResourceProperties')
    logger.debug("Loading application")
    app = App(api_token, properties.get('AppId'))

    expiration_date = datetime.date.today() + relativedelta(years=1)
    logger.debug("creating customer")
    customer = Customer.create(api_token, properties.get('Name'), properties.get('Email'),
                               app.id, expiration_date, properties.get('Type'),
                               properties.get('Channel'))  

    license_id = customer.installationId
    helper.Data.update({'DownloadToken': f'{license_id}'})

    license_data = customer.license()
    bucket_name = os.environ["LICENSE_BUCKET_NAME"]
    bucket_domain = os.environ["LICENSE_BUCKET_DOMAIN"]
    file_key = "{customer}.yaml".format(customer=customer.id)
    logger.debug(f'saving license to file {file_key} in bucket {bucket_name}')
    s3.put_object(Bucket=bucket_name, Key=file_key, Body=license_data)
    helper.Data.update({'LicenseFileUri': f'https://{bucket_domain}/{file_key}'})

    app_domain = app.api_host
    slug = app.slug
    channel = properties.get('Channel').lower()
    helper.Data.update({'InstallerUri': f'https://{app_domain}/embedded/{slug}/{channel}'})

    return customer.id

@helper.delete
def delete(event, context):
    customerId = event['PhysicalResourceId']
    logger.info("deleting customer: {customer}".format(customer=customerId))
    api_token = get_api_token()
    properties = event.get('ResourceProperties')

    customer = Customer(api_token, properties.get('AppId'), customerId)

    bucket_name = os.environ["LICENSE_BUCKET_NAME"]
    file_key = "{customer}.yaml".format(customer=customer.id)
    s3.delete_object(Bucket=bucket_name, Key=file_key)

    customer.remove()

