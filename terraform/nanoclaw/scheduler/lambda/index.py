import boto3
import os


def handler(event, context):
    ec2 = boto3.client("ec2", region_name=os.environ["REGION"])
    instance_id = os.environ["INSTANCE_ID"]
    action = os.environ["ACTION"]

    if action == "start":
        ec2.start_instances(InstanceIds=[instance_id])
        print(f"Started {instance_id}")
    elif action == "stop":
        ec2.stop_instances(InstanceIds=[instance_id])
        print(f"Stopped {instance_id}")
    else:
        raise ValueError(f"Unknown action: {action}")
