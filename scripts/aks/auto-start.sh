#!/usr/bin/env bash
registrySlackWebhook=$1

function subscription () {
   
        SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
        az account set -s $SUBSCRIPTION_ID
        CLUSTERS=$(az resource list \
        --resource-type Microsoft.ContainerService/managedClusters \
        --query "[?tags.autoShutdown == 'true']" -o json)
}

function cluster () {
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
        NAME=$(jq -r '.name' <<< $cluster)
}

function ts_echo() {
    date +"%H:%M:%S $(printf "%s "  "$@")"
}

function notification() {
            ts_echo "$APP works in $ENVIRONMENT after $NAME start-up"
            curl -X POST --data-urlencode "payload={\"channel\": \"#aks-monitor-$ENV\", \"username\": \"AKS Auto-Start\", \"text\": \"$APP works in $ENVIRONMENT after $NAME start-up.\", \"icon_emoji\": \":tim-webster:\"}" \
            ${registrySlackWebhook}
}

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
subscription
    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        cluster
        ts_echo "About to start cluster $NAME (rg:$RESOURCE_GROUP)"
        az aks start --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors starting cluster $NAME 
    done
done

echo "Waiting 10 mins to give clusters time to start before testing pods"
sleep 600

# Tests
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
subscription
    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        cluster

        BUSINESS_AREA=$(jq -r '.tags.businessArea' <<< $cluster)
        if [[ "$BUSINESS_AREA" == "Cross-Cutting" ]]; then
            APP="toffee"
        elif [[ "$BUSINESS_AREA" == "CFT" ]]; then
            APP="plum"
        fi

        ENVIRONMENT=$(jq -r '.tags.environment' <<< $cluster)

        if [[ "$ENVIRONMENT" == "sandbox" || "$ENVIRONMENT" == "Sandbox" ]]; then
            ENV="sbox"
        elif [[ "$ENVIRONMENT" == "testing" ]]; then
            ENV="perftest"
        elif [[ "$ENVIRONMENT" == "staging" ]]; then
            ENV="aat"
        else
            ENV="$ENVIRONMENT"
        fi

        ts_echo "Test that $APP works in $ENVIRONMENT after $NAME start-up"
        if [[ "$ENVIRONMENT" == "testing" && "$APP" == "toffee" ]]; then
            APPLICATION="$APP.test"
        elif [[ "$ENVIRONMENT" == "testing" && "$APP" == "plum" ]]; then
            APPLICATION="$APP.perftest"
        elif [[ "$ENVIRONMENT" == "staging" && "$APP" == "toffee" ]]; then
            APPLICATION="$APP.staging"
        elif [[ "$ENVIRONMENT" == "staging" && "$APP" == "plum" ]]; then
            APPLICATION="$APP.aat"
        else 
            APPLICATION="$APP.$ENVIRONMENT"
        fi

            statuscode=$(curl --max-time 30 --retry 20 --retry-delay 15 -s -o /dev/null -w "%{http_code}"  https://$APPLICATION.platform.hmcts.net)

        if [[ "$ENVIRONMENT" == "demo" && $statuscode -eq 302 ]]; then
            notification
        elif [[ $statuscode -eq 200 ]]; then
            notification
        else
            ts_echo "$APP does not work in $ENVIRONMENT after $NAME start-up"
            curl -X POST --data-urlencode "payload={\"channel\": \"#green-daily-checks\", \"username\": \"AKS Auto-Start\", \"text\": \"$APP does not work in $ENVIRONMENT after $NAME start-up. Please check cluster.\", \"icon_emoji\": \":tim-webster:\"}" \
            ${registrySlackWebhook} 
            curl -X POST --data-urlencode "payload={\"channel\": \"#aks-monitor-$ENV\", \"username\": \"AKS Auto-Start\", \"text\": \"$APP does not work in $ENVIRONMENT after $NAME start-up. Please check cluster.\", \"icon_emoji\": \":tim-webster:\"}" \
            ${registrySlackWebhook}
        fi
    done
done

#Summary
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
subscription
    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
        cluster
        ts_echo $NAME
        RESULT=$(az aks show --name  $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
        ts_echo "${RESULT}"
    done
done
