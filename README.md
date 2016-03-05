# A rexx socket server

A socket server coded in rexx, the server recieve data from client socket, when a whole packet arrived, the server invoke coresponding packet handler, after the packet handler proccessed the packet, the server send the result to client socket.

## Code organization

*socksvr.rexx:* socket server coded in rexx, the main logic of the server.

*strsvr.jcl:* jcl to run the server as a batch job in mainframe.

*config.ini:* configuration file to set server parameters and configure packet handler

*RXPDSMGT.rexx:* packet handler to read a pds member(or sequential dataset) and return the content to client

*RXSYSCMD.rexx:* packet handler to execute a command and return the result to client 

*pycli.py:* a sample python client to send packet to server and print the result

## Installation

1. use ftp to transfer config.ini, strsvr.jcl, socksvr.rexx, RXPDSMGT.rexx and RXSYSCMD.rexx to a pds in mainframe.
2. submit strsvr.jcl as a batch job.

Done! the server is ready for use!

## Packet format

#### Request packet

`8 bytes packet type + 10 bytes content length + content length bytes of content`

packet type is used to decide which packet handler to invoke to process the packet, and the content length is used to decide whether the whole packet is arrived. 

#### Response packet

`8 bytes message id + 10 bytes content lenght + content length bytes of content`

rule of message id:

- the first 2 bytes of message id is 'RX'

- the next 1 bytes represent module, 'S' means socket server main module, 'H' means packet handler.

- the next 4 bytes represent message number.

- the next 1 bytes represent message type. 'I' means information, 'W' means warning, 'E' means error.

commonly used message id:

- `RXH0000I`: packet proccessed sucessfully

- `RXS0001E`: packet handler interface error

- `RXS0002E`: packet handler not found

## Packet handler configuration

New packet handler can be conveniently added to the server, once new packet handler developped, you can configure as shown below:

1. edit configuration file, add a line like this: `packet_type=paket_handler  /* add a new packet handler */ `

2. put the new packet handler rexx scripts in the rexx library specified in the jcl
3. restart the server batch job.
