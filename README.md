# Open Traffic Datastore

Open Traffic Datastore is part of OTv2, the new Open Traffic platform under development. It will take the place of OTv1's Data Pool and the back-end API portions of the [Traffic Engine Application](https://github.com/opentraffic/traffic-engine-app).

The Datastore ingests input from distributed [Reporter](https://github.com/opentraffic/reporter) instances, powers an API for querying and visualization, and creates processed data products.



### Docker
```
docker build -t opentraffic-datastore:v1.0.0 .

docker image tag opentraffic-datastore:v1.0.0 chenmiaowei/opentraffic-datastore:v1.0.0
docker push chenmiaowei/opentraffic-datastore:v1.0.0

docker run -it -p 8003:8003 -e POSTGRES_USER= -e POSTGRES_DB= -e POSTGRES_PASSWORD= -e POSTGRES_HOST= -e POSTGRES_PORT= opentraffic-datastore:v1.0.0
```