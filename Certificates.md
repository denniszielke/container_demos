# Certificates

## Create self-signed certificate

```
echo "create private key"
openssl genrsa -des3 -out CAPrivate.key 2048

echo "create ca root certificate"
openssl req -x509 -new -nodes -key CAPrivate.key -sha256 -days 365 -out CAPrivate.pem

echo "create private key"
openssl genrsa -out MyPrivate.key 2048

echo "create signing request"
openssl req -new -key MyPrivate.key -extensions v3_ca -out MyRequest.csr

echo "create extensions file"
touch openssl.ss.cnf

basicConstraints=CA:FALSE
subjectAltName=DNS:*.mydomain.tld
extendedKeyUsage=serverAuth

echo "generate certificate using CSR"
openssl x509 -req -in MyRequest.csr -CA CAPrivate.pem -CAkey CAPrivate.key -CAcreateserial -extfile openssl.ss.cnf -out MyCert.crt -days 365 -sha256


```