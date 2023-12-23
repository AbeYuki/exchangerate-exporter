from fastapi import FastAPI, Response
from prometheus_client import CollectorRegistry, Gauge, generate_latest, CONTENT_TYPE_LATEST
import requests
import logging
import os
from datetime import datetime, timedelta

logger = logging.getLogger('uvicorn')
app = FastAPI()

registry = CollectorRegistry()
USD_JPY_RATE = Gauge('usd_jpy_exchange_rate', 'Current exchange rate of USD to JPY', registry=registry)
EUR_JPY_RATE = Gauge('eur_jpy_exchange_rate', 'Current exchange rate of EUR to JPY', registry=registry)

last_request_time = None

async def get_exchange_rate(currency_pair, gauge):
    try:
        api_key = os.getenv('API_KEY')
        if api_key:
            url = f"https://v6.exchangerate-api.com/v6/{api_key}/latest/{currency_pair}"
            logger.info(f"API_KEYが設定されているため、v6のエンドポイントを利用")
        else:
            url = f"https://api.exchangerate-api.com/v4/latest/{currency_pair}"
            logger.info(f"API_KEYが設定されていないため、v4のエンドポイントを利用")

        response = requests.get(url)
        if response.status_code != 200:
            logger.error(f"{currency_pair}のAPIリクエストに失敗しました。HTTP status: {response.status_code}")
            return

        data = response.json()
        if data.get("result") == "error":
            error_type = data.get("error-type", "unknown-error")
            logger.error(f"{currency_pair}のAPIリクエストした際にエラー応答。 error type: {error_type}")
            return

        if api_key:
            rates = data.get("conversion_rates", {})
        else:
            rates = data.get("rates", {})

        jpy_rate = rates.get("JPY")
        if jpy_rate:
            logger.info(f"{currency_pair} rate: {jpy_rate}")
            gauge.set(jpy_rate)

    except requests.RequestException as e:
        logger.error(f"{currency_pair}のAPIリクエストに失敗: {e}")
    except KeyError as e:
        logger.error(f"{currency_pair}のAPIレスポンスでkeyエラー : {e}")

@app.get("/metrics")
async def metrics():
    global last_request_time
    current_time = datetime.now()

    limit_enabled = not(os.getenv('LIMIT_1H', '').lower() == 'false')

    if not limit_enabled or not last_request_time or current_time - last_request_time >= timedelta(hours=1):
        await get_exchange_rate('USD', USD_JPY_RATE)
        await get_exchange_rate('EUR', EUR_JPY_RATE)
        last_request_time = current_time
    else:
        logger.info("1時間のAPIリクエスト制限が有効です。リクエストをスキップします。")

    return Response(generate_latest(registry), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    import uvicorn

    host = os.environ.get("HOST_IP", "0.0.0.0")
    port = int(os.environ.get("PORT", 9110))

    uvicorn.run("main:app", host=host, port=port, reload=True)
