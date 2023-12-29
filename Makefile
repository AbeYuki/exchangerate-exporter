DOCKERFILE_PATH = .

IMAGE_NAME = exchangerate-exporter

VERSION = 1.0.1

REGISTRY = abeyuki

PLATFORMS = linux/amd64,linux/arm64,linux/ppc64le,linux/s390x,linux/arm/v7,linux/arm/v8

define RELEASE_NOTES
## metrics

```
# HELP usd_jpy_exchange_rate Current exchange rate of USD to JPY
# TYPE usd_jpy_exchange_rate gauge
usd_jpy_exchange_rate 142.28
# HELP eur_jpy_exchange_rate Current exchange rate of EUR to JPY
# TYPE eur_jpy_exchange_rate gauge
eur_jpy_exchange_rate 156.73
```

## ExchageRate-API を利用

[ExchageRate-API](https://www.exchangerate-api.com/) は為替レート API サービスを提供しています。  
複数のプランがありアカウント登録を行い API_KEY を利用すると無料で1か月 1500 リクエストが可能です。  
[ここにプラン](https://www.exchangerate-api.com/#pricing)の情報があります。  
  
v4 の API バージョンはオープンで提供しており、1日1リクエストまで可能です。  
アカウント登録していない場合でも exchangerate-exporter が稼働するように v4 のエンドポイントを利用しています。  

## リクエスト制限について

exchangerate-exporter では1時間に1回 ExchageRate-API のエンドポイントに対してリクエストを行うようにしています。  
また、ExchageRate-API には USD と EUR のパスに対してリクエストを行うため 1回の動作で 2回の API リクエストを行います。
そのため月次で約 1440 リクエストを行います。  
環境変数の設定でリクエスト制限を解除することもできます。  

## 環境変数

デフォルトでは ExchageRate-API の v4 エンドポイントで動作しますが  
API_KEY の環境変数を設定することで v6 のエンドポイントで契約しているプランで動作します。  
```
API_KEY=apikey
```
デフォルトで1時間に1回のリクエストに制限していますが、LIMIT_1H=false に設定すると制限がなくなります。  
そのため prometheus のスクレイプの間隔で動作します。  
```
LIMIT_1H=false
```
デフォルト port は 9110 で動作します。  
PORT の環境変数を設定することで port を変更できます。  
```
ER_PORT=9110
```
デフォルトは 0.0.0.0 で全てのアドレスからのアクセスを許可します。
ER_IP の環境変数を設定することでアクセス元を指定できます。  
```
ER_IP=192.168.1.1
```

## API エンドポイントのパス
```
curl http://127.0.0.1:9110/metrics
```

## docker

```
docker run -itd -p 9110:9110 abeyuki/exchangerate-exporter:latest
```

## kubernetes

```
kubectl create deployment exchangerate-exporter --image=abeyuki/exchangerate-exporter --port=9110
```

endef

export RELEASE_NOTES


build:
	docker build --no-cache -t $(IMAGE_NAME):latest $(DOCKERFILE_PATH)
	docker build --no-cache -t $(IMAGE_NAME):$(VERSION) $(DOCKERFILE_PATH)

push:
	docker buildx build --no-cache --platform $(PLATFORMS) -t $(REGISTRY)/$(IMAGE_NAME):latest --push $(DOCKERFILE_PATH)
	docker buildx build --no-cache --platform $(PLATFORMS) -t $(REGISTRY)/$(IMAGE_NAME):$(VERSION) --push $(DOCKERFILE_PATH)

release:
	git tag $(VERSION)
	git push origin $(VERSION)
	echo "$$RELEASE_NOTES" | gh release create $(VERSION) -t "$(VERSION)" -F -
