// 引入websocket
const websocket = require('ws');

const ws = new websocket.Server({ port: 7080 }, () => {
    console.log("ws:// 0.0.0.0:" + 7080);
});// 创建一个websocket对象，监听端口7080

// 保存连接socket对象的set容器
var clients = new Set();

// 保存会话的sesssion容器
var sessions = [];

// 刷新房间内人员信息
function updatePeers() {
    var peers = [];
    clients.forEach(function (client) {
        var peer = {};

        if (client.hasOwnProperty('id')) {
            peer.id = client.id;
        }

        if (client.hasOwnProperty('name')) {
            peer.name = client.name;
        }

        if (client.hasOwnProperty('session_id')) {
            peer.session_id = client.session_id;
        }
        peers.push(peer);
    });

    var msg = {
        type: "peers",
        data: peers
    };

    clients.forEach(function (client) {
        send(client, JSON.stringify(msg));
    });
}

// 连接处理
ws.on('connection', function connection(client_self) {
    clients.add(client_self);

    //收到消息处理
    client_self.on('message', function (message) {
        try {
            message = JSON.parse(message);
            console.log("message.type::: " + message.type + ", \n body: " + JSON.stringify(message));

        } catch (e) {
            console.log(e.message);
        }

        switch (message.type) {
            // 新成员加入
            case 'new':
                {
                    client_self.id = "" + message.id;
                    client_self.name = message.name;
                    client_self.user_agent = message.user_agent;
                    // 向客户端发送有新用户进入房间需要刷新
                    updatePeers();
                }
                break;

            // 离开房间
            case 'bye':
                {
                    var session = null;
                    sessions.forEach((sess) => {
                        if (sess.id == message.session_id) {
                            session = sess;
                        }

                    });

                    if (!session) {
                        var msg = {
                            type: "error", data: {
                                error: "Invalid session" + message.session_id,
                            }
                        };
                        send(client_self, JSON.stringify(msg));
                        return;
                    }

                    clients.forEach((client) => {
                        if (client.session_id === message.session_id) {
                            var msg = {
                                type: "bye",
                                data: {
                                    session_id: message.session_id,
                                    from: message.from,
                                    to: (client.id == session.from ? session.to : session.from),
                                }
                            };
                            send(client,JSON.stringify(msg));

                        }
                    });

                    break;
                }
            // 转发offer
            case "offer": {
                var peer = null;
                clients.forEach(function (client) {
                    if (client.hasOwnProperty('id') && client.id === "" + message.to) {
                        peer = client;
                    }
                });
                if (peer != null) {
                    msg = {
                        type: "offer",
                        data: {
                            to: peer.id,
                            from: client_self.id,
                            session_id: message.session_id,
                            description: message.description,
                        }
                    }
                    send(peer, JSON.stringify(msg));

                    peer.session_id = message.session_id;
                    client_self.session_id = message.session_id;

                    let session = {
                        id: message.session_id,
                        from: client_self.id,
                        to: peer.id
                    };
                    sessions.push(session);
                }
            }
                break;
            // 转发answer
            case 'answer':
                {
                    var msg = {
                        type: "answer",
                        data: {
                            to: message.to,
                            from: client_self.id,
                            description: message.description,
                        }
                    };

                    clients.forEach(function (client) {
                        if (client.id === "" + message.to &&
                            client.session_id === message.session_id) {
                            send(client, JSON.stringify(msg));
                        }
                    });
                }
                break;

            // 收到候选者转发 candidate
            case 'candidate':
                {
                    var msg = {
                        type: "candidate",
                        data: {
                            from: client_self.id,
                            to: message.to,
                            candidate: message.candidate
                        }
                    };

                    clients.forEach(function (client) {
                        if (client.id === "" + message.to &&
                            client.session_id === message.session_id) {
                            send(client, JSON.stringify(msg));
                        }
                    });
                }
                break;
            // keepalive 心跳
            case "keepalive":
                {
                    send(client_self, JSON.stringify({ type: 'keepalive', data: {} }));
                }
                break;
        }
    });
});


// 发送消息
function send(client, message) {
    try {
        client.send(message);
    } catch (e) {
        console.log("Send failure !:" + e);
    }

}