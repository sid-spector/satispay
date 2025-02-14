from flask import Flask

app = Flask(__name__)

@app.route('/api/object', methods=['GET', 'POST'])
def handle_request():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)