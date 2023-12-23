FROM python:3.10
WORKDIR /usr/src/
COPY . ./
RUN pip install -r requirements.txt
ENTRYPOINT ["python", "main.py"]