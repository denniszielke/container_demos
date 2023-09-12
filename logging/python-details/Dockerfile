FROM python:3   

WORKDIR /app

ADD main.py /app/
ADD requirements.txt /app/

RUN pip install -r requirements.txt

CMD ["python main.py"]