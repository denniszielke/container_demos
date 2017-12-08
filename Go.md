# Building a go rest api

## Installing go on ubuntu bash
https://stefanprodan.com/2016/golang-bash-on-windows-installer/
```
GOURL=https://gist.githubusercontent.com/stefanprodan/29d738c3049a8714297a9bdd8353f31c/raw/1f3ae2cf97cb2faff52a8a3d98f0b6415d86c810/win10-bash-go-install.sh
curl -s -L $GOURL | sudo bash
```
or on ubuntu

https://github.com/golang/go/wiki/Ubuntu
```
sudo apt-get install golang-go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
```

## Running the demo
```
docker run -e "INSTRUMENTATIONKEY=4c3d38bd-58e3-480e-9fe1" -e "PORT=3001" -p 8080:3001 gocalcbackend

docker ps

docker stop
```

