from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/ip', methods=['GET'])
def name():
    return jsonify({'remoteip': request.remote_addr, 'realip':  request.environ.get('HTTP_X_REAL_IP', request.remote_addr), 'remoteaddr': request.environ['REMOTE_ADDR'] }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)