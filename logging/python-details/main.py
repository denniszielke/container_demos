from fastapi import FastAPI, Header, Request, status
from fastapi.responses import HTMLResponse, FileResponse, RedirectResponse
import uvicorn

app = FastAPI()

@app.get('/')
async def default(request: Request):
    return { 'remoteip': request.client.host, 'realip': request.headers.get('x-real-ip', request.client.host), 'remoteaddr': request.client.host}

@app.get('/ip')
async def ip(request: Request):
    return { 'remoteip': request.client.host, 'realip': request.headers.get('x-real-ip', request.client.host), 'remoteaddr': request.client.host}

@app.get('/headers')
async def header(request: Request):
    return request.headers

if __name__ == '__main__':
    uvicorn.run('main:app', host='0.0.0.0', port=8080)