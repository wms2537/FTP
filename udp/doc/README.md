| Author | Date       | Remarks | Rev |
|--------|------------|---------|-----|
| 苏伟铭 20222080074 | 2024-09-25 | Initial | 1.0 |

# UDP 
How to write a chat program (two clients chat with each other) with UDP?

To write a chat program where two clients can chat with each other using UDP, we have two options:

1. Use a server to relay messages between the clients.
2. Use a P2P model, where the clients are directly connected to each other.

### Option 1: Using a Server

In this model, the clients both establishes UDP sockets to send and receive messages from the server. The server receives a message and send it to the other client through the socket.


### Option 2: P2P Model

In this model, the clients are directly connected to each other. They both establishes UDP sockets to send and receive messages.



