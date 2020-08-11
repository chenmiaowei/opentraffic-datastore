#!/usr/bin/env bash

usage(){
  echo "Usage: $0 [prod|dev] [us-east-1]"
  exit 2
}

if [ -z $2 ]; then
  usage
else
  case $1 in
    'prod'|'dev')
      ENV=$1
      ;;
    *)
      usage
      ;;
  esac

  case $2 in
    'us-east-1')
      REGION=$2
      ;;
    *)
      usage
      ;;
  esac
fi

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
  aws --version
  aws configure set default.region $REGION
  aws configure set default.output json
}

deploy_cluster() {
  family="opentraffic-datastore-$ENV"

  make_task_def
  register_definition

  if [[ $(aws ecs update-service --cluster datastore-$ENV --service opentraffic-datastore-$ENV --task-definition $revision | $JQ '.service.taskDefinition') != $revision ]]; then
    echo "Error updating service."
    return 1
  fi

  # wait for older revisions to disappear
  # not really necessary, but nice for demos
  for attempt in {1..60}; do
    if stale=$(aws ecs describe-services --cluster datastore-$ENV --services opentraffic-datastore-$ENV | \
            $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
      echo "Waiting for stale deployments:"
      echo "$stale"
      sleep 10
    else
      echo "Deployed!"
      return 0
    fi
  done

  echo "Service update took too long."
  return 1
}

make_task_def(){
  task_template='[
    {
      "name": "opentraffic-datastore-%s",
      "image": "%s.dkr.ecr.%s.amazonaws.com/opentraffic/datastore-%s:%s",
      "essential": true,
      "memoryReservation": 512,
      "cpu": 512,
      "logConfiguration": {
        "logDriver": "awslogs",
          "options": {
          "awslogs-group": "datastore-%s",
          "awslogs-region": "%s"
        }
      },
      "environment": [
        {
          "name": "POSTGRES_HOST",
          "value": "%s"
        },
        {
          "name": "POSTGRES_PORT",
          "value": "%s"
        },
        {
          "name": "POSTGRES_USER",
          "value": "%s"
        },
        {
          "name": "POSTGRES_PASSWORD",
          "value": "%s"
        },
        {
          "name": "POSTGRES_DB",
          "value": "%s"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8003,
          "hostPort": 0
        }
      ]
    }
  ]'

  # figure out vars per env
  pg_host_raw=$(echo $`printf $ENV`_POSTGRES_HOST)
  pg_host=$(eval echo $pg_host_raw)

  pg_port_raw=$(echo $`printf $ENV`_POSTGRES_PORT)
  pg_port=$(eval echo $pg_port_raw)

  pg_db_raw=$(echo $`printf $ENV`_POSTGRES_DB)
  pg_db=$(eval echo $pg_db_raw)

  pg_user_raw=$(echo $`printf $ENV`_POSTGRES_USER)
  pg_user=$(eval echo $pg_user_raw)

  pg_password_raw=$(echo $`printf $ENV`_POSTGRES_PASSWORD)
  pg_password=$(eval echo $pg_password_raw)

  task_def=$(printf "$task_template" $ENV $AWS_ACCOUNT_ID $REGION $ENV $CIRCLE_SHA1 $ENV $REGION $pg_host $pg_port $pg_user $pg_password $pg_db)
}

push_ecr_image(){
  eval $(aws ecr get-login --region $REGION)
  docker tag datastore:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/opentraffic/datastore-$ENV:$CIRCLE_SHA1
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/opentraffic/datastore-$ENV:$CIRCLE_SHA1
}

register_definition() {
  if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
    echo "Revision: $revision"
  else
    echo "Failed to register task definition"
    return 1
  fi
}

configure_aws_cli
push_ecr_image
deploy_cluster
