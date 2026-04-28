echo "grafana password"
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode


echo "======================================"
echo "📊 FETCHING MONITORING URLS"
echo "======================================"

NAMESPACE="monitoring"


NODE_IP="192.168.56.10"


GRAFANA_PORT=$(kubectl get svc -n $NAMESPACE monitoring-grafana \
-o jsonpath='{.spec.ports[0].nodePort}')


PROM_PORT=$(kubectl get svc -n $NAMESPACE monitoring-kube-prometheus-prometheus \
-o jsonpath='{.spec.ports[0].nodePort}')


GRAFANA_URL="http://$NODE_IP:$GRAFANA_PORT"
PROM_URL="http://$NODE_IP:$PROM_PORT"


echo ""
echo "🎯 GRAFANA"
echo "--------------------------------------"
echo $GRAFANA_URL

echo ""
echo "🎯 PROMETHEUS"
echo "--------------------------------------"
echo $PROM_URL

echo ""
echo "======================================"
echo "✅ DONE"
echo "======================================"

echo "======================================"
echo "📊 ELK STACK (LOGGING) URL FETCHER"
echo "======================================"
NAMESPACE="logging"

NODE_IP="192.168.56.10"

ES_PORT=$(kubectl get svc elasticsearch -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')

KIBANA_PORT=$(kubectl get svc kibana -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')

ES_URL="http://$NODE_IP:$ES_PORT"
KIBANA_URL="http://$NODE_IP:$KIBANA_PORT"

echo ""
echo "📦 Elasticsearch"
echo "--------------------------------------"
echo $ES_URL
echo ""
echo "📊 Kibana"
echo "--------------------------------------"
echo $KIBANA_URL
echo ""
echo "======================================"
echo "✅ DONE"
echo "======================================"


echo "======================================"
echo "🌐 APPLICATION URLS"
echo "======================================"

kubectl get svc